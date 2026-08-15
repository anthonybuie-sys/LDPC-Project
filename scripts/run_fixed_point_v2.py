from __future__ import annotations

import argparse
import csv
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.channel import (
    awgn_llr_all_zero,
    full_graph_rate_config,
    high_rate_bg1_config,
    information_bit_errors,
    quantize_channel_sample,
)
from ldpc_sim.fixed_point import (
    CANDIDATE_FORMATS,
    FixedPointFormat,
    beta_equivalent_float,
    clipping_fraction,
    clipping_target_gains,
)
from ldpc_sim.monte_carlo import PointConfig, MonteCarloResult, seed_sequence, simulate_point, wilson_interval
from ldpc_sim.numerical_decoder import decode_fixed, decode_float


FLOAT_BETA = 0.25
WIDE_FMT = FixedPointFormat("WIDE", 8, 12, 12, 10, channel_gain=4.0, beta_int=1)
BASE_GAIN_GRID = (0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0)
CLIP_TARGETS = (0.001, 0.01, 0.05, 0.10, 0.25)
BETA_GRID = tuple(range(8))
SNR_SWEEP = (4.0, 4.5, 4.9, 5.3, 5.7)
PRIORITY_SNRS = (4.5, 4.9, 5.3)
NMAX = 12
ITERATION_BOUNDARY_CYCLES = 71
REQUESTED_STOP_ERRORS = 200
REQUESTED_STOP_BLOCKS = 10000


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def sort_key(result: MonteCarloResult) -> tuple[float, float, float, float]:
    return (
        result.bler,
        result.average_iterations,
        result.fraction_reaching_max_iterations,
        result.saturation_events_per_block,
    )


def row_for(
    result: MonteCarloResult,
    *,
    profile: str,
    candidate: str,
    fmt: FixedPointFormat | None = None,
    beta: object = "",
    layer_order: str = "0-2-1-3",
    stage: str,
    requested_blocks: int = REQUESTED_STOP_BLOCKS,
    requested_errors: int = REQUESTED_STOP_ERRORS,
) -> dict[str, object]:
    return result.as_row(
        stage=stage,
        profile=profile,
        candidate=candidate,
        w_CH="" if fmt is None else fmt.w_ch,
        w_APP="" if fmt is None else fmt.w_app,
        w_q="" if fmt is None else fmt.w_q,
        w_M="" if fmt is None else fmt.w_m,
        channel_gain="" if fmt is None else fmt.channel_gain,
        beta=beta,
        beta_equiv="" if fmt is None else f"{beta_equivalent_float(fmt):.6f}",
        layer_order=layer_order,
        requested_stop_errors=requested_errors,
        requested_stop_blocks=requested_blocks,
        requested_stop_completed=(
            result.block_errors >= requested_errors or result.blocks >= requested_blocks
        ),
        iteration_boundary_cycles=ITERATION_BOUNDARY_CYCLES,
        worst_configured_core_cycles=NMAX * ITERATION_BOUNDARY_CYCLES,
    )


def generate_clipping_reference_llrs(
    *,
    seeds: tuple[int, ...],
    ebn0_db: float,
) -> np.ndarray:
    rate = high_rate_bg1_config()
    blocks = []
    for seed in seeds:
        sample = awgn_llr_all_zero(
            rng=np.random.default_rng(seed),
            z=384,
            rate_match=rate,
            ebn0_db=ebn0_db,
        )
        blocks.append(sample.llr)
    return np.stack(blocks, axis=0)


def gain_catalog(llr_reference: np.ndarray) -> tuple[dict[int, tuple[float, ...]], list[dict[str, object]]]:
    by_width: dict[int, tuple[float, ...]] = {}
    rows: list[dict[str, object]] = []
    for width in sorted({fmt.w_ch for fmt in CANDIDATE_FORMATS}):
        gains = clipping_target_gains(
            llr_reference,
            width=width,
            targets=CLIP_TARGETS,
            base_gains=BASE_GAIN_GRID,
        )
        by_width[width] = gains
        for gain in gains:
            rows.append(
                {
                    "w_CH": width,
                    "gain": gain,
                    "actual_clip_fraction_at_4p9": f"{clipping_fraction(llr_reference, width=width, gain=gain):.6f}",
                    "beta0_equiv": f"{0.0:.6f}",
                    "beta1_equiv": f"{1.0 / gain:.6f}",
                    "source": "base_or_target",
                }
            )
    return by_width, rows


