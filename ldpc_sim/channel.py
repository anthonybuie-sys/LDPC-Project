"""BPSK/AWGN channel helpers for all-zero LDPC numerical studies."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from ldpc_sim.fixed_point import FixedPointFormat, quantize_channel


@dataclass(frozen=True)
class RateMatchConfig:
    n_base_cols: int
    info_base_cols: int
    punctured_base_cols: tuple[int, ...]
    rate: float
    name: str


@dataclass(frozen=True)
class ChannelSample:
    llr: np.ndarray
    transmitted_mask: np.ndarray
    sigma2: float


@dataclass(frozen=True)
class QuantizedChannelSample:
    values: np.ndarray
    channel_saturation_count: int


def high_rate_bg1_config() -> RateMatchConfig:
    x = 22
    y = 4
    return RateMatchConfig(
        n_base_cols=x + y,
        info_base_cols=x,
        punctured_base_cols=(0, 1),
        rate=x / (x + y - 2),
        name="BG1_high_rate_X22_Y4",
    )


def full_graph_rate_config(base_graph: int, n_base_cols: int) -> RateMatchConfig:
    info = 22 if base_graph == 1 else 10
    punctured = (0, 1)
    transmitted_cols = n_base_cols - len(punctured)
    return RateMatchConfig(
        n_base_cols=n_base_cols,
        info_base_cols=info,
        punctured_base_cols=punctured,
        rate=info / transmitted_cols,
        name=f"BG{base_graph}_full_no_filler",
    )


def sigma2_from_ebn0(ebn0_db: float, rate: float) -> float:
    return 1.0 / (2.0 * rate * (10.0 ** (ebn0_db / 10.0)))


def awgn_llr_all_zero(
    *,
    rng: np.random.Generator,
    z: int,
    rate_match: RateMatchConfig,
    ebn0_db: float,
) -> ChannelSample:
    sigma2 = sigma2_from_ebn0(ebn0_db, rate_match.rate)
    noise = rng.normal(
        loc=0.0,
        scale=float(np.sqrt(sigma2)),
        size=(rate_match.n_base_cols, z),
    )
    y = 1.0 + noise
    llr = 2.0 * y / sigma2
    transmitted_mask = np.ones(rate_match.n_base_cols, dtype=bool)
    for col in rate_match.punctured_base_cols:
        transmitted_mask[col] = False
        llr[col, :] = 0.0
    return ChannelSample(
        llr=llr.astype(np.float64),
        transmitted_mask=transmitted_mask,
        sigma2=float(sigma2),
    )


def quantize_channel_sample(
    sample: ChannelSample,
    fmt: FixedPointFormat,
) -> QuantizedChannelSample:
    values, saturation_count = quantize_channel(sample.llr, fmt)
    return QuantizedChannelSample(
        values=values,
        channel_saturation_count=saturation_count,
    )


def information_bit_errors(hard_bits: np.ndarray, info_base_cols: int) -> int:
    return int(np.count_nonzero(hard_bits[:info_base_cols, :]))
