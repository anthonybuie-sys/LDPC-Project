from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.architecture import ArchitectureConfig
from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.schedule_encoding import build_packed_program, decode_program
from ldpc_sim.simulator import run_configured
from ldpc_sim.syndrome import (
    FinalTouchAnalysis,
    SyndromeRunResult,
    analyze_final_touches,
    simulate_syndrome_engine,
)


S_VALUES = (1, 2, 4, 8, 16)
Q_VALUES = (2, 4, 8, 16)


@dataclass(frozen=True)
class Profile:
    name: str
    base_graph: int
    z: int
    i_ls: int
    active_layer_ids: tuple[int, ...] | None

    @property
    def active_text(self) -> str:
        if self.active_layer_ids is None:
            return "all"
        return "-".join(str(layer_id) for layer_id in self.active_layer_ids)


PROFILES: tuple[Profile, ...] = (
    Profile("BG1_first4_high_rate", 1, 384, 1, (0, 1, 2, 3)),
    Profile("BG1_full", 1, 384, 1, None),
    Profile("BG2_single0", 2, 384, 1, (0,)),
    Profile("BG2_full", 2, 384, 1, None),
)


def config() -> ArchitectureConfig:
    return ArchitectureConfig(
        Z=384,
        P=384,
        B=2,
        D_A=3,
        D_R=3,
        num_app_banks=8,
        forward_cache_depth=8,
        enable_lookahead=True,
        enable_forwarding=True,
        enable_jit_forwarding=True,
        enable_reconstruction_reorder=True,
        enable_layer_reorder=True,
        bank_strategy="optimized",
        pairing_strategy="optimized",
        max_cycles=20000,
    )


def verify_packed_final_touch_flags(result, final_touch: FinalTouchAnalysis) -> None:
    program = build_packed_program(
        result,
        rec_final_touch_by_cycle=final_touch.final_touch_by_rec_cycle,
    )
    _, decoded_rec = decode_program(program)
    for record in result.rec_issues:
        decoded = decoded_rec[record.cycle]
        expected = tuple(
            1 if final_touch.final_touch_by_rec_cycle[record.cycle].get(column, False) else 0
            for column in record.columns
        )
        if decoded.final_touch_values != expected:
            raise AssertionError(
                f"REC final-touch flag mismatch at cycle {record.cycle}: "
                f"{decoded.final_touch_values} != {expected}"
            )


def row_for(profile: Profile, result, run: SyndromeRunResult) -> dict[str, object]:
    return {
        "profile": profile.name,
        "base_graph": profile.base_graph,
        "active_layers": profile.active_text,
        "S": run.S,
        "Q": run.queue_depth,
        "valid": run.valid,
        "decoder_iteration_cycles": result.metrics.cycles_per_iteration,
        "total_qc_syndrome_work_items": run.total_work_items,
        "first_finalized_column_cycle": run.first_final_cycle,
        "last_finalized_column_cycle": run.last_final_cycle,
        "maximum_syndrome_backlog": run.max_syndrome_backlog,
        "maximum_finalized_column_queue_occupancy": run.max_finalized_queue_occupancy,
        "maximum_finalized_column_queue_occupancy_cycle": (
            run.max_finalized_queue_occupancy_cycle
        ),
        "required_queue_depth": run.required_queue_depth,
        "syndrome_engine_utilization": f"{run.syndrome_engine_utilization:.6f}",
        "syndrome_completion_cycle": run.syndrome_completion_cycle,
        "additional_tail_cycles": run.additional_tail_cycles,
        "effective_iteration_boundary": run.effective_iteration_boundary,
        "selected_layer_order": "-".join(str(item) for item in result.metrics.layer_order),
    }


def format_bits(bits: int) -> str:
    return f"{bits} bits ({bits / 3072:.3f}x APP path)"


def min_high_rate(rows: list[dict[str, object]]) -> dict[str, object] | None:
    candidates = [
        row
        for row in rows
        if row["profile"] == "BG1_first4_high_rate"
        and row["valid"] is True
        and int(row["additional_tail_cycles"]) <= 1
    ]
    return min(candidates, key=lambda row: (int(row["S"]), int(row["Q"])), default=None)


def min_all_profiles(rows: list[dict[str, object]]) -> tuple[int, int] | None:
    by_sq: dict[tuple[int, int], list[dict[str, object]]] = {}
    for row in rows:
        by_sq.setdefault((int(row["S"]), int(row["Q"])), []).append(row)
    candidates: list[tuple[int, int]] = []
    for (s, q), sq_rows in by_sq.items():
        if len(sq_rows) != len(PROFILES):
            continue
        if all(row["valid"] is True and int(row["additional_tail_cycles"]) <= 4 for row in sq_rows):
            candidates.append((s, q))
    return min(candidates, default=None)


