from __future__ import annotations

import argparse
import csv
from contextlib import contextmanager
from itertools import permutations
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.architecture import ArchitectureConfig
from ldpc_sim.base_graphs import load_3gpp_base_graph
import ldpc_sim.channel as channel_mod
from ldpc_sim.channel import high_rate_bg1_config
from ldpc_sim.fixed_point import FixedPointFormat, beta_equivalent_float
import ldpc_sim.numerical_decoder as decoder_mod
from ldpc_sim.monte_carlo import PointConfig, MonteCarloResult, seed_sequence, simulate_point, wilson_interval
from ldpc_sim.simulator import SimulationResult, simulate_iteration
from ldpc_sim.syndrome import analyze_final_touches, simulate_syndrome_engine


FLOAT_BETA = 0.25
NMAX = 12
SYNDROME_S = 8
SYNDROME_Q = 2
STAGE1_SNRS = (4.2, 4.4, 4.9)
STAGE2_SNRS = (4.2, 4.4)
FINAL_SNRS = (4.2, 4.4)
SATURATION_SNRS = (4.2, 4.4)
NATURAL_ORDER = (0, 1, 2, 3)
CURRENT_HW_ORDER = (0, 2, 1, 3)

F1_FMT = FixedPointFormat(
    "F1", 6, 8, 8, 6, channel_gain=1.32, beta_int=1, ch_to_app_shift=1
)
F2_FMT = FixedPointFormat(
    "F2", 6, 8, 8, 6, channel_gain=1.542, beta_int=1, ch_to_app_shift=1
)
D_FMT = FixedPointFormat(
    "D", 5, 8, 8, 6, channel_gain=0.759, beta_int=1, ch_to_app_shift=2
)


def architecture_config() -> ArchitectureConfig:
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
        enable_layer_reorder=False,
        bank_strategy="optimized",
        pairing_strategy="optimized",
        max_cycles=20000,
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


def order_text(order: tuple[int, ...]) -> str:
    return "-".join(str(item) for item in order)


def fmt_config_id(fmt: FixedPointFormat) -> str:
    return (
        f"{fmt.name}_ch{fmt.w_ch}_app{fmt.w_app}_q{fmt.w_q}_m{fmt.w_m}"
        f"_g{fmt.channel_gain:g}_s{fmt.ch_to_app_shift}_b{fmt.beta_int}"
    )


def format_float(value: float, digits: int = 6) -> str:
    return f"{value:.{digits}f}"


def simulate_schedule(
    *,
    graph,
    cfg: ArchitectureConfig,
    order: tuple[int, ...],
) -> tuple[SimulationResult, int, object]:
    schedule = simulate_iteration(graph, cfg, layer_order=order, trace=False)
    final_touch = analyze_final_touches(graph, schedule, cfg)
    syndrome = simulate_syndrome_engine(
        profile="BG1_first4_high_rate",
        decoder_cycles_per_iteration=schedule.metrics.cycles_per_iteration,
        final_touch=final_touch,
        S=SYNDROME_S,
        queue_depth=SYNDROME_Q,
    )
    return schedule, syndrome.effective_iteration_boundary, syndrome


def schedule_cycle_row(
    *,
    rank: int,
    schedule: SimulationResult,
    effective_boundary: int,
    syndrome,
) -> dict[str, object]:
    metrics = schedule.metrics
    return {
        "cycle_rank": rank,
        "layer_order": order_text(metrics.layer_order),
        "decoder_cycles_per_iteration": metrics.cycles_per_iteration,
        "syndrome_S": SYNDROME_S,
        "syndrome_Q": SYNDROME_Q,
        "syndrome_valid": syndrome.valid,
        "syndrome_tail": syndrome.additional_tail_cycles,
        "effective_iteration_boundary": effective_boundary,
        "first_final_cycle": syndrome.first_final_cycle,
        "last_final_cycle": syndrome.last_final_cycle,
        "syndrome_completion_cycle": syndrome.syndrome_completion_cycle,
        "required_queue_depth": syndrome.required_queue_depth,
        "max_syndrome_backlog": syndrome.max_syndrome_backlog,
        "RAW_stalls": metrics.RAW_stall_cycles,
        "APP_bank_stalls": metrics.bank_conflict_cycles,
        "forwarded_APP_reads": metrics.forwarded_APP_reads,
        "max_live_forward_vectors": metrics.max_live_forward_vectors,
        "tau_f_avg": format_float(metrics.avg_forward_lifetime),
    }


