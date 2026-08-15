"""High-level simulator entry points."""

from __future__ import annotations

import csv
from dataclasses import dataclass
from itertools import permutations, product
from pathlib import Path

from config.architecture import ArchitectureConfig
from ldpc_sim.banking import build_bank_map
from ldpc_sim.dependencies import independent_transition_capacity, overlap_count_matrix
from ldpc_sim.graph import LDPCGraph
from ldpc_sim.invariants import (
    assert_all_stalls_classified,
    assert_context_limit,
    assert_edge_coverage,
)
from ldpc_sim.metrics import STALL_CATEGORIES, SimulationMetrics
from ldpc_sim.pairing import build_pair_schedule
from ldpc_sim.scheduler import (
    AccIssueRecord,
    CycleTrace,
    GreedyScheduler,
    RecIssueRecord,
    ScheduleResult,
)

PIPELINE_SWEEP_DEPTHS = (2, 3, 4, 5, 6)
REFERENCE_FREQUENCIES_MHZ = (200, 220, 250, 280, 300, 320, 350)

PIPELINE_SWEEP_CSV_FIELDS = (
    "D_A",
    "D_R",
    "cycles_per_iteration",
    "service_lower_bound",
    "delta_T_above_lower_bound",
    "best_layer_order",
    "STALL_RAW",
    "STALL_APP_BANK",
    "STALL_Q_BUFFER",
    "STALL_FORWARD_CAPACITY",
    "STALL_CONTEXT",
    "STALL_REC_NOT_CLOSED",
    "STALL_PIPE_RESOURCE",
    "STALL_PAIRING",
    "STALL_OTHER",
    "ACC_utilization",
    "REC_utilization",
    "steady_state_overlap_utilization",
    "B_lane_utilization",
    "forwarded_APP_reads",
    "max_live_forward_vectors",
    "tau_f_min",
    "tau_f_avg",
    "tau_f_max",
    "lookahead_cycles_hidden",
    "delta_vs_ipctek_133",
    "percent_reduction_vs_ipctek_133",
    "meets_minimum_success",
    "meets_strong_target",
    "meets_promising_target",
    "required_relative_frequency_vs_DA4_DR4",
    "allowable_frequency_loss_pct_vs_DA4_DR4",
    "required_frequency_gain_pct_vs_DA4_DR4",
    "time_us_at_200_mhz",
    "time_us_at_220_mhz",
    "time_us_at_250_mhz",
    "time_us_at_280_mhz",
    "time_us_at_300_mhz",
    "time_us_at_320_mhz",
    "time_us_at_350_mhz",
    "graph_name",
    "graph_is_synthetic",
    "graph_source_note",
)


@dataclass
class SimulationResult:
    metrics: SimulationMetrics
    trace: list[CycleTrace]
    graph: LDPCGraph
    bank_strategy: str
    pairing_strategy: str
    layer_close_cycles: dict[int, int]
    acc_issues: list[AccIssueRecord]
    rec_issues: list[RecIssueRecord]

    def as_dict(self) -> dict[str, object]:
        data = self.metrics.as_dict()
        data["graph"] = self.graph.name
        data["graph_source_note"] = self.graph.source_note
        data["bank_strategy"] = self.bank_strategy
        data["pairing_strategy"] = self.pairing_strategy
        data["layer_close_cycles"] = dict(self.layer_close_cycles)
        return data


def simulate_iteration(
    graph: LDPCGraph,
    config: ArchitectureConfig,
    layer_order: tuple[int, ...] | None = None,
    trace: bool = False,
) -> SimulationResult:
    ordered_layers = graph.ordered_layers(layer_order)
    bank_map = build_bank_map(graph, config.num_app_banks, config.bank_strategy)
    scheduler = GreedyScheduler(
        ordered_layers=ordered_layers,
        config=config,
        bank_map=bank_map,
        trace_enabled=trace,
    )
    schedule_result: ScheduleResult = scheduler.run()
    active_edges = sum(layer.degree for layer in ordered_layers)
    assert_edge_coverage(
        active_edges=active_edges,
        acc_issued_edges=scheduler.acc_issued_edges,
        rec_issued_edges=scheduler.rec_issued_edges,
    )
    assert_context_limit(scheduler.max_contexts_seen, config.num_acc_contexts)
    assert_all_stalls_classified(schedule_result.metrics.stall_counts)
    return SimulationResult(
        metrics=schedule_result.metrics,
        trace=schedule_result.trace,
        graph=graph,
        bank_strategy=config.bank_strategy,
        pairing_strategy=config.pairing_strategy,
        layer_close_cycles=schedule_result.layer_close_cycles,
        acc_issues=schedule_result.acc_issues,
        rec_issues=schedule_result.rec_issues,
    )


