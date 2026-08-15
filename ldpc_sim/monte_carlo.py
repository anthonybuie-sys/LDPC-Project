"""Monte Carlo helpers for numerical OMS studies."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

import numpy as np

from ldpc_sim.channel import (
    RateMatchConfig,
    awgn_llr_all_zero,
    information_bit_errors,
    quantize_channel_sample,
)
from ldpc_sim.fixed_point import FixedPointFormat, SaturationStats
from ldpc_sim.graph import LDPCGraph
from ldpc_sim.numerical_decoder import DecodeResult, decode_fixed, decode_float


ModelKind = Literal["float", "fixed"]


@dataclass(frozen=True)
class PointConfig:
    label: str
    model: ModelKind
    beta: float = 0.0
    fmt: FixedPointFormat | None = None
    layer_order: tuple[int, ...] | None = None


@dataclass
class MonteCarloResult:
    label: str
    model: str
    ebn0_db: float
    blocks: int
    block_errors: int
    bit_errors: int
    info_bits: int
    iterations_sum: int
    successful_iterations_sum: int
    successful_blocks: int
    max_iterations_observed: int
    reached_max_iterations: int
    undetected_errors: int
    syndrome_pass_count: int
    convergence_failures: int
    saturation: SaturationStats
    saturation_blocks: int

    @property
    def bler(self) -> float:
        return self.block_errors / self.blocks if self.blocks else 0.0

    @property
    def ber(self) -> float:
        denom = self.blocks * self.info_bits
        return self.bit_errors / denom if denom else 0.0

    @property
    def average_iterations(self) -> float:
        return self.iterations_sum / self.blocks if self.blocks else 0.0

    @property
    def average_successful_iterations(self) -> float:
        if not self.successful_blocks:
            return 0.0
        return self.successful_iterations_sum / self.successful_blocks

    @property
    def fraction_reaching_max_iterations(self) -> float:
        return self.reached_max_iterations / self.blocks if self.blocks else 0.0

    @property
    def saturation_block_fraction(self) -> float:
        return self.saturation_blocks / self.blocks if self.blocks else 0.0

    @property
    def saturation_events_per_block(self) -> float:
        return self.saturation.total / self.blocks if self.blocks else 0.0

    @property
    def expected_core_cycles(self) -> float:
        return self.average_iterations * 71.0

    def as_row(self, **extra: object) -> dict[str, object]:
        row: dict[str, object] = {
            "label": self.label,
            "model": self.model,
            "EbN0_dB": self.ebn0_db,
            "blocks": self.blocks,
            "block_errors": self.block_errors,
            "BLER": f"{self.bler:.8f}",
            "bit_errors_info": self.bit_errors,
            "BER": f"{self.ber:.10f}",
            "avg_iterations": f"{self.average_iterations:.6f}",
            "avg_success_iterations": f"{self.average_successful_iterations:.6f}",
            "max_iterations_observed": self.max_iterations_observed,
            "fraction_reaching_max_iterations": f"{self.fraction_reaching_max_iterations:.6f}",
            "undetected_errors": self.undetected_errors,
            "syndrome_pass_count": self.syndrome_pass_count,
            "convergence_failures": self.convergence_failures,
            "channel_saturation_count": self.saturation.channel,
            "q_sub_saturation_count": self.saturation.q_sub,
            "min_input_clip_count": self.saturation.min_input_clip,
            "app_add_saturation_count": self.saturation.app_add,
            "saturation_block_fraction": f"{self.saturation_block_fraction:.6f}",
            "saturation_events_per_block": f"{self.saturation_events_per_block:.6f}",
            "expected_core_cycles": f"{self.expected_core_cycles:.3f}",
            "worst_configured_core_cycles": 12 * 71,
        }
        row.update(extra)
        return row


def seed_sequence(base_seed: int, count: int) -> tuple[int, ...]:
    return tuple(int(base_seed + index) for index in range(count))


def simulate_point(
    *,
    graph: LDPCGraph,
    rate_match: RateMatchConfig,
    ebn0_db: float,
    point: PointConfig,
    seeds: tuple[int, ...],
    max_iterations: int,
    max_errors: int,
) -> MonteCarloResult:
    saturation = SaturationStats()
    blocks = 0
    block_errors = 0
    bit_errors = 0
    iterations_sum = 0
    successful_iterations_sum = 0
    successful_blocks = 0
    max_iterations_observed = 0
    reached_max_iterations = 0
    undetected_errors = 0
    syndrome_pass_count = 0
    convergence_failures = 0
    saturation_blocks = 0
    info_bits = rate_match.info_base_cols * graph.Z

    for seed in seeds:
        rng = np.random.default_rng(seed)
        sample = awgn_llr_all_zero(
            rng=rng,
            z=graph.Z,
            rate_match=rate_match,
            ebn0_db=ebn0_db,
        )
        if point.model == "float":
            decoded = decode_float(
                graph,
                sample.llr,
                beta=point.beta,
                max_iterations=max_iterations,
                layer_order=point.layer_order,
                representation="compressed",
                early_termination=True,
            )
        else:
            if point.fmt is None:
                raise ValueError("fixed point simulation requires fmt.")
            quantized = quantize_channel_sample(sample, point.fmt)
            decoded = decode_fixed(
                graph,
                quantized.values,
                fmt=point.fmt,
                max_iterations=max_iterations,
                layer_order=point.layer_order,
                representation="compressed",
                early_termination=True,
                channel_saturation_count=quantized.channel_saturation_count,
            )
        assert isinstance(decoded, DecodeResult)
        blocks += 1
        errors = information_bit_errors(decoded.hard_bits, rate_match.info_base_cols)
        is_block_error = errors > 0
        bit_errors += errors
        block_errors += 1 if is_block_error else 0
        iterations_sum += decoded.iterations
        max_iterations_observed = max(max_iterations_observed, decoded.iterations)
        if decoded.iterations >= max_iterations:
            reached_max_iterations += 1
        if decoded.syndrome_passed:
            syndrome_pass_count += 1
        else:
            convergence_failures += 1
        if decoded.syndrome_passed and is_block_error:
            undetected_errors += 1
        if decoded.syndrome_passed and not is_block_error:
            successful_blocks += 1
            successful_iterations_sum += decoded.iterations
        saturation.add(decoded.saturation)
        if decoded.saturation.any:
            saturation_blocks += 1
        if block_errors >= max_errors:
            break

    return MonteCarloResult(
        label=point.label,
        model=point.model,
        ebn0_db=ebn0_db,
        blocks=blocks,
        block_errors=block_errors,
        bit_errors=bit_errors,
        info_bits=info_bits,
        iterations_sum=iterations_sum,
        successful_iterations_sum=successful_iterations_sum,
        successful_blocks=successful_blocks,
        max_iterations_observed=max_iterations_observed,
        reached_max_iterations=reached_max_iterations,
        undetected_errors=undetected_errors,
        syndrome_pass_count=syndrome_pass_count,
        convergence_failures=convergence_failures,
        saturation=saturation,
        saturation_blocks=saturation_blocks,
    )
