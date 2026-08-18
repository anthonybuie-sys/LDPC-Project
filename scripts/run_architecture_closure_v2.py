from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from itertools import combinations, permutations
from math import exp, lgamma, log, sqrt
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.architecture import ArchitectureConfig
from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.channel import (
    awgn_llr_all_zero,
    high_rate_bg1_config,
    information_bit_errors,
    quantize_channel_sample,
)
from ldpc_sim.fixed_point import FixedPointFormat, SaturationStats, beta_equivalent_float
from ldpc_sim.monte_carlo import seed_sequence, wilson_interval
from ldpc_sim.numerical_decoder import decode_fixed
from ldpc_sim.simulator import SimulationResult, simulate_iteration
from ldpc_sim.syndrome import analyze_final_touches, simulate_syndrome_engine


NMAX = 12
STAGE1_SNRS = (4.2, 4.4, 4.9)
CONFIRM_SNRS = (4.2, 4.4)
SYNDROME_S = 8
SYNDROME_Q = 8
MANDATORY_ORDERS = (
    (0, 2, 1, 3),
    (0, 1, 2, 3),
    (1, 2, 3, 0),
    (1, 3, 0, 2),
    (3, 2, 1, 0),
)
F1_FMT = FixedPointFormat(
    "F1", 6, 8, 8, 6, channel_gain=1.32, beta_int=1, ch_to_app_shift=1
)


@dataclass(frozen=True)
class BlockOutcome:
    seed: int
    block_error: bool
    bit_errors: int
    iterations: int
    reached_max_iterations: bool

    @property
    def latency_cycles(self) -> int:
        raise AttributeError("Latency requires an order-specific boundary.")


