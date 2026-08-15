"""Deterministic greedy cycle scheduler."""

from __future__ import annotations

from dataclasses import dataclass
from math import ceil

from config.architecture import ArchitectureConfig
from ldpc_sim.banking import BankMap
from ldpc_sim.dependencies import latest_prior_producer, next_consumer
from ldpc_sim.forwarding import ForwardCache, ForwardEntry
from ldpc_sim.graph import Layer
from ldpc_sim.memory import QScratch, SignGenerationState
from ldpc_sim.metrics import STALL_CATEGORIES, SimulationMetrics
from ldpc_sim.pairing import EdgePair, build_pair_schedule
from ldpc_sim.pipeline import TokenPipeline


@dataclass
class ProducerUpdate:
    producer_position: int
    layer_id: int
    column: int
    pair_id: int
    rec_issue_cycle: int
    forward_valid_cycle: int
    memory_safe_cycle: int


@dataclass
class AccCandidate:
    position: int
    layer: Layer
    pair: EdgePair
    source_by_column: dict[int, str]
    forward_entries: dict[int, ForwardEntry]
    read_banks: set[int]
    priority: int
    score: int
    starts_layer: bool


@dataclass
class RecCandidate:
    position: int
    layer: Layer
    pair: EdgePair
    write_banks: set[int]
    forward_columns: list[int]
    next_consumers: dict[int, int | None]
    score: int


@dataclass
class CycleTrace:
    cycle: int
    acc: str
    rec: str
    forward: str
    stall: str

    def format(self) -> str:
        return (
            f"Cycle {self.cycle}\n"
            f"  ACC: {self.acc}\n"
            f"  REC: {self.rec}\n"
            f"  Forward: {self.forward}\n"
            f"  Stall: {self.stall}"
        )


@dataclass(frozen=True)
class AccIssueRecord:
    cycle: int
    position: int
    layer_id: int
    pair_id: int
    edge_ids: tuple[int, ...]
    columns: tuple[int, ...]
    qbuf: int
    qslot: int
    context: int
    source_by_column: dict[int, str]
    forward_slot_by_column: dict[int, int]
    read_banks: tuple[int, ...]
    starts_layer: bool


@dataclass(frozen=True)
class RecIssueRecord:
    cycle: int
    position: int
    layer_id: int
    pair_id: int
    edge_ids: tuple[int, ...]
    columns: tuple[int, ...]
    qbuf: int
    qslot: int
    write_banks: tuple[int, ...]
    forward_slot_by_column: dict[int, int]


@dataclass
class ScheduleResult:
    metrics: SimulationMetrics
    trace: list[CycleTrace]
    bank_map: BankMap
    pair_schedules: dict[int, tuple[EdgePair, ...]]
    layer_close_cycles: dict[int, int]
    acc_issues: list[AccIssueRecord]
    rec_issues: list[RecIssueRecord]