def best_layer_order(
    graph: LDPCGraph, config: ArchitectureConfig
) -> tuple[SimulationResult, list[SimulationResult]]:
    orders = list(permutations(graph.layer_ids))
    results = [
        simulate_iteration(graph, config, layer_order=order, trace=False)
        for order in orders
    ]
    ranked = sorted(
        results,
        key=lambda result: (
            result.metrics.cycles_per_iteration,
            result.metrics.RAW_stall_cycles,
            result.metrics.bank_conflict_cycles,
            result.metrics.layer_order,
        ),
    )
    return ranked[0], ranked


def run_configured(
    graph: LDPCGraph,
    config: ArchitectureConfig,
    trace: bool = False,
) -> SimulationResult:
    if config.enable_layer_reorder and len(graph.layers) <= 8 and not trace:
        best, _ = best_layer_order(graph, config)
        return best
    if config.enable_layer_reorder and len(graph.layers) <= 8 and trace:
        best, _ = best_layer_order(graph, config)
        return simulate_iteration(
            graph, config, layer_order=best.metrics.layer_order, trace=True
        )
    return simulate_iteration(graph, config, trace=trace)


def layer_order_table(
    graph: LDPCGraph, config: ArchitectureConfig
) -> list[dict[str, object]]:
    _, ranked = best_layer_order(graph, config)
    table: list[dict[str, object]] = []
    for rank, result in enumerate(ranked, 1):
        metrics = result.metrics
        table.append(
            {
                "rank": rank,
                "layer_order": metrics.layer_order,
                "cycles_per_iteration": metrics.cycles_per_iteration,
                "RAW_stalls": metrics.RAW_stall_cycles,
                "bank_stalls": metrics.bank_conflict_cycles,
                "lookahead_cycles_hidden": metrics.lookahead_cycles_hidden,
                "forward_count": metrics.forwarded_APP_reads,
            }
        )
    return table


def overlap_matrix_table(
    graph: LDPCGraph, layer_order: tuple[int, ...] | None = None
) -> list[list[int]]:
    return overlap_count_matrix(graph.ordered_layers(layer_order))


def transition_capacity_table(
    graph: LDPCGraph,
    config: ArchitectureConfig,
    layer_order: tuple[int, ...] | None = None,
) -> list[dict[str, int]]:
    ordered_layers = graph.ordered_layers(layer_order)
    bank_map = build_bank_map(graph, config.num_app_banks, config.bank_strategy)
    pair_schedules = build_pair_schedule(
        ordered_layers, bank_map, config.pairing_strategy
    )
    rows: list[dict[str, int]] = []
    for producer in ordered_layers:
        for consumer_position, consumer in enumerate(ordered_layers):
            if producer.layer_id == consumer.layer_id:
                continue
            rows.append(
                independent_transition_capacity(
                    producer,
                    consumer,
                    pair_schedules[consumer_position],
                )
            )
    return rows


def feature_ablation(
    graph: LDPCGraph, base_config: ArchitectureConfig
) -> list[tuple[str, SimulationResult]]:
    configs = [
        (
            "Basic B=2",
            base_config.with_overrides(
                enable_lookahead=False,
                enable_forwarding=False,
                enable_reconstruction_reorder=False,
                enable_layer_reorder=False,
                bank_strategy="modulo",
                pairing_strategy="sequential",
            ),
        ),
        (
            "+ look-ahead",
            base_config.with_overrides(
                enable_lookahead=True,
                enable_forwarding=False,
                enable_reconstruction_reorder=False,
                enable_layer_reorder=False,
                bank_strategy="modulo",
                pairing_strategy="sequential",
            ),
        ),
        (
            "+ forwarding",
            base_config.with_overrides(
                enable_lookahead=True,
                enable_forwarding=True,
                enable_reconstruction_reorder=False,
                enable_layer_reorder=False,
                bank_strategy="modulo",
                pairing_strategy="sequential",
            ),
        ),
        (
            "+ independent reconstruction ordering",
            base_config.with_overrides(
                enable_lookahead=True,
                enable_forwarding=True,
                enable_reconstruction_reorder=True,
                enable_layer_reorder=False,
                bank_strategy="modulo",
                pairing_strategy="sequential",
            ),
        ),
        (
            "+ optimized bank mapping",
            base_config.with_overrides(
                enable_lookahead=True,
                enable_forwarding=True,
                enable_reconstruction_reorder=True,
                enable_layer_reorder=False,
                bank_strategy="optimized",
                pairing_strategy="sequential",
            ),
        ),
        (
            "Full scheduler",
            base_config.with_overrides(
                enable_lookahead=True,
                enable_forwarding=True,
                enable_reconstruction_reorder=True,
                enable_layer_reorder=True,
                bank_strategy="optimized",
                pairing_strategy="optimized",
            ),
        ),
    ]
    return [(label, run_configured(graph, cfg)) for label, cfg in configs]