@dataclass
class RunStats:
    label: str
    ebn0_db: float
    saturation: SaturationStats = field(default_factory=SaturationStats)
    outcomes: list[BlockOutcome] = field(default_factory=list)
    syndrome_pass_count: int = 0
    convergence_failures: int = 0
    undetected_errors: int = 0
    max_iterations_observed: int = 0
    saturation_blocks: int = 0

    def add(self, *, seed: int, decoded, bit_errors: int) -> None:
        is_error = bit_errors > 0
        outcome = BlockOutcome(
            seed=seed,
            block_error=is_error,
            bit_errors=bit_errors,
            iterations=decoded.iterations,
            reached_max_iterations=decoded.iterations >= NMAX,
        )
        self.outcomes.append(outcome)
        self.max_iterations_observed = max(self.max_iterations_observed, decoded.iterations)
        if decoded.syndrome_passed:
            self.syndrome_pass_count += 1
        else:
            self.convergence_failures += 1
        if decoded.syndrome_passed and is_error:
            self.undetected_errors += 1
        self.saturation.add(decoded.saturation)
        if decoded.saturation.any:
            self.saturation_blocks += 1

    @property
    def blocks(self) -> int:
        return len(self.outcomes)

    @property
    def block_errors(self) -> int:
        return sum(1 for outcome in self.outcomes if outcome.block_error)

    @property
    def bit_errors(self) -> int:
        return sum(outcome.bit_errors for outcome in self.outcomes)

    @property
    def bler(self) -> float:
        return self.block_errors / self.blocks if self.blocks else 0.0

    @property
    def avg_iterations(self) -> float:
        return (
            sum(outcome.iterations for outcome in self.outcomes) / self.blocks
            if self.blocks
            else 0.0
        )

    @property
    def avg_iteration_se(self) -> float:
        if self.blocks <= 1:
            return 0.0
        values = np.array([outcome.iterations for outcome in self.outcomes], dtype=np.float64)
        return float(values.std(ddof=1) / sqrt(self.blocks))

    @property
    def max_iteration_fraction(self) -> float:
        return (
            sum(1 for outcome in self.outcomes if outcome.reached_max_iterations) / self.blocks
            if self.blocks
            else 0.0
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


def format_float(value: float, digits: int = 6) -> str:
    return f"{value:.{digits}f}"


def seed_base_for(*, root_seed: int, stage_offset: int, snr: float) -> int:
    return root_seed + stage_offset + int(round(snr * 1000.0)) * 10000


def seed_manifest_row(
    *,
    stage: str,
    snr: float,
    seeds: tuple[int, ...],
    stage_offset: int,
    root_seed: int,
) -> dict[str, object]:
    return {
        "stage": stage,
        "EbN0_dB": snr,
        "seed_base": seed_base_for(root_seed=root_seed, stage_offset=stage_offset, snr=snr),
        "seed_count": len(seeds),
        "first_seed": seeds[0] if seeds else "",
        "last_seed": seeds[-1] if seeds else "",
        "depends_on_order_index": False,
        "reuse_rule": "same tuple reused for every layer order at this SNR",
    }


def simulate_schedule(
    *,
    graph,
    cfg: ArchitectureConfig,
    order: tuple[int, ...],
) -> tuple[SimulationResult, object]:
    schedule = simulate_iteration(graph, cfg, layer_order=order, trace=False)
    final_touch = analyze_final_touches(graph, schedule, cfg)
    syndrome = simulate_syndrome_engine(
        profile="BG1_first4_high_rate",
        decoder_cycles_per_iteration=schedule.metrics.cycles_per_iteration,
        final_touch=final_touch,
        S=SYNDROME_S,
        queue_depth=SYNDROME_Q,
    )
    return schedule, syndrome


def cycle_row(rank: int, schedule: SimulationResult, syndrome) -> dict[str, object]:
    metrics = schedule.metrics
    return {
        "cycle_rank": rank,
        "layer_order": order_text(metrics.layer_order),
        "decoder_cycles_per_iteration": metrics.cycles_per_iteration,
        "syndrome_S": SYNDROME_S,
        "syndrome_Q": SYNDROME_Q,
        "syndrome_valid": syndrome.valid,
        "syndrome_tail": syndrome.additional_tail_cycles,
        "effective_iteration_boundary": syndrome.effective_iteration_boundary,
        "first_final_cycle": syndrome.first_final_cycle,
        "last_final_cycle": syndrome.last_final_cycle,
        "syndrome_completion_cycle": syndrome.syndrome_completion_cycle,
        "required_queue_depth": syndrome.required_queue_depth,
        "max_syndrome_backlog": syndrome.max_syndrome_backlog,
        "RAW_stalls": metrics.RAW_stall_cycles,
        "APP_bank_stalls": metrics.bank_conflict_cycles,
        "forwarded_APP_reads": metrics.forwarded_APP_reads,
        "max_live_forward_vectors": metrics.max_live_forward_vectors,
    }


def run_common_seed_orders(
    *,
    graph,
    rate,
    ebn0_db: float,
    seeds: tuple[int, ...],
    orders: tuple[tuple[int, ...], ...],
    progress_label: str,
) -> dict[tuple[int, ...], RunStats]:
    stats_by_order = {
        order: RunStats(label=order_text(order), ebn0_db=ebn0_db)
        for order in orders
    }
    for block_index, seed in enumerate(seeds, start=1):
        sample = awgn_llr_all_zero(
            rng=np.random.default_rng(seed),
            z=graph.Z,
            rate_match=rate,
            ebn0_db=ebn0_db,
        )
        quantized = quantize_channel_sample(sample, F1_FMT)
        for order in orders:
            decoded = decode_fixed(
                graph,
                quantized.values,
                fmt=F1_FMT,
                max_iterations=NMAX,
                layer_order=order,
                representation="compressed",
                early_termination=True,
                channel_saturation_count=quantized.channel_saturation_count,
            )
            bit_errors = information_bit_errors(decoded.hard_bits, rate.info_base_cols)
            stats_by_order[order].add(seed=seed, decoded=decoded, bit_errors=bit_errors)
        if block_index % 100 == 0 or block_index == len(seeds):
            print(
                f"  {progress_label} Eb/N0 {ebn0_db:.1f}: "
                f"{block_index}/{len(seeds)} common-seed blocks",
                flush=True,
            )
    return stats_by_order


def result_row(
    *,
    stage: str,
    stats: RunStats,
    schedule: SimulationResult,
    syndrome,
    requested_blocks: int,
    seed_base: int,
) -> dict[str, object]:
    ci_low, ci_high = wilson_interval(stats.block_errors, stats.blocks)
    info_bits = stats.blocks * 22 * 384
    return {
        "stage": stage,
        "profile": "BG1_first4_high_rate",
        "config_name": "F1",
        "EbN0_dB": stats.ebn0_db,
        "seed_base": seed_base,
        "seed_count": stats.blocks,
        "layer_order": stats.label,
        "decoder_cycles_per_iteration": schedule.metrics.cycles_per_iteration,
        "syndrome_S": SYNDROME_S,
        "syndrome_Q": SYNDROME_Q,
        "syndrome_valid": syndrome.valid,
        "syndrome_tail": syndrome.additional_tail_cycles,
        "effective_iteration_boundary": syndrome.effective_iteration_boundary,
        "blocks": stats.blocks,
        "requested_blocks": requested_blocks,
        "completed_requested_blocks": stats.blocks >= requested_blocks,
        "block_errors": stats.block_errors,
        "BLER": format_float(stats.bler, 8),
        "BLER_CI95_low": format_float(ci_low, 8),
        "BLER_CI95_high": format_float(ci_high, 8),
        "bit_errors_info": stats.bit_errors,
        "BER": format_float(stats.bit_errors / info_bits if info_bits else 0.0, 10),
        "avg_iterations": format_float(stats.avg_iterations),
        "avg_iteration_se": format_float(stats.avg_iteration_se),
        "max_iterations_observed": stats.max_iterations_observed,
        "fraction_reaching_max_iterations": format_float(stats.max_iteration_fraction),
        "expected_latency_cycles": format_float(
            stats.avg_iterations * syndrome.effective_iteration_boundary,
            3,
        ),
        "syndrome_pass_count": stats.syndrome_pass_count,
        "convergence_failures": stats.convergence_failures,
        "undetected_errors": stats.undetected_errors,
        "channel_quantizer_clip_count": stats.saturation.channel,
        "app_init_saturation_count": stats.saturation.app_init,
        "q_sub_saturation_count": stats.saturation.q_sub,
        "check_magnitude_clip_count": stats.saturation.min_input_clip,
        "app_update_saturation_count": stats.saturation.app_add,
        "saturation_block_fraction": format_float(
            stats.saturation_blocks / stats.blocks if stats.blocks else 0.0
        ),
        "w_CH": F1_FMT.w_ch,
        "w_APP": F1_FMT.w_app,
        "w_q": F1_FMT.w_q,
        "w_M": F1_FMT.w_m,
        "channel_gain": F1_FMT.channel_gain,
        "ch_to_app_shift": F1_FMT.ch_to_app_shift,
        "beta_int": F1_FMT.beta_int,
        "beta_equiv": format_float(beta_equivalent_float(F1_FMT)),
        "saturation_rule": "asymmetric two's-complement",
    }


def aggregate_result_rows(rows: list[dict[str, object]]) -> dict[str, object]:
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


def summarize_by_order(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    grouped: dict[str, list[dict[str, object]]] = {}
    for row in rows:
        grouped.setdefault(str(row["layer_order"]), []).append(row)
    summary: list[dict[str, object]] = []
    for order, group in grouped.items():
        aggregate = aggregate_result_rows(group)
        first = group[0]
        summary.append(
            {
                "layer_order": order,
                "decoder_cycles_per_iteration": first["decoder_cycles_per_iteration"],
                "syndrome_tail": first["syndrome_tail"],
                "effective_iteration_boundary": first["effective_iteration_boundary"],
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
            }
        )
    return summary


def annotate_ranked_summary(
    rows: list[dict[str, object]],
    *,
    bler_margin: float,
    retained_count: int,
    rank_prefix: str,
) -> tuple[list[dict[str, object]], list[str]]:
    best_bler = min(float(row["BLER"]) for row in rows)
    for row in rows:
        ci_low = float(row["BLER_CI95_low"])
        ci_high = float(row["BLER_CI95_high"])
        row["quality_pass"] = (
            float(row["BLER"]) <= best_bler + bler_margin
            or ci_low <= best_bler <= ci_high
        )
    ranked = sorted(
        rows,
        key=lambda row: (
            not bool(row["quality_pass"]),
            float(row["expected_latency_cycles"]),
            float(row["BLER"]),
            str(row["layer_order"]),
        ),
    )
    retained: list[str] = []
    for rank, row in enumerate(ranked, start=1):
        row[f"{rank_prefix}_rank"] = rank
        row[f"{rank_prefix}_retained"] = rank <= retained_count
        if rank <= retained_count:
            retained.append(str(row["layer_order"]))
    return ranked, retained


def mcnemar_exact_p(discord_left: int, discord_right: int) -> float:
    n = discord_left + discord_right
    if n == 0:
        return 1.0
    k = min(discord_left, discord_right)
    log_terms = [
        lgamma(n + 1) - lgamma(i + 1) - lgamma(n - i + 1) - n * log(2.0)
        for i in range(k + 1)
    ]
    max_log = max(log_terms)
    cdf = exp(max_log) * sum(exp(term - max_log) for term in log_terms)
    return min(1.0, 2.0 * cdf)


def mean_and_se(values: list[float]) -> tuple[float, float]:
    if not values:
        return 0.0, 0.0
    array = np.array(values, dtype=np.float64)
    if array.size <= 1:
        return float(array.mean()), 0.0
    return float(array.mean()), float(array.std(ddof=1) / sqrt(array.size))


def paired_comparison_row(
    *,
    stage: str,
    ebn0_db: float | str,
    left_order: str,
    right_order: str,
    left_boundary: int,
    right_boundary: int,
    left_outcomes: list[BlockOutcome],
    right_outcomes: list[BlockOutcome],
) -> dict[str, object]:
    if len(left_outcomes) != len(right_outcomes):
        raise ValueError("Paired comparisons require equal outcome counts.")
    for left, right in zip(left_outcomes, right_outcomes):
        if left.seed != right.seed:
            raise ValueError("Paired comparisons require aligned seeds.")
    left_errors = sum(1 for item in left_outcomes if item.block_error)
    right_errors = sum(1 for item in right_outcomes if item.block_error)
    left_only = sum(
        1
        for left, right in zip(left_outcomes, right_outcomes)
        if left.block_error and not right.block_error
    )
    right_only = sum(
        1
        for left, right in zip(left_outcomes, right_outcomes)
        if right.block_error and not left.block_error
    )
    iter_delta = [
        right.iterations - left.iterations
        for left, right in zip(left_outcomes, right_outcomes)
    ]
    latency_delta = [
        right.iterations * right_boundary - left.iterations * left_boundary
        for left, right in zip(left_outcomes, right_outcomes)
    ]
    mean_iter_delta, se_iter_delta = mean_and_se(iter_delta)
    mean_latency_delta, se_latency_delta = mean_and_se(latency_delta)
    blocks = len(left_outcomes)
    return {
        "stage": stage,
        "EbN0_dB": ebn0_db,
        "left_order": left_order,
        "right_order": right_order,
        "blocks": blocks,
        "left_block_errors": left_errors,
        "right_block_errors": right_errors,
        "left_BLER": format_float(left_errors / blocks if blocks else 0.0, 8),
        "right_BLER": format_float(right_errors / blocks if blocks else 0.0, 8),
        "left_error_right_clean": left_only,
        "left_clean_right_error": right_only,
        "delta_BLER_right_minus_left": format_float(
            (right_errors - left_errors) / blocks if blocks else 0.0,
            8,
        ),
        "mcnemar_exact_p": format_float(mcnemar_exact_p(left_only, right_only), 8),
        "mean_iteration_delta_right_minus_left": format_float(mean_iter_delta),
        "se_iteration_delta": format_float(se_iter_delta),
        "mean_latency_delta_right_minus_left": format_float(mean_latency_delta, 3),
        "se_latency_delta": format_float(se_latency_delta, 3),
    }


def select_final_order(
    confirmation_summary: list[dict[str, object]],
    aggregate_pair_rows: list[dict[str, object]],
) -> tuple[dict[str, object], list[dict[str, object]]]:
    best_error = min(confirmation_summary, key=lambda row: float(row["BLER"]))
    best_error_order = str(best_error["layer_order"])
    comparison_by_order: dict[str, dict[str, object]] = {}
    for row in aggregate_pair_rows:
        if row["left_order"] == best_error_order:
            comparison_by_order[str(row["right_order"])] = row
        elif row["right_order"] == best_error_order:
            comparison_by_order[str(row["left_order"])] = {
                **row,
                "delta_BLER_right_minus_left": format_float(
                    -float(row["delta_BLER_right_minus_left"]),
                    8,
                ),
                "mcnemar_exact_p": row["mcnemar_exact_p"],
            }

    for row in confirmation_summary:
        order = str(row["layer_order"])
        if order == best_error_order:
            row["meaningful_error_degradation"] = False
            row["selection_quality_pass"] = True
            continue
        comparison = comparison_by_order.get(order)
        raw_delta = float(row["BLER"]) - float(best_error["BLER"])
        significant = (
            comparison is not None
            and float(comparison["mcnemar_exact_p"]) < 0.05
            and raw_delta > 0.01
        )
        ci_overlap = not (
            float(row["BLER_CI95_low"]) > float(best_error["BLER_CI95_high"])
            or float(best_error["BLER_CI95_low"]) > float(row["BLER_CI95_high"])
        )
        row["meaningful_error_degradation"] = significant and not ci_overlap
        row["selection_quality_pass"] = not row["meaningful_error_degradation"]

    candidates = [row for row in confirmation_summary if row["selection_quality_pass"]]
    selected = min(
        candidates,
        key=lambda row: (
            float(row["expected_latency_cycles"]),
            float(row["BLER"]),
            str(row["layer_order"]),
        ),
    )
    return selected, confirmation_summary


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
    parser.add_argument("--screen-blocks", type=int, default=500)
    parser.add_argument("--confirm-blocks", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=20260819)
    args = parser.parse_args()

    out_dir = ROOT / "results" / "architecture_closure_v2"
    out_dir.mkdir(parents=True, exist_ok=True)

    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    rate = high_rate_bg1_config()
    cfg = architecture_config()
    all_orders = tuple(permutations(graph.layer_ids))

    print("Evaluating all 24 layer-order cycle/syndrome boundaries with S=8 Q=8...", flush=True)
    schedule_by_order: dict[tuple[int, ...], SimulationResult] = {}
    syndrome_by_order: dict[tuple[int, ...], object] = {}
    cycle_rows: list[dict[str, object]] = []
    for order in all_orders:
        schedule, syndrome = simulate_schedule(graph=graph, cfg=cfg, order=order)
        schedule_by_order[order] = schedule
        syndrome_by_order[order] = syndrome
    for rank, order in enumerate(
        sorted(
            all_orders,
            key=lambda item: (
                syndrome_by_order[item].effective_iteration_boundary,
                schedule_by_order[item].metrics.cycles_per_iteration,
                item,
            ),
        ),
        start=1,
    ):
        cycle_rows.append(cycle_row(rank, schedule_by_order[order], syndrome_by_order[order]))
    write_csv(out_dir / "layer_order_cycle_table.csv", cycle_rows)

    seed_rows: list[dict[str, object]] = []
    screen_rows: list[dict[str, object]] = []
    print("Stage 1: true common-seed screen of all 24 orders...", flush=True)
    for snr in STAGE1_SNRS:
        seeds = seed_sequence(
            seed_base_for(root_seed=args.seed, stage_offset=10_000_000, snr=snr),
            args.screen_blocks,
        )
        seed_rows.append(
            seed_manifest_row(
                stage="screen",
                snr=snr,
                seeds=seeds,
                stage_offset=10_000_000,
                root_seed=args.seed,
            )
        )
        stats_by_order = run_common_seed_orders(
            graph=graph,
            rate=rate,
            ebn0_db=snr,
            seeds=seeds,
            orders=all_orders,
            progress_label="screen all-orders",
        )
        for order, stats in stats_by_order.items():
            screen_rows.append(
                result_row(
                    stage="layer_order_screen",
                    stats=stats,
                    schedule=schedule_by_order[order],
                    syndrome=syndrome_by_order[order],
                    requested_blocks=args.screen_blocks,
                    seed_base=seeds[0],
                )
            )

    screen_summary = summarize_by_order(screen_rows)
    screen_summary, top5_orders_text = annotate_ranked_summary(
        screen_summary,
        bler_margin=0.02,
        retained_count=5,
        rank_prefix="screen",
    )
    screen_annotations = {
        str(row["layer_order"]): row for row in screen_summary
    }
    for row in screen_rows:
        annotation = screen_annotations[str(row["layer_order"])]
        row["screen_rank"] = annotation["screen_rank"]
        row["screen_quality_pass"] = annotation["quality_pass"]
        row["screen_retained_top5"] = annotation["screen_retained"]
        row["aggregate_blocks"] = annotation["blocks"]
        row["aggregate_block_errors"] = annotation["block_errors"]
        row["aggregate_BLER"] = annotation["BLER"]
        row["aggregate_expected_latency_cycles"] = annotation["expected_latency_cycles"]
    write_csv(out_dir / "layer_order_screen.csv", sorted(
        screen_rows,
        key=lambda row: (int(row["screen_rank"]), float(row["EbN0_dB"])),
    ))

    confirm_order_texts = set(top5_orders_text)
    confirm_order_texts.update(order_text(order) for order in MANDATORY_ORDERS)
    order_by_text = {order_text(order): order for order in all_orders}
    confirm_orders = tuple(
        order_by_text[text]
        for text in sorted(
            confirm_order_texts,
            key=lambda text: (
                int(screen_annotations[text]["screen_rank"]),
                text,
            ),
        )
    )

    print(
        "Stage 2: confirmation with true common seeds for "
        + ", ".join(order_text(order) for order in confirm_orders),
        flush=True,
    )
    confirm_rows: list[dict[str, object]] = []
    confirmation_outcomes: dict[float, dict[str, list[BlockOutcome]]] = {}
    for snr in CONFIRM_SNRS:
        seeds = seed_sequence(
            seed_base_for(root_seed=args.seed, stage_offset=20_000_000, snr=snr),
            args.confirm_blocks,
        )
        seed_rows.append(
            seed_manifest_row(
                stage="confirmation",
                snr=snr,
                seeds=seeds,
                stage_offset=20_000_000,
                root_seed=args.seed,
            )
        )
        stats_by_order = run_common_seed_orders(
            graph=graph,
            rate=rate,
            ebn0_db=snr,
            seeds=seeds,
            orders=confirm_orders,
            progress_label="confirmation retained-orders",
        )
        confirmation_outcomes[snr] = {}
        for order, stats in stats_by_order.items():
            text = order_text(order)
            confirmation_outcomes[snr][text] = stats.outcomes
            confirm_rows.append(
                result_row(
                    stage="layer_order_confirmation",
                    stats=stats,
                    schedule=schedule_by_order[order],
                    syndrome=syndrome_by_order[order],
                    requested_blocks=args.confirm_blocks,
                    seed_base=seeds[0],
                )
            )

    confirm_summary = summarize_by_order(confirm_rows)
    confirm_summary, _ = annotate_ranked_summary(
        confirm_summary,
        bler_margin=0.01,
        retained_count=len(confirm_summary),
        rank_prefix="confirmation",
    )

    paired_rows: list[dict[str, object]] = []
    for snr in CONFIRM_SNRS:
        for left, right in combinations([order_text(order) for order in confirm_orders], 2):
            paired_rows.append(
                paired_comparison_row(
                    stage="confirmation",
                    ebn0_db=snr,
                    left_order=left,
                    right_order=right,
                    left_boundary=syndrome_by_order[order_by_text[left]].effective_iteration_boundary,
                    right_boundary=syndrome_by_order[order_by_text[right]].effective_iteration_boundary,
                    left_outcomes=confirmation_outcomes[snr][left],
                    right_outcomes=confirmation_outcomes[snr][right],
                )
            )

    aggregate_outcomes: dict[str, list[BlockOutcome]] = {}
    for text in [order_text(order) for order in confirm_orders]:
        aggregate_outcomes[text] = []
        for snr in CONFIRM_SNRS:
            aggregate_outcomes[text].extend(confirmation_outcomes[snr][text])
    aggregate_pair_rows: list[dict[str, object]] = []
    for left, right in combinations([order_text(order) for order in confirm_orders], 2):
        aggregate_pair_rows.append(
            paired_comparison_row(
                stage="confirmation_aggregate",
                ebn0_db="4.2+4.4",
                left_order=left,
                right_order=right,
                left_boundary=syndrome_by_order[order_by_text[left]].effective_iteration_boundary,
                right_boundary=syndrome_by_order[order_by_text[right]].effective_iteration_boundary,
                left_outcomes=aggregate_outcomes[left],
                right_outcomes=aggregate_outcomes[right],
            )
        )
    paired_rows.extend(aggregate_pair_rows)

    selected_order, confirm_summary = select_final_order(confirm_summary, aggregate_pair_rows)
    selected_text = str(selected_order["layer_order"])
    for row in confirm_rows:
        annotation = next(
            item for item in confirm_summary if item["layer_order"] == row["layer_order"]
        )
        row["confirmation_rank"] = annotation["confirmation_rank"]
        row["confirmation_quality_pass"] = annotation["quality_pass"]
        row["selection_quality_pass"] = annotation["selection_quality_pass"]
        row["meaningful_error_degradation"] = annotation["meaningful_error_degradation"]
        row["selected_final_order"] = row["layer_order"] == selected_text
        row["aggregate_blocks"] = annotation["blocks"]
        row["aggregate_block_errors"] = annotation["block_errors"]
        row["aggregate_BLER"] = annotation["BLER"]
        row["aggregate_expected_latency_cycles"] = annotation["expected_latency_cycles"]

    write_csv(out_dir / "layer_order_confirmation.csv", sorted(
        confirm_rows,
        key=lambda row: (int(row["confirmation_rank"]), float(row["EbN0_dB"])),
    ))
    write_csv(out_dir / "paired_order_comparison.csv", paired_rows)
    write_csv(out_dir / "order_selection_summary.csv", confirm_summary)
    write_csv(out_dir / "seed_manifest.csv", seed_rows)

    selected_order_tuple = order_by_text[selected_text]
    selected_schedule = schedule_by_order[selected_order_tuple]
    selected_syndrome = syndrome_by_order[selected_order_tuple]
    max_tail = max(int(row["syndrome_tail"]) for row in cycle_rows)
    all_q8_valid = all(str(row["syndrome_valid"]) == "True" or row["syndrome_valid"] is True for row in cycle_rows)

    report_lines = [
        "# Architecture Closure v2 - Common-Seed Layer-Order Validation",
        "",
        "This correction writes only under `results/architecture_closure_v2/` and does not modify previous closure results.",
        "The previous order-index seed dependency was removed: each SNR uses one seed tuple reused across every order.",
        "",
        "## Fixed Architecture",
        "",
        "`P=384`, `B=2`, `D_A=3`, `D_R=3`, APP banks=8, forward cache=8.",
        f"Syndrome architecture: `S={SYNDROME_S}`, `Q={SYNDROME_Q}`.",
        "Fixed-point configuration: `F1`, CH=6, APP=8, q=8, M=6, gain=1.32, shift=1, beta_int=1, asymmetric two's-complement saturation.",
        "",
        "## Q=8 Syndrome Check",
        "",
        f"All 24 layer orders were syndrome-valid with `Q={SYNDROME_Q}`: `{all_q8_valid}`.",
        f"Maximum high-rate syndrome tail across the 24 orders: `{max_tail}` cycle.",
        "This preserves the previously observed high-rate tail behavior while using the globally safe queue depth.",
        "",
        "## Cycle Table",
        "",
        *markdown_table(
            cycle_rows,
            (
                "cycle_rank",
                "layer_order",
                "decoder_cycles_per_iteration",
                "syndrome_tail",
                "effective_iteration_boundary",
                "required_queue_depth",
            ),
            limit=10,
        ),
        "",
        "## Stage 1 Screen",
        "",
        f"All 24 permutations were run at 4.2, 4.4, and 4.9 dB with `{args.screen_blocks}` common-seed blocks/order/SNR.",
        "",
        *markdown_table(
            screen_summary,
            (
                "screen_rank",
                "layer_order",
                "quality_pass",
                "blocks",
                "block_errors",
                "BLER",
                "avg_iterations",
                "expected_latency_cycles",
                "fraction_reaching_max_iterations",
            ),
            limit=10,
        ),
        "",
        "## Confirmation",
        "",
        f"Confirmed orders: `{', '.join(order_text(order) for order in confirm_orders)}`.",
        f"Each SNR used one common seed tuple across every confirmed order with `{args.confirm_blocks}` blocks/order/SNR.",
        "",
        *markdown_table(
            confirm_summary,
            (
                "confirmation_rank",
                "layer_order",
                "selection_quality_pass",
                "meaningful_error_degradation",
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
        "Paired comparisons are in `paired_order_comparison.csv`; final selection uses latency first after filtering meaningful error-correction degradation.",
        "",
        "## Final Recommendation",
        "",
        f"Final layer order: `{selected_text}`.",
        f"Decoder cycles/iteration: `{selected_schedule.metrics.cycles_per_iteration}`.",
        f"Syndrome tail: `{selected_syndrome.additional_tail_cycles}`.",
        f"Effective iteration boundary: `{selected_syndrome.effective_iteration_boundary}`.",
        "",
        "Reaffirmed architecture items:",
        "- Width family: `F`.",
        "- Gain: `1.32`.",
        "- Channel-to-APP shift: `1`.",
        "- beta_int: `1`.",
        "- Saturation: `asymmetric two's-complement`.",
        f"- Syndrome: `S={SYNDROME_S}`, `Q={SYNDROME_Q}`.",
        "",
        "## Raw Outputs",
        "",
        "- `results/architecture_closure_v2/layer_order_cycle_table.csv`",
        "- `results/architecture_closure_v2/layer_order_screen.csv`",
        "- `results/architecture_closure_v2/layer_order_confirmation.csv`",
        "- `results/architecture_closure_v2/paired_order_comparison.csv`",
        "- `results/architecture_closure_v2/order_selection_summary.csv`",
        "- `results/architecture_closure_v2/seed_manifest.csv`",
    ]
    report_path = out_dir / "architecture_closure_v2_report.md"
    report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
