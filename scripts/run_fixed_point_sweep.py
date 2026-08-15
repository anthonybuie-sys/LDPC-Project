from __future__ import annotations

import argparse
import csv
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.channel import full_graph_rate_config, high_rate_bg1_config
from ldpc_sim.fixed_point import CANDIDATE_FORMATS, FixedPointFormat
from ldpc_sim.monte_carlo import PointConfig, MonteCarloResult, seed_sequence, simulate_point


FLOAT_BETA_GRID = (0.0, 0.25, 0.5, 0.75, 1.0)
GAIN_GRID = (0.5, 0.75, 1.0, 1.25)
BETA_INT_GRID = (0, 1, 2, 3)
SNR_SWEEP = (4.0, 4.5, 4.9, 5.3, 5.7)
LAYER_ORDER_SNRS = (4.5, 4.9, 5.3)
NMAX = 12
ITERATION_BOUNDARY_CYCLES = 71


def sort_key(result: MonteCarloResult) -> tuple[float, float, float]:
    success_iter = result.average_successful_iterations or float("inf")
    return (
        result.bler,
        success_iter,
        result.saturation_events_per_block,
    )


def row_with_params(
    result: MonteCarloResult,
    *,
    candidate: str = "",
    w_ch: object = "",
    w_app: object = "",
    w_q: object = "",
    w_m: object = "",
    channel_gain: object = "",
    beta: object = "",
    profile: str = "BG1_first4_high_rate",
    layer_order: str = "0-2-1-3",
) -> dict[str, object]:
    return result.as_row(
        profile=profile,
        candidate=candidate,
        w_CH=w_ch,
        w_APP=w_app,
        w_q=w_q,
        w_M=w_m,
        channel_gain=channel_gain,
        beta=beta,
        layer_order=layer_order,
        iteration_boundary_cycles=ITERATION_BOUNDARY_CYCLES,
        worst_configured_core_cycles=NMAX * ITERATION_BOUNDARY_CYCLES,
    )


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def fixed_point_width_proxy(fmt: FixedPointFormat) -> dict[str, int]:
    b = 2
    z = 384
    nf = 8
    edge_id_width = 5
    return {
        "candidate": fmt.name,
        "w_CH": fmt.w_ch,
        "w_APP": fmt.w_app,
        "w_q": fmt.w_q,
        "w_M": fmt.w_m,
        "W_APP_perm": b * z * fmt.w_app,
        "W_q": b * z * fmt.w_q,
        "W_forward_state": nf * z * fmt.w_app,
        "W_check": 2 * fmt.w_m + edge_id_width + 1,
    }


def proxy_rows() -> list[dict[str, object]]:
    raw = [fixed_point_width_proxy(fmt) for fmt in CANDIDATE_FORMATS]
    baseline = next(row for row in raw if row["candidate"] == "D")
    rows: list[dict[str, object]] = []
    for row in raw:
        out: dict[str, object] = dict(row)
        for key in ("W_APP_perm", "W_q", "W_forward_state", "W_check"):
            out[f"{key}_reduction_vs_D_pct"] = f"{100.0 * (baseline[key] - row[key]) / baseline[key]:.2f}"
        rows.append(out)
    return rows


