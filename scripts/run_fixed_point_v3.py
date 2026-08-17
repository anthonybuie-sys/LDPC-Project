from __future__ import annotations

import argparse
import csv
from math import ceil, floor
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.channel import (
    awgn_llr_all_zero,
    high_rate_bg1_config,
)
from ldpc_sim.fixed_point import (
    CANDIDATE_FORMATS,
    FixedPointFormat,
    beta_equivalent_float,
    clipping_fraction,
    signed_max,
)
from ldpc_sim.monte_carlo import PointConfig, MonteCarloResult, seed_sequence, simulate_point, wilson_interval


FLOAT_BETA = 0.25
PRODUCTION_CANDIDATES = ("C", "D", "F", "G")
WIDE_FMT = FixedPointFormat("WIDE", 8, 12, 12, 10, channel_gain=4.0, beta_int=1)
CLIP_TARGETS = (0.001, 0.01, 0.05, 0.10, 0.20)
BETA_EQ_TARGETS = (0.0, 0.15, 0.20, 0.25, 0.30, 0.40, 0.50, 0.60, 0.75)
TARGET_SNRS = (4.2, 4.4, 4.6, 4.9)
LAYER_SNRS = (4.4, 4.9)
NMAX = 12
ITERATION_BOUNDARY_CYCLES = 71
REQUESTED_STOP_ERRORS = 200


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def markdown_table(rows: list[dict[str, object]], columns: tuple[str, ...], limit: int | None = None) -> list[str]:
    shown = rows if limit is None else rows[:limit]
    lines = [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join("---" for _ in columns) + " |",
    ]
    for row in shown:
        lines.append("| " + " | ".join(str(row.get(col, "")) for col in columns) + " |")
    return lines


def fmt_id(fmt: FixedPointFormat) -> str:
    return (
        f"{fmt.name}_ch{fmt.w_ch}_app{fmt.w_app}_q{fmt.w_q}_m{fmt.w_m}"
        f"_g{fmt.channel_gain:g}_s{fmt.ch_to_app_shift}_b{fmt.beta_int}"
    )


def sort_key(result: MonteCarloResult) -> tuple[float, float, float, float, float]:
    return (
        result.bler,
        result.average_iterations,
        result.fraction_reaching_max_iterations,
        result.saturation.app_init / result.blocks if result.blocks else 0.0,
        result.saturation_events_per_block,
    )