class GreedyScheduler:
    def __init__(
        self,
        ordered_layers: tuple[Layer, ...],
        config: ArchitectureConfig,
        bank_map: BankMap,
        trace_enabled: bool = False,
    ) -> None:
        self.ordered_layers = ordered_layers
        self.config = config
        self.bank_map = bank_map
        self.trace_enabled = trace_enabled
        self.pair_schedules = build_pair_schedule(
            ordered_layers, bank_map, config.pairing_strategy
        )
        self.acc_remaining = {
            pos: {pair.pair_id for pair in pairs}
            for pos, pairs in self.pair_schedules.items()
        }
        self.rec_remaining = {
            pos: {pair.pair_id for pair in pairs}
            for pos, pairs in self.pair_schedules.items()
        }
        self.started_positions: set[int] = set()
        self.layer_close_cycles: dict[int, int] = {}
        self.acc_issue_cycles: dict[tuple[int, int], int] = {}
        self.rec_issue_cycles: dict[tuple[int, int], int] = {}
        self.producer_updates: dict[tuple[int, int], ProducerUpdate] = {}
        self.forward_cache = ForwardCache(
            config.forward_cache_depth, config.enable_forwarding
        )
        self.qscratch = QScratch()
        self.sign_state = SignGenerationState()
        self.acc_pipeline = TokenPipeline("ACC", config.D_A)
        self.rec_pipeline = TokenPipeline("REC", config.D_R)
        self.stall_counts = {category: 0 for category in STALL_CATEGORIES}
        self.trace: list[CycleTrace] = []
        self.acc_issues: list[AccIssueRecord] = []
        self.rec_issues: list[RecIssueRecord] = []
        self.lookahead_cycles_hidden = 0
        self.forwarded_reads = 0
        self.normal_reads = 0
        self.max_contexts_seen = 0
        self.acc_issued_edges = 0
        self.rec_issued_edges = 0
        self.dual_issue_cycles = 0

    def run(self) -> ScheduleResult:
        cycle = 0
        last_rec_done_cycle = 0
        while not self._all_rec_issued():
            if cycle > self.config.max_cycles:
                raise RuntimeError(
                    f"Simulation exceeded max_cycles={self.config.max_cycles}."
                )
            self._update_closed_layers(cycle)
            self.forward_cache.retire(cycle)
            self.max_contexts_seen = max(
                self.max_contexts_seen, len(self._open_context_positions(cycle))
            )

            acc_candidates, acc_reasons = self._acc_candidates(cycle)
            rec_candidates, rec_reasons = self._rec_candidates(cycle)
            acc_choice, rec_choice = self._choose_issue_combo(
                acc_candidates, rec_candidates
            )

            acc_text = "idle"
            rec_text = "idle"
            forward_text = "none"
            stall_parts: list[str] = []

            if acc_choice is None:
                if (
                    rec_choice is not None
                    and acc_candidates
                    and all(
                        candidate.read_banks.intersection(rec_choice.write_banks)
                        for candidate in acc_candidates
                    )
                ):
                    acc_reasons.append("STALL_APP_BANK")
                reason = self._select_stall_reason(acc_reasons, "ACC")
                if reason is not None:
                    self.stall_counts[reason] += 1
                    stall_parts.append(f"ACC={reason}")
            else:
                acc_text = self._issue_acc(cycle, acc_choice)

            if rec_choice is None:
                if (
                    acc_choice is not None
                    and rec_candidates
                    and all(
                        acc_choice.read_banks.intersection(candidate.write_banks)
                        for candidate in rec_candidates
                    )
                ):
                    rec_reasons.append("STALL_APP_BANK")
                reason = self._select_stall_reason(rec_reasons, "REC")
                if reason is not None:
                    self.stall_counts[reason] += 1
                    stall_parts.append(f"REC={reason}")
            else:
                rec_text, forward_text = self._issue_rec(cycle, rec_choice)
                last_rec_done_cycle = max(
                    last_rec_done_cycle, cycle + self.config.D_R
                )

            if acc_choice is not None and rec_choice is not None:
                self.dual_issue_cycles += 1

            if self.trace_enabled:
                self.trace.append(
                    CycleTrace(
                        cycle=cycle,
                        acc=acc_text,
                        rec=rec_text,
                        forward=forward_text,
                        stall=", ".join(stall_parts) if stall_parts else "none",
                    )
                )
            cycle += 1

        cycles_per_iteration = max(last_rec_done_cycle, cycle)
        self.forward_cache.retire(
            cycles_per_iteration + self.config.app_commit_delay + 1
        )
        active_edges = sum(layer.degree for layer in self.ordered_layers)
        pair_slots = sum(len(pairs) for pairs in self.pair_schedules.values())
        service_lower_bound = pair_slots + max(
            len(pairs) for pairs in self.pair_schedules.values()
        )
        acc_cycles = list(self.acc_issue_cycles.values())
        rec_cycles = list(self.rec_issue_cycles.values())
        overlap_window_cycles = 0
        if acc_cycles and rec_cycles:
            first_overlap_cycle = min(rec_cycles)
            last_overlap_cycle = max(acc_cycles)
            if first_overlap_cycle <= last_overlap_cycle:
                overlap_window_cycles = last_overlap_cycle - first_overlap_cycle + 1
        metrics = SimulationMetrics(
            cycles_per_iteration=cycles_per_iteration,
            service_lower_bound=service_lower_bound,
            layer_order=tuple(layer.layer_id for layer in self.ordered_layers),
            ACC_issue_cycles=len(self.acc_issue_cycles),
            REC_issue_cycles=len(self.rec_issue_cycles),
            active_edges=active_edges,
            B=self.config.B,
            lookahead_cycles_hidden=self.lookahead_cycles_hidden,
            forwarded_APP_reads=self.forwarded_reads,
            normal_APP_reads=self.normal_reads,
            max_live_forward_vectors=self.forward_cache.max_occupancy,
            max_forward_lifetime=self.forward_cache.max_lifetime,
            min_forward_lifetime=self.forward_cache.min_lifetime,
            avg_forward_lifetime=self.forward_cache.average_lifetime,
            forward_overflow_events=self.forward_cache.overflow_events,
            dual_issue_cycles=self.dual_issue_cycles,
            overlap_window_cycles=overlap_window_cycles,
            stall_counts=dict(self.stall_counts),
            input_overhead=self.config.input_overhead,
            output_overhead=self.config.output_overhead,
            termination_overhead=self.config.termination_overhead,
            max_iterations=self.config.max_iterations,
            ipctek_cycles_per_iteration=self.config.ipctek_cycles_per_iteration,
            ipctek_fixed_overhead=self.config.ipctek_fixed_overhead,
        )
        return ScheduleResult(
            metrics=metrics,
            trace=self.trace,
            bank_map=self.bank_map,
            pair_schedules=self.pair_schedules,
            layer_close_cycles=dict(self.layer_close_cycles),
            acc_issues=list(self.acc_issues),
            rec_issues=list(self.rec_issues),
        )

    def _pair_by_id(self, position: int, pair_id: int) -> EdgePair:
        for pair in self.pair_schedules[position]:
            if pair.pair_id == pair_id:
                return pair
        raise KeyError(pair_id)

    def _all_acc_issued(self, position: int) -> bool:
        return not self.acc_remaining[position]

    def _all_rec_issued(self) -> bool:
        return all(not remaining for remaining in self.rec_remaining.values())

    def _update_closed_layers(self, cycle: int) -> None:
        for position in range(len(self.ordered_layers)):
            if position in self.layer_close_cycles:
                continue
            if position not in self.started_positions:
                continue
            if not self._all_acc_issued(position):
                continue
            issue_times = [
                self.acc_issue_cycles[(position, pair.pair_id)]
                for pair in self.pair_schedules[position]
            ]
            close_cycle = max(issue_times) + self.config.D_A
            if close_cycle <= cycle:
                self.layer_close_cycles[position] = close_cycle

    def _open_context_positions(self, cycle: int) -> set[int]:
        open_positions: set[int] = set()
        for position in self.started_positions:
            close_cycle = self.layer_close_cycles.get(position)
            if close_cycle is None or close_cycle > cycle:
                open_positions.add(position)
        return open_positions

    def _acc_candidates(self, cycle: int) -> tuple[list[AccCandidate], list[str]]:
        reasons: list[str] = []
        candidates: list[AccCandidate] = []
        if not self.acc_pipeline.can_issue(cycle):
            return [], ["STALL_PIPE_RESOURCE"]

        eligible_positions = self._eligible_acc_positions(cycle, reasons)
        for position in eligible_positions:
            starts_layer = position not in self.started_positions
            for pair_id in sorted(self.acc_remaining[position]):
                pair = self._pair_by_id(position, pair_id)
                candidate, reason = self._classify_acc_pair(
                    position, pair, cycle, starts_layer
                )
                if candidate is None:
                    reasons.append(reason)
                else:
                    candidates.append(candidate)
        return candidates, reasons

    def _eligible_acc_positions(self, cycle: int, reasons: list[str]) -> list[int]:
        positions = [
            position
            for position in sorted(self.started_positions)
            if self.acc_remaining[position]
        ]

        next_unstarted = None
        for position in range(len(self.ordered_layers)):
            if position not in self.started_positions:
                next_unstarted = position
                break
        if next_unstarted is None:
            return positions

        if next_unstarted == 0:
            positions.append(next_unstarted)
            return positions

        previous = next_unstarted - 1
        previous_closed = previous in self.layer_close_cycles
        open_contexts = self._open_context_positions(cycle)

        if previous_closed:
            positions.append(next_unstarted)
        elif self.config.enable_lookahead:
            if len(open_contexts) < self.config.num_acc_contexts:
                positions.append(next_unstarted)
            else:
                reasons.append("STALL_CONTEXT")
        else:
            reasons.append("STALL_RAW")
        return positions

    def _classify_acc_pair(
        self,
        position: int,
        pair: EdgePair,
        cycle: int,
        starts_layer: bool,
    ) -> tuple[AccCandidate | None, str]:
        qbuf = self.qscratch.qbuf_for_position(position)
        if not self.qscratch.can_reserve(qbuf, pair.pair_id, cycle):
            return None, "STALL_Q_BUFFER"

        source_by_column: dict[int, str] = {}
        forward_entries: dict[int, ForwardEntry] = {}
        read_banks: set[int] = set()
        dependent = False
        used_forward = False
        for edge in pair.edges:
            producer_pos = latest_prior_producer(
                self.ordered_layers, position, edge.column
            )
            if producer_pos is None:
                source_by_column[edge.column] = f"APP bank {self.bank_map.bank(edge.column)}"
                read_banks.add(self.bank_map.bank(edge.column))
                continue

            dependent = True
            update = self.producer_updates.get((producer_pos, edge.column))
            if update is None:
                return None, "STALL_RAW"

            entry = self.forward_cache.find(edge.column, producer_pos, cycle)
            if self.config.enable_forwarding and entry is not None:
                source_by_column[edge.column] = f"FORWARD slot {entry.slot}"
                forward_entries[edge.column] = entry
                used_forward = True
            elif update.memory_safe_cycle <= cycle:
                source_by_column[edge.column] = f"APP bank {self.bank_map.bank(edge.column)}"
                read_banks.add(self.bank_map.bank(edge.column))
            else:
                return None, "STALL_RAW"

        if len(read_banks) != len(
            [
                column
                for column, source in source_by_column.items()
                if source.startswith("APP")
            ]
        ):
            return None, "STALL_APP_BANK"

        if not self.config.enable_lookahead and starts_layer and position > 0:
            previous = position - 1
            if previous not in self.layer_close_cycles:
                return None, "STALL_RAW"

        priority = 1 if not dependent else 2 if used_forward else 3
        independent_bonus = 100 if not dependent else 0
        forward_bonus = 60 if used_forward else 0
        tail_penalty = 0 if pair.lane_count == self.config.B else -20
        score = (
            1000
            - priority * 100
            + independent_bonus
            + forward_bonus
            + pair.lane_count * 10
            + tail_penalty
            - pair.pair_id
        )
        return (
            AccCandidate(
                position=position,
                layer=self.ordered_layers[position],
                pair=pair,
                source_by_column=source_by_column,
                forward_entries=forward_entries,
                read_banks=read_banks,
                priority=priority,
                score=score,
                starts_layer=starts_layer,
            ),
            "",
        )

    def _rec_candidates(self, cycle: int) -> tuple[list[RecCandidate], list[str]]:
        reasons: list[str] = []
        candidates: list[RecCandidate] = []
        if not self.rec_pipeline.can_issue(cycle):
            return [], ["STALL_PIPE_RESOURCE"]

        eligible_positions = [
            position
            for position in range(len(self.ordered_layers))
            if position in self.layer_close_cycles and self.rec_remaining[position]
        ]
        if not eligible_positions and any(self.rec_remaining.values()):
            reasons.append("STALL_REC_NOT_CLOSED")
            return [], reasons

        if not self.config.enable_reconstruction_reorder and eligible_positions:
            first = min(eligible_positions)
            next_pair_id = min(self.rec_remaining[first])
            eligible_pair_ids = {first: {next_pair_id}}
        else:
            eligible_pair_ids = {
                position: set(self.rec_remaining[position])
                for position in eligible_positions
            }

        for position, pair_ids in eligible_pair_ids.items():
            for pair_id in sorted(pair_ids):
                pair = self._pair_by_id(position, pair_id)
                candidate, reason = self._classify_rec_pair(position, pair, cycle)
                if candidate is None:
                    reasons.append(reason)
                else:
                    candidates.append(candidate)
        return candidates, reasons

    def _classify_rec_pair(
        self, position: int, pair: EdgePair, cycle: int
    ) -> tuple[RecCandidate | None, str]:
        qbuf = self.qscratch.qbuf_for_position(position)
        if not self.qscratch.can_read(qbuf, pair.pair_id, cycle):
            return None, "STALL_Q_BUFFER"

        write_banks = {self.bank_map.bank(column) for column in pair.columns}
        if len(write_banks) != len(pair.columns):
            return None, "STALL_APP_BANK"

        next_consumers = {
            column: next_consumer(self.ordered_layers, position, column)
            for column in pair.columns
        }
        forward_columns = self._select_forward_columns(
            position, pair, next_consumers, cycle
        )

        next_layer_columns = (
            self.ordered_layers[position + 1].columns
            if position + 1 < len(self.ordered_layers)
            else frozenset()
        )
        urgent_columns = sum(1 for column in pair.columns if column in next_layer_columns)
        future_columns = sum(1 for column in pair.columns if next_consumers[column] is not None)
        forward_need = sum(
            self._forward_need_score(position, column, next_consumers[column], cycle)
            for column in forward_columns
        )
        live_after_issue = self.forward_cache.live_count() + len(forward_columns)
        score = (
            urgent_columns * 200
            + future_columns * 35
            + forward_need
            + pair.lane_count * 10
            - live_after_issue * 25
            - pair.pair_id
        )
        return (
            RecCandidate(
                position=position,
                layer=self.ordered_layers[position],
                pair=pair,
                write_banks=write_banks,
                forward_columns=forward_columns,
                next_consumers=next_consumers,
                score=score,
            ),
            "",
        )

    def _select_forward_columns(
        self,
        position: int,
        pair: EdgePair,
        next_consumers: dict[int, int | None],
        cycle: int,
    ) -> list[int]:
        if not self.config.enable_forwarding or self.config.forward_cache_depth == 0:
            return []

        candidate_columns = [
            column for column in pair.columns if next_consumers[column] is not None
        ]
        if not candidate_columns:
            return []

        if not self.config.enable_jit_forwarding:
            if not self.forward_cache.can_allocate(len(candidate_columns), cycle):
                raise RuntimeError("Forward cache capacity exceeded.")
            return candidate_columns

        free_slots = self.forward_cache.available_slots(cycle)
        if free_slots <= 0:
            return []

        ranked = sorted(
            candidate_columns,
            key=lambda column: (
                -self._forward_need_score(
                    position, column, next_consumers[column], cycle
                ),
                column,
            ),
        )
        useful = [
            column
            for column in ranked
            if self._forward_need_score(position, column, next_consumers[column], cycle)
            > 0
        ]
        return useful[:free_slots]

    def _forward_need_score(
        self,
        producer_position: int,
        column: int,
        consumer_position: int | None,
        cycle: int,
    ) -> int:
        if consumer_position is None:
            return 0
        if consumer_position <= producer_position:
            return 0

        consumer_pair_id = self._consumer_pair_id(consumer_position, column)
        if consumer_pair_id is None:
            return 0
        if consumer_pair_id not in self.acc_remaining.get(consumer_position, set()):
            return 0

        distance = consumer_position - producer_position
        score = max(25, 250 - distance * 30)
        if consumer_position == producer_position + 1:
            score += 250
        if consumer_position in self.started_positions:
            score += 120

        next_unstarted = None
        for position in range(len(self.ordered_layers)):
            if position not in self.started_positions:
                next_unstarted = position
                break
        if consumer_position == next_unstarted:
            score += 80

        valid_cycle = cycle + self.config.D_R
        memory_safe_cycle = valid_cycle + self.config.app_commit_delay
        if memory_safe_cycle - valid_cycle > 0:
            score += 20
        return score

    def _consumer_pair_id(self, position: int, column: int) -> int | None:
        for pair in self.pair_schedules[position]:
            if column in pair.columns:
                return pair.pair_id
        return None

    def _choose_issue_combo(
        self,
        acc_candidates: list[AccCandidate],
        rec_candidates: list[RecCandidate],
    ) -> tuple[AccCandidate | None, RecCandidate | None]:
        best: tuple[int, AccCandidate | None, RecCandidate | None] | None = None
        acc_options: list[AccCandidate | None] = [None] + acc_candidates
        rec_options: list[RecCandidate | None] = [None] + rec_candidates

        for acc in acc_options:
            for rec in rec_options:
                if acc is None and rec is None:
                    continue
                if acc is not None and rec is not None:
                    if acc.read_banks.intersection(rec.write_banks):
                        continue
                score = 0
                if acc is not None:
                    score += 10000 + acc.score
                if rec is not None:
                    score += 10000 + rec.score
                if acc is not None and rec is not None:
                    score += 500
                candidate = (score, acc, rec)
                if best is None or candidate[0] > best[0]:
                    best = candidate
        if best is None:
            return None, None
        return best[1], best[2]

    def _issue_acc(self, cycle: int, candidate: AccCandidate) -> str:
        if candidate.starts_layer:
            self.started_positions.add(candidate.position)
        self.acc_pipeline.issue(
            cycle,
            candidate.layer.layer_id,
            candidate.pair.pair_id,
            context=candidate.position % self.config.num_acc_contexts,
        )
        qbuf = self.qscratch.qbuf_for_position(candidate.position)
        self.qscratch.reserve_write(
            qbuf=qbuf,
            qslot=candidate.pair.pair_id,
            layer_position=candidate.position,
            layer_id=candidate.layer.layer_id,
            pair_id=candidate.pair.pair_id,
            written_cycle=cycle + self.config.D_A,
            cycle=cycle,
        )
        self.acc_remaining[candidate.position].remove(candidate.pair.pair_id)
        self.acc_issue_cycles[(candidate.position, candidate.pair.pair_id)] = cycle
        self.acc_issued_edges += candidate.pair.lane_count

        for entry in candidate.forward_entries.values():
            self.forward_cache.consume(entry, cycle)
        self.forwarded_reads += len(candidate.forward_entries)
        self.normal_reads += sum(
            1 for source in candidate.source_by_column.values() if source.startswith("APP")
        )

        previous = candidate.position - 1
        if (
            self.config.enable_lookahead
            and previous >= 0
            and previous not in self.layer_close_cycles
        ):
            self.lookahead_cycles_hidden += 1

        self.acc_issues.append(
            AccIssueRecord(
                cycle=cycle,
                position=candidate.position,
                layer_id=candidate.layer.layer_id,
                pair_id=candidate.pair.pair_id,
                edge_ids=tuple(edge.edge_id for edge in candidate.pair.edges),
                columns=candidate.pair.columns,
                qbuf=qbuf,
                qslot=candidate.pair.pair_id,
                context=candidate.position % self.config.num_acc_contexts,
                source_by_column=dict(candidate.source_by_column),
                forward_slot_by_column={
                    column: entry.slot
                    for column, entry in candidate.forward_entries.items()
                },
                read_banks=tuple(sorted(candidate.read_banks)),
                starts_layer=candidate.starts_layer,
            )
        )

        source_text = ", ".join(
            f"col {column}: {source}"
            for column, source in sorted(candidate.source_by_column.items())
        )
        return (
            f"layer {candidate.layer.layer_id} context "
            f"{candidate.position % self.config.num_acc_contexts} "
            f"pair {candidate.pair.pair_id} columns {list(candidate.pair.columns)} "
            f"sources [{source_text}] qbuf QBUF{qbuf} qslot {candidate.pair.pair_id}"
        )

    def _issue_rec(self, cycle: int, candidate: RecCandidate) -> tuple[str, str]:
        self.rec_pipeline.issue(
            cycle,
            candidate.layer.layer_id,
            candidate.pair.pair_id,
            qbuf=self.qscratch.qbuf_for_position(candidate.position),
        )
        qbuf = self.qscratch.qbuf_for_position(candidate.position)
        self.qscratch.mark_read(
            qbuf,
            candidate.pair.pair_id,
            release_cycle=cycle + self.config.D_R,
        )
        valid_cycle = cycle + self.config.D_R
        memory_safe_cycle = valid_cycle + self.config.app_commit_delay

        created_entries: list[ForwardEntry] = []
        if candidate.forward_columns:
            created_entries = self.forward_cache.allocate_many(
                columns=candidate.forward_columns,
                producer_position=candidate.position,
                producer_layer=candidate.layer.layer_id,
                valid_cycle=valid_cycle,
                memory_safe_cycle=memory_safe_cycle,
                next_consumers=candidate.next_consumers,
                cycle=cycle,
            )

        for column in candidate.pair.columns:
            self.producer_updates[(candidate.position, column)] = ProducerUpdate(
                producer_position=candidate.position,
                layer_id=candidate.layer.layer_id,
                column=column,
                pair_id=candidate.pair.pair_id,
                rec_issue_cycle=cycle,
                forward_valid_cycle=valid_cycle,
                memory_safe_cycle=memory_safe_cycle,
            )

        self.rec_remaining[candidate.position].remove(candidate.pair.pair_id)
        self.rec_issue_cycles[(candidate.position, candidate.pair.pair_id)] = cycle
        self.rec_issued_edges += candidate.pair.lane_count
        write_banks = sorted(candidate.write_banks)
        self.rec_issues.append(
            RecIssueRecord(
                cycle=cycle,
                position=candidate.position,
                layer_id=candidate.layer.layer_id,
                pair_id=candidate.pair.pair_id,
                edge_ids=tuple(edge.edge_id for edge in candidate.pair.edges),
                columns=candidate.pair.columns,
                qbuf=qbuf,
                qslot=candidate.pair.pair_id,
                write_banks=tuple(write_banks),
                forward_slot_by_column={
                    entry.column: entry.slot for entry in created_entries
                },
            )
        )
        rec_text = (
            f"layer {candidate.layer.layer_id} pair {candidate.pair.pair_id} "
            f"qbuf QBUF{qbuf} columns {list(candidate.pair.columns)} "
            f"APP write banks {write_banks}"
        )
        if created_entries:
            forward_text = ", ".join(
                f"created col {entry.column} -> slot {entry.slot} valid {entry.valid_cycle}"
                for entry in created_entries
            )
        else:
            forward_text = "none"
        return rec_text, forward_text

    def _select_stall_reason(self, reasons: list[str], pipeline: str) -> str | None:
        if pipeline == "ACC" and all(not remaining for remaining in self.acc_remaining.values()):
            return None
        if pipeline == "REC" and self._all_rec_issued():
            return None
        if not reasons:
            return "STALL_OTHER"
        priority = [
            "STALL_RAW",
            "STALL_APP_BANK",
            "STALL_Q_BUFFER",
            "STALL_FORWARD_CAPACITY",
            "STALL_CONTEXT",
            "STALL_REC_NOT_CLOSED",
            "STALL_PIPE_RESOURCE",
            "STALL_PAIRING",
            "STALL_OTHER",
        ]
        reason_set = set(reasons)
        for reason in priority:
            if reason in reason_set:
                return reason
        return "STALL_OTHER"


def expected_pair_slots(layers: tuple[Layer, ...], b: int = 2) -> int:
    return sum(ceil(layer.degree / b) for layer in layers)
