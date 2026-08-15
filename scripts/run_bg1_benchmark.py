from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.benchmark_bg1_z384 import DEFAULT_CONFIG, DEFAULT_GRAPH
from ldpc_sim.simulator import (
    feature_ablation,
    layer_order_table,
    overlap_matrix_table,
    run_configured,
    transition_capacity_table,
)


def pct(value: float) -> str:
    return f"{value * 100:.1f}%"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the BG1 Z=384 B=2 benchmark.")
    parser.add_argument("--trace", action="store_true", help="Print cycle trace.")
    parser.add_argument("--json", action="store_true", help="Print JSON metrics.")
    parser.add_argument("--freq-mhz", type=float, default=None, help="Optional clock in MHz.")
    args = parser.parse_args()

    result = run_configured(DEFAULT_GRAPH, DEFAULT_CONFIG, trace=args.trace)
    metrics = result.metrics

    if args.json:
        print(json.dumps(result.as_dict(), indent=2, sort_keys=True))
    else:
        print(DEFAULT_GRAPH.source_note)
        print()
        print("Initial BG1 Z=384 P=384 B=2 four-layer benchmark")
        print(f"cycles/iteration: {metrics.cycles_per_iteration}")
        print(f"service lower bound: {metrics.service_lower_bound}")
        print(f"Delta T vs 50: {metrics.delta_T}")
        print(f"best layer order: {metrics.layer_order}")
        print(f"ACC utilization: {pct(metrics.ACC_utilization)}")
        print(f"REC utilization: {pct(metrics.REC_utilization)}")
        print(f"B-lane utilization: {pct(metrics.B_lane_utilization)}")
        print(f"dual-issue cycles: {metrics.dual_issue_cycles}")
        print(
            "full-iteration overlap utilization: "
            f"{pct(metrics.full_iteration_overlap_utilization)}"
        )
        print(
            "steady-state overlap utilization: "
            f"{pct(metrics.steady_state_overlap_utilization)}"
        )
        print(f"lookahead cycles hidden: {metrics.lookahead_cycles_hidden}")
        print(f"forwarded APP reads: {metrics.forwarded_APP_reads}")
        print(f"normal APP reads: {metrics.normal_APP_reads}")
        print(f"max forward-cache occupancy: {metrics.max_live_forward_vectors}")
        print(
            "forward lifetime tau_f "
            f"min/avg/max: {metrics.min_forward_lifetime}/"
            f"{metrics.avg_forward_lifetime:.2f}/{metrics.max_forward_lifetime}"
        )
        print()
        print("Layer-overlap matrix |Ci intersection Cj|")
        layers = DEFAULT_GRAPH.ordered_layers(metrics.layer_order)
        print("      " + " ".join(f"L{layer.layer_id:>3}" for layer in layers))
        for layer, row in zip(layers, overlap_matrix_table(DEFAULT_GRAPH, metrics.layer_order)):
            print(f"L{layer.layer_id:<3} " + " ".join(f"{value:4d}" for value in row))
        print()
        print("Independent capacity for every ordered layer transition")
        print(
            f"{'from':>5} {'to':>5} {'overlap':>8} {'ind edges':>10} "
            f"{'full ind pairs':>14} {'part ind pairs':>14} {'total pairs':>12}"
        )
        for row in transition_capacity_table(
            DEFAULT_GRAPH, DEFAULT_CONFIG, metrics.layer_order
        ):
            print(
                f"{row['from_layer']:5d} {row['to_layer']:5d} "
                f"{row['overlap']:8d} {row['independent_edges']:10d} "
                f"{row['fully_independent_pairs']:14d} "
                f"{row['partially_independent_pairs']:14d} "
                f"{row['total_pairs']:12d}"
            )
        print()
        print("Stall breakdown")
        for name, value in metrics.stall_counts.items():
            print(f"  {name}: {value}")
        print()
        print("IPCTEK comparison")
        print(f"candidate cycles/iteration: {metrics.cycles_per_iteration}")
        print(f"IPCTEK cycles/iteration: {metrics.ipctek_cycles_per_iteration}")
        print(f"reduction: {metrics.cycles_reduction_vs_ipctek_iter} cycles")
        print(f"percentage reduction: {metrics.percent_reduction_vs_ipctek_iter:.1f}%")
        print(
            "candidate iteration-dependent cycles "
            f"(N={metrics.max_iterations}): {metrics.candidate_iteration_dependent_cycles}"
        )
        print(
            "IPCTEK iteration-dependent cycles "
            f"(N={metrics.max_iterations}): {metrics.ipctek_iteration_dependent_cycles}"
        )
        if args.freq_mhz:
            seconds = metrics.candidate_total_cycles / (args.freq_mhz * 1_000_000)
            print(f"candidate total time at {args.freq_mhz:g} MHz: {seconds * 1e6:.3f} us")

        print()
        print("Feature ablation")
        print(
            f"{'Configuration':42} {'Cycles':>8} {'RAW':>6} {'Bank':>6} "
            f"{'Closure':>8} {'Total':>7} {'Fwd':>6}"
        )
        for label, ablation_result in feature_ablation(DEFAULT_GRAPH, DEFAULT_CONFIG):
            m = ablation_result.metrics
            print(
                f"{label:42} {m.cycles_per_iteration:8d} "
                f"{m.RAW_stall_cycles:6d} {m.bank_conflict_cycles:6d} "
                f"{m.closure_stall_cycles:8d} {m.total_stalls:7d} "
                f"{m.forwarded_APP_reads:6d}"
            )

        print()
        print("Layer-order search, all 24")
        for row in layer_order_table(DEFAULT_GRAPH, DEFAULT_CONFIG):
            print(
                f"#{row['rank']:2d} order={row['layer_order']} "
                f"cycles={row['cycles_per_iteration']} "
                f"RAW={row['RAW_stalls']} bank={row['bank_stalls']} "
                f"lookahead={row['lookahead_cycles_hidden']} fwd={row['forward_count']}"
            )

    if args.trace:
        print()
        print("Cycle trace")
        for item in result.trace:
            print(item.format())


if __name__ == "__main__":
    main()