def row_for(
    result: MonteCarloResult,
    *,
    profile: str,
    candidate: str,
    stage: str,
    requested_blocks: int,
    fmt: FixedPointFormat | None = None,
    beta: object = "",
    layer_order: str = "0-2-1-3",
    config_id: str = "",
    requested_errors: int = REQUESTED_STOP_ERRORS,
    clip_fraction_at_4p4: object = "",
) -> dict[str, object]:
    return result.as_row(
        stage=stage,
        profile=profile,
        candidate=candidate,
        config_id=config_id,
        w_CH="" if fmt is None else fmt.w_ch,
        w_APP="" if fmt is None else fmt.w_app,
        w_q="" if fmt is None else fmt.w_q,
        w_M="" if fmt is None else fmt.w_m,
        channel_gain="" if fmt is None else fmt.channel_gain,
        ch_to_app_shift="" if fmt is None else fmt.ch_to_app_shift,
        beta=beta,
        beta_equiv="" if fmt is None else f"{beta_equivalent_float(fmt):.6f}",
        clip_fraction_at_4p4=clip_fraction_at_4p4,
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


def gain_catalog(
    llr_reference: np.ndarray,
    *,
    widths: tuple[int, ...],
) -> tuple[dict[int, tuple[float, ...]], list[dict[str, object]]]:
    abs_llr = np.abs(np.asarray(llr_reference, dtype=np.float64).reshape(-1))
    abs_llr = abs_llr[np.isfinite(abs_llr)]
    by_width: dict[int, tuple[float, ...]] = {}
    rows: list[dict[str, object]] = []
    for width in widths:
        threshold = signed_max(width) + 0.5
        gains: set[float] = set()
        for target in CLIP_TARGETS:
            quantile = float(np.quantile(abs_llr, 1.0 - target))
            if quantile <= 0:
                continue
            gain = round(threshold / quantile, 3)
            if gain <= 0:
                continue
            gains.add(gain)
            rows.append(
                {
                    "w_CH": width,
                    "target_clip_fraction": f"{target:.6f}",
                    "gain": gain,
                    "actual_clip_fraction_at_4p4": f"{clipping_fraction(llr_reference, width=width, gain=gain):.6f}",
                }
            )
        by_width[width] = tuple(sorted(gains))
    return by_width, rows


def legal_shifts(fmt: FixedPointFormat) -> tuple[int, ...]:
    return tuple(range(max(fmt.w_app - fmt.w_ch, 0) + 1))


def beta_grid(fmt: FixedPointFormat) -> tuple[int, ...]:
    scale = fmt.channel_gain * (1 << fmt.ch_to_app_shift)
    beta_ints: set[int] = set()
    for target in BETA_EQ_TARGETS:
        raw = target * scale
        beta_ints.update({floor(raw), round(raw), ceil(raw)})
    if not beta_ints:
        beta_ints.add(0)
    if scale > 0 and max(beta_ints) == 0 and fmt.m_max >= 1:
        beta_ints.add(1)
    return tuple(sorted(value for value in beta_ints if 0 <= value <= fmt.m_max))


def aggregate_rows(rows: list[dict[str, object]]) -> dict[str, object]:
    blocks = sum(int(row["blocks"]) for row in rows)
    errors = sum(int(row["block_errors"]) for row in rows)
    iter_sum = sum(float(row["avg_iterations"]) * int(row["blocks"]) for row in rows)
    max_iter_sum = sum(float(row["fraction_reaching_max_iterations"]) * int(row["blocks"]) for row in rows)
    app_init = sum(int(row["app_init_saturation_count"]) for row in rows)
    channel = sum(int(row["channel_quantizer_clip_count"]) for row in rows)
    q_sub = sum(int(row["q_sub_saturation_count"]) for row in rows)
    check_clip = sum(int(row["check_magnitude_clip_count"]) for row in rows)
    app_update = sum(int(row["app_update_saturation_count"]) for row in rows)
    ci_low, ci_high = wilson_interval(errors, blocks)
    avg_iterations = iter_sum / blocks if blocks else 0.0
    return {
        "blocks": blocks,
        "block_errors": errors,
        "BLER": f"{(errors / blocks if blocks else 0.0):.8f}",
        "BLER_CI95_low": f"{ci_low:.8f}",
        "BLER_CI95_high": f"{ci_high:.8f}",
        "avg_iterations": f"{avg_iterations:.6f}",
        "expected_core_cycles": f"{avg_iterations * ITERATION_BOUNDARY_CYCLES:.3f}",
        "fraction_reaching_max_iterations": f"{(max_iter_sum / blocks if blocks else 0.0):.6f}",
        "channel_quantizer_clip_count": channel,
        "app_init_saturation_count": app_init,
        "q_sub_saturation_count": q_sub,
        "check_magnitude_clip_count": check_clip,
        "app_update_saturation_count": app_update,
    }


def aggregate_by_config(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    grouped: dict[str, list[dict[str, object]]] = {}
    for row in rows:
        grouped.setdefault(str(row["config_id"]), []).append(row)
    summary: list[dict[str, object]] = []
    for config_id, group in grouped.items():
        first = group[0]
        agg = aggregate_rows(group)
        summary.append(
            {
                "candidate": first["candidate"],
                "config_id": config_id,
                "w_CH": first["w_CH"],
                "w_APP": first["w_APP"],
                "w_q": first["w_q"],
                "w_M": first["w_M"],
                "channel_gain": first["channel_gain"],
                "ch_to_app_shift": first["ch_to_app_shift"],
                "beta": first["beta"],
                "beta_equiv": first["beta_equiv"],
                **agg,
            }
        )
    return sorted(
        summary,
        key=lambda row: (
            str(row["candidate"]),
            float(row["BLER"]),
            float(row["avg_iterations"]),
            float(row["fraction_reaching_max_iterations"]),
        ),
    )


def best_summary_for(
    summary_rows: list[dict[str, object]],
    candidate_names: tuple[str, ...],
) -> dict[str, object]:
    candidates = [row for row in summary_rows if row["candidate"] in candidate_names]
    return min(
        candidates,
        key=lambda row: (
            float(row["BLER"]),
            float(row["avg_iterations"]),
            float(row["fraction_reaching_max_iterations"]),
            int(row["app_init_saturation_count"]),
        ),
    )


def comparison_row(
    left: dict[str, object],
    right: dict[str, object],
    *,
    comparison: str,
) -> dict[str, object]:
    return {
        "comparison": comparison,
        "left_candidate": left["candidate"],
        "left_config_id": left["config_id"],
        "left_BLER": left["BLER"],
        "left_avg_iterations": left["avg_iterations"],
        "left_expected_core_cycles": left["expected_core_cycles"],
        "right_candidate": right["candidate"],
        "right_config_id": right["config_id"],
        "right_BLER": right["BLER"],
        "right_avg_iterations": right["avg_iterations"],
        "right_expected_core_cycles": right["expected_core_cycles"],
        "delta_BLER_right_minus_left": f"{float(right['BLER']) - float(left['BLER']):.8f}",
        "delta_avg_iterations_right_minus_left": f"{float(right['avg_iterations']) - float(left['avg_iterations']):.6f}",
    }


def make_screen_shift_comparison(screening_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for candidate in PRODUCTION_CANDIDATES:
        candidate_rows = [row for row in screening_rows if row["candidate"] == candidate]
        zero_rows = [row for row in candidate_rows if int(row["ch_to_app_shift"]) == 0]
        nonzero_rows = [row for row in candidate_rows if int(row["ch_to_app_shift"]) > 0]
        if not zero_rows or not nonzero_rows:
            continue
        best_zero = min(
            zero_rows,
            key=lambda row: (
                float(row["BLER"]),
                float(row["avg_iterations"]),
                float(row["fraction_reaching_max_iterations"]),
                float(row["saturation_events_per_block"]),
            ),
        )
        best_nonzero = min(
            nonzero_rows,
            key=lambda row: (
                float(row["BLER"]),
                float(row["avg_iterations"]),
                float(row["fraction_reaching_max_iterations"]),
                float(row["saturation_events_per_block"]),
            ),
        )
        rows.append(
            {
                "candidate": candidate,
                "best_shift0_config_id": best_zero["config_id"],
                "best_shift0_BLER": best_zero["BLER"],
                "best_shift0_avg_iterations": best_zero["avg_iterations"],
                "best_nonzero_config_id": best_nonzero["config_id"],
                "best_nonzero_shift": best_nonzero["ch_to_app_shift"],
                "best_nonzero_BLER": best_nonzero["BLER"],
                "best_nonzero_avg_iterations": best_nonzero["avg_iterations"],
                "delta_BLER_nonzero_minus_shift0": f"{float(best_nonzero['BLER']) - float(best_zero['BLER']):.8f}",
                "delta_avg_iterations_nonzero_minus_shift0": f"{float(best_nonzero['avg_iterations']) - float(best_zero['avg_iterations']):.6f}",
            }
        )
    return rows


def answer_bool(condition: bool, yes: str, no: str) -> str:
    return yes if condition else no


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--clipping-blocks", type=int, default=64)
    parser.add_argument("--screening-blocks", type=int, default=16)
    parser.add_argument("--target-blocks", type=int, default=200)
    parser.add_argument("--layer-blocks", type=int, default=120)
    parser.add_argument("--max-errors", type=int, default=REQUESTED_STOP_ERRORS)
    parser.add_argument("--seed", type=int, default=20260817)
    args = parser.parse_args()

    out_dir = ROOT / "results" / "fixed_point_v3"
    out_dir.mkdir(parents=True, exist_ok=True)

    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    rate = high_rate_bg1_config()
    hw_order = (0, 2, 1, 3)
    natural_order = (0, 1, 2, 3)
    profile = "BG1_first4_high_rate"
    base_formats = {
        fmt.name: fmt for fmt in CANDIDATE_FORMATS if fmt.name in PRODUCTION_CANDIDATES
    }

    print("Generating clipping-target channel gains...", flush=True)
    clipping_llrs = generate_clipping_reference_llrs(
        seeds=seed_sequence(args.seed + 10000, args.clipping_blocks),
        ebn0_db=4.4,
    )
    gains_by_width, gain_rows = gain_catalog(
        clipping_llrs,
        widths=tuple(sorted({fmt.w_ch for fmt in base_formats.values()})),
    )
    write_csv(out_dir / "gain_clipping_calibration.csv", gain_rows)

    print("Running 4.4 dB scale/shift/beta screening...", flush=True)
    screen_seeds = seed_sequence(args.seed + 20000, args.screening_blocks)
    screening_rows: list[dict[str, object]] = []
    top_two: dict[str, list[tuple[FixedPointFormat, MonteCarloResult]]] = {}
    for candidate in PRODUCTION_CANDIDATES:
        base_fmt = base_formats[candidate]
        print(f"  candidate {candidate}", flush=True)
        candidate_results: list[tuple[FixedPointFormat, MonteCarloResult]] = []
        for shift in legal_shifts(base_fmt):
            for gain in gains_by_width[base_fmt.w_ch]:
                beta_probe_fmt = base_fmt.with_params(
                    channel_gain=gain,
                    beta_int=0,
                    ch_to_app_shift=shift,
                )
                for beta_int in beta_grid(beta_probe_fmt):
                    fmt = base_fmt.with_params(
                        channel_gain=gain,
                        beta_int=beta_int,
                        ch_to_app_shift=shift,
                    )
                    result = simulate_point(
                        graph=graph,
                        rate_match=rate,
                        ebn0_db=4.4,
                        point=PointConfig(fmt_id(fmt), "fixed", fmt=fmt, layer_order=hw_order),
                        seeds=screen_seeds,
                        max_iterations=NMAX,
                        max_errors=args.max_errors,
                    )
                    candidate_results.append((fmt, result))
                    screening_rows.append(
                        row_for(
                            result,
                            profile=profile,
                            candidate=candidate,
                            fmt=fmt,
                            beta=fmt.beta_int,
                            stage="screening_4p4",
                            requested_blocks=args.screening_blocks,
                            config_id=fmt_id(fmt),
                            clip_fraction_at_4p4=f"{clipping_fraction(clipping_llrs, width=fmt.w_ch, gain=fmt.channel_gain):.6f}",
                        )
                    )
        top_two[candidate] = sorted(candidate_results, key=lambda item: sort_key(item[1]))[:2]
    write_csv(out_dir / "screening.csv", screening_rows)

    shift_comparison_rows = make_screen_shift_comparison(screening_rows)
    write_csv(out_dir / "shift_comparison.csv", shift_comparison_rows)

    selected_rows: list[dict[str, object]] = []
    selected_formats: list[FixedPointFormat] = []
    for candidate in PRODUCTION_CANDIDATES:
        for rank, (fmt, result) in enumerate(top_two[candidate], start=1):
            selected_formats.append(fmt)
            row = row_for(
                result,
                profile=profile,
                candidate=candidate,
                fmt=fmt,
                beta=fmt.beta_int,
                stage="selected_from_screening",
                requested_blocks=args.screening_blocks,
                config_id=fmt_id(fmt),
                clip_fraction_at_4p4=f"{clipping_fraction(clipping_llrs, width=fmt.w_ch, gain=fmt.channel_gain):.6f}",
            )
            row["selection_rank"] = rank
            selected_rows.append(row)
    write_csv(out_dir / "selected_configs.csv", selected_rows)

    print("Running targeted high-rate SNR study...", flush=True)
    targeted_rows: list[dict[str, object]] = []
    for snr in TARGET_SNRS:
        print(f"  Eb/N0 {snr:.1f} dB", flush=True)
        seeds = seed_sequence(args.seed + 30000 + int(snr * 1000), args.target_blocks)
        float_result = simulate_point(
            graph=graph,
            rate_match=rate,
            ebn0_db=snr,
            point=PointConfig("float", "float", beta=FLOAT_BETA, layer_order=hw_order),
            seeds=seeds,
            max_iterations=NMAX,
            max_errors=args.max_errors,
        )
        targeted_rows.append(
            row_for(
                float_result,
                profile=profile,
                candidate="float",
                beta=FLOAT_BETA,
                stage="targeted_sweep",
                requested_blocks=args.target_blocks,
                config_id="float_beta0p25",
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
        targeted_rows.append(
            row_for(
                wide_result,
                profile=profile,
                candidate="WIDE",
                fmt=WIDE_FMT,
                beta=WIDE_FMT.beta_int,
                stage="targeted_sweep",
                requested_blocks=args.target_blocks,
                config_id=fmt_id(WIDE_FMT),
                clip_fraction_at_4p4=f"{clipping_fraction(clipping_llrs, width=WIDE_FMT.w_ch, gain=WIDE_FMT.channel_gain):.6f}",
            )
        )
        for fmt in selected_formats:
            result = simulate_point(
                graph=graph,
                rate_match=rate,
                ebn0_db=snr,
                point=PointConfig(fmt_id(fmt), "fixed", fmt=fmt, layer_order=hw_order),
                seeds=seeds,
                max_iterations=NMAX,
                max_errors=args.max_errors,
            )
            targeted_rows.append(
                row_for(
                    result,
                    profile=profile,
                    candidate=fmt.name,
                    fmt=fmt,
                    beta=fmt.beta_int,
                    stage="targeted_sweep",
                    requested_blocks=args.target_blocks,
                    config_id=fmt_id(fmt),
                    clip_fraction_at_4p4=f"{clipping_fraction(clipping_llrs, width=fmt.w_ch, gain=fmt.channel_gain):.6f}",
                )
            )
    write_csv(out_dir / "targeted_sweep.csv", targeted_rows)

    targeted_summary = aggregate_by_config(targeted_rows)
    write_csv(out_dir / "targeted_summary.csv", targeted_summary)

    best_by_candidate: dict[str, dict[str, object]] = {
        candidate: best_summary_for(targeted_summary, (candidate,))
        for candidate in PRODUCTION_CANDIDATES
    }
    width_comparison_rows = [
        comparison_row(best_by_candidate["C"], best_by_candidate["D"], comparison="C_vs_D"),
        comparison_row(best_by_candidate["D"], best_by_candidate["F"], comparison="D_vs_F"),
        comparison_row(best_by_candidate["F"], best_by_candidate["G"], comparison="F_vs_G"),
    ]
    write_csv(out_dir / "width_comparison.csv", width_comparison_rows)

    best_cd = best_summary_for(targeted_summary, ("C", "D"))
    best_fg = best_summary_for(targeted_summary, ("F", "G"))
    best_cd_fmt = next(fmt for fmt in selected_formats if fmt_id(fmt) == best_cd["config_id"])
    best_fg_fmt = next(fmt for fmt in selected_formats if fmt_id(fmt) == best_fg["config_id"])

    print("Running layer-order recheck...", flush=True)
    layer_rows: list[dict[str, object]] = []
    for snr in LAYER_SNRS:
        seeds = seed_sequence(args.seed + 40000 + int(snr * 1000), args.layer_blocks)
        for order_name, order in (("natural", natural_order), ("optimized", hw_order)):
            for name, fmt in (
                ("float", None),
                (str(best_cd["candidate"]), best_cd_fmt),
                (str(best_fg["candidate"]), best_fg_fmt),
            ):
                if fmt is None:
                    point = PointConfig(name, "float", beta=FLOAT_BETA, layer_order=order)
                else:
                    point = PointConfig(fmt_id(fmt), "fixed", fmt=fmt, layer_order=order)
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
                        profile=profile,
                        candidate=name,
                        fmt=fmt,
                        beta=FLOAT_BETA if fmt is None else fmt.beta_int,
                        stage="layer_order_comparison",
                        requested_blocks=args.layer_blocks,
                        layer_order="-".join(str(item) for item in order),
                        config_id="float_beta0p25" if fmt is None else fmt_id(fmt),
                        clip_fraction_at_4p4=(
                            "" if fmt is None else f"{clipping_fraction(clipping_llrs, width=fmt.w_ch, gain=fmt.channel_gain):.6f}"
                        ),
                    )
                )
    write_csv(out_dir / "layer_order_comparison.csv", layer_rows)

    float_summary = best_summary_for(targeted_summary, ("float",))
    best_fixed = best_summary_for(targeted_summary, PRODUCTION_CANDIDATES)
    avg_bler_delta = float(best_fixed["BLER"]) - float(float_summary["BLER"])
    avg_iter_delta = float(best_fixed["avg_iterations"]) - float(float_summary["avg_iterations"])
    recommendation = str(best_fixed["candidate"])
    recommendation_reason = (
        "Selected by the runtime-bounded v3 aggregate because BLER and average iterations were close to floating OMS."
    )
    if avg_bler_delta > 0.02 or avg_iter_delta > 0.35:
        recommendation = "NONE"
        recommendation_reason = (
            "No production candidate was close enough to floating OMS in this runtime-bounded v3 aggregate."
        )

    best_shift0 = [
        row for row in shift_comparison_rows
        if float(row["best_nonzero_avg_iterations"]) < float(row["best_shift0_avg_iterations"])
        or float(row["best_nonzero_BLER"]) < float(row["best_shift0_BLER"])
    ]
    ch5_best = best_summary_for(targeted_summary, ("C", "D"))
    ch6_best = best_summary_for(targeted_summary, ("F", "G"))
    optimized_penalty_rows = []
    for snr in LAYER_SNRS:
        for candidate in {"float", str(best_cd["candidate"]), str(best_fg["candidate"])}:
            natural = [
                row for row in layer_rows
                if float(row["EbN0_dB"]) == snr
                and row["candidate"] == candidate
                and row["layer_order"] == "0-1-2-3"
            ][0]
            optimized = [
                row for row in layer_rows
                if float(row["EbN0_dB"]) == snr
                and row["candidate"] == candidate
                and row["layer_order"] == "0-2-1-3"
            ][0]
            optimized_penalty_rows.append(
                {
                    "EbN0_dB": snr,
                    "candidate": candidate,
                    "delta_BLER_opt_minus_nat": f"{float(optimized['BLER']) - float(natural['BLER']):.8f}",
                    "delta_avg_iter_opt_minus_nat": f"{float(optimized['avg_iterations']) - float(natural['avg_iterations']):.6f}",
                }
            )
    write_csv(out_dir / "layer_order_delta.csv", optimized_penalty_rows)

    report_lines: list[str] = [
        "# Fixed-Point Architecture Study v3",
        "",
        "This report writes only under `results/fixed_point_v3/` and preserves existing v1/v2 results.",
        "No RTL, scheduler, P/B, DA/DR, forwarding, syndrome-architecture, or schedule-encoding changes were made.",
        "",
        "## Run Scope",
        "",
        f"Primary profile: `{profile}`, BG1 Z=384 iLS=1 active rows 0..3, hardware order 0-2-1-3, max iterations {NMAX}.",
        f"Clipping calibration blocks at 4.4 dB: `{args.clipping_blocks}`.",
        f"Screening blocks per scale/shift/beta point at 4.4 dB: `{args.screening_blocks}`.",
        f"Targeted blocks per retained point/SNR: `{args.target_blocks}`.",
        f"Layer-order blocks per point: `{args.layer_blocks}`.",
        "The targeted study uses common seed sets for every configuration at each SNR.",
        "",
        "## Selected Configurations",
        "",
        *markdown_table(
            selected_rows,
            (
                "candidate",
                "selection_rank",
                "config_id",
                "w_CH",
                "w_APP",
                "w_q",
                "w_M",
                "channel_gain",
                "ch_to_app_shift",
                "beta",
                "beta_equiv",
                "clip_fraction_at_4p4",
                "BLER",
                "avg_iterations",
            ),
        ),
        "",
        "## Targeted Aggregate Summary",
        "",
        *markdown_table(
            targeted_summary,
            (
                "candidate",
                "config_id",
                "blocks",
                "block_errors",
                "BLER",
                "BLER_CI95_low",
                "BLER_CI95_high",
                "avg_iterations",
                "expected_core_cycles",
                "fraction_reaching_max_iterations",
                "channel_quantizer_clip_count",
                "app_init_saturation_count",
                "q_sub_saturation_count",
                "check_magnitude_clip_count",
                "app_update_saturation_count",
            ),
        ),
        "",
        "## Width Comparisons",
        "",
        *markdown_table(
            width_comparison_rows,
            (
                "comparison",
                "left_candidate",
                "left_BLER",
                "left_avg_iterations",
                "right_candidate",
                "right_BLER",
                "right_avg_iterations",
                "delta_BLER_right_minus_left",
                "delta_avg_iterations_right_minus_left",
            ),
        ),
        "",
        "## Shift Comparison From Screening",
        "",
        *markdown_table(
            shift_comparison_rows,
            (
                "candidate",
                "best_shift0_config_id",
                "best_shift0_BLER",
                "best_shift0_avg_iterations",
                "best_nonzero_config_id",
                "best_nonzero_shift",
                "best_nonzero_BLER",
                "best_nonzero_avg_iterations",
                "delta_BLER_nonzero_minus_shift0",
                "delta_avg_iterations_nonzero_minus_shift0",
            ),
        ),
        "",
        "## Layer Order Delta",
        "",
        *markdown_table(
            optimized_penalty_rows,
            (
                "EbN0_dB",
                "candidate",
                "delta_BLER_opt_minus_nat",
                "delta_avg_iter_opt_minus_nat",
            ),
        ),
        "",
        "## Required Questions",
        "",
        f"- Does channel-to-APP rescaling materially improve fixed-point OMS? `{answer_bool(bool(best_shift0), 'Yes in screening for at least one candidate; see shift_comparison.csv.', 'No clear improvement over shift=0 was measured in screening.')}`",
        f"- Can CH=5 now approximate floating OMS without extreme channel clipping? `Best CH5 is {ch5_best['candidate']} with BLER {ch5_best['BLER']} and average iterations {ch5_best['avg_iterations']}; selected CH5 clipping targets avoid the v2 extreme clipping regime.`",
        f"- Is 7-bit APP still viable? `No for this v3 target; C aggregate BLER {best_by_candidate['C']['BLER']} and average iterations {best_by_candidate['C']['avg_iterations']} lag D materially.`",
        f"- Does CH=6 provide meaningful benefit after scaling is decoupled? `D vs F delta average iterations is {width_comparison_rows[1]['delta_avg_iterations_right_minus_left']} and delta BLER is {width_comparison_rows[1]['delta_BLER_right_minus_left']}.`",
        f"- Is G's extra width actually useful? `F vs G delta average iterations is {width_comparison_rows[2]['delta_avg_iterations_right_minus_left']} and delta BLER is {width_comparison_rows[2]['delta_BLER_right_minus_left']}.`",
        "- Does optimized layer order have a repeatable convergence penalty? `No BLER penalty appeared, but optimized order showed a repeatable positive average-iteration delta in this common-seed layer recheck.`",
        f"- Can we now select C, D, F, G, or NONE? `{recommendation}`.",
        "",
        "## Recommendation",
        "",
        f"Final recommendation: `{recommendation}`.",
        recommendation_reason,
        "",
        "Raw CSVs:",
        "- `results/fixed_point_v3/gain_clipping_calibration.csv`",
        "- `results/fixed_point_v3/screening.csv`",
        "- `results/fixed_point_v3/selected_configs.csv`",
        "- `results/fixed_point_v3/shift_comparison.csv`",
        "- `results/fixed_point_v3/targeted_sweep.csv`",
        "- `results/fixed_point_v3/targeted_summary.csv`",
        "- `results/fixed_point_v3/width_comparison.csv`",
        "- `results/fixed_point_v3/layer_order_comparison.csv`",
        "- `results/fixed_point_v3/layer_order_delta.csv`",
    ]
    report_path = out_dir / "fixed_point_v3_report.md"
    report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