def pipeline_depth_sweep(
    graph: LDPCGraph, base_config: ArchitectureConfig
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    sweep_config = real_bg1_pipeline_sweep_config(base_config)
    if graph.is_synthetic:
        raise ValueError("Real-BG1 pipeline depth sweep cannot use a synthetic graph.")
    raw_rows: list[dict[str, object]] = []
    for d_a, d_r in product(PIPELINE_SWEEP_DEPTHS, repeat=2):
        config = sweep_config.with_overrides(D_A=d_a, D_R=d_r)
        result = run_configured(graph, config)
        raw_rows.append(_pipeline_sweep_row(result, d_a, d_r))

    baseline = next(
        row for row in raw_rows if row["D_A"] == 4 and row["D_R"] == 4
    )
    baseline_cycles = int(baseline["cycles_per_iteration"])
    for row in raw_rows:
        cycles = int(row["cycles_per_iteration"])
        ratio = cycles / baseline_cycles
        row["required_relative_frequency_vs_DA4_DR4"] = ratio
        row["allowable_frequency_loss_pct_vs_DA4_DR4"] = max(0.0, (1.0 - ratio) * 100.0)
        row["required_frequency_gain_pct_vs_DA4_DR4"] = max(0.0, (ratio - 1.0) * 100.0)
        rows.append(row)
    return rows


def real_bg1_pipeline_sweep_config(
    base_config: ArchitectureConfig,
) -> ArchitectureConfig:
    return base_config.with_overrides(
        P=384,
        B=2,
        num_app_banks=8,
        forward_cache_depth=8,
        enable_lookahead=True,
        enable_forwarding=True,
        enable_jit_forwarding=True,
        enable_reconstruction_reorder=True,
        enable_layer_reorder=True,
        num_acc_contexts=2,
        bank_strategy="optimized",
        pairing_strategy="optimized",
    )


def _pipeline_sweep_row(
    result: SimulationResult,
    d_a: int,
    d_r: int,
) -> dict[str, object]:
    metrics = result.metrics
    row: dict[str, object] = {
        "D_A": d_a,
        "D_R": d_r,
        "cycles_per_iteration": metrics.cycles_per_iteration,
        "service_lower_bound": metrics.service_lower_bound,
        "delta_T_above_lower_bound": metrics.overhead_above_lower_bound,
        "best_layer_order": "-".join(str(item) for item in metrics.layer_order),
        "ACC_utilization": metrics.ACC_utilization,
        "REC_utilization": metrics.REC_utilization,
        "steady_state_overlap_utilization": metrics.steady_state_overlap_utilization,
        "B_lane_utilization": metrics.B_lane_utilization,
        "forwarded_APP_reads": metrics.forwarded_APP_reads,
        "max_live_forward_vectors": metrics.max_live_forward_vectors,
        "tau_f_min": metrics.min_forward_lifetime,
        "tau_f_avg": metrics.avg_forward_lifetime,
        "tau_f_max": metrics.max_forward_lifetime,
        "lookahead_cycles_hidden": metrics.lookahead_cycles_hidden,
        "delta_vs_ipctek_133": metrics.cycles_reduction_vs_ipctek_iter,
        "percent_reduction_vs_ipctek_133": metrics.percent_reduction_vs_ipctek_iter,
        "meets_minimum_success": metrics.cycles_per_iteration < 133,
        "meets_strong_target": metrics.cycles_per_iteration <= 70,
        "meets_promising_target": metrics.cycles_per_iteration <= 65,
        "required_relative_frequency_vs_DA4_DR4": 1.0,
        "allowable_frequency_loss_pct_vs_DA4_DR4": 0.0,
        "required_frequency_gain_pct_vs_DA4_DR4": 0.0,
        "graph_name": result.graph.name,
        "graph_is_synthetic": result.graph.is_synthetic,
        "graph_source_note": result.graph.source_note,
    }
    for category in STALL_CATEGORIES:
        row[category] = metrics.stall_counts[category]
    for frequency_mhz in REFERENCE_FREQUENCIES_MHZ:
        row[f"time_us_at_{frequency_mhz}_mhz"] = (
            metrics.cycles_per_iteration / frequency_mhz
        )
    return row


def write_pipeline_depth_sweep_csv(
    rows: list[dict[str, object]],
    output_path: Path,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=PIPELINE_SWEEP_CSV_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row[field] for field in PIPELINE_SWEEP_CSV_FIELDS})