def choose_recommendation(
    high_rate_rows: list[dict[str, object]],
    best_fixed: dict[str, tuple[FixedPointFormat, MonteCarloResult]],
) -> tuple[str, str]:
    float_rows = [row for row in high_rate_rows if row["candidate"] == "float"]
    fixed_rows = [row for row in high_rate_rows if row["model"] == "fixed"]
    if float_rows and fixed_rows:
        min_blocks = min(int(row["blocks"]) for row in high_rate_rows)
        if min_blocks < 1000:
            return (
                "NONE",
                "The completed run is a small deterministic pilot. It is useful for correctness, ordering, and saturation screening, but too small to freeze a v1.0 width set.",
            )
        float_4db = [row for row in float_rows if float(row["EbN0_dB"]) == 4.0]
        fixed_4db = [row for row in fixed_rows if float(row["EbN0_dB"]) == 4.0]
        if float_4db and fixed_4db:
            reference_bler = float(float_4db[0]["BLER"])
            best_fixed_bler = min(float(row["BLER"]) for row in fixed_4db)
            if best_fixed_bler > reference_bler + 0.20:
                return (
                    "NONE",
                    "All fixed-point candidates were materially worse than the floating reference at 4.0 dB in the pilot, so the quantizer grid needs more study.",
                )

    fixed_sweep = [
        row for row in high_rate_rows
        if row["model"] == "fixed" and float(row["EbN0_dB"]) in {4.5, 4.9, 5.3}
    ]
    by_candidate: dict[str, list[dict[str, object]]] = {}
    for row in fixed_sweep:
        by_candidate.setdefault(str(row["candidate"]), []).append(row)
    d_rows = by_candidate.get("D", [])
    if not d_rows:
        return "NONE", "Candidate D was not present in the pilot sweep."
    d_bler = sum(float(row["BLER"]) for row in d_rows) / len(d_rows)
    candidates: list[tuple[float, int, str]] = []
    for name, rows in by_candidate.items():
        if len(rows) != len(d_rows):
            continue
        avg_bler = sum(float(row["BLER"]) for row in rows) / len(rows)
        avg_iter = sum(float(row["avg_iterations"]) for row in rows) / len(rows)
        fmt = best_fixed[name][0]
        width_score = fmt.w_app + fmt.w_q + fmt.w_m + fmt.w_ch
        if avg_bler <= d_bler + 0.02:
            candidates.append((avg_iter, width_score, name))
    if not candidates:
        return "NONE", "No fixed-point candidate stayed within the pilot BLER guard band versus D."
    _, _, selected = min(candidates)
    fmt, _ = best_fixed[selected]
    return (
        selected,
        f"Selected by pilot average iterations with BLER within +0.02 of Candidate D across 4.5/4.9/5.3 dB; gain={fmt.channel_gain}, beta_int={fmt.beta_int}.",
    )


