from __future__ import annotations

from collections import defaultdict
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ldpc_sim.banking import build_bank_map
from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.graph import Edge
from ldpc_sim.production_v1 import PRODUCTION_V1, sha256_json
from ldpc_sim.schedule_encoding import unpack_instruction
from ldpc_sim.syndrome import (
    FinalTouch,
    FinalTouchAnalysis,
    SyndromeWorkItem,
    simulate_syndrome_engine,
)


OUT_DIR = ROOT / "results" / "rtl_handoff_category_b"
CATEGORY_A_DIR = ROOT / "results" / "rtl_handoff_category_a"
SCHEDULE_PATH = CATEGORY_A_DIR / "schedule_program.json"
PROFILE_PATH = CATEGORY_A_DIR / "profile_metadata.json"
PHASE1_LOG = ROOT / "results" / "rtl_phase1" / "rtl_phase1_iverilog.log"
PHASE2_LOG = ROOT / "results" / "rtl_phase2" / "rtl_phase2_iverilog.log"
PHASE2_QC_JSON = ROOT / "results" / "rtl_phase2" / "qc_python_crosscheck.json"
PHASE3_LOG = ROOT / "results" / "rtl_phase3" / "rtl_phase3_iverilog.log"
VALIDATION_PATH = OUT_DIR / "validation_evidence.json"


@dataclass(frozen=True)
class LaneUse:
    edge_id: int
    column: int
    bank: int
    aux: int
    final_touch: int


@dataclass
class ForwardEntry:
    slot: int
    column: int
    producer_layer: int
    producer_edge_id: int
    rec_issue_cycle: int
    valid_cycle: int
    memory_safe_cycle: int
    created_cycle: int
    consumed_cycle: int | None = None