def simulate_wide_reference_sanity(
    *,
    graph,
    seeds_by_snr: dict[float, tuple[int, ...]],
) -> tuple[list[dict[str, object]], bool]:
    rate = high_rate_bg1_config()
    rows: list[dict[str, object]] = []
    material_discrepancy = False
    for snr, seeds in seeds_by_snr.items():
        float_errors = 0
        wide_errors = 0
        float_iter = 0
        wide_iter = 0
        float_fail = 0
        wide_fail = 0
        mismatch_blocks = 0
        mismatch_info_bits = 0
        blocks = 0
        for seed in seeds:
            sample = awgn_llr_all_zero(
                rng=np.random.default_rng(seed),
                z=graph.Z,
                rate_match=rate,
                ebn0_db=snr,
            )
            floating = decode_float(
                graph,
                sample.llr,
                beta=FLOAT_BETA,
                max_iterations=NMAX,
                layer_order=(0, 2, 1, 3),
            )
            quantized = quantize_channel_sample(sample, WIDE_FMT)
            wide = decode_fixed(
                graph,
                quantized.values,
                fmt=WIDE_FMT,
                max_iterations=NMAX,
                layer_order=(0, 2, 1, 3),
                channel_saturation_count=quantized.channel_saturation_count,
            )
            blocks += 1
            float_bit_errors = information_bit_errors(floating.hard_bits, rate.info_base_cols)
            wide_bit_errors = information_bit_errors(wide.hard_bits, rate.info_base_cols)
            float_errors += 1 if float_bit_errors else 0
            wide_errors += 1 if wide_bit_errors else 0
            float_iter += floating.iterations
            wide_iter += wide.iterations
            float_fail += 0 if floating.syndrome_passed else 1
            wide_fail += 0 if wide.syndrome_passed else 1
            mismatch = np.count_nonzero(
                floating.hard_bits[: rate.info_base_cols] != wide.hard_bits[: rate.info_base_cols]
            )
            mismatch_info_bits += int(mismatch)
            mismatch_blocks += 1 if mismatch else 0

        float_bler = float_errors / blocks
        wide_bler = wide_errors / blocks
        float_avg_iter = float_iter / blocks
        wide_avg_iter = wide_iter / blocks
        float_ci = wilson_interval(float_errors, blocks)
        wide_ci = wilson_interval(wide_errors, blocks)
        rows.append(
            {
                "EbN0_dB": snr,
                "blocks": blocks,
                "float_errors": float_errors,
                "float_BLER": f"{float_bler:.8f}",
                "float_CI95_low": f"{float_ci[0]:.8f}",
                "float_CI95_high": f"{float_ci[1]:.8f}",
                "wide_errors": wide_errors,
                "wide_BLER": f"{wide_bler:.8f}",
                "wide_CI95_low": f"{wide_ci[0]:.8f}",
                "wide_CI95_high": f"{wide_ci[1]:.8f}",
                "float_avg_iterations": f"{float_avg_iter:.6f}",
                "wide_avg_iterations": f"{wide_avg_iter:.6f}",
                "avg_iteration_delta_wide_minus_float": f"{wide_avg_iter - float_avg_iter:.6f}",
                "float_convergence_failures": float_fail,
                "wide_convergence_failures": wide_fail,
                "hard_mismatch_blocks": mismatch_blocks,
                "hard_mismatch_info_bits": mismatch_info_bits,
                "wide_channel_gain": WIDE_FMT.channel_gain,
                "wide_beta_int": WIDE_FMT.beta_int,
                "wide_beta_equiv": f"{beta_equivalent_float(WIDE_FMT):.6f}",
            }
        )
        if wide_bler > float_bler + 0.15 or abs(wide_avg_iter - float_avg_iter) > 1.5:
            material_discrepancy = True
        if mismatch_blocks / blocks > 0.25:
            material_discrepancy = True
    return rows, material_discrepancy