def row_for_result(
    result: MonteCarloResult,
    *,
    stage: str,
    order: tuple[int, ...],
    config_name: str,
    fmt: FixedPointFormat | None,
    effective_boundary: int,
    decoder_cycles: int,
    syndrome_tail: int,
    saturation_rule: str = "asymmetric",
    requested_blocks: int,
) -> dict[str, object]:
    row = result.as_row(
        stage=stage,
        profile="BG1_first4_high_rate",
        config_name=config_name,
        layer_order=order_text(order),
        decoder_cycles_per_iteration=decoder_cycles,
        syndrome_tail=syndrome_tail,
        effective_iteration_boundary=effective_boundary,
        expected_latency_cycles=format_float(result.average_iterations * effective_boundary, 3),
        saturation_rule=saturation_rule,
        requested_blocks=requested_blocks,
        completed_requested_blocks=result.blocks >= requested_blocks,
        w_CH="" if fmt is None else fmt.w_ch,
        w_APP="" if fmt is None else fmt.w_app,
        w_q="" if fmt is None else fmt.w_q,
        w_M="" if fmt is None else fmt.w_m,
        channel_gain="" if fmt is None else fmt.channel_gain,
        ch_to_app_shift="" if fmt is None else fmt.ch_to_app_shift,
        beta_int="" if fmt is None else fmt.beta_int,
        beta_equiv="" if fmt is None else format_float(beta_equivalent_float(fmt)),
    )
    row["expected_core_cycles"] = row["expected_latency_cycles"]
    return row


def run_point(
    *,
    graph,
    rate,
    snr: float,
    seeds: tuple[int, ...],
    order: tuple[int, ...],
    config_name: str,
    fmt: FixedPointFormat | None,
    saturation_rule: str = "asymmetric",
) -> MonteCarloResult:
    if fmt is None:
        point = PointConfig(config_name, "float", beta=FLOAT_BETA, layer_order=order)
    else:
        point = PointConfig(config_name, "fixed", fmt=fmt, layer_order=order)
    with maybe_symmetric_saturation(saturation_rule):
        return simulate_point(
            graph=graph,
            rate_match=rate,
            ebn0_db=snr,
            point=point,
            seeds=seeds,
            max_iterations=NMAX,
            max_errors=len(seeds) + 1,
        )


@contextmanager
def maybe_symmetric_saturation(rule: str):
    if rule == "asymmetric":
        yield
        return
    if rule != "symmetric":
        raise ValueError("saturation rule must be asymmetric or symmetric.")

    original_channel_quantize = channel_mod.quantize_channel
    original_add = decoder_mod.saturating_add
    original_sub = decoder_mod.saturating_sub
    original_init = decoder_mod.initialize_app_from_channel

    def symmetric_signed_range(width: int) -> tuple[int, int]:
        limit = (1 << (width - 1)) - 1
        return -limit, limit

    def symmetric_saturate_signed(values, width: int) -> tuple[np.ndarray, int]:
        array = np.asarray(values, dtype=np.int64)
        lo, hi = symmetric_signed_range(width)
        clipped = np.clip(array, lo, hi).astype(np.int64)
        return clipped, int(np.count_nonzero(clipped != array))

    def symmetric_add(a, b, width: int) -> tuple[np.ndarray, int]:
        return symmetric_saturate_signed(
            np.asarray(a, dtype=np.int64) + np.asarray(b, dtype=np.int64),
            width,
        )

    def symmetric_sub(a, b, width: int) -> tuple[np.ndarray, int]:
        return symmetric_saturate_signed(
            np.asarray(a, dtype=np.int64) - np.asarray(b, dtype=np.int64),
            width,
        )

    def symmetric_init(channel_values, fmt: FixedPointFormat) -> tuple[np.ndarray, int]:
        if fmt.ch_to_app_shift < 0:
            raise ValueError("ch_to_app_shift must be non-negative.")
        shifted = np.asarray(channel_values, dtype=np.int64) * (1 << fmt.ch_to_app_shift)
        return symmetric_saturate_signed(shifted, fmt.w_app)

    def symmetric_quantize(llr, fmt: FixedPointFormat) -> tuple[np.ndarray, int]:
        scaled = np.rint(np.asarray(llr, dtype=np.float64) * fmt.channel_gain).astype(np.int64)
        return symmetric_saturate_signed(scaled, fmt.w_ch)

    channel_mod.quantize_channel = symmetric_quantize
    decoder_mod.saturating_add = symmetric_add
    decoder_mod.saturating_sub = symmetric_sub
    decoder_mod.initialize_app_from_channel = symmetric_init
    try:
        yield
    finally:
        channel_mod.quantize_channel = original_channel_quantize
        decoder_mod.saturating_add = original_add
        decoder_mod.saturating_sub = original_sub
        decoder_mod.initialize_app_from_channel = original_init


