from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.benchmark_bg1_z384 import DEFAULT_CONFIG, DEFAULT_GRAPH
from ldpc_sim.simulator import (
    PIPELINE_SWEEP_DEPTHS,
    pipeline_depth_sweep,
    pipeline_sensitivity_summary,
    sweep_matrix,
    write_pipeline_depth_sweep_csv,
)

CSV_PATH = ROOT / "results" / "pipeline_depth_sweep_real_bg1.csv"


def _fmt_value(value: object) -> str:
    if isinstance(value, float):
        return f"{value:.3f}"
    return str(value)


def print_matrix(title: str, rows: list[dict[str, object]], metric: str) -> None:
    print(title)
    print("D_A \\ D_R " + " ".join(f"{d_r:>6}" for d_r in PIPELINE_SWEEP_DEPTHS))
    for d_a, values in zip(PIPELINE_SWEEP_DEPTHS, sweep_matrix(rows, metric)):
        print(f"{d_a:>9} " + " ".join(f"{_fmt_value(value):>6}" for value in values))
    print()


def row_for(
    rows: list[dict[str, object]],
    d_a: int,
    d_r: int,
) -> dict[str, object]:
    for row in rows:
        if row["D_A"] == d_a and row["D_R"] == d_r:
            return row
    raise KeyError((d_a, d_r))


def target_label(cycles: int) -> str:
    if cycles <= 65:
        return "particularly promising"
    if cycles <= 70:
        return "strong target"
    if cycles < 133:
        return "minimum success"
    return "misses IPCTEK reference"


def print_point(label: str, row: dict[str, object]) -> None:
    cycles = int(row["cycles_per_iteration"])
    print(
        f"{label:18} DA={row['D_A']} DR={row['D_R']} "
        f"T_iter={cycles:3d} order={row['best_layer_order']} "
        f"RAW={row['STALL_RAW']} REC_CLOSE={row['STALL_REC_NOT_CLOSED']} "
        f"APP_BANK={row['STALL_APP_BANK']} fwd={row['forwarded_APP_reads']} "
        f"maxF={row['max_live_forward_vectors']} "
        f"tau_f={row['tau_f_min']}/{float(row['tau_f_avg']):.2f}/{row['tau_f_max']} "
        f"IPCTEK_delta={row['delta_vs_ipctek_133']} "
        f"loss_tie={float(row['allowable_frequency_loss_pct_vs_DA4_DR4']):.1f}% "
        f"({target_label(cycles)})"
    )


def print_sensitivity(summary: dict[str, object]) -> None:
    print("Sensitivity analysis")
    print(
        "Average cycles saved by reducing D_A by one stage: "
        f"{float(summary['average_D_A_stage_savings']):.2f}"
    )
    print(
        "Average cycles saved by reducing D_R by one stage: "
        f"{float(summary['average_D_R_stage_savings']):.2f}"
    )
    print(f"Maximum D_A one-stage saving: {summary['max_D_A_stage_savings']}")
    print(f"Maximum D_R one-stage saving: {summary['max_D_R_stage_savings']}")
    print(f"D_A no-benefit points: {summary['D_A_no_benefit_points']}")
    print(f"D_R no-benefit points: {summary['D_R_no_benefit_points']}")
    path = summary["more_sensitive_path"]
    if path == "D_A":
        conclusion = "accumulation closure latency is more valuable to shorten."
    elif path == "D_R":
        conclusion = "reconstruction/forwarding latency is more valuable to shorten."
    else:
        conclusion = "D_A and D_R have equal average sensitivity in this sweep."
    print(f"Conclusion: {conclusion}")
    print()


def main() -> None:
    rows = pipeline_depth_sweep(DEFAULT_GRAPH, DEFAULT_CONFIG)
    write_pipeline_depth_sweep_csv(rows, CSV_PATH)

    print(DEFAULT_GRAPH.source_note)
    print("Pipeline depth sensitivity sweep")
    print("Fixed: P=384, B=2, APP banks=8, forward cache=8, actual BG1 layers 0..3")
    print(f"CSV: {CSV_PATH}")
    print()

    print_matrix("Cycles/iteration matrix", rows, "cycles_per_iteration")
    print_matrix("RAW stall matrix", rows, "STALL_RAW")
    print_matrix("REC_NOT_CLOSED stall matrix", rows, "STALL_REC_NOT_CLOSED")
    print_matrix("APP_BANK stall matrix", rows, "STALL_APP_BANK")
    print_matrix("Max forward-cache occupancy matrix", rows, "max_live_forward_vectors")

    best = min(rows, key=lambda row: (row["cycles_per_iteration"], row["D_A"], row["D_R"]))
    print("Key points")
    print_point("Best point", best)
    print_point("Current 4,4", row_for(rows, 4, 4))
    print_point("Shallow ACC", row_for(rows, 3, 4))
    print_point("Shallow REC", row_for(rows, 4, 3))
    print_point("Both shallow", row_for(rows, 3, 3))
    print_point("Aggressive bound", row_for(rows, 2, 2))
    print()

    summary = pipeline_sensitivity_summary(rows)
    print_sensitivity(summary)
    print("Frequency break-even values are reported as allowable loss versus DA=4, DR=4.")
    print("Reference-frequency iteration times are included in the CSV as sensitivity assumptions only.")


if __name__ == "__main__":
    main()
