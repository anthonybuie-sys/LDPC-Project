"""Final-touch streaming syndrome model.

This module observes an already-built decoder schedule. It does not change
decoder issue order, forwarding, APP banking, or pipeline behavior.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass

from config.architecture import ArchitectureConfig
from ldpc_sim.graph import LDPCGraph
from ldpc_sim.scheduler import RecIssueRecord
from ldpc_sim.simulator import SimulationResult


@dataclass(frozen=True)
class FinalTouch:
    column: int
    final_position: int
    final_layer_id: int
    final_edge_id: int
    rec_pair_id: int
    rec_issue_cycle: int
    final_valid_cycle: int


@dataclass(frozen=True)
class SyndromeWorkItem:
    layer_id: int
    edge_id: int
    column: int
    shift: int
    final_valid_cycle: int

    @property
    def key(self) -> tuple[int, int, int, int]:
        return (self.layer_id, self.edge_id, self.column, self.shift)


@dataclass(frozen=True)
class FinalTouchAnalysis:
    final_by_column: dict[int, FinalTouch]
    final_touch_by_rec_cycle: dict[int, dict[int, bool]]
    work_by_column: dict[int, tuple[SyndromeWorkItem, ...]]

    @property
    def first_final_cycle(self) -> int:
        return min(touch.final_valid_cycle for touch in self.final_by_column.values())

    @property
    def last_final_cycle(self) -> int:
        return max(touch.final_valid_cycle for touch in self.final_by_column.values())

    @property
    def total_work_items(self) -> int:
        return sum(len(items) for items in self.work_by_column.values())


@dataclass(frozen=True)
class SyndromeRunResult:
    profile: str
    S: int
    queue_depth: int
    valid: bool
    total_work_items: int
    first_final_cycle: int
    last_final_cycle: int
    max_syndrome_backlog: int
    max_finalized_queue_occupancy: int
    max_finalized_queue_occupancy_cycle: int
    syndrome_engine_utilization: float
    syndrome_completion_cycle: int
    additional_tail_cycles: int
    effective_iteration_boundary: int
    required_queue_depth: int


def analyze_final_touches(
    graph: LDPCGraph,
    result: SimulationResult,
    config: ArchitectureConfig,
) -> FinalTouchAnalysis:
    ordered_layers = graph.ordered_layers(result.metrics.layer_order)
    final_position_by_column: dict[int, int] = {}
    for position, layer in enumerate(ordered_layers):
        for edge in layer.edges:
            final_position_by_column[edge.column] = position

    active_columns = set(graph.columns)
    final_by_column: dict[int, FinalTouch] = {}
    final_touch_by_rec_cycle: dict[int, dict[int, bool]] = {}

    for record in result.rec_issues:
        lane_flags: dict[int, bool] = {}
        for edge_id, column in zip(record.edge_ids, record.columns):
            is_final = record.position == final_position_by_column[column]
            lane_flags[column] = is_final
            if is_final:
                if column in final_by_column:
                    raise AssertionError(f"Column {column} finalized more than once.")
                final_by_column[column] = FinalTouch(
                    column=column,
                    final_position=record.position,
                    final_layer_id=record.layer_id,
                    final_edge_id=edge_id,
                    rec_pair_id=record.pair_id,
                    rec_issue_cycle=record.cycle,
                    final_valid_cycle=record.cycle + config.D_R,
                )
        final_touch_by_rec_cycle[record.cycle] = lane_flags

    omitted = active_columns.difference(final_by_column)
    if omitted:
        raise AssertionError(f"Active columns omitted from final touch: {sorted(omitted)}")
    extra = set(final_by_column).difference(active_columns)
    if extra:
        raise AssertionError(f"Final touches found for inactive columns: {sorted(extra)}")

    work_by_column: dict[int, list[SyndromeWorkItem]] = {column: [] for column in active_columns}
    expected_edges: set[tuple[int, int, int, int]] = set()
    for layer in graph.layers:
        for edge in layer.edges:
            key = (edge.layer_id, edge.edge_id, edge.column, edge.shift)
            if key in expected_edges:
                raise AssertionError(f"Duplicate active QC edge: {key}")
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
        final_touch_by_rec_cycle=final_touch_by_rec_cycle,
        work_by_column={
            column: tuple(sorted(items, key=lambda item: (item.layer_id, item.edge_id)))
            for column, items in work_by_column.items()
        },
    )


def simulate_syndrome_engine(
    profile: str,
    decoder_cycles_per_iteration: int,
    final_touch: FinalTouchAnalysis,
    S: int,
    queue_depth: int,
) -> SyndromeRunResult:
    if S <= 0:
        raise ValueError("S must be positive.")
    if queue_depth <= 0:
        raise ValueError("queue_depth must be positive.")

    finalized_by_cycle: dict[int, list[int]] = {}
    for column, touch in final_touch.final_by_column.items():
        finalized_by_cycle.setdefault(touch.final_valid_cycle, []).append(column)
    for columns in finalized_by_cycle.values():
        columns.sort()

    pending_columns: deque[tuple[int, deque[SyndromeWorkItem]]] = deque()
    consumed_edges: set[tuple[int, int, int, int]] = set()
    expected_edges = {
        item.key
        for items in final_touch.work_by_column.values()
        for item in items
    }
    max_queue_occupancy = 0
    max_queue_occupancy_cycle = final_touch.first_final_cycle
    max_backlog = 0
    processed_items = 0
    last_processed_cycle: int | None = None

    cycle = final_touch.first_final_cycle
    final_cycles = sorted(finalized_by_cycle)
    final_index = 0

    while final_index < len(final_cycles) or pending_columns:
        while final_index < len(final_cycles) and final_cycles[final_index] <= cycle:
            for column in finalized_by_cycle[final_cycles[final_index]]:
                items = final_touch.work_by_column[column]
                if not items:
                    raise AssertionError(f"Finalized column {column} has no syndrome work.")
                pending_columns.append((column, deque(items)))
            final_index += 1

        queue_occupancy = len(pending_columns)
        if queue_occupancy > max_queue_occupancy:
            max_queue_occupancy = queue_occupancy
            max_queue_occupancy_cycle = cycle
        backlog = sum(len(items) for _, items in pending_columns)
        max_backlog = max(max_backlog, backlog)

        remaining_capacity = S
        while remaining_capacity > 0 and pending_columns:
            column, items = pending_columns[0]
            item = items.popleft()
            if cycle < item.final_valid_cycle:
                raise AssertionError(
                    f"Syndrome item {item.key} consumed before final APP generation."
                )
            if item.key in consumed_edges:
                raise AssertionError(f"Syndrome item consumed twice: {item.key}")
            consumed_edges.add(item.key)
            processed_items += 1
            last_processed_cycle = cycle
            remaining_capacity -= 1
            if not items:
                pending_columns.popleft()

        cycle += 1
        if not pending_columns and final_index < len(final_cycles):
            cycle = max(cycle, final_cycles[final_index])

    if consumed_edges != expected_edges:
        missing = expected_edges.difference(consumed_edges)
        extra = consumed_edges.difference(expected_edges)
        raise AssertionError(
            f"Syndrome contribution mismatch: missing={sorted(missing)} extra={sorted(extra)}"
        )
    if pending_columns:
        raise AssertionError("Syndrome completion declared with pending work.")

    completion_cycle = (
        final_touch.first_final_cycle if last_processed_cycle is None else last_processed_cycle + 1
    )
    active_window = max(1, completion_cycle - final_touch.first_final_cycle)
    utilization = processed_items / (S * active_window)
    tail_cycles = max(0, completion_cycle - decoder_cycles_per_iteration)
    valid = max_queue_occupancy <= queue_depth

    return SyndromeRunResult(
        profile=profile,
        S=S,
        queue_depth=queue_depth,
        valid=valid,
        total_work_items=final_touch.total_work_items,
        first_final_cycle=final_touch.first_final_cycle,
        last_final_cycle=final_touch.last_final_cycle,
        max_syndrome_backlog=max_backlog,
        max_finalized_queue_occupancy=max_queue_occupancy,
        max_finalized_queue_occupancy_cycle=max_queue_occupancy_cycle,
        syndrome_engine_utilization=utilization,
        syndrome_completion_cycle=completion_cycle,
        additional_tail_cycles=tail_cycles,
        effective_iteration_boundary=max(decoder_cycles_per_iteration, completion_cycle),
        required_queue_depth=max_queue_occupancy,
    )