def main() -> int:
    results_dir = ROOT / "results"
    results_dir.mkdir(exist_ok=True)
    csv_path = results_dir / "syndrome_streaming_sweep.csv"
    final_touch_csv = results_dir / "syndrome_final_touches.csv"
    rec_flags_csv = results_dir / "syndrome_rec_final_touch_flags.csv"
    work_items_csv = results_dir / "syndrome_work_items.csv"
    report_path = results_dir / "syndrome_streaming_analysis.md"

    cfg = config()
    rows: list[dict[str, object]] = []
    final_touch_rows: list[dict[str, object]] = []
    rec_flag_rows: list[dict[str, object]] = []
    work_item_rows: list[dict[str, object]] = []
    profile_lines: list[str] = []

    for profile in PROFILES:
        graph = load_3gpp_base_graph(
            profile.base_graph,
            profile.z,
            i_ls=profile.i_ls,
            active_layer_ids=profile.active_layer_ids,
        )
        result = run_configured(graph, cfg)
        final_touch = analyze_final_touches(graph, result, cfg)
        verify_packed_final_touch_flags(result, final_touch)
        for column, touch in sorted(final_touch.final_by_column.items()):
            final_touch_rows.append(
                {
                    "profile": profile.name,
                    "column": column,
                    "final_layer_id": touch.final_layer_id,
                    "final_edge_id": touch.final_edge_id,
                    "final_rec_pair_id": touch.rec_pair_id,
                    "rec_issue_cycle": touch.rec_issue_cycle,
                    "final_forward_valid_cycle": touch.final_valid_cycle,
                    "syndrome_work_items_for_column": len(final_touch.work_by_column[column]),
                }
            )
        for record in result.rec_issues:
            flags = final_touch.final_touch_by_rec_cycle[record.cycle]
            columns = list(record.columns)
            edge_ids = list(record.edge_ids)
            rec_flag_rows.append(
                {
                    "profile": profile.name,
                    "rec_cycle": record.cycle,
                    "layer_id": record.layer_id,
                    "pair_id": record.pair_id,
                    "column_A": columns[0] if len(columns) > 0 else "",
                    "edge_A": edge_ids[0] if len(edge_ids) > 0 else "",
                    "final_touch_A": bool(flags.get(columns[0], False)) if len(columns) > 0 else "",
                    "column_B": columns[1] if len(columns) > 1 else "",
                    "edge_B": edge_ids[1] if len(edge_ids) > 1 else "",
                    "final_touch_B": bool(flags.get(columns[1], False)) if len(columns) > 1 else "",
                }
            )
        for column, items in sorted(final_touch.work_by_column.items()):
            for item in items:
                work_item_rows.append(
                    {
                        "profile": profile.name,
                        "finalized_column": column,
                        "layer_id": item.layer_id,
                        "edge_id": item.edge_id,
                        "column": item.column,
                        "shift": item.shift,
                        "final_forward_valid_cycle": item.final_valid_cycle,
                    }
                )
        profile_lines.append(
            "| {name} | BG{bg} | {active} | {cycles} | {work} | {first} | {last} | {order} |".format(
                name=profile.name,
                bg=profile.base_graph,
                active=profile.active_text,
                cycles=result.metrics.cycles_per_iteration,
                work=final_touch.total_work_items,
                first=final_touch.first_final_cycle,
                last=final_touch.last_final_cycle,
                order="-".join(str(item) for item in result.metrics.layer_order),
            )
        )
        for s in S_VALUES:
            for q in Q_VALUES:
                run = simulate_syndrome_engine(
                    profile=profile.name,
                    decoder_cycles_per_iteration=result.metrics.cycles_per_iteration,
                    final_touch=final_touch,
                    S=s,
                    queue_depth=q,
                )
                rows.append(row_for(profile, result, run))

    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    with final_touch_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(final_touch_rows[0].keys()))
        writer.writeheader()
        writer.writerows(final_touch_rows)

    with rec_flags_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rec_flag_rows[0].keys()))
        writer.writeheader()
        writer.writerows(rec_flag_rows)

    with work_items_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(work_item_rows[0].keys()))
        writer.writeheader()
        writer.writerows(work_item_rows)

    high_rate = min_high_rate(rows)
    all_profiles = min_all_profiles(rows)

    def profile_sq_row(profile_name: str, s: int, q: int) -> dict[str, object]:
        for row in rows:
            if row["profile"] == profile_name and int(row["S"]) == s and int(row["Q"]) == q:
                return row
        raise KeyError((profile_name, s, q))

    high_rate_text = (
        "none"
        if high_rate is None
        else f"S={high_rate['S']}, Q={high_rate['Q']}, tail={high_rate['additional_tail_cycles']}"
    )
    all_profiles_text = (
        "none"
        if all_profiles is None
        else f"S={all_profiles[0]}, Q={all_profiles[1]}"
    )

    recommended = "dedicated post-iteration syndrome pass instead"
    recommended_q = "N/A"
    if high_rate is not None:
        recommended = f"S={high_rate['S']}"
        recommended_q = str(high_rate["Q"])

    lines = [
        "# Final-Touch Streaming Syndrome Analysis",
        "",
        "Architecture model: real BG1/BG2 schedules, `P=384`, `B=2`, `D_A=3`, `D_R=3`, `APP banks=8`, `forward_cache_depth=8`, optimized bank map, optimized pairing, JIT forwarding.",
        "The decoder schedule is observed after construction; decoder issue order, forwarding, banking, and pipeline behavior are unchanged.",
        "",
        "## Profile Timing",
        "",
        "| Profile | BG | Active Layers | Decoder Iteration Cycles | QC Work Items | First Final Cycle | Last Final Cycle | Selected Layer Order |",
        "|---|---:|---|---:|---:|---:|---:|---|",
        *profile_lines,
        "",
        "## High-Rate BG1 Tail Sweep",
        "",
        "| S | Q | Valid | Max Backlog | Max Queue Occupancy | Utilization | Completion | Tail | Effective Boundary |",
        "|---:|---:|---|---:|---:|---:|---:|---:|---:|",
    ]
    for s in S_VALUES:
        for q in Q_VALUES:
            row = profile_sq_row("BG1_first4_high_rate", s, q)
            lines.append(
                "| {S} | {Q} | {valid} | {maximum_syndrome_backlog} | "
                "{maximum_finalized_column_queue_occupancy} | {syndrome_engine_utilization} | "
                "{syndrome_completion_cycle} | {additional_tail_cycles} | "
                "{effective_iteration_boundary} |".format(**row)
            )

    lines.extend(
        [
            "",
            "## Minimums",
            "",
            f"Minimum high-rate BG1 configuration with `L_syndrome-tail <= 1`: {high_rate_text}.",
            f"Minimum configuration with `L_syndrome-tail <= 4` across all tested profiles: {all_profiles_text}.",
            "",
            "## Cross-Section",
            "",
            "| S | W_syndrome at Z=384 | Compare to 3072-bit APP permutation path |",
            "|---:|---:|---:|",
        ]
    )
    for s in S_VALUES:
        bits = s * 384
        lines.append(f"| {s} | {bits} | {bits / 3072:.3f}x |")

    lines.extend(
        [
            "",
            "## All-Profile Recommended Row",
            "",
            "| Profile | S | Q | Valid | Tail | Required Queue | Max Backlog | Utilization |",
            "|---|---:|---:|---|---:|---:|---:|---:|",
        ]
    )
    if all_profiles is not None:
        s, q = all_profiles
        for profile in PROFILES:
            row = profile_sq_row(profile.name, s, q)
            lines.append(
                "| {profile} | {S} | {Q} | {valid} | {additional_tail_cycles} | "
                "{required_queue_depth} | {maximum_syndrome_backlog} | "
                "{syndrome_engine_utilization} |".format(**row)
            )
    else:
        lines.append("| N/A | N/A | N/A | False | N/A | N/A | N/A | N/A |")

    lines.extend(
        [
            "",
            "## Recommendation",
            "",
            f"Recommended option for the high-rate early-termination objective: `{recommended}` with finalized-column queue depth `{recommended_q}`.",
            "A dedicated post-iteration pass is not required for the high-rate BG1 four-layer benchmark if that architecture is acceptable.",
            "",
            f"Raw sweep CSV: `{csv_path.relative_to(ROOT)}`.",
            f"Per-column final-touch CSV: `{final_touch_csv.relative_to(ROOT)}`.",
            f"REC A/B final-touch flag CSV: `{rec_flags_csv.relative_to(ROOT)}`.",
            f"Per-edge syndrome work CSV: `{work_items_csv.relative_to(ROOT)}`.",
        ]
    )
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