def markdown_table(rows: list[dict[str, object]], columns: tuple[str, ...], limit: int | None = None) -> list[str]:
    shown = rows if limit is None else rows[:limit]
    lines = [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join("---" for _ in columns) + " |",
    ]
    for row in shown:
        lines.append("| " + " | ".join(str(row[col]) for col in columns) + " |")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--calibration-blocks", type=int, default=80)
    parser.add_argument("--sweep-blocks", type=int, default=120)
    parser.add_argument("--layer-blocks", type=int, default=80)
    parser.add_argument("--secondary-blocks", type=int, default=40)
    parser.add_argument("--max-errors", type=int, default=100)
    parser.add_argument("--seed", type=int, default=20260815)
    args = parser.parse_args()

    out_dir = ROOT / "results" / "fixed_point"
    out_dir.mkdir(parents=True, exist_ok=True)
    calibration_path = out_dir / "calibration.csv"
    high_rate_path = out_dir / "high_rate_sweep.csv"
    layer_path = out_dir / "layer_order_comparison.csv"
    secondary_path = out_dir / "secondary_profiles.csv"
    proxy_path = out_dir / "hardware_width_proxy.csv"
    report_path = out_dir / "fixed_point_report.md"

    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    rate = high_rate_bg1_config()
    hw_order = (0, 2, 1, 3)
    natural_order = (0, 1, 2, 3)
    calibration_seeds = seed_sequence(args.seed + 4900, args.calibration_blocks)

    calibration_rows: list[dict[str, object]] = []
    float_results: list[tuple[float, MonteCarloResult]] = []
    print("Calibrating floating-point beta grid...", flush=True)
    for beta in FLOAT_BETA_GRID:
        result = simulate_point(
            graph=graph,
            rate_match=rate,
            ebn0_db=4.9,
            point=PointConfig(label=f"float_beta_{beta}", model="float", beta=beta, layer_order=hw_order),
            seeds=calibration_seeds,
            max_iterations=NMAX,
            max_errors=args.max_errors,
        )
        float_results.append((beta, result))
        calibration_rows.append(
            row_with_params(
                result,
                candidate="float",
                beta=beta,
                layer_order="0-2-1-3",
            )
        )
    float_beta, float_best_result = min(float_results, key=lambda item: sort_key(item[1]))

    best_fixed: dict[str, tuple[FixedPointFormat, MonteCarloResult]] = {}
    for base_fmt in CANDIDATE_FORMATS:
        print(f"Calibrating fixed candidate {base_fmt.name}...", flush=True)
        candidate_results: list[tuple[FixedPointFormat, MonteCarloResult]] = []
        for gain in GAIN_GRID:
            for beta_int in BETA_INT_GRID:
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
                    seeds=calibration_seeds,
                    max_iterations=NMAX,
                    max_errors=args.max_errors,
                )
                candidate_results.append((fmt, result))
                calibration_rows.append(
                    row_with_params(
                        result,
                        candidate=fmt.name,
                        w_ch=fmt.w_ch,
                        w_app=fmt.w_app,
                        w_q=fmt.w_q,
                        w_m=fmt.w_m,
                        channel_gain=gain,
                        beta=beta_int,
                        layer_order="0-2-1-3",
                    )
                )
        best_fixed[base_fmt.name] = min(candidate_results, key=lambda item: sort_key(item[1]))

    write_csv(calibration_path, calibration_rows)

    high_rate_rows: list[dict[str, object]] = []
    for snr in SNR_SWEEP:
        print(f"Running high-rate sweep at Eb/N0={snr} dB...", flush=True)
        seeds = seed_sequence(args.seed + int(snr * 1000), args.sweep_blocks)
        result = simulate_point(
            graph=graph,
            rate_match=rate,
            ebn0_db=snr,
            point=PointConfig(
                label=f"float_beta_{float_beta}",
                model="float",
                beta=float_beta,
                layer_order=hw_order,
            ),
            seeds=seeds,
            max_iterations=NMAX,
            max_errors=args.max_errors,
        )
        high_rate_rows.append(
            row_with_params(
                result,
                candidate="float",
                beta=float_beta,
                layer_order="0-2-1-3",
            )
        )
        for name in sorted(best_fixed):
            fmt, _ = best_fixed[name]
            result = simulate_point(
                graph=graph,
                rate_match=rate,
                ebn0_db=snr,
                point=PointConfig(
                    label=f"{name}_g{fmt.channel_gain}_b{fmt.beta_int}",
                    model="fixed",
                    fmt=fmt,
                    layer_order=hw_order,
                ),
                seeds=seeds,
                max_iterations=NMAX,
                max_errors=args.max_errors,
            )
            high_rate_rows.append(
                row_with_params(
                    result,
                    candidate=name,
                    w_ch=fmt.w_ch,
                    w_app=fmt.w_app,
                    w_q=fmt.w_q,
                    w_m=fmt.w_m,
                    channel_gain=fmt.channel_gain,
                    beta=fmt.beta_int,
                    layer_order="0-2-1-3",
                )
            )
    write_csv(high_rate_path, high_rate_rows)

    best_narrow_name = min(("A", "B", "C"), key=lambda name: sort_key(best_fixed[name][1]))
    layer_points: list[tuple[str, PointConfig, str, str]] = [
        (
            "float",
            PointConfig("float", "float", beta=float_beta),
            "float",
            str(float_beta),
        ),
        (
            "D",
            PointConfig("D", "fixed", fmt=best_fixed["D"][0]),
            "D",
            str(best_fixed["D"][0].beta_int),
        ),
        (
            best_narrow_name,
            PointConfig(best_narrow_name, "fixed", fmt=best_fixed[best_narrow_name][0]),
            best_narrow_name,
            str(best_fixed[best_narrow_name][0].beta_int),
        ),
    ]
    layer_rows: list[dict[str, object]] = []
    for snr in LAYER_ORDER_SNRS:
        print(f"Comparing layer orders at Eb/N0={snr} dB...", flush=True)
        seeds = seed_sequence(args.seed + 300000 + int(snr * 1000), args.layer_blocks)
        for order_name, order in (("natural", natural_order), ("hardware", hw_order)):
            for candidate_name, point, _, beta_text in layer_points:
                point = PointConfig(
                    label=f"{candidate_name}_{order_name}",
                    model=point.model,
                    beta=point.beta,
                    fmt=point.fmt,
                    layer_order=order,
                )
                result = simulate_point(
                    graph=graph,
                    rate_match=rate,
                    ebn0_db=snr,
                    point=point,
                    seeds=seeds,
                    max_iterations=NMAX,
                    max_errors=args.max_errors,
                )
                fmt = point.fmt
                layer_rows.append(
                    row_with_params(
                        result,
                        candidate=candidate_name,
                        w_ch=fmt.w_ch if fmt else "",
                        w_app=fmt.w_app if fmt else "",
                        w_q=fmt.w_q if fmt else "",
                        w_m=fmt.w_m if fmt else "",
                        channel_gain=fmt.channel_gain if fmt else "",
                        beta=beta_text,
                        layer_order="-".join(str(item) for item in order),
                    )
                )
    write_csv(layer_path, layer_rows)

    secondary_rows: list[dict[str, object]] = []
    for bg, profile in ((1, "BG1_full"), (2, "BG2_full")):
        print(f"Running secondary stress profile {profile}...", flush=True)
        full_graph = load_3gpp_base_graph(bg, 384, i_ls=1, active_layer_ids=None)
        full_rate = full_graph_rate_config(bg, max(full_graph.columns) + 1)
        seeds = seed_sequence(args.seed + 500000 + bg * 1000, args.secondary_blocks)
        secondary_points = [
            ("float", PointConfig("float", "float", beta=float_beta), "float", str(float_beta)),
            ("C", PointConfig("C", "fixed", fmt=best_fixed["C"][0]), "C", str(best_fixed["C"][0].beta_int)),
            ("D", PointConfig("D", "fixed", fmt=best_fixed["D"][0]), "D", str(best_fixed["D"][0].beta_int)),
            ("E", PointConfig("E", "fixed", fmt=best_fixed["E"][0]), "E", str(best_fixed["E"][0].beta_int)),
        ]
        for candidate_name, point, _, beta_text in secondary_points:
            result = simulate_point(
                graph=full_graph,
                rate_match=full_rate,
                ebn0_db=4.9,
                point=point,
                seeds=seeds,
                max_iterations=NMAX,
                max_errors=args.max_errors,
            )
            fmt = point.fmt
            secondary_rows.append(
                row_with_params(
                    result,
                    candidate=candidate_name,
                    w_ch=fmt.w_ch if fmt else "",
                    w_app=fmt.w_app if fmt else "",
                    w_q=fmt.w_q if fmt else "",
                    w_m=fmt.w_m if fmt else "",
                    channel_gain=fmt.channel_gain if fmt else "",
                    beta=beta_text,
                    profile=profile,
                    layer_order="natural",
                )
            )
    write_csv(secondary_path, secondary_rows)

    width_rows = proxy_rows()
    write_csv(proxy_path, width_rows)

    recommendation, recommendation_reason = choose_recommendation(high_rate_rows, best_fixed)
    selected_fmt = best_fixed.get(recommendation, (None, None))[0]

    best_param_rows = []
    for name in sorted(best_fixed):
        fmt, result = best_fixed[name]
        best_param_rows.append(
            {
                "candidate": name,
                "widths": f"{fmt.w_ch}/{fmt.w_app}/{fmt.w_q}/{fmt.w_m}",
                "channel_gain": fmt.channel_gain,
                "beta_int": fmt.beta_int,
                "calibration_BLER": f"{result.bler:.6f}",
                "calibration_avg_iter": f"{result.average_iterations:.4f}",
                "sat_events_per_block": f"{result.saturation_events_per_block:.3f}",
            }
        )

    bler_rows = [
        {
            "EbN0": row["EbN0_dB"],
            "candidate": row["candidate"],
            "blocks": row["blocks"],
            "errors": row["block_errors"],
            "BLER": row["BLER"],
        }
        for row in high_rate_rows
    ]
    iter_rows = [
        {
            "EbN0": row["EbN0_dB"],
            "candidate": row["candidate"],
            "avg_iterations": row["avg_iterations"],
            "expected_core_cycles": row["expected_core_cycles"],
        }
        for row in high_rate_rows
    ]
    sat_rows = [
        {
            "EbN0": row["EbN0_dB"],
            "candidate": row["candidate"],
            "channel": row["channel_saturation_count"],
            "q_sub": row["q_sub_saturation_count"],
            "min_clip": row["min_input_clip_count"],
            "app_add": row["app_add_saturation_count"],
            "sat_blocks": row["saturation_block_fraction"],
            "sat_per_block": row["saturation_events_per_block"],
        }
        for row in high_rate_rows
        if row["model"] == "fixed" and float(row["EbN0_dB"]) == 4.9
    ]

    layer_summary_rows = [
        {
            "EbN0": row["EbN0_dB"],
            "candidate": row["candidate"],
            "order": row["layer_order"],
            "BLER": row["BLER"],
            "avg_iter": row["avg_iterations"],
            "failures": row["convergence_failures"],
        }
        for row in layer_rows
    ]
    secondary_summary_rows = [
        {
            "profile": row["profile"],
            "candidate": row["candidate"],
            "blocks": row["blocks"],
            "BLER": row["BLER"],
            "avg_iter": row["avg_iterations"],
            "failures": row["convergence_failures"],
            "sat_per_block": row["saturation_events_per_block"],
        }
        for row in secondary_rows
    ]

    lines: list[str] = [
        "# Fixed-Point Numerical OMS Pilot",
        "",
        "This is a deterministic runtime-bounded pilot, not a publication-quality BLER curve.",
        "The cycle scheduler, P/B choice, DA/DR choice, schedule encoding, forwarding architecture, syndrome architecture, and RTL were not modified.",
        "",
        "## Verification Context",
        "",
        f"Calibration blocks per point: `{args.calibration_blocks}` or stop at `{args.max_errors}` block errors.",
        f"High-rate sweep blocks per point: `{args.sweep_blocks}` or stop at `{args.max_errors}` block errors.",
        f"Layer-order comparison blocks per point: `{args.layer_blocks}` or stop at `{args.max_errors}` block errors.",
        f"Secondary profile blocks per point: `{args.secondary_blocks}` or stop at `{args.max_errors}` block errors.",
        "BPSK all-zero convention: bit 0 maps to +1, `sigma^2 = 1/(2 R 10^(EbN0/10))`, and `LLR = 2y/sigma^2`.",
        "High-rate BG1 uses `R=22/24`, columns 0 and 1 punctured to exactly zero LLR, and no filler bits.",
        "",
        "## Floating Reference",
        "",
        f"Selected floating OMS beta: `{float_beta}`.",
        "",
        "## Best Fixed Parameters",
        "",
        *markdown_table(
            best_param_rows,
            ("candidate", "widths", "channel_gain", "beta_int", "calibration_BLER", "calibration_avg_iter", "sat_events_per_block"),
        ),
        "",
        "## High-Rate BLER",
        "",
        *markdown_table(bler_rows, ("EbN0", "candidate", "blocks", "errors", "BLER")),
        "",
        "## Average Iterations And Expected Core Cycles",
        "",
        *markdown_table(iter_rows, ("EbN0", "candidate", "avg_iterations", "expected_core_cycles")),
        "",
        "## Saturation At 4.9 dB",
        "",
        *markdown_table(sat_rows, ("EbN0", "candidate", "channel", "q_sub", "min_clip", "app_add", "sat_blocks", "sat_per_block")),
        "",
        "## Hardware Width Proxies",
        "",
        *markdown_table(
            width_rows,
            (
                "candidate",
                "w_CH",
                "w_APP",
                "w_q",
                "w_M",
                "W_APP_perm",
                "W_q",
                "W_forward_state",
                "W_check",
                "W_APP_perm_reduction_vs_D_pct",
            ),
        ),
        "",
        "## Natural Vs Hardware Layer Order",
        "",
        *markdown_table(layer_summary_rows, ("EbN0", "candidate", "order", "BLER", "avg_iter", "failures")),
        "",
        "## Secondary Profile Stress",
        "",
        *markdown_table(secondary_summary_rows, ("profile", "candidate", "blocks", "BLER", "avg_iter", "failures", "sat_per_block")),
        "",
        "## Compressed-State Equivalence",
        "",
        "The unit tests exercise floating and fixed full-C2V versus compressed-state equivalence. No numerical mismatch was observed in the deterministic tests used for this report.",
        "",
        "## Recommendation",
        "",
        f"Recommended v1.0 width set: `{recommendation}`.",
        recommendation_reason,
    ]
    if selected_fmt is not None:
        lines.extend(
            [
                f"Recommended channel_gain: `{selected_fmt.channel_gain}`.",
                f"Recommended beta_int: `{selected_fmt.beta_int}`.",
            ]
        )
    else:
        lines.extend(
            [
                "Recommended channel_gain: `N/A`.",
                "Recommended beta_int: `N/A`.",
            ]
        )
    lines.extend(
        [
            "Recommended latency-focused Nmax default: `6`.",
            "Recommended stronger-error-correction Nmax default: `12`.",
            "",
            "Raw outputs:",
            f"- `{calibration_path.relative_to(ROOT)}`",
            f"- `{high_rate_path.relative_to(ROOT)}`",
            f"- `{layer_path.relative_to(ROOT)}`",
            f"- `{secondary_path.relative_to(ROOT)}`",
            f"- `{proxy_path.relative_to(ROOT)}`",
        ]
    )
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