@dataclass
class QRecord:
    qbuf: int
    qslot: int
    layer_id: int
    edge_ids: tuple[int, ...]
    reserve_cycle: int
    write_visible_cycle: int
    release_cycle: int | None = None


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(
        json.dumps(data, indent=2, sort_keys=True, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def fmt_order(order: tuple[int, ...]) -> str:
    return "-".join(str(item) for item in order)


def decide_after_syndrome(
    completed_iterations: int,
    max_iterations: int,
    syndrome_zero: bool,
) -> dict[str, Any]:
    if not 1 <= max_iterations <= 15:
        raise ValueError("max_iterations must be in the legal range 1..15.")
    completed_next = completed_iterations + 1
    if syndrome_zero:
        action = "terminate_success"
    elif completed_next >= max_iterations:
        action = "terminate_max_iterations"
    else:
        action = "launch_next_iteration"
    return {
        "completed_iterations_before_decide": completed_iterations,
        "completed_next": completed_next,
        "max_iterations": max_iterations,
        "syndrome_zero": syndrome_zero,
        "action": action,
        "completed_iterations_after_decide": completed_next,
    }


def max_iteration_boundary_tests() -> dict[str, Any]:
    tests: dict[str, Any] = {}
    for max_iterations in (1, 2, 12, 15):
        completed = 0
        decisions: list[dict[str, Any]] = []
        for _ in range(20):
            decision = decide_after_syndrome(
                completed,
                max_iterations,
                syndrome_zero=False,
            )
            decisions.append(decision)
            if decision["action"] != "launch_next_iteration":
                break
            completed = int(decision["completed_iterations_after_decide"])
        require(
            decisions[-1]["action"] == "terminate_max_iterations",
            f"max_iterations={max_iterations} did not terminate by max count.",
        )
        require(
            decisions[-1]["completed_next"] == max_iterations,
            f"max_iterations={max_iterations} off-by-one failure.",
        )
        require(
            decisions[-1]["completed_iterations_after_decide"] == max_iterations,
            f"max_iterations={max_iterations} final counter mismatch.",
        )
        success = decide_after_syndrome(
            completed_iterations=0,
            max_iterations=max_iterations,
            syndrome_zero=True,
        )
        require(
            success["action"] == "terminate_success",
            f"max_iterations={max_iterations} syndrome-zero path failed.",
        )
        tests[str(max_iterations)] = {
            "all_fail_iterations_executed": decisions[-1]["completed_next"],
            "all_fail_completed_iterations_after_decide": decisions[-1][
                "completed_iterations_after_decide"
            ],
            "all_fail_terminal_action": decisions[-1]["action"],
            "syndrome_zero_completed_iterations_after_decide": success[
                "completed_iterations_after_decide"
            ],
            "syndrome_zero_terminal_action_after_one_iteration": success["action"],
            "pass": True,
        }
    return tests


def logical_read_latency_table() -> list[dict[str, Any]]:
    return [
        {
            "structure": "APP ordinary read",
            "request_address_cycle": "ACC issue c / A0",
            "data_valid_cycle": "during A0 cycle c",
            "consumer_stage": "A0 source selection and forward QC permutation; A0 result is registered for A1 at c+1",
            "same_cycle_combinational_read_required": True,
            "one_cycle_synchronous_read_allowed": False,
            "prefetch_required": False,
            "bypass_requirement": "If ACC aux selects a forward slot, APP memory is not read; the forward slot APP follows the same A0 timing and must be available during c for QC permutation.",
        },
        {
            "structure": "old compressed layer-state read",
            "request_address_cycle": "ACC issue c / A0",
            "data_valid_cycle": "c+1",
            "consumer_stage": "A1 reconstructs oldC2V with old q_sign",
            "same_cycle_combinational_read_required": False,
            "one_cycle_synchronous_read_allowed": True,
            "prefetch_required": False,
            "bypass_requirement": "If the old generation is invalid for the current block/epoch, reconstruction returns logical zero; no M1/M2/Imin sentinel is observed.",
        },
        {
            "structure": "old q_sign read",
            "request_address_cycle": "ACC issue c / A0",
            "data_valid_cycle": "c+1",
            "consumer_stage": "A1 reconstructs oldC2V sign",
            "same_cycle_combinational_read_required": False,
            "one_cycle_synchronous_read_allowed": True,
            "prefetch_required": False,
            "bypass_requirement": "Same invalid-old-generation zero rule as old compressed layer state.",
        },
        {
            "structure": "new compressed layer-state read",
            "request_address_cycle": "REC issue c / R0",
            "data_valid_cycle": "during R0 cycle c",
            "consumer_stage": "R0 reconstructs newC2V",
            "same_cycle_combinational_read_required": True,
            "one_cycle_synchronous_read_allowed": False,
            "prefetch_required": False,
            "bypass_requirement": "If closing ACC issues at x, new state is visible at start x+3; a REC issued at c=x+3 may consume that newly published state during R0 c.",
        },
        {
            "structure": "new q_sign read",
            "request_address_cycle": "REC issue c / R0",
            "data_valid_cycle": "during R0 cycle c",
            "consumer_stage": "R0 reconstructs newC2V sign",
            "same_cycle_combinational_read_required": True,
            "one_cycle_synchronous_read_allowed": False,
            "prefetch_required": False,
            "bypass_requirement": "Must match the new compressed layer-state generation and iteration epoch; mismatch is fatal.",
        },
        {
            "structure": "q scratch read",
            "request_address_cycle": "REC issue c / R0",
            "data_valid_cycle": "c+1",
            "consumer_stage": "R1 computes APP update with q and newC2V",
            "same_cycle_combinational_read_required": False,
            "one_cycle_synchronous_read_allowed": True,
            "prefetch_required": False,
            "bypass_requirement": "A read at the q write-visible boundary must return the written q vector or be proven absent by schedule validation; no hidden cycle is allowed.",
        },
    ]


def edge_lookup(graph) -> dict[int, dict[int, Edge]]:
    return {
        layer.layer_id: {edge.edge_id: edge for edge in layer.edges}
        for layer in graph.layers
    }


def instruction_lanes(inst, edge_by_layer, bank_map) -> tuple[LaneUse, ...]:
    lanes: list[LaneUse] = []
    for edge_id, aux, final_touch in zip(
        inst.edge_ids, inst.aux_values, inst.final_touch_values
    ):
        edge = edge_by_layer[inst.layer_id][edge_id]
        lanes.append(
            LaneUse(
                edge_id=edge_id,
                column=edge.column,
                bank=bank_map.bank(edge.column),
                aux=aux,
                final_touch=final_touch,
            )
        )
    return tuple(lanes)


def selected_profile() -> tuple[Any, dict[str, Any], dict[str, Any]]:
    profile_data = read_json(PROFILE_PATH)
    schedule_data = read_json(SCHEDULE_PATH)
    profile = profile_data["profile"]
    graph = load_3gpp_base_graph(
        int(profile["base_graph"]),
        int(profile["Z"]),
        int(profile["iLS"]),
        active_layer_ids=tuple(int(item) for item in profile["active_layers"]),
    )
    return graph, profile_data, schedule_data


def retire_forward_slots(
    slots: dict[int, ForwardEntry],
    cycle: int,
    lifetimes: list[int],
) -> None:
    for slot, entry in list(slots.items()):
        consumed_and_past = (
            entry.consumed_cycle is not None and entry.consumed_cycle < cycle
        )
        memory_safe = entry.memory_safe_cycle <= cycle
        if consumed_and_past or memory_safe:
            if entry.consumed_cycle is None:
                lifetimes.append(entry.memory_safe_cycle - entry.created_cycle)
            else:
                lifetimes.append(entry.consumed_cycle - entry.created_cycle)
            del slots[slot]


def build_final_touch_analysis(
    graph,
    rec_final_touches: dict[int, dict[int, bool]],
    rec_touch_records: dict[int, list[tuple[int, int, int, int]]],
    d_r: int,
) -> FinalTouchAnalysis:
    active_columns = set(graph.columns)
    final_by_column: dict[int, FinalTouch] = {}
    for cycle, flags in sorted(rec_final_touches.items()):
        for column, is_final in flags.items():
            if not is_final:
                continue
            matching = [
                item
                for item in rec_touch_records[cycle]
                if item[2] == column
            ]
            require(len(matching) == 1, f"Cannot resolve final-touch column {column}.")
            layer_id, edge_id, _, pair_id = matching[0]
            require(column not in final_by_column, f"Column {column} finalized twice.")
            final_by_column[column] = FinalTouch(
                column=column,
                final_position=-1,
                final_layer_id=layer_id,
                final_edge_id=edge_id,
                rec_pair_id=pair_id,
                rec_issue_cycle=cycle,
                final_valid_cycle=cycle + d_r,
            )
    omitted = active_columns.difference(final_by_column)
    require(not omitted, f"Active columns omitted from final touch: {sorted(omitted)}")
    extra = set(final_by_column).difference(active_columns)
    require(not extra, f"Inactive columns finalized: {sorted(extra)}")

    expected_edges: set[tuple[int, int, int, int]] = set()
    work_by_column: dict[int, list[SyndromeWorkItem]] = {
        column: [] for column in active_columns
    }
    for layer in graph.layers:
        for edge in layer.edges:
            key = (edge.layer_id, edge.edge_id, edge.column, edge.shift)
            require(key not in expected_edges, f"Duplicate QC edge: {key}")
            expected_edges.add(key)
            touch = final_by_column[edge.column]
            work_by_column[edge.column].append(
                SyndromeWorkItem(
                    layer_id=edge.layer_id,
                    edge_id=edge.edge_id,
                    column=edge.column,
                    shift=edge.shift,
                    final_valid_cycle=touch.final_valid_cycle,
                )
            )

    return FinalTouchAnalysis(
        final_by_column=final_by_column,
        final_touch_by_rec_cycle=rec_final_touches,
        work_by_column={
            column: tuple(sorted(items, key=lambda item: (item.layer_id, item.edge_id)))
            for column, items in work_by_column.items()
        },
    )


def analyze_schedule() -> dict[str, Any]:
    graph, profile_data, schedule_data = selected_profile()
    profile = profile_data["profile"]
    expected = schedule_data["expected_metrics"]
    cfg = PRODUCTION_V1
    bank_map = build_bank_map(graph, cfg.num_app_banks, "optimized")
    edge_by_layer = edge_lookup(graph)
    layer_order = tuple(int(item) for item in profile["layer_order"])
    position_by_layer = {layer_id: pos for pos, layer_id in enumerate(layer_order)}
    layer_degree = {layer.layer_id: layer.degree for layer in graph.layers}

    issue_words = schedule_data["issue_words"]
    require(len(issue_words) == expected["decoder_cycles_per_iteration"], "program length mismatch")

    q_records: dict[tuple[int, int], QRecord] = {}
    forward_slots: dict[int, ForwardEntry] = {}
    forward_lifetimes: list[int] = []
    final_touch_flags_by_cycle: dict[int, dict[int, bool]] = {}
    rec_touch_records: dict[int, list[tuple[int, int, int, int]]] = {}

    app_issue_rows: list[dict[str, Any]] = []
    physical_app_collisions: list[dict[str, Any]] = []
    q_port_by_cycle: dict[int, dict[str, int]] = defaultdict(
        lambda: {"reads": 0, "writes": 0}
    )
    check_port_by_cycle: dict[int, dict[str, int]] = defaultdict(
        lambda: {
            "acc_old_layer_vector_reads": 0,
            "acc_old_qsign_edge_reads": 0,
            "rec_new_layer_vector_reads": 0,
            "rec_new_qsign_edge_reads": 0,
            "a2_new_qsign_edge_writes": 0,
            "a2_context_updates": 0,
            "layer_close_commits": 0,
        }
    )

    app_reads_by_cycle: dict[int, list[LaneUse]] = defaultdict(list)
    app_writes_by_issue_cycle: dict[int, list[LaneUse]] = defaultdict(list)
    app_writes_by_r2_cycle: dict[int, list[LaneUse]] = defaultdict(list)

    acc_count = 0
    rec_count = 0
    acc_edges = 0
    rec_edges = 0
    normal_app_reads = 0
    forwarded_app_reads = 0
    forward_allocations = 0
    max_forward_live = 0
    last_acc_cycle_by_layer: dict[int, int] = {}
    first_acc_cycle_by_layer: dict[int, int] = {}
    first_rec_cycle_by_layer: dict[int, int] = {}
    last_rec_cycle_by_layer: dict[int, int] = {}
    acc_edges_by_layer: dict[int, set[int]] = defaultdict(set)
    rec_edges_by_layer: dict[int, set[int]] = defaultdict(set)

    for word in issue_words:
        cycle = int(word["cycle"])
        retire_forward_slots(forward_slots, cycle, forward_lifetimes)

        acc = unpack_instruction(int(word["acc36_hex"], 16))
        rec = unpack_instruction(int(word["rec36_hex"], 16))
        ordinary_read_lanes: list[LaneUse] = []
        write_lanes: list[LaneUse] = []

        if acc.valid:
            acc_count += 1
            require(acc.qbuf in (0, 1), f"ACC qbuf out of range at cycle {cycle}")
            require(0 <= acc.qslot <= 9, f"ACC qslot out of range at cycle {cycle}")
            require(
                acc.qbuf == position_by_layer[acc.layer_id] % 2,
                f"ACC qbuf does not match layer position at cycle {cycle}",
            )
            lanes = instruction_lanes(acc, edge_by_layer, bank_map)
            acc_edges += len(lanes)
            first_acc_cycle_by_layer.setdefault(acc.layer_id, cycle)
            last_acc_cycle_by_layer[acc.layer_id] = cycle
            check_port_by_cycle[cycle]["acc_old_layer_vector_reads"] += 1
            check_port_by_cycle[cycle]["acc_old_qsign_edge_reads"] += len(lanes)
            check_port_by_cycle[cycle + cfg.D_A]["a2_context_updates"] += 1
            check_port_by_cycle[cycle + cfg.D_A]["a2_new_qsign_edge_writes"] += len(lanes)
            q_port_by_cycle[cycle + cfg.D_A]["writes"] += 1

            key = (acc.qbuf, acc.qslot)
            existing = q_records.get(key)
            require(
                existing is None
                or (
                    existing.release_cycle is not None
                    and existing.release_cycle <= cycle
                ),
                f"q overwrite before release at cycle {cycle} qbuf={acc.qbuf} qslot={acc.qslot}",
            )
            q_records[key] = QRecord(
                qbuf=acc.qbuf,
                qslot=acc.qslot,
                layer_id=acc.layer_id,
                edge_ids=tuple(lane.edge_id for lane in lanes),
                reserve_cycle=cycle,
                write_visible_cycle=cycle + cfg.D_A,
            )

            for lane in lanes:
                require(lane.edge_id not in acc_edges_by_layer[acc.layer_id], "duplicate ACC edge")
                acc_edges_by_layer[acc.layer_id].add(lane.edge_id)
                if lane.aux == 0:
                    ordinary_read_lanes.append(lane)
                    app_reads_by_cycle[cycle].append(lane)
                    normal_app_reads += 1
                else:
                    require(1 <= lane.aux <= cfg.forward_cache_depth, "ACC forward aux out of range")
                    slot = lane.aux - 1
                    entry = forward_slots.get(slot)
                    require(entry is not None, f"ACC uses empty forward slot {slot} at cycle {cycle}")
                    require(
                        entry.valid_cycle <= cycle,
                        f"ACC uses forward slot {slot} before visible at cycle {cycle}",
                    )
                    require(
                        entry.column == lane.column,
                        f"ACC forward slot column mismatch at cycle {cycle}",
                    )
                    require(entry.consumed_cycle is None, "forward slot consumed twice")
                    entry.consumed_cycle = cycle
                    forwarded_app_reads += 1

        if rec.valid:
            rec_count += 1
            require(rec.qbuf in (0, 1), f"REC qbuf out of range at cycle {cycle}")
            require(0 <= rec.qslot <= 9, f"REC qslot out of range at cycle {cycle}")
            require(
                rec.qbuf == position_by_layer[rec.layer_id] % 2,
                f"REC qbuf does not match layer position at cycle {cycle}",
            )
            lanes = instruction_lanes(rec, edge_by_layer, bank_map)
            rec_edges += len(lanes)
            first_rec_cycle_by_layer.setdefault(rec.layer_id, cycle)
            last_rec_cycle_by_layer[rec.layer_id] = cycle
            check_port_by_cycle[cycle]["rec_new_layer_vector_reads"] += 1
            check_port_by_cycle[cycle]["rec_new_qsign_edge_reads"] += len(lanes)
            q_port_by_cycle[cycle]["reads"] += 1
            rec_touch_records[cycle] = [
                (rec.layer_id, lane.edge_id, lane.column, rec.qslot)
                for lane in lanes
            ]
            final_touch_flags_by_cycle[cycle] = {
                lane.column: bool(lane.final_touch) for lane in lanes
            }

            q_record = q_records.get((rec.qbuf, rec.qslot))
            require(q_record is not None, f"REC q read before reservation at cycle {cycle}")
            require(
                q_record.write_visible_cycle <= cycle,
                f"REC q read before A2 visible at cycle {cycle}",
            )
            require(q_record.layer_id == rec.layer_id, "REC q layer mismatch")
            require(q_record.release_cycle is None, "q slot read twice")
            q_record.release_cycle = cycle + cfg.D_R

            produced_slots: set[int] = set()
            for lane in lanes:
                require(lane.edge_id not in rec_edges_by_layer[rec.layer_id], "duplicate REC edge")
                rec_edges_by_layer[rec.layer_id].add(lane.edge_id)
                write_lanes.append(lane)
                app_writes_by_issue_cycle[cycle].append(lane)
                app_writes_by_r2_cycle[cycle + cfg.D_R].append(lane)
                if lane.aux:
                    require(1 <= lane.aux <= cfg.forward_cache_depth, "REC forward aux out of range")
                    slot = lane.aux - 1
                    require(slot not in produced_slots, "REC duplicated forward slot in one issue")
                    produced_slots.add(slot)
                    require(slot not in forward_slots, f"REC overwrites live forward slot {slot}")
                    forward_slots[slot] = ForwardEntry(
                        slot=slot,
                        column=lane.column,
                        producer_layer=rec.layer_id,
                        producer_edge_id=lane.edge_id,
                        rec_issue_cycle=cycle,
                        valid_cycle=cycle + cfg.D_R,
                        memory_safe_cycle=cycle + cfg.D_R + 1,
                        created_cycle=cycle,
                    )
                    forward_allocations += 1

        read_banks = [lane.bank for lane in ordinary_read_lanes]
        write_banks = [lane.bank for lane in write_lanes]
        require(len(read_banks) == len(set(read_banks)), f"APP read bank conflict at cycle {cycle}")
        require(len(write_banks) == len(set(write_banks)), f"APP write bank conflict at cycle {cycle}")
        require(
            not set(read_banks).intersection(write_banks),
            f"APP issue-cycle read/write bank conflict at cycle {cycle}",
        )
        app_issue_rows.append(
            {
                "cycle": cycle,
                "ordinary_read_banks": sorted(read_banks),
                "write_banks_issue_aligned": sorted(write_banks),
                "ordinary_reads": len(read_banks),
                "writes": len(write_banks),
            }
        )
        max_forward_live = max(max_forward_live, len(forward_slots))

    drain_cycle = max(int(word["cycle"]) for word in issue_words) + cfg.D_R + 3
    for cycle in range(int(issue_words[-1]["cycle"]) + 1, drain_cycle + 1):
        retire_forward_slots(forward_slots, cycle, forward_lifetimes)
    require(not forward_slots, "forward slots remain live after drain")

    close_cycles = {
        layer_id: last_cycle + cfg.D_A
        for layer_id, last_cycle in sorted(last_acc_cycle_by_layer.items())
    }
    for layer_id, close_cycle in close_cycles.items():
        check_port_by_cycle[close_cycle]["layer_close_commits"] += 1
        require(
            first_rec_cycle_by_layer[layer_id] >= close_cycle,
            f"REC begins before layer close for layer {layer_id}",
        )

    for layer_id, degree in layer_degree.items():
        require(len(acc_edges_by_layer[layer_id]) == degree, f"ACC edge coverage mismatch layer {layer_id}")
        require(len(rec_edges_by_layer[layer_id]) == degree, f"REC edge coverage mismatch layer {layer_id}")

    # Physical R2 writes happen later than the scheduler issue cycle. A one-op
    # physical bank would see these collisions, so the contract requires either
    # 1R1W banking or equivalent latency-neutral write buffering.
    for cycle in sorted(set(app_reads_by_cycle) | set(app_writes_by_r2_cycle)):
        read_banks = {lane.bank for lane in app_reads_by_cycle[cycle]}
        write_banks = {lane.bank for lane in app_writes_by_r2_cycle[cycle]}
        overlap = sorted(read_banks.intersection(write_banks))
        if overlap:
            physical_app_collisions.append(
                {
                    "cycle": cycle,
                    "same_bank_ids": overlap,
                    "ordinary_reads": [
                        asdict(lane) for lane in app_reads_by_cycle[cycle]
                    ],
                    "r2_writes": [
                        asdict(lane) for lane in app_writes_by_r2_cycle[cycle]
                    ],
                }
            )

    final_touch = build_final_touch_analysis(
        graph,
        final_touch_flags_by_cycle,
        rec_touch_records,
        cfg.D_R,
    )
    syndrome_s8q8 = simulate_syndrome_engine(
        profile="BG1_Z384_first4_order_1_3_2_0",
        decoder_cycles_per_iteration=expected["decoder_cycles_per_iteration"],
        final_touch=final_touch,
        S=cfg.syndrome_S,
        queue_depth=cfg.syndrome_Q,
    )
    require(syndrome_s8q8.valid, "S=8 Q=8 syndrome queue invalid")

    max_q_reads = max((row["reads"] for row in q_port_by_cycle.values()), default=0)
    max_q_writes = max((row["writes"] for row in q_port_by_cycle.values()), default=0)
    max_check_ports = {
        name: max((row[name] for row in check_port_by_cycle.values()), default=0)
        for name in next(iter(check_port_by_cycle.values())).keys()
    }
    max_issue_reads = max(row["ordinary_reads"] for row in app_issue_rows)
    max_issue_writes = max(row["writes"] for row in app_issue_rows)

    evidence = {
        "artifact_type": "category_b_schedule_contract_evidence",
        "source_schedule": str(SCHEDULE_PATH.relative_to(ROOT)),
        "source_profile": str(PROFILE_PATH.relative_to(ROOT)),
        "profile_identity": schedule_data["profile_identity"],
        "program_length": len(issue_words),
        "decoder_cycles_per_iteration": expected["decoder_cycles_per_iteration"],
        "syndrome_tail": expected["syndrome_tail"],
        "effective_iteration_boundary": expected["effective_iteration_boundary"],
        "layer_order": list(layer_order),
        "layer_close_cycles": close_cycles,
        "first_acc_cycle_by_layer": first_acc_cycle_by_layer,
        "first_rec_cycle_by_layer": first_rec_cycle_by_layer,
        "last_rec_cycle_by_layer": last_rec_cycle_by_layer,
        "acc_issue_cycles": acc_count,
        "rec_issue_cycles": rec_count,
        "acc_edges": acc_edges,
        "rec_edges": rec_edges,
        "active_edges": sum(layer_degree.values()),
        "active_columns": len(graph.columns),
        "bank_map": {
            str(column): int(bank)
            for column, bank in sorted(bank_map.mapping.items())
        },
        "app_ports": {
            "max_issue_aligned_ordinary_reads_per_cycle": max_issue_reads,
            "max_issue_aligned_writes_per_cycle": max_issue_writes,
            "issue_aligned_bank_conflicts": 0,
            "r2_aligned_same_bank_read_write_cycles": physical_app_collisions,
            "r2_aligned_same_bank_read_write_cycle_count": len(physical_app_collisions),
        },
        "q_scratch": {
            "max_reads_per_cycle": max_q_reads,
            "max_writes_per_cycle": max_q_writes,
            "max_qslot": max(record.qslot for record in q_records.values()),
            "qbufs": sorted({record.qbuf for record in q_records.values()}),
            "all_reads_after_writes": True,
            "all_reuses_after_release": True,
        },
        "check_state": {
            "max_ports_by_cycle": max_check_ports,
            "layer_close_atomicity_checked": True,
            "acc_old_generation_only": True,
            "rec_new_generation_only": True,
        },
        "forwarding": {
            "depth": cfg.forward_cache_depth,
            "normal_app_reads": normal_app_reads,
            "forwarded_app_reads": forwarded_app_reads,
            "forward_allocations": forward_allocations,
            "max_live_entries": max_forward_live,
            "lifetime_min": min(forward_lifetimes) if forward_lifetimes else 0,
            "lifetime_max": max(forward_lifetimes) if forward_lifetimes else 0,
            "lifetime_avg": (
                sum(forward_lifetimes) / len(forward_lifetimes)
                if forward_lifetimes
                else 0.0
            ),
            "valid_cycle_rule": "REC issue c -> forward visible c+3",
            "memory_safe_rule": "REC issue c -> ordinary APP memory safe c+4",
        },
        "syndrome": {
            "S": cfg.syndrome_S,
            "Q": cfg.syndrome_Q,
            "total_work_items": syndrome_s8q8.total_work_items,
            "first_final_cycle": syndrome_s8q8.first_final_cycle,
            "last_final_cycle": syndrome_s8q8.last_final_cycle,
            "max_backlog": syndrome_s8q8.max_syndrome_backlog,
            "max_queue_occupancy": syndrome_s8q8.max_finalized_queue_occupancy,
            "completion_cycle": syndrome_s8q8.syndrome_completion_cycle,
            "tail_cycles": syndrome_s8q8.additional_tail_cycles,
            "effective_iteration_boundary": syndrome_s8q8.effective_iteration_boundary,
        },
    }
    evidence["evidence_hash"] = sha256_json(evidence)
    return evidence


def memory_contract(evidence: dict[str, Any]) -> dict[str, Any]:
    cfg = PRODUCTION_V1
    return {
        "artifact_type": "memory_interface_contract",
        "status": "CLOSED",
        "source_evidence_hash": evidence["evidence_hash"],
        "logical_contract_authoritative": True,
        "frozen_parameters": {
            "P": cfg.P,
            "B": cfg.B,
            "D_A": cfg.D_A,
            "D_R": cfg.D_R,
            "APP_banks": cfg.num_app_banks,
            "forward_depth": cfg.forward_cache_depth,
            "ACC_contexts": cfg.num_acc_contexts,
            "widths": {"CH": cfg.w_CH, "APP": cfg.w_APP, "q": cfg.w_q, "M": cfg.w_M},
        },
        "logical_read_latency_table": logical_read_latency_table(),
        "app_memory": {
            "oq": "OQ-02",
            "decision": "Eight logical APP banks, canonical P-lane vector words, scheduler-boundary global 2R+2W envelope, and latency-neutral physical wrapper that supports any R2-aligned same-bank read/write collision without adding a cycle.",
            "logical_banks": 8,
            "logical_word": {
                "basis": "one active base column in canonical orientation",
                "lanes": 384,
                "lane_width_bits": 8,
                "word_width_bits": 3072,
                "partial_vector_visibility_allowed": False,
            },
            "address": {
                "basis": "(bank_id, bank_local_column)",
                "column_to_bank_map_source": "profile metadata/generator; not modulo",
                "bank_map": evidence["bank_map"],
            },
            "scheduler_boundary_ports_per_cycle": {
                "ordinary_ACC_reads_global_max": 2,
                "ordinary_REC_writes_global_max": 2,
                "ordinary_operation_per_bank_per_issue_cycle_max": 1,
                "forwarded_ACC_operand_consumes_APP_bank": False,
                "validated_max_reads": evidence["app_ports"]["max_issue_aligned_ordinary_reads_per_cycle"],
                "validated_max_writes": evidence["app_ports"]["max_issue_aligned_writes_per_cycle"],
            },
            "physical_wrapper_requirement": {
                "reason": "R2 writes occur c+3, not at schedule issue c; the reference program has same-bank physical read/write cycles.",
                "same_bank_read_write_cycle_count": evidence["app_ports"]["r2_aligned_same_bank_read_write_cycle_count"],
                "required_behavior": "support one read and one write to the same logical bank in the same physical cycle, or use an equivalent write buffer/register shadow, with no added visible latency",
                "read_during_write_same_address_dependency": "not relied upon; forwarding supplies not-yet-memory-safe values",
                "a0_source_requirement": "stored APP source must be logically available during A0 cycle c for QC permutation; a bare one-cycle synchronous BRAM read that makes APP first available in A1 does not satisfy this interface",
            },
            "latency": {
                "ACC_pipeline": {
                    "A0": "ACC issue c: APP source selection and forward QC permutation",
                    "A1": "c+1: old C2V reconstruction and q",
                    "A2": "c+2: B=2 accumulation update and q/sign publication",
                    "commit_start_visible": "c+3",
                },
                "REC_pipeline": {
                    "R0": "REC issue c: new C2V reconstruction",
                    "R1": "c+1: APP = q + newC2V",
                    "R2": "c+2: inverse QC permutation",
                    "forward_write_request": "c+3",
                },
                "ordinary_ACC_source_cycle": "stored or forwarded APP must be logically available during A0 cycle c",
                "REC_forward_visible": "REC issue c -> c+3",
                "ordinary_APP_safe": "REC issue c -> c+4",
                "added_hidden_pipeline_cycle_allowed": False,
            },
            "initialization": {
                "input_format": "already quantized CH6",
                "active_lane_rule": "APP_initial = sat8(sign_extend(CH6) << 1)",
                "inactive_lane_rule": "logical zero and masked from updates",
                "orientation": "canonical",
            },
            "suggested_xilinx_realizations": [
                "register or LUTRAM bank store for latency-critical A0 source access",
                "BRAM/URAM payload behind a register shadow, cache, or other latency-neutral wrapper that preserves A0 source availability",
                "LUTRAM/register shadow for the latency-critical high-rate profile",
                "write-buffered bank wrapper with c+4 ordinary-read safety and c+3 forwarding"
            ],
        },
        "compressed_check_state": {
            "oq": "OQ-04",
            "decision": "Use two logical generation arrays plus per-layer epoch/valid/closed metadata. ACC reads old generation, A2 writes new generation, REC reads newly closed generation.",
            "generation_scheme": "ping_pong_generations_with_epoch_valid_bits",
            "fields": {
                "layer_lane_fields": ["M1[5:0]", "M2[5:0]", "Imin[4:0]", "aggregate_sign"],
                "per_edge_lane_fields": ["q_sign"],
                "layer_lane_payload_bits": 18,
            },
            "first_iteration": {
                "oldC2V": "if old generation is invalid for the current block/epoch, reconstructed oldC2V = 0",
                "initial_block_setup": "leaves the old generation logically invalid",
                "architectural_semantics": "single valid/epoch logical-zero rule",
                "bulk_memory_clear_required": False,
                "invalid_sentinel_allowed": False,
                "M1_M2_Imin_sentinel_allowed": False,
            },
            "ownership": {
                "ACC": "old generation only",
                "A2": "new generation update and layer close publication",
                "REC": "new closed generation only",
                "iteration_advance": "after syndrome decision, new generation becomes old for the next iteration; previous old becomes next write target",
            },
            "layer_close": {
                "atomic_to_REC": True,
                "visibility": "closing ACC issue c -> closed new generation visible c+3",
                "Imin_after_close": "must name a real local edge ID",
            },
            "ports_required": {
                "per_ACC_issue": "one old-generation layer-vector read plus up to two old q_sign edge-vector reads",
                "per_A2_cycle": "one context update plus up to two new q_sign edge-vector writes",
                "per_REC_issue": "one new-generation layer-vector read plus up to two new q_sign edge-vector reads",
                "validated_maxima": evidence["check_state"]["max_ports_by_cycle"],
            },
            "suggested_xilinx_realizations": [
                "register or LUTRAM layer context for running and just-closed minima",
                "duplicated/striped q_sign storage for B=2 edge-vector reads",
                "BRAM/LUTRAM arrays behind a wrapper that preserves c+3 close visibility"
            ],
        },
        "q_scratch": {
            "oq": "OQ-15",
            "decision": "Two q buffers, ten valid q slots per buffer, one B-vector write and one B-vector read per cycle, with explicit owner metadata.",
            "buffers": 2,
            "valid_qslots": "0..9",
            "invalid_qslots": "10..15",
            "qbuf_rule": "layer_position mod 2",
            "qslot_rule": "B=2 pair identifier",
            "slot_payload": {
                "lanes_per_slot": 2,
                "P": 384,
                "q_width_bits": 8,
                "payload_bits": 6144,
            },
            "timing": {
                "write_visible": "ACC issue c -> c+3",
                "read_allowed": "REC issue cycle >= write_visible and layer closed",
                "release": "REC issue c -> c+3",
                "read_latency": "request in R0 cycle c, data valid in R1 cycle c+1",
                "hidden_cycle_allowed": False,
            },
            "ports_required": {
                "writes_per_cycle": 1,
                "reads_per_cycle": 1,
                "same_qbuf_read_write_allowed": True,
                "same_qslot_read_write_required": False,
                "validated_max_reads": evidence["q_scratch"]["max_reads_per_cycle"],
                "validated_max_writes": evidence["q_scratch"]["max_writes_per_cycle"],
                "validated_max_qslot": evidence["q_scratch"]["max_qslot"],
            },
            "metadata": ["valid", "iteration_epoch", "layer_id", "qslot", "qbuf", "lane_mask"],
        },
        "forward_cache": {
            "depth": 8,
            "entry_payload_bits": 3072,
            "aux_encoding": "ACC/REC aux values 1..8 encode slots 0..7; 0 means no forward source/allocation",
            "validated": evidence["forwarding"],
        },
    }


def forwarding_contract(evidence: dict[str, Any]) -> dict[str, Any]:
    return {
        "artifact_type": "forwarding_timing_contract",
        "status": "CLOSED",
        "source_evidence_hash": evidence["evidence_hash"],
        "cycle_convention": {
            "cycle_start": "Cycle c begins immediately after rising edge c.",
            "issue": "An issue in cycle c presents operands/addresses during c..c+1 and is captured into stage 0 at the next rising edge.",
            "D_stage_visibility": "A D-stage token issued at c is registered and visible at start of c+D.",
        },
        "REC_pipeline": {
            "REC_issue_cycle": "c",
            "R0": "cycle c; reconstruct newC2V from newly closed compressed state",
            "R1": "cycle c+1; consume q slot data and compute APP=q+newC2V in check domain",
            "R2": "cycle c+2; inverse QC permutation and canonical APP production",
            "forward_production": "start of cycle c+3",
            "APP_write_request": "start of cycle c+3",
            "APP_memory_safe_for_ordinary_ACC": "start of cycle c+4",
        },
        "ACC_source_selection": {
            "A0_forward_earliest": "cycle c+3 for a producer REC issued at c",
            "A0_APP_memory_earliest": "cycle c+4 for the same producer",
            "A0_functional_timing": "stored APP and forward-slot APP are both available during A0 cycle c; A0 performs forward QC permutation and registers the permuted result for A1 at c+1",
            "selector_rule": "aux=0 selects stored APP; aux=1..8 selects forward slot aux-1",
            "fallback_on_tag_mismatch": "fatal error; do not silently fall back to APP memory",
        },
        "slot_metadata_contract": {
            "logical_fields": [
                "valid",
                "column_id_tag",
                "iteration_epoch",
                "canonical_APP_vector[384][8]",
            ],
            "payload_bits_per_slot": 384 * 8,
            "producer": "REC R2 for the lane whose REC aux value names the slot",
            "producer_tag_write": "column_id_tag is the REC lane base column; iteration_epoch is the current decoder iteration epoch",
            "valid_assertion": "start of cycle c+3 for REC issue c, atomically with canonical APP vector visibility",
            "ACC_expected_tag": "base column resolved from the ACC instruction layer_id/local_edge_id plus the current iteration epoch",
            "ACC_check_cycle": "A0 of the consuming ACC issue",
            "retirement": "valid clears after the encoded consumer cycle has elapsed, or at memory_safe c+4 when no live scheduled consumer remains",
            "epoch_or_column_mismatch": "fatal error; the core stops issuing and partial output is invalid",
            "implementation_note": "metadata may be held in registers and shall not add a cycle",
        },
        "validated_reference_schedule": {
            "profile": evidence["profile_identity"],
            "decoder_cycles": evidence["decoder_cycles_per_iteration"],
            "normal_app_reads": evidence["forwarding"]["normal_app_reads"],
            "forwarded_app_reads": evidence["forwarding"]["forwarded_app_reads"],
            "forward_allocations": evidence["forwarding"]["forward_allocations"],
            "max_live_forward_entries": evidence["forwarding"]["max_live_entries"],
            "lifetime_min_cycles": evidence["forwarding"]["lifetime_min"],
            "lifetime_avg_cycles": evidence["forwarding"]["lifetime_avg"],
            "lifetime_max_cycles": evidence["forwarding"]["lifetime_max"],
        },
        "depth_contract": {
            "FORWARD_DEPTH": 8,
            "slot_ids": "0..7",
            "microinstruction_aux_values": "1..8",
            "shrink_depth_without_reschedule_allowed": False,
        },
    }


def control_contract(evidence: dict[str, Any]) -> dict[str, Any]:
    return {
        "artifact_type": "control_semantics_contract",
        "status": "CLOSED",
        "source_evidence_hash": evidence["evidence_hash"],
        "reset": {
            "oq": "OQ-09",
            "core_reset_signal": "rst_i",
            "polarity": "active_high",
            "synchronization": "synchronous to the single core clock; board-level async reset synchronization is outside the decoder core",
            "minimum_assertion": "one rising edge after clock stability",
            "deassertion": "synchronous; enters IDLE on a clock boundary",
            "state_after_reset": {
                "fsm": "IDLE",
                "busy": 0,
                "done": 0,
                "output_valid": 0,
                "error_flags": "clear",
                "program_counter": 0,
                "iteration_counter": 0,
                "contexts": "closed",
                "forward_entries": "invalid",
                "q_slots": "invalid",
                "syndrome_queue": "empty",
            },
            "large_memory_clear": "not required; epoch/valid metadata must prevent stale payload visibility",
        },
        "start_done_abort_error": {
            "start": "accepted only in IDLE with legal configuration; illegal configuration enters ERROR before memory mutation",
            "done_behavior": "done_o is a sticky level in DONE until the next accepted start, explicit status clear, abort clear, or reset; a one-cycle pulse may be derived but is not the architectural state",
            "early_termination": "only DECIDE may terminate early after syndrome_done and syndrome_zero are both true",
            "abort": "synchronous abort stops new issue on the next cycle, invalidates live epochs/valids, suppresses output, and returns to IDLE with aborted status set",
            "fatal_error": "stop new issue, invalidate partial output, latch error cause, and remain in ERROR until reset or explicit clear from IDLE-safe integration",
        },
        "max_iterations": {
            "oq": "OQ-10",
            "width_bits": 4,
            "legal_range": "1..15",
            "reset_default": 12,
            "zero_behavior": "illegal configuration error",
            "out_of_range_behavior": "unrepresentable at 4 bits; wider integration values must be rejected before programming the core",
            "iteration_counter": "4-bit completed-iteration counter; starts at 0 for a block and increments once per completed syndrome decision",
            "decide_semantics": {
                "completed_next": "completed_iterations + 1 for the iteration whose syndrome decision just completed",
                "if_syndrome_zero": "terminate successfully",
                "else_if_completed_next_gte_max_iterations": "terminate due to maximum iterations",
                "counter_update": "completed_iterations_after_decide = completed_next for every DECIDE outcome",
                "else": "launch next iteration after recording completed_next",
            },
            "comparison": "on syndrome fail, launch another iteration only when completed_next < max_iterations",
            "boundary_tests": max_iteration_boundary_tests(),
            "syndrome_independence": "max_iterations bounds retry count; it does not force or bypass syndrome early termination",
            "non_speculative_policy": "no next-iteration ACC issue before the current syndrome decision",
        },
        "syndrome": {
            "oq": "OQ-14",
            "S": 8,
            "Q": 8,
            "accumulator_owner": "syndrome engine only",
            "logical_zero_semantics": "at each iteration start all architectural syndrome accumulators behave as zero before any work item is consumed; stale prior-iteration state is inaccessible; establishing logical zero consumes no decoder cycle",
            "clear_semantics": "parallel clear or epoch invalidation are permitted physical mechanisms beneath the same logical-zero rule",
            "queue_entry": "base column, canonical hard vector from final APP, active-lane mask, iteration epoch, and work iterator",
            "push_pop_order": "new finalized columns with final_valid_cycle <= current cycle are admitted before up to S work items are consumed; enqueue and consume in the same cycle are legal",
            "queue_overflow": "fatal architectural error; no drop or overwrite",
            "collision_behavior": "if multiple consumed work items target the same row in one cycle, XOR-reduce by row before the single architectural accumulator update or use an equivalent collision-safe multiwrite implementation",
            "syndrome_done": "all active columns finalized exactly once, all active QC edges consumed exactly once, queue empty, internal iterator empty, and all row accumulators complete",
            "syndrome_zero": "all active syndrome bits in every active row are zero",
            "validated_reference": evidence["syndrome"],
        },
    }


def resolve_result_path(path_text: str) -> Path:
    path = Path(path_text)
    if not path.is_absolute():
        path = ROOT / path
    return path


def read_validation_log(entry: dict[str, Any]) -> str:
    log_text = entry.get("log")
    require(isinstance(log_text, str) and log_text, "Validation entry missing log path.")
    path = resolve_result_path(log_text)
    require(path.exists(), f"Validation log does not exist: {path}")
    return path.read_text(encoding="utf-8")


def parse_phase3_log(text: str) -> tuple[int, int, int]:
    require(
        "PASS phase3 compressed c2v reconstruction" in text,
        "Phase 3 PASS text missing from source log.",
    )
    scalar = re.search(r"scalar_cases=(\d+)", text)
    vector = re.search(r"vector_cases=(\d+)", text)
    explicit = re.search(r"explicit_edges_checked=(\d+)", text)
    require(scalar is not None, "Phase 3 scalar count missing from source log.")
    require(vector is not None, "Phase 3 vector count missing from source log.")
    require(explicit is not None, "Phase 3 explicit-edge count missing from source log.")
    return int(scalar.group(1)), int(vector.group(1)), int(explicit.group(1))


def parse_qc_log(text: str) -> int:
    require("PASS" in text, "Phase 2 Python QC PASS text missing from source log.")
    rows = re.search(r"(\d+) observed SV lane rows checked", text)
    require(rows is not None, "Phase 2 Python QC row count missing from source log.")
    return int(rows.group(1))


def parse_python_regression_log(text: str) -> int:
    passed = re.search(r"(\d+) passed", text)
    require(passed is not None, "Python regression pass count missing from source log.")
    return int(passed.group(1))


def build_validation_evidence_from_logs() -> dict[str, Any]:
    phase1_log = "results/rtl_handoff_category_b/phase1_sv_validation.log"
    phase2_log = "results/rtl_handoff_category_b/phase2_sv_validation.log"
    qc_log = "results/rtl_handoff_category_b/phase2_python_qc_validation.log"
    phase3_log = "results/rtl_handoff_category_b/phase3_sv_validation.log"
    py_log = "results/rtl_handoff_category_b/python_regression_validation.log"

    phase1_text = resolve_result_path(phase1_log).read_text(encoding="utf-8")
    phase2_text = resolve_result_path(phase2_log).read_text(encoding="utf-8")
    qc_text = resolve_result_path(qc_log).read_text(encoding="utf-8")
    phase3_text = resolve_result_path(phase3_log).read_text(encoding="utf-8")
    py_text = resolve_result_path(py_log).read_text(encoding="utf-8")

    require(
        "PASS phase1 arithmetic primitives" in phase1_text,
        "Phase 1 PASS text missing from source log.",
    )
    require(
        "PASS phase2 qc permutation" in phase2_text,
        "Phase 2 PASS text missing from source log.",
    )
    qc_rows = parse_qc_log(qc_text)
    scalar, vector, explicit = parse_phase3_log(phase3_text)
    py_passed = parse_python_regression_log(py_text)
    require(qc_rows == 14208, "Phase 2 Python QC row count mismatch.")
    require((scalar, vector, explicit) == (32768, 116, 96), "Phase 3 count mismatch.")
    require(py_passed == 76, "Python regression count mismatch.")

    return {
        "artifact_type": "category_b_validation_evidence",
        "phase1_sv": {
            "status": "PASS",
            "summary": "PASS phase1 arithmetic primitives",
            "log": phase1_log,
        },
        "phase2_sv": {
            "status": "PASS",
            "summary": "PASS phase2 qc permutation",
            "log": phase2_log,
        },
        "phase2_python_qc": {
            "status": "PASS",
            "observed_rows": qc_rows,
            "summary": f"{qc_rows} observed SV lane rows checked",
            "log": qc_log,
        },
        "phase3_sv": {
            "status": "PASS",
            "summary": "PASS phase3 compressed c2v reconstruction",
            "scalar_cases": scalar,
            "vector_cases": vector,
            "explicit_edges_checked": explicit,
            "log": phase3_log,
        },
        "python_regression": {
            "status": "PASS",
            "passed": py_passed,
            "summary": f"{py_passed} passed",
            "log": py_log,
        },
        "max_iteration_boundary_tests": max_iteration_boundary_tests(),
    }


def validation_status() -> dict[str, Any]:
    require(
        VALIDATION_PATH.exists(),
        f"Missing required validation evidence artifact: {VALIDATION_PATH}",
    )
    data = read_json(VALIDATION_PATH)
    require(data.get("artifact_type") == "category_b_validation_evidence", "Invalid validation artifact type.")
    phase1_text = read_validation_log(data["phase1_sv"])
    require(
        "PASS phase1 arithmetic primitives" in phase1_text,
        "Phase 1 PASS text missing from referenced log.",
    )
    require(data["phase1_sv"]["status"] == "PASS", "Phase 1 SV validation failed or missing.")
    phase2_text = read_validation_log(data["phase2_sv"])
    require(
        "PASS phase2 qc permutation" in phase2_text,
        "Phase 2 PASS text missing from referenced log.",
    )
    require(data["phase2_sv"]["status"] == "PASS", "Phase 2 SV validation failed or missing.")
    qc_text = read_validation_log(data["phase2_python_qc"])
    qc_rows = parse_qc_log(qc_text)
    require(data["phase2_python_qc"]["status"] == "PASS", "Phase 2 Python QC validation failed or missing.")
    require(data["phase2_python_qc"]["observed_rows"] == qc_rows, "Phase 2 Python QC summary/log mismatch.")
    require(qc_rows == 14208, "Phase 2 Python QC row count mismatch.")
    phase3_text = read_validation_log(data["phase3_sv"])
    scalar, vector, explicit = parse_phase3_log(phase3_text)
    require(data["phase3_sv"]["status"] == "PASS", "Phase 3 SV validation failed or missing.")
    require(data["phase3_sv"]["scalar_cases"] == scalar, "Phase 3 scalar summary/log mismatch.")
    require(data["phase3_sv"]["vector_cases"] == vector, "Phase 3 vector summary/log mismatch.")
    require(data["phase3_sv"]["explicit_edges_checked"] == explicit, "Phase 3 explicit-edge summary/log mismatch.")
    require((scalar, vector, explicit) == (32768, 116, 96), "Phase 3 count mismatch.")
    py_text = read_validation_log(data["python_regression"])
    py_passed = parse_python_regression_log(py_text)
    require(data["python_regression"]["status"] == "PASS", "Full Python regression failed or missing.")
    require(data["python_regression"]["passed"] == py_passed, "Python regression summary/log mismatch.")
    require(py_passed == 76, "Full Python regression count mismatch.")
    expected_boundary = max_iteration_boundary_tests()
    require(
        data["max_iteration_boundary_tests"] == expected_boundary,
        "max_iterations boundary test evidence mismatch.",
    )
    require(
        all(item["pass"] for item in data["max_iteration_boundary_tests"].values()),
        "max_iterations boundary test failure.",
    )
    return data


def report(
    evidence: dict[str, Any],
    mem: dict[str, Any],
    fwd: dict[str, Any],
    ctrl: dict[str, Any],
) -> str:
    validations = validation_status()
    oq_rows = [
        (
            "OQ-02",
            "APP logical memory contract: 8 banks, 3072-bit canonical column vectors, c+4 ordinary visibility, c+3 forwarding, physical wrapper must absorb R2-aligned same-bank read/write collisions.",
            f"{evidence['app_ports']['max_issue_aligned_ordinary_reads_per_cycle']} reads, {evidence['app_ports']['max_issue_aligned_writes_per_cycle']} writes max at issue boundary; {evidence['app_ports']['r2_aligned_same_bank_read_write_cycle_count']} R2-aligned same-bank cycles require 1R1W/equivalent wrapper.",
            "APP memory, ACC A0, REC R2, schedule_ctrl",
            "CLOSED",
        ),
        (
            "OQ-04",
            "Two logical check-state generations with epoch/valid/closed metadata; first iteration oldC2V is a zero override, not fake M sentinel values.",
            f"Layer close cycles from program: {evidence['layer_close_cycles']}; REC first cycles: {evidence['first_rec_cycle_by_layer']}.",
            "ACC A2, REC R0, check-state storage",
            "CLOSED",
        ),
        (
            "OQ-09",
            "Active-high synchronous core reset; deterministic IDLE after reset; sticky done level; synchronous abort invalidates epochs and suppresses output; fatal errors latch until clear/reset.",
            "Matches spec reset-visible behavior while avoiding large payload-RAM reset networks.",
            "top-level FSM, schedule_ctrl, all validity metadata",
            "CLOSED",
        ),
        (
            "OQ-10",
            "max_iterations is 4 bits, legal 1..15, default 12, zero illegal; DECIDE uses completed_next=completed_iterations+1, then success, max-count, or retry in that order.",
            "Boundary tests for max_iterations 1, 2, 12, and 15 pass and preserve the non-speculative policy.",
            "configuration registers, top-level FSM",
            "CLOSED",
        ),
        (
            "OQ-12",
            "REC c produces forward-visible canonical APP at c+3; ordinary APP memory is safe at c+4; ACC aux selects forward vs stored APP exactly.",
            f"Forward depth {evidence['forwarding']['depth']}, {evidence['forwarding']['forwarded_app_reads']} forwarded reads, max live {evidence['forwarding']['max_live_entries']}.",
            "forward_fabric, ACC A0, REC R2, APP wrapper",
            "CLOSED",
        ),
        (
            "OQ-14",
            "Syndrome S=8 Q=8; row collision XOR-combine before accumulator update; completion requires full final-touch and edge-consumption coverage.",
            f"S=8/Q=8 high-rate queue peak {evidence['syndrome']['max_queue_occupancy']}, completion {evidence['syndrome']['completion_cycle']}, tail {evidence['syndrome']['tail_cycles']}.",
            "syndrome engine, top-level DECIDE",
            "CLOSED",
        ),
        (
            "OQ-15",
            "q scratch uses two ping-pong buffers, qslots 0..9, one B-vector write and one B-vector read per cycle; check-state ports are explicit for ACC old, A2 new, REC new.",
            f"q max reads/writes {evidence['q_scratch']['max_reads_per_cycle']}/{evidence['q_scratch']['max_writes_per_cycle']}; check-state maxima {evidence['check_state']['max_ports_by_cycle']}.",
            "q scratch, check-state storage, ACC A2, REC R0",
            "CLOSED",
        ),
    ]

    lines = [
        "# Category-B Production Interface Closure",
        "",
        "This closure writes no RTL and does not modify `rtl_prototypes/`. It analyzes the checked-in Category-A program and freezes the interface contracts needed before integrated ACC/REC datapath RTL.",
        "",
        "## Source Baseline",
        "",
        f"- Phase 1 production RTL commit: `0ee8909e6c96ce8adf25859533400f3c9d5f0bf9`.",
        f"- Phase 2 production RTL commit: `26f3f1af502ac23e8c2d920df187874c82f96ac3`.",
        f"- Phase 3 production RTL commit: `e344d54233526888e173fa97289bf67c48c20467`.",
        f"- Schedule: `{SCHEDULE_PATH.relative_to(ROOT)}`.",
        f"- Profile metadata: `{PROFILE_PATH.relative_to(ROOT)}`.",
        f"- Evidence hash: `{evidence['evidence_hash']}`.",
        "",
        "## Frozen Reference Profile",
        "",
        f"- Profile: `{evidence['profile_identity']}`.",
        f"- Layer order: `{fmt_order(tuple(evidence['layer_order']))}`.",
        f"- Program length / decoder cycles: `{evidence['program_length']}` / `{evidence['decoder_cycles_per_iteration']}`.",
        f"- Syndrome tail / effective boundary: `{evidence['syndrome_tail']}` / `{evidence['effective_iteration_boundary']}`.",
        f"- ACC / REC issue cycles: `{evidence['acc_issue_cycles']}` / `{evidence['rec_issue_cycles']}`.",
        f"- Active edges / active columns: `{evidence['active_edges']}` / `{evidence['active_columns']}`.",
        "",
        "## Closure Table",
        "",
        "| OQ | decision | evidence | affected RTL phases | status |",
        "|---|---|---|---|---|",
    ]
    for oq, decision, ev, phases, status in oq_rows:
        lines.append(f"| {oq} | {decision} | {ev} | {phases} | {status} |")

    lines.extend(
        [
            "",
            "## Logical Read Latency Table",
            "",
            "| Structure | Request/address cycle | Data-valid cycle | Consumer stage | Same-cycle read required | One-cycle sync read allowed | Prefetch required | Bypass requirement |",
            "|---|---|---|---|---|---|---|---|",
        ]
    )
    for row in mem["logical_read_latency_table"]:
        lines.append(
            "| {structure} | {request_address_cycle} | {data_valid_cycle} | "
            "{consumer_stage} | {same_cycle_combinational_read_required} | "
            "{one_cycle_synchronous_read_allowed} | {prefetch_required} | "
            "{bypass_requirement} |".format(**row)
        )

    lines.extend(
        [
            "",
            "## Important Port-Timing Result",
            "",
            "At the scheduler issue boundary, the canonical program has no APP bank conflict: up to two ordinary ACC reads and two REC writes occur globally, and no bank sees more than one issue-aligned operation.",
            "",
            "At the physical R2 boundary, APP writes occur three cycles after REC issue. The script found same-bank read/write physical cycles, so the APP wrapper contract is intentionally stronger than a single one-operation-per-bank RAM. The implementation shall use per-bank 1R1W capability, a write buffer, register shadowing, or equivalent latency-neutral realization. It shall not insert a new decoder cycle.",
            "",
            "## Generation And Lifetime Decisions",
            "",
            "- APP storage remains canonical. Forwarding carries a pending canonical shadow only until ordinary APP memory is safe.",
            "- Compressed check state uses old/new ping-pong generations with epoch and valid metadata. If the old generation is invalid for the current block/epoch, reconstructed oldC2V is exactly zero. No M1/M2/Imin sentinel is permitted.",
            "- q scratch uses qbuf=`layer_position mod 2`, qslot=`pair_id`, qslots `0..9` only. A slot is owned from ACC issue until REC issue plus `D_R`.",
            "- Layer-close visibility is exact: closing ACC issue `c` makes the new generation visible to REC at `c+3`.",
            "- Forward slots contain `valid`, `column_id_tag`, `iteration_epoch`, and the canonical 384x8 APP vector. REC R2 writes the tag at c+3; ACC A0 compares against the expected column and current epoch; mismatch is fatal and does not fall back to APP memory.",
            "",
            "## Max-Iterations Semantics",
            "",
            "`completed_next = completed_iterations + 1` for the iteration whose syndrome decision just completed. The architectural completed-iteration counter records `completed_iterations_after_decide = completed_next` for success, max-iteration termination, and retry. If `syndrome_zero`, terminate successfully. Else if `completed_next >= max_iterations`, terminate due to maximum iterations. Otherwise launch the next iteration. Thus `max_iterations=1` executes exactly one iteration and `max_iterations=12` executes at most twelve.",
            "",
            "## Syndrome Contract",
            "",
            f"- S=8, Q=8 are retained. For this reference program, total syndrome work is `{evidence['syndrome']['total_work_items']}`, first final cycle is `{evidence['syndrome']['first_final_cycle']}`, last final cycle is `{evidence['syndrome']['last_final_cycle']}`, queue peak is `{evidence['syndrome']['max_queue_occupancy']}`, completion is `{evidence['syndrome']['completion_cycle']}`, and tail is `{evidence['syndrome']['tail_cycles']}`.",
            "- Same-row collisions among the S consumed items are resolved by XOR reduction before the architectural row accumulator update, or by an equivalent collision-safe multiwrite implementation.",
            "- At each iteration start, syndrome accumulators behave as architectural zero before any work item is consumed. Stale prior-iteration state is inaccessible and establishing this logical zero consumes no decoder cycle.",
            "",
            "## Validation",
            "",
            f"Validation evidence artifact: `{VALIDATION_PATH.relative_to(ROOT)}`.",
            "",
            "| Check | Expected | Observed |",
            "|---|---|---|",
        ]
    )
    lines.append(
        f"| Phase 1 SV | PASS phase1 arithmetic primitives | {validations['phase1_sv']['status']} |"
    )
    lines.append(
        f"| Phase 2 SV | PASS phase2 qc permutation | {validations['phase2_sv']['status']} |"
    )
    lines.append(
        f"| Phase 2 Python QC | PASS, 14208 rows | {validations['phase2_python_qc']['status']}, {validations['phase2_python_qc']['observed_rows']} rows |"
    )
    lines.append(
        f"| Phase 3 SV | PASS phase3 compressed c2v reconstruction | {validations['phase3_sv']['status']}; scalar={validations['phase3_sv']['scalar_cases']}, vector={validations['phase3_sv']['vector_cases']}, explicit={validations['phase3_sv']['explicit_edges_checked']} |"
    )
    lines.extend(
        [
            f"| Full Python regression | 76 passed | {validations['python_regression']['passed']} passed |",
            "| max_iterations boundary tests | 1, 2, 12, 15 pass | PASS |",
            "",
            "## Output Artifacts",
            "",
            "- `memory_interface_contract.json`",
            "- `forwarding_timing_contract.json`",
            "- `control_semantics_contract.json`",
            "- `schedule_contract_evidence.json`",
            "- `validation_evidence.json`",
            "- `category_b_closure_report.md`",
            "",
            "## Decision Gate",
            "",
            "CATEGORY B CLOSED — INTEGRATED DATAPATH RTL AUTHORIZED",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_json(VALIDATION_PATH, build_validation_evidence_from_logs())
    evidence = analyze_schedule()
    mem = memory_contract(evidence)
    fwd = forwarding_contract(evidence)
    ctrl = control_contract(evidence)

    write_json(OUT_DIR / "schedule_contract_evidence.json", evidence)
    write_json(OUT_DIR / "memory_interface_contract.json", mem)
    write_json(OUT_DIR / "forwarding_timing_contract.json", fwd)
    write_json(OUT_DIR / "control_semantics_contract.json", ctrl)
    (OUT_DIR / "category_b_closure_report.md").write_text(
        report(evidence, mem, fwd, ctrl),
        encoding="utf-8",
    )
    print(OUT_DIR / "category_b_closure_report.md")
    print("CATEGORY B CLOSED — INTEGRATED DATAPATH RTL AUTHORIZED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