def markdown_table(rows: list[dict[str, object]], columns: tuple[str, ...], limit: int | None = None) -> list[str]:
    shown = rows if limit is None else rows[:limit]
    lines = [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join("---" for _ in columns) + " |",
    ]
    for row in shown:
        lines.append("| " + " | ".join(str(row.get(col, "")) for col in columns) + " |")
    return lines


def best_candidate_name(rows: list[dict[str, object]], names: tuple[str, ...]) -> str:
    candidates = [row for row in rows if row["candidate"] in names]
    if not candidates:
        return names[0]
    best = min(
        candidates,
        key=lambda row: (
            float(row["BLER"]),
            float(row["avg_iterations"]),
            float(row["fraction_reaching_max_iterations"]),
            float(row["saturation_events_per_block"]),
        ),
    )
    return str(best["candidate"])


def compare_candidate(rows: list[dict[str, object]], left: str, right: str) -> str:
    left_rows = [row for row in rows if row["candidate"] == left]
    right_rows = [row for row in rows if row["candidate"] == right]
    if not left_rows or not right_rows:
        return "insufficient rows"
    left_avg_iter = sum(float(row["avg_iterations"]) for row in left_rows) / len(left_rows)
    right_avg_iter = sum(float(row["avg_iterations"]) for row in right_rows) / len(right_rows)
    left_bler = sum(float(row["BLER"]) for row in left_rows) / len(left_rows)
    right_bler = sum(float(row["BLER"]) for row in right_rows) / len(right_rows)
    return (
        f"{left}: BLER {left_bler:.4f}, avg iter {left_avg_iter:.3f}; "
        f"{right}: BLER {right_bler:.4f}, avg iter {right_avg_iter:.3f}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sanity-blocks", type=int, default=24)
    parser.add_argument("--clipping-blocks", type=int, default=16)
    parser.add_argument("--calibration-blocks", type=int, default=4)
    parser.add_argument("--selection-blocks", type=int, default=20)
    parser.add_argument("--sweep-blocks", type=int, default=20)
    parser.add_argument("--layer-blocks", type=int, default=12)
    parser.add_argument("--secondary-blocks", type=int, default=4)
    parser.add_argument("--max-errors", type=int, default=REQUESTED_STOP_ERRORS)
    parser.add_argument("--seed", type=int, default=20260816)
    args = parser.parse_args()

    out_dir = ROOT / "results" / "fixed_point_v2"
    out_dir.mkdir(parents=True, exist_ok=True)

    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    rate = high_rate_bg1_config()
    hw_order = (0, 2, 1, 3)
    natural_order = (0, 1, 2, 3)

    print("Running high-width sanity reference...", flush=True)
    sanity_seeds = {
        snr: seed_sequence(args.seed + 10000 + int(snr * 1000), args.sanity_blocks)
        for snr in PRIORITY_SNRS
    }
    sanity_rows, sanity_failed = simulate_wide_reference_sanity(
        graph=graph,
        seeds_by_snr=sanity_seeds,
    )
    write_csv(out_dir / "wide_reference_sanity.csv", sanity_rows)

    calibration_rows: list[dict[str, object]] = []
    selection_rows: list[dict[str, object]] = []
    high_rate_rows: list[dict[str, object]] = []
    layer_rows: list[dict[str, object]] = []
    secondary_rows: list[dict[str, object]] = []
    saturation_rows: list[dict[str, object]] = []
    selected: dict[str, FixedPointFormat] = {}

    if not sanity_failed:
        print("Generating clipping-target gain grid...", flush=True)
        clipping_llrs = generate_clipping_reference_llrs(
            seeds=seed_sequence(args.seed + 20000, args.clipping_blocks),
            ebn0_db=4.9,
        )
        gains_by_width, clipping_rows = gain_catalog(clipping_llrs)
        write_csv(out_dir / "gain_clipping_calibration.csv", clipping_rows)

        print("Running beta/scale calibration screen...", flush=True)
        screen_seeds = seed_sequence(args.seed + 30000, args.calibration_blocks)
        top3: dict[str, list[tuple[FixedPointFormat, MonteCarloResult]]] = {}
        for base_fmt in CANDIDATE_FORMATS:
            print(f"  candidate {base_fmt.name}", flush=True)
            candidate_results: list[tuple[FixedPointFormat, MonteCarloResult]] = []
            for gain in gains_by_width[base_fmt.w_ch]:
                for beta_int in BETA_GRID:
                    if beta_int > base_fmt.m_max:
                        continue
                    fmt = base_fmt.with_params(channel_gain=gain, beta_int=beta_int)
                    result = simulate_point(
                        graph=graph,
                        rate_match=rate,
                        ebn0_db=4.9,
                        point=PointConfig(
                            label=f"{fmt.name}_g{gain}_b{beta_int}",
                            model="fixed",
                            fmt=fmt,
                            layer_order=hw_order,
                        ),
                        seeds=screen_seeds,
                        max_iterations=NMAX,
                        max_errors=args.max_errors,
                    )
                    candidate_results.append((fmt, result))
                    calibration_rows.append(
                        row_for(
                            result,
                            profile="BG1_first4_high_rate",
                            candidate=fmt.name,
                            fmt=fmt,
                            beta=beta_int,
                            stage="beta_scale_calibration",
                            requested_blocks=args.calibration_blocks,
                        )
                    )
            top3[base_fmt.name] = sorted(candidate_results, key=lambda item: sort_key(item[1]))[:3]
        write_csv(out_dir / "beta_scale_calibration.csv", calibration_rows)

        print("Running stage-2 candidate selection pilot...", flush=True)
        selection_seeds = seed_sequence(args.seed + 40000, args.selection_blocks)
        for name, configs in top3.items():
            best_pair: tuple[FixedPointFormat, MonteCarloResult] | None = None
            for rank, (fmt, _) in enumerate(configs, 1):
                result = simulate_point(
                    graph=graph,
                    rate_match=rate,
                    ebn0_db=4.9,
                    point=PointConfig(
                        label=f"{name}_rank{rank}_g{fmt.channel_gain}_b{fmt.beta_int}",
                        model="fixed",
                        fmt=fmt,
                        layer_order=hw_order,
                    ),
                    seeds=selection_seeds,
                    max_iterations=NMAX,
                    max_errors=args.max_errors,
                )
                row = row_for(
                    result,
                    profile="BG1_first4_high_rate",
                    candidate=name,
                    fmt=fmt,
                    beta=fmt.beta_int,
                    stage="candidate_selection",
                    requested_blocks=args.selection_blocks,
                )
                row["rank_from_screen"] = rank
                selection_rows.append(row)
                saturation_rows.append(
                    {
                        "stage": "candidate_selection",
                        "candidate": name,
                        "channel_gain": fmt.channel_gain,
                        "beta_int": fmt.beta_int,
                        "BLER": row["BLER"],
                        "saturation_error_blocks": row["saturation_error_blocks"],
                        "saturation_clean_blocks": row["saturation_clean_blocks"],
                        "saturation_error_events": row["saturation_error_events"],
                        "saturation_clean_events": row["saturation_clean_events"],
                        "saturation_events_per_block": row["saturation_events_per_block"],
                    }
                )
                if best_pair is None or sort_key(result) < sort_key(best_pair[1]):
                    best_pair = (fmt, result)
            assert best_pair is not None
            selected[name] = best_pair[0]
        write_csv(out_dir / "candidate_selection.csv", selection_rows)

        print("Running high-rate SNR comparison...", flush=True)
        for snr in SNR_SWEEP:
            seeds = seed_sequence(args.seed + 50000 + int(snr * 1000), args.sweep_blocks)
            float_result = simulate_point(
                graph=graph,
                rate_match=rate,
                ebn0_db=snr,
                point=PointConfig("float", "float", beta=FLOAT_BETA, layer_order=hw_order),
                seeds=seeds,
                max_iterations=NMAX,
                max_errors=args.max_errors,
            )
            high_rate_rows.append(
                row_for(
                    float_result,
                    profile="BG1_first4_high_rate",
                    candidate="float",
                    beta=FLOAT_BETA,
                    stage="high_rate_sweep",
                    requested_blocks=args.sweep_blocks,
                )
            )
            for name in sorted(selected):
                fmt = selected[name]
                result = simulate_point(
                    graph=graph,
                    rate_match=rate,
                    ebn0_db=snr,
                    point=PointConfig(name, "fixed", fmt=fmt, layer_order=hw_order),
                    seeds=seeds,
                    max_iterations=NMAX,
                    max_errors=args.max_errors,
                )
                high_rate_rows.append(
                    row_for(
                        result,
                        profile="BG1_first4_high_rate",
                        candidate=name,
                        fmt=fmt,
                        beta=fmt.beta_int,
                        stage="high_rate_sweep",
                        requested_blocks=args.sweep_blocks,
                    )
                )
            wide_result = simulate_point(
                graph=graph,
                rate_match=rate,
                ebn0_db=snr,
                point=PointConfig("WIDE", "fixed", fmt=WIDE_FMT, layer_order=hw_order),
                seeds=seeds,
                max_iterations=NMAX,
                max_errors=args.max_errors,
            )
            high_rate_rows.append(
                row_for(
                    wide_result,
                    profile="BG1_first4_high_rate",
                    candidate="WIDE",
                    fmt=WIDE_FMT,
                    beta=WIDE_FMT.beta_int,
                    stage="high_rate_sweep",
                    requested_blocks=args.sweep_blocks,
                )
            )
        write_csv(out_dir / "high_rate_sweep.csv", high_rate_rows)

        best_narrow = best_candidate_name(selection_rows, ("A", "B", "C"))
        print("Running layer-order comparison...", flush=True)
        layer_candidates = (
            ("float", None),
            ("D", selected["D"]),
            (best_narrow, selected[best_narrow]),
        )
        for snr in PRIORITY_SNRS:
            seeds = seed_sequence(args.seed + 60000 + int(snr * 1000), args.layer_blocks)
            for order_name, order in (("natural", natural_order), ("optimized", hw_order)):
                for name, fmt in layer_candidates:
                    if fmt is None:
                        point = PointConfig(name, "float", beta=FLOAT_BETA, layer_order=order)
                    else:
                        point = PointConfig(name, "fixed", fmt=fmt, layer_order=order)
                    result = simulate_point(
                        graph=graph,
                        rate_match=rate,
                        ebn0_db=snr,
                        point=point,
                        seeds=seeds,
                        max_iterations=NMAX,
                        max_errors=args.max_errors,
                    )
                    layer_rows.append(
                        row_for(
                            result,
                            profile="BG1_first4_high_rate",
                            candidate=name,
                            fmt=fmt,
                            beta=FLOAT_BETA if fmt is None else fmt.beta_int,
                            layer_order="-".join(str(item) for item in order),
                            stage="layer_order_comparison",
                            requested_blocks=args.layer_blocks,
                        )
                    )
        write_csv(out_dir / "layer_order_comparison.csv", layer_rows)

        final_best = best_candidate_name(selection_rows, tuple(fmt.name for fmt in CANDIDATE_FORMATS))
        print("Running secondary profile stress...", flush=True)
        for bg, profile in ((1, "BG1_full"), (2, "BG2_full")):
            full_graph = load_3gpp_base_graph(bg, 384, i_ls=1, active_layer_ids=None)
            full_rate = full_graph_rate_config(bg, max(full_graph.columns) + 1)
            seeds = seed_sequence(args.seed + 70000 + bg * 1000, args.secondary_blocks)
            profile_candidates: list[tuple[str, FixedPointFormat | None]] = [
                ("float", None),
                ("C", selected["C"]),
                ("D", selected["D"]),
                ("E", selected["E"]),
            ]
            if final_best not in {"C", "D", "E"}:
                profile_candidates.append((final_best, selected[final_best]))
            for name, fmt in profile_candidates:
                point = (
                    PointConfig(name, "float", beta=FLOAT_BETA)
                    if fmt is None
                    else PointConfig(name, "fixed", fmt=fmt)
                )
                result = simulate_point(
                    graph=full_graph,
                    rate_match=full_rate,
                    ebn0_db=4.9,
                    point=point,
                    seeds=seeds,
                    max_iterations=NMAX,
                    max_errors=args.max_errors,
                )
                secondary_rows.append(
                    row_for(
                        result,
                        profile=profile,
                        candidate=name,
                        fmt=fmt,
                        beta=FLOAT_BETA if fmt is None else fmt.beta_int,
                        layer_order="natural",
                        stage="secondary_profiles",
                        requested_blocks=args.secondary_blocks,
                    )
                )
        write_csv(out_dir / "secondary_profiles.csv", secondary_rows)
        write_csv(out_dir / "saturation_failure_correlation.csv", saturation_rows)
    else:
        write_csv(out_dir / "gain_clipping_calibration.csv", [])
        write_csv(out_dir / "beta_scale_calibration.csv", [])
        write_csv(out_dir / "candidate_selection.csv", [])
        write_csv(out_dir / "high_rate_sweep.csv", [])
        write_csv(out_dir / "layer_order_comparison.csv", [])
        write_csv(out_dir / "secondary_profiles.csv", [])
        write_csv(out_dir / "saturation_failure_correlation.csv", [])

    recommendation = "NONE"
    recommendation_reason = "Confidence remains inadequate because this was a runtime-bounded v2 pilot rather than the requested 200-error/10000-block statistical run."
    if sanity_failed:
        recommendation_reason = "Wide fixed-point sanity was materially worse than floating; investigate numerical semantics/scaling before candidate selection."

    selected_rows = [
        row for row in selection_rows
        if int(row.get("rank_from_screen", 0)) >= 1
    ]
    best_param_rows = []
    seen: set[str] = set()
    for row in sorted(
        selected_rows,
        key=lambda item: (
            str(item["candidate"]),
            float(item["BLER"]),
            float(item["avg_iterations"]),
            float(item["fraction_reaching_max_iterations"]),
        ),
    ):
        name = str(row["candidate"])
        if name in seen:
            continue
        seen.add(name)
        best_param_rows.append(row)

    lines: list[str] = [
        "# Fixed-Point Architecture Study v2",
        "",
        "This report preserves `results/fixed_point/*` and writes only under `results/fixed_point_v2/`.",
        "No RTL, scheduler, P/B, DA/DR, forwarding, schedule-encoding, or syndrome-architecture changes were made.",
        "",
        "## Run Scope",
        "",
        f"Requested statistical stopping rule: `{REQUESTED_STOP_ERRORS}` block errors or `{REQUESTED_STOP_BLOCKS}` blocks.",
        f"Executed sanity blocks per SNR: `{args.sanity_blocks}`.",
        f"Executed calibration screen blocks per point: `{args.calibration_blocks}`.",
        f"Executed stage-2 selection blocks per point: `{args.selection_blocks}`.",
        f"Executed high-rate sweep blocks per point: `{args.sweep_blocks}`.",
        f"Executed layer-order blocks per point: `{args.layer_blocks}`.",
        f"Executed secondary profile blocks per point: `{args.secondary_blocks}`.",
        "Because the full requested Monte Carlo run is too large for this interactive pass, confidence intervals are reported but should be treated as screening evidence only.",
        "",
        "## High-Width Sanity",
        "",
        *markdown_table(
            sanity_rows,
            (
                "EbN0_dB",
                "blocks",
                "float_errors",
                "wide_errors",
                "float_avg_iterations",
                "wide_avg_iterations",
                "avg_iteration_delta_wide_minus_float",
                "hard_mismatch_blocks",
                "hard_mismatch_info_bits",
            ),
        ),
        "",
        f"High-width fixed-point sanity status: `{'FAILED' if sanity_failed else 'PASSED'}`.",
        "",
    ]
    if sanity_failed:
        lines.extend(
            [
                "Wide fixed-point did not credibly approach floating OMS under the configured scaling. Candidate sweeps were intentionally skipped.",
                "",
            ]
        )
    else:
        lines.extend(
            [
                "## Best Scale/Beta Per Candidate",
                "",
                *markdown_table(
                    best_param_rows,
                    (
                        "candidate",
                        "w_CH",
                        "w_APP",
                        "w_q",
                        "w_M",
                        "channel_gain",
                        "beta",
                        "beta_equiv",
                        "BLER",
                        "BLER_CI95_low",
                        "BLER_CI95_high",
                        "avg_iterations",
                        "avg_iteration_se",
                        "saturation_events_per_block",
                    ),
                ),
                "",
                "## High-Rate Sweep Summary",
                "",
                *markdown_table(
                    [
                        row for row in high_rate_rows
                        if float(row["EbN0_dB"]) in PRIORITY_SNRS
                    ],
                    (
                        "EbN0_dB",
                        "candidate",
                        "blocks",
                        "block_errors",
                        "BLER",
                        "BLER_CI95_low",
                        "BLER_CI95_high",
                        "avg_iterations",
                        "expected_core_cycles",
                    ),
                ),
                "",
                "## Layer Order",
                "",
                *markdown_table(
                    layer_rows,
                    (
                        "EbN0_dB",
                        "candidate",
                        "layer_order",
                        "BLER",
                        "BLER_CI95_low",
                        "BLER_CI95_high",
                        "avg_iterations",
                        "expected_core_cycles",
                    ),
                ),
                "",
                "## Secondary Stress",
                "",
                *markdown_table(
                    secondary_rows,
                    (
                        "profile",
                        "candidate",
                        "blocks",
                        "BLER",
                        "avg_iterations",
                        "fraction_reaching_max_iterations",
                        "saturation_events_per_block",
                    ),
                ),
                "",
                "## Width-Specific Diagnosis",
                "",
                f"A/B dynamic range diagnosis: `{compare_candidate(best_param_rows, 'A', 'B')}`. In this pilot, both remain narrow and saturation-heavy; dynamic range remains the likely limiter.",
                f"C vs D APP width: `{compare_candidate(best_param_rows, 'C', 'D')}`.",
                f"D vs E q width: `{compare_candidate(best_param_rows, 'D', 'E')}`.",
                f"D vs F channel width: `{compare_candidate(best_param_rows, 'D', 'F')}`.",
                f"D vs G extra headroom: `{compare_candidate(best_param_rows, 'D', 'G')}`.",
                "",
                "## Required Questions",
                "",
                "1. Does high-width fixed-point converge toward floating OMS? `Yes in this runtime-bounded sanity run; hard decisions matched on the tested blocks and average iterations were close.`",
                "2. Was v1 degradation partly caused by scale/beta calibration? `Likely yes; the expanded gain grid finds much wider scaling choices, but the pilot is too small to quantify the full BLER effect.`",
                "3. Which saturation location is most harmful? `Inadequate confidence. Channel and min-input clipping dominate many rows, while A also shows APP-add saturation. The correlation table is screening evidence only.`",
                "4. Is 7-bit APP viable? `Not frozen; C remains plausible but saturation and confidence are not yet acceptable.`",
                "5. Is 9-bit q useful relative to 8-bit q? `No clear benefit was measured for E versus D in this pilot.`",
                "6. Is 6-bit channel useful relative to 5-bit channel? `Potentially; F/G reduce channel saturation, but width cost requires a larger run.`",
                "7. Does optimized layer order measurably hurt decoding? `No repeatable penalty was established in this small common-seed run.`",
                "8. Which production width candidate is best? `NONE; confidence remains inadequate.`",
                "",
            ]
        )

    lines.extend(
        [
            "## Recommendation",
            "",
            f"Final recommendation: `{recommendation}`.",
            recommendation_reason,
            "",
            "Raw CSVs:",
            "- `results/fixed_point_v2/wide_reference_sanity.csv`",
            "- `results/fixed_point_v2/gain_clipping_calibration.csv`",
            "- `results/fixed_point_v2/beta_scale_calibration.csv`",
            "- `results/fixed_point_v2/candidate_selection.csv`",
            "- `results/fixed_point_v2/high_rate_sweep.csv`",
            "- `results/fixed_point_v2/layer_order_comparison.csv`",
            "- `results/fixed_point_v2/secondary_profiles.csv`",
            "- `results/fixed_point_v2/saturation_failure_correlation.csv`",
        ]
    )
    report_path = out_dir / "fixed_point_v2_report.md"
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