def sweep_matrix(
    rows: list[dict[str, object]],
    metric: str,
    depths: tuple[int, ...] = PIPELINE_SWEEP_DEPTHS,
) -> list[list[object]]:
    by_point = {
        (int(row["D_A"]), int(row["D_R"])): row[metric]
        for row in rows
    }
    return [[by_point[(d_a, d_r)] for d_r in depths] for d_a in depths]


def pipeline_sensitivity_summary(
    rows: list[dict[str, object]],
) -> dict[str, object]:
    cycles = {
        (int(row["D_A"]), int(row["D_R"])): int(row["cycles_per_iteration"])
        for row in rows
    }
    d_a_savings: list[int] = []
    d_r_savings: list[int] = []
    d_a_no_benefit: list[tuple[int, int]] = []
    d_r_no_benefit: list[tuple[int, int]] = []
    for d_a, d_r in product(PIPELINE_SWEEP_DEPTHS, repeat=2):
        current = cycles[(d_a, d_r)]
        if d_a > min(PIPELINE_SWEEP_DEPTHS):
            saved = current - cycles[(d_a - 1, d_r)]
            d_a_savings.append(saved)
            if saved <= 0:
                d_a_no_benefit.append((d_a, d_r))
        if d_r > min(PIPELINE_SWEEP_DEPTHS):
            saved = current - cycles[(d_a, d_r - 1)]
            d_r_savings.append(saved)
            if saved <= 0:
                d_r_no_benefit.append((d_a, d_r))

    avg_a = sum(d_a_savings) / len(d_a_savings)
    avg_r = sum(d_r_savings) / len(d_r_savings)
    return {
        "average_D_A_stage_savings": avg_a,
        "average_D_R_stage_savings": avg_r,
        "max_D_A_stage_savings": max(d_a_savings),
        "max_D_R_stage_savings": max(d_r_savings),
        "D_A_no_benefit_points": d_a_no_benefit,
        "D_R_no_benefit_points": d_r_no_benefit,
        "more_sensitive_path": "D_A" if avg_a > avg_r else "D_R" if avg_r > avg_a else "tie",
    }


def bank_sweep(
    graph: LDPCGraph, base_config: ArchitectureConfig
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for banks in (4, 8, 16):
        for strategy in ("modulo", "optimized"):
            try:
                result = run_configured(
                    graph,
                    base_config.with_overrides(
                        num_app_banks=banks,
                        bank_strategy=strategy,
                    ),
                )
                rows.append(
                    {
                        "num_app_banks": banks,
                        "strategy": strategy,
                        "cycles_per_iteration": result.metrics.cycles_per_iteration,
                        "bank_stalls": result.metrics.bank_conflict_cycles,
                        "status": "OK",
                    }
                )
            except RuntimeError as exc:
                rows.append(
                    {
                        "num_app_banks": banks,
                        "strategy": strategy,
                        "cycles_per_iteration": None,
                        "bank_stalls": None,
                        "status": f"UNSCHEDULABLE: {exc}",
                    }
                )
    return rows


def forward_cache_sweep(
    graph: LDPCGraph, base_config: ArchitectureConfig
) -> list[dict[str, int]]:
    rows: list[dict[str, int]] = []
    for depth in (2, 4, 8, 16):
        result = run_configured(
            graph,
            base_config.with_overrides(forward_cache_depth=depth)
        )
        rows.append(
            {
                "forward_cache_depth": depth,
                "cycles_per_iteration": result.metrics.cycles_per_iteration,
                "overflow_events": result.metrics.forward_overflow_events,
                "max_live_entries": result.metrics.max_live_forward_vectors,
            }
        )
    return rows