def aggregate_rows(rows: list[dict[str, object]]) -> dict[str, object]:
    blocks = sum(int(row["blocks"]) for row in rows)
    errors = sum(int(row["block_errors"]) for row in rows)
    iter_sum = sum(float(row["avg_iterations"]) * int(row["blocks"]) for row in rows)
    latency_sum = sum(float(row["expected_latency_cycles"]) * int(row["blocks"]) for row in rows)
    max_iter_sum = sum(
        float(row["fraction_reaching_max_iterations"]) * int(row["blocks"])
        for row in rows
    )
    ci_low, ci_high = wilson_interval(errors, blocks)
    return {
        "blocks": blocks,
        "block_errors": errors,
        "BLER": errors / blocks if blocks else 0.0,
        "BLER_CI95_low": ci_low,
        "BLER_CI95_high": ci_high,
        "avg_iterations": iter_sum / blocks if blocks else 0.0,
        "expected_latency_cycles": latency_sum / blocks if blocks else 0.0,
        "fraction_reaching_max_iterations": max_iter_sum / blocks if blocks else 0.0,
    }


def annotate_layer_screen(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    by_order: dict[str, list[dict[str, object]]] = {}
    by_snr: dict[float, list[dict[str, object]]] = {}
    for row in rows:
        by_order.setdefault(str(row["layer_order"]), []).append(row)
        by_snr.setdefault(float(row["EbN0_dB"]), []).append(row)

    aggregate_by_order = {order: aggregate_rows(group) for order, group in by_order.items()}
    best_aggregate_bler = min(item["BLER"] for item in aggregate_by_order.values())
    best_bler_by_snr = {
        snr: min(float(row["BLER"]) for row in snr_rows)
        for snr, snr_rows in by_snr.items()
    }
    quality_by_order: dict[str, bool] = {}
    for order, group in by_order.items():
        aggregate = aggregate_by_order[order]
        per_snr_ok = all(
            float(row["BLER"]) <= best_bler_by_snr[float(row["EbN0_dB"])] + 0.03
            for row in group
        )
        quality_by_order[order] = aggregate["BLER"] <= best_aggregate_bler + 0.02 and per_snr_ok

    ranked_orders = sorted(
        by_order,
        key=lambda order: (
            not quality_by_order[order],
            aggregate_by_order[order]["expected_latency_cycles"],
            aggregate_by_order[order]["BLER"],
            order,
        ),
    )
    rank_by_order = {order: rank for rank, order in enumerate(ranked_orders, start=1)}
    retained_orders = set(ranked_orders[:3])

    annotated: list[dict[str, object]] = []
    for row in rows:
        order = str(row["layer_order"])
        aggregate = aggregate_by_order[order]
        new_row = dict(row)
        new_row.update(
            {
                "stage1_latency_rank": rank_by_order[order],
                "stage1_quality_pass": quality_by_order[order],
                "stage1_retained_top3": order in retained_orders,
                "aggregate_blocks": aggregate["blocks"],
                "aggregate_block_errors": aggregate["block_errors"],
                "aggregate_BLER": format_float(aggregate["BLER"], 8),
                "aggregate_BLER_CI95_low": format_float(aggregate["BLER_CI95_low"], 8),
                "aggregate_BLER_CI95_high": format_float(aggregate["BLER_CI95_high"], 8),
                "aggregate_avg_iterations": format_float(aggregate["avg_iterations"]),
                "aggregate_expected_latency_cycles": format_float(
                    aggregate["expected_latency_cycles"], 3
                ),
                "aggregate_max_iteration_fraction": format_float(
                    aggregate["fraction_reaching_max_iterations"]
                ),
            }
        )
        annotated.append(new_row)
    return sorted(
        annotated,
        key=lambda row: (
            int(row["stage1_latency_rank"]),
            float(row["EbN0_dB"]),
        ),
    )


def selected_stage2_orders(screen_rows: list[dict[str, object]]) -> list[tuple[int, ...]]:
    orders: dict[str, tuple[int, ...]] = {
        row["layer_order"]: tuple(int(part) for part in str(row["layer_order"]).split("-"))
        for row in screen_rows
    }
    selected_texts = {
        str(row["layer_order"])
        for row in screen_rows
        if bool(row["stage1_retained_top3"])
    }
    selected_texts.add(order_text(NATURAL_ORDER))
    selected_texts.add(order_text(CURRENT_HW_ORDER))
    return [orders[text] for text in sorted(selected_texts, key=lambda text: (min(
        int(row["stage1_latency_rank"]) for row in screen_rows if row["layer_order"] == text
    ), text))]


def rank_confirmation_rows(rows: list[dict[str, object]]) -> tuple[list[dict[str, object]], list[str]]:
    by_order: dict[str, list[dict[str, object]]] = {}
    for row in rows:
        by_order.setdefault(str(row["layer_order"]), []).append(row)
    aggregate_by_order = {order: aggregate_rows(group) for order, group in by_order.items()}
    best_bler = min(item["BLER"] for item in aggregate_by_order.values())
    quality_by_order = {
        order: aggregate["BLER"] <= best_bler + 0.01
        for order, aggregate in aggregate_by_order.items()
    }
    ranked = sorted(
        by_order,
        key=lambda order: (
            not quality_by_order[order],
            aggregate_by_order[order]["expected_latency_cycles"],
            aggregate_by_order[order]["BLER"],
            order,
        ),
    )
    rank_by_order = {order: rank for rank, order in enumerate(ranked, start=1)}
    annotated: list[dict[str, object]] = []
    for row in rows:
        order = str(row["layer_order"])
        aggregate = aggregate_by_order[order]
        new_row = dict(row)
        new_row.update(
            {
                "confirmation_latency_rank": rank_by_order[order],
                "confirmation_quality_pass": quality_by_order[order],
                "aggregate_blocks": aggregate["blocks"],
                "aggregate_block_errors": aggregate["block_errors"],
                "aggregate_BLER": format_float(aggregate["BLER"], 8),
                "aggregate_BLER_CI95_low": format_float(aggregate["BLER_CI95_low"], 8),
                "aggregate_BLER_CI95_high": format_float(aggregate["BLER_CI95_high"], 8),
                "aggregate_avg_iterations": format_float(aggregate["avg_iterations"]),
                "aggregate_expected_latency_cycles": format_float(
                    aggregate["expected_latency_cycles"], 3
                ),
                "aggregate_max_iteration_fraction": format_float(
                    aggregate["fraction_reaching_max_iterations"]
                ),
            }
        )
        annotated.append(new_row)
    return sorted(
        annotated,
        key=lambda row: (
            int(row["confirmation_latency_rank"]),
            float(row["EbN0_dB"]),
        ),
    ), ranked


def aggregate_by_keys(
    rows: list[dict[str, object]],
    keys: tuple[str, ...],
) -> list[dict[str, object]]:
    grouped: dict[tuple[object, ...], list[dict[str, object]]] = {}
    for row in rows:
        grouped.setdefault(tuple(row[key] for key in keys), []).append(row)
    summary: list[dict[str, object]] = []
    for key_values, group in grouped.items():
        aggregate = aggregate_rows(group)
        first = group[0]
        row = {key: value for key, value in zip(keys, key_values)}
        row.update(
            {
                "blocks": aggregate["blocks"],
                "block_errors": aggregate["block_errors"],
                "BLER": format_float(aggregate["BLER"], 8),
                "BLER_CI95_low": format_float(aggregate["BLER_CI95_low"], 8),
                "BLER_CI95_high": format_float(aggregate["BLER_CI95_high"], 8),
                "avg_iterations": format_float(aggregate["avg_iterations"]),
                "expected_latency_cycles": format_float(
                    aggregate["expected_latency_cycles"], 3
                ),
                "fraction_reaching_max_iterations": format_float(
                    aggregate["fraction_reaching_max_iterations"]
                ),
                "w_CH": first.get("w_CH", ""),
                "w_APP": first.get("w_APP", ""),
                "w_q": first.get("w_q", ""),
                "w_M": first.get("w_M", ""),
                "channel_gain": first.get("channel_gain", ""),
                "ch_to_app_shift": first.get("ch_to_app_shift", ""),
                "beta_int": first.get("beta_int", ""),
                "beta_equiv": first.get("beta_equiv", ""),
            }
        )
        summary.append(row)
    return sorted(
        summary,
        key=lambda row: (
            str(row.get("layer_order", "")),
            float(row["BLER"]),
            float(row["expected_latency_cycles"]),
            str(row.get("config_name", "")),
            str(row.get("saturation_rule", "")),
        ),
    )


def material_saturation_difference(summary_rows: list[dict[str, object]]) -> bool:
    by_config_snr: dict[tuple[str, str], dict[str, dict[str, object]]] = {}
    for row in summary_rows:
        key = (str(row["config_name"]), str(row.get("EbN0_dB", "aggregate")))
        by_config_snr.setdefault(key, {})[str(row["saturation_rule"])] = row
    for pair in by_config_snr.values():
        if "asymmetric" not in pair or "symmetric" not in pair:
            continue
        asym = pair["asymmetric"]
        sym = pair["symmetric"]
        if abs(float(sym["BLER"]) - float(asym["BLER"])) > 0.015:
            return True
        if abs(float(sym["avg_iterations"]) - float(asym["avg_iterations"])) > 0.15:
            return True
        if (
            abs(
                float(sym["fraction_reaching_max_iterations"])
                - float(asym["fraction_reaching_max_iterations"])
            )
            > 0.02
        ):
            return True
    return False


def choose_final_config(final_summary: list[dict[str, object]], winning_order: str) -> dict[str, object]:
    candidates = [
        row for row in final_summary
        if row["layer_order"] == winning_order and row["config_name"] in {"F1", "F2", "D"}
    ]
    best_bler = min(float(row["BLER"]) for row in candidates)
    quality = [row for row in candidates if float(row["BLER"]) <= best_bler + 0.01]
    return min(
        quality,
        key=lambda row: (
            float(row["expected_latency_cycles"]),
            float(row["BLER"]),
            0 if row["config_name"] == "F2" else 1,
        ),
    )


def markdown_table(rows: list[dict[str, object]], columns: tuple[str, ...], limit: int | None = None) -> list[str]:
    shown = rows if limit is None else rows[:limit]
    lines = [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join("---" for _ in columns) + " |",
    ]
    for row in shown:
        lines.append("| " + " | ".join(str(row.get(column, "")) for column in columns) + " |")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage1-blocks", type=int, default=200)
    parser.add_argument("--stage2-blocks", type=int, default=1000)
    parser.add_argument("--final-blocks", type=int, default=1000)
    parser.add_argument("--saturation-blocks", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=20260818)
    args = parser.parse_args()

    out_dir = ROOT / "results" / "architecture_closure"
    out_dir.mkdir(parents=True, exist_ok=True)

    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    rate = high_rate_bg1_config()
    cfg = architecture_config()

    print("Evaluating all 24 layer-order cycle/syndrome boundaries...", flush=True)
    schedules: dict[tuple[int, ...], tuple[SimulationResult, int, object]] = {}
    cycle_rows_raw: list[dict[str, object]] = []
    for order in permutations(graph.layer_ids):
        schedule, effective_boundary, syndrome = simulate_schedule(graph=graph, cfg=cfg, order=order)
        schedules[order] = (schedule, effective_boundary, syndrome)
    cycle_ranked = sorted(
        schedules.items(),
        key=lambda item: (
            item[1][1],
            item[1][0].metrics.cycles_per_iteration,
            item[0],
        ),
    )
    for rank, (_, (schedule, boundary, syndrome)) in enumerate(cycle_ranked, start=1):
        cycle_rows_raw.append(
            schedule_cycle_row(
                rank=rank,
                schedule=schedule,
                effective_boundary=boundary,
                syndrome=syndrome,
            )
        )
    write_csv(out_dir / "layer_order_cycle_table.csv", cycle_rows_raw)

    print("Stage 1: screening all 24 layer orders with F2...", flush=True)
    stage1_rows: list[dict[str, object]] = []
    for order_index, order in enumerate(permutations(graph.layer_ids), start=1):
        schedule, boundary, syndrome = schedules[order]
        print(f"  order {order_index:02d}/24 {order_text(order)}", flush=True)
        for snr in STAGE1_SNRS:
            seeds = seed_sequence(args.seed + 100000 + order_index * 10000 + int(snr * 1000), args.stage1_blocks)
            result = run_point(
                graph=graph,
                rate=rate,
                snr=snr,
                seeds=seeds,
                order=order,
                config_name="F2",
                fmt=F2_FMT,
            )
            stage1_rows.append(
                row_for_result(
                    result,
                    stage="layer_order_stage1",
                    order=order,
                    config_name="F2",
                    fmt=F2_FMT,
                    effective_boundary=boundary,
                    decoder_cycles=schedule.metrics.cycles_per_iteration,
                    syndrome_tail=syndrome.additional_tail_cycles,
                    requested_blocks=args.stage1_blocks,
                )
            )
    stage1_rows = annotate_layer_screen(stage1_rows)
    write_csv(out_dir / "layer_order_screen.csv", stage1_rows)

    stage2_orders = selected_stage2_orders(stage1_rows)
    print(
        "Stage 2: confirming retained orders "
        + ", ".join(order_text(order) for order in stage2_orders),
        flush=True,
    )
    stage2_rows_raw: list[dict[str, object]] = []
    for order_index, order in enumerate(stage2_orders, start=1):
        schedule, boundary, syndrome = schedules[order]
        for snr in STAGE2_SNRS:
            print(
                f"  stage2 order {order_index}/{len(stage2_orders)} "
                f"{order_text(order)} Eb/N0 {snr:.1f} dB",
                flush=True,
            )
            seeds = seed_sequence(args.seed + 200000 + order_index * 10000 + int(snr * 1000), args.stage2_blocks)
            result = run_point(
                graph=graph,
                rate=rate,
                snr=snr,
                seeds=seeds,
                order=order,
                config_name="F2",
                fmt=F2_FMT,
            )
            stage2_rows_raw.append(
                row_for_result(
                    result,
                    stage="layer_order_stage2_confirmation",
                    order=order,
                    config_name="F2",
                    fmt=F2_FMT,
                    effective_boundary=boundary,
                    decoder_cycles=schedule.metrics.cycles_per_iteration,
                    syndrome_tail=syndrome.additional_tail_cycles,
                    requested_blocks=args.stage2_blocks,
                )
            )
    stage2_rows, ranked_stage2_order_texts = rank_confirmation_rows(stage2_rows_raw)
    write_csv(out_dir / "layer_order_confirmation.csv", stage2_rows)
    winning_order_text = ranked_stage2_order_texts[0]
    top_two_order_texts = ranked_stage2_order_texts[:2]
    top_two_orders = [tuple(int(part) for part in text.split("-")) for text in top_two_order_texts]

    print(
        "Final fixed-point comparison on top order(s) "
        + ", ".join(top_two_order_texts),
        flush=True,
    )
    final_rows: list[dict[str, object]] = []
    final_configs: tuple[tuple[str, FixedPointFormat | None], ...] = (
        ("float", None),
        ("F1", F1_FMT),
        ("F2", F2_FMT),
        ("D", D_FMT),
    )
    for order_index, order in enumerate(top_two_orders, start=1):
        schedule, boundary, syndrome = schedules[order]
        for snr in FINAL_SNRS:
            seeds = seed_sequence(args.seed + 300000 + order_index * 10000 + int(snr * 1000), args.final_blocks)
            for config_name, fmt in final_configs:
                print(
                    f"  final order {order_index}/{len(top_two_orders)} "
                    f"{order_text(order)} {config_name} Eb/N0 {snr:.1f} dB",
                    flush=True,
                )
                result = run_point(
                    graph=graph,
                    rate=rate,
                    snr=snr,
                    seeds=seeds,
                    order=order,
                    config_name=config_name,
                    fmt=fmt,
                )
                final_rows.append(
                    row_for_result(
                        result,
                        stage="final_fixed_point_comparison",
                        order=order,
                        config_name=config_name,
                        fmt=fmt,
                        effective_boundary=boundary,
                        decoder_cycles=schedule.metrics.cycles_per_iteration,
                        syndrome_tail=syndrome.additional_tail_cycles,
                        requested_blocks=args.final_blocks,
                    )
                )
    write_csv(out_dir / "final_fixed_point_comparison.csv", final_rows)
    final_summary = aggregate_by_keys(final_rows, ("layer_order", "config_name"))
    final_choice = choose_final_config(final_summary, winning_order_text)

    print("Saturation semantics check on winning order...", flush=True)
    winning_order = tuple(int(part) for part in winning_order_text.split("-"))
    schedule, boundary, syndrome = schedules[winning_order]
    saturation_rows: list[dict[str, object]] = []
    for snr in SATURATION_SNRS:
        seeds = seed_sequence(args.seed + 400000 + int(snr * 1000), args.saturation_blocks)
        for config_name, fmt in (("F1", F1_FMT), ("F2", F2_FMT)):
            for rule in ("asymmetric", "symmetric"):
                print(
                    f"  saturation {config_name} {rule} Eb/N0 {snr:.1f} dB",
                    flush=True,
                )
                result = run_point(
                    graph=graph,
                    rate=rate,
                    snr=snr,
                    seeds=seeds,
                    order=winning_order,
                    config_name=config_name,
                    fmt=fmt,
                    saturation_rule=rule,
                )
                saturation_rows.append(
                    row_for_result(
                        result,
                        stage="saturation_rule_comparison",
                        order=winning_order,
                        config_name=config_name,
                        fmt=fmt,
                        effective_boundary=boundary,
                        decoder_cycles=schedule.metrics.cycles_per_iteration,
                        syndrome_tail=syndrome.additional_tail_cycles,
                        saturation_rule=rule,
                        requested_blocks=args.saturation_blocks,
                    )
                )
    write_csv(out_dir / "saturation_rule_comparison.csv", saturation_rows)
    saturation_summary = aggregate_by_keys(
        saturation_rows,
        ("config_name", "saturation_rule"),
    )
    saturation_unresolved = material_saturation_difference(saturation_summary)
    final_saturation_rule = "UNRESOLVED" if saturation_unresolved else "asymmetric two's-complement"

    stage2_summary = aggregate_by_keys(stage2_rows, ("layer_order", "config_name"))
    stage1_order_summary = aggregate_by_keys(stage1_rows, ("layer_order", "config_name"))
    stage1_ranked_summary: list[dict[str, object]] = []
    seen_stage1_orders: set[str] = set()
    for row in sorted(stage1_rows, key=lambda item: int(item["stage1_latency_rank"])):
        order = str(row["layer_order"])
        if order in seen_stage1_orders:
            continue
        seen_stage1_orders.add(order)
        stage1_ranked_summary.append(
            {
                "stage1_latency_rank": row["stage1_latency_rank"],
                "layer_order": order,
                "stage1_quality_pass": row["stage1_quality_pass"],
                "blocks": row["aggregate_blocks"],
                "block_errors": row["aggregate_block_errors"],
                "BLER": row["aggregate_BLER"],
                "avg_iterations": row["aggregate_avg_iterations"],
                "expected_latency_cycles": row["aggregate_expected_latency_cycles"],
                "fraction_reaching_max_iterations": row["aggregate_max_iteration_fraction"],
            }
        )
    winning_schedule, winning_boundary, winning_syndrome = schedules[winning_order]
    final_width_family = "F" if str(final_choice["config_name"]).startswith("F") else "D"
    final_fmt = F1_FMT if final_choice["config_name"] == "F1" else F2_FMT if final_choice["config_name"] == "F2" else D_FMT

    report_lines = [
        "# Final Numerical / Schedule Architecture Closure",
        "",
        "This report writes only under `results/architecture_closure/` and preserves existing v1/v2/v3 result directories.",
        "No RTL, P/B, D_A/D_R, forwarding, syndrome architecture, or scheduler behavior was changed.",
        "",
        "## Architecture Model",
        "",
        f"Scheduler: `P=384`, `B=2`, `D_A=3`, `D_R=3`, APP banks=8, forward cache=8, optimized bank map/pairing/JIT forwarding.",
        f"Syndrome architecture held fixed at `S={SYNDROME_S}`, `Q={SYNDROME_Q}`.",
        "Layer-order optimization used provisional `F2` because v3 selected it within the F family.",
        "",
        "## Cycle And Syndrome Boundary",
        "",
        *markdown_table(
            cycle_rows_raw,
            (
                "cycle_rank",
                "layer_order",
                "decoder_cycles_per_iteration",
                "syndrome_tail",
                "effective_iteration_boundary",
                "syndrome_valid",
                "required_queue_depth",
            ),
            limit=8,
        ),
        "",
        "## Stage 1 Layer-Order Screen",
        "",
        "All 24 permutations were evaluated with 200 common-seed blocks/order/SNR at 4.2, 4.4, and 4.9 dB.",
        "Quality pass was enforced before latency ranking using aggregate BLER and per-SNR BLER margins.",
        "",
        *markdown_table(
            stage1_ranked_summary,
            (
                "stage1_latency_rank",
                "layer_order",
                "stage1_quality_pass",
                "blocks",
                "block_errors",
                "BLER",
                "avg_iterations",
                "expected_latency_cycles",
                "fraction_reaching_max_iterations",
            ),
            limit=8,
        ),
        "",
        "## Stage 2 Layer-Order Confirmation",
        "",
        f"Confirmed orders: `{', '.join(order_text(order) for order in stage2_orders)}`.",
        "",
        *markdown_table(
            stage2_summary,
            (
                "layer_order",
                "blocks",
                "block_errors",
                "BLER",
                "BLER_CI95_low",
                "BLER_CI95_high",
                "avg_iterations",
                "expected_latency_cycles",
                "fraction_reaching_max_iterations",
            ),
        ),
        "",
        f"Selected layer order: `{winning_order_text}` with effective boundary `{winning_boundary}` cycles.",
        "",
        "## Final Fixed-Point Comparison",
        "",
        *markdown_table(
            final_summary,
            (
                "layer_order",
                "config_name",
                "blocks",
                "block_errors",
                "BLER",
                "BLER_CI95_low",
                "BLER_CI95_high",
                "avg_iterations",
                "expected_latency_cycles",
                "fraction_reaching_max_iterations",
            ),
        ),
        "",
        "## Saturation Rule Comparison",
        "",
        *markdown_table(
            saturation_summary,
            (
                "config_name",
                "saturation_rule",
                "blocks",
                "block_errors",
                "BLER",
                "BLER_CI95_low",
                "BLER_CI95_high",
                "avg_iterations",
                "expected_latency_cycles",
                "fraction_reaching_max_iterations",
            ),
        ),
        "",
        (
            "Symmetric saturation materially changed the measured result; saturation semantics remain `UNRESOLVED`."
            if saturation_unresolved
            else "Symmetric and asymmetric saturation were materially equivalent in this narrow check; retain the current asymmetric two's-complement rule."
        ),
        "",
        "## Explicit Recommendations",
        "",
        f"- Final width family: `{final_width_family}`.",
        f"- Final gain: `{final_fmt.channel_gain}`.",
        f"- Final channel-to-APP shift: `{final_fmt.ch_to_app_shift}`.",
        f"- Final beta_int: `{final_fmt.beta_int}`.",
        f"- Final layer order: `{winning_order_text}`.",
        f"- Final saturation rule: `{final_saturation_rule}`.",
        "",
        "## Raw Outputs",
        "",
        "- `results/architecture_closure/layer_order_cycle_table.csv`",
        "- `results/architecture_closure/layer_order_screen.csv`",
        "- `results/architecture_closure/layer_order_confirmation.csv`",
        "- `results/architecture_closure/final_fixed_point_comparison.csv`",
        "- `results/architecture_closure/saturation_rule_comparison.csv`",
    ]
    report_path = out_dir / "architecture_closure_report.md"
    report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
