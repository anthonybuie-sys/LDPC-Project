"""Fixed-point utilities for bit-accurate OMS experiments."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass(frozen=True)
class FixedPointFormat:
    name: str
    w_ch: int
    w_app: int
    w_q: int
    w_m: int
    channel_gain: float = 1.0
    beta_int: int = 0

    @property
    def ch_min(self) -> int:
        return signed_min(self.w_ch)

    @property
    def ch_max(self) -> int:
        return signed_max(self.w_ch)

    @property
    def app_min(self) -> int:
        return signed_min(self.w_app)

    @property
    def app_max(self) -> int:
        return signed_max(self.w_app)

    @property
    def q_min(self) -> int:
        return signed_min(self.w_q)

    @property
    def q_max(self) -> int:
        return signed_max(self.w_q)

    @property
    def m_max(self) -> int:
        return magnitude_max(self.w_m)

    def with_params(self, *, channel_gain: float, beta_int: int) -> "FixedPointFormat":
        return FixedPointFormat(
            name=self.name,
            w_ch=self.w_ch,
            w_app=self.w_app,
            w_q=self.w_q,
            w_m=self.w_m,
            channel_gain=channel_gain,
            beta_int=beta_int,
        )


@dataclass
class SaturationStats:
    channel: int = 0
    q_sub: int = 0
    min_input_clip: int = 0
    app_add: int = 0

    @property
    def total(self) -> int:
        return self.channel + self.q_sub + self.min_input_clip + self.app_add

    @property
    def any(self) -> bool:
        return self.total > 0

    def add(self, other: "SaturationStats") -> None:
        self.channel += other.channel
        self.q_sub += other.q_sub
        self.min_input_clip += other.min_input_clip
        self.app_add += other.app_add

    def copy(self) -> "SaturationStats":
        return SaturationStats(
            channel=self.channel,
            q_sub=self.q_sub,
            min_input_clip=self.min_input_clip,
            app_add=self.app_add,
        )


CANDIDATE_FORMATS: tuple[FixedPointFormat, ...] = (
    FixedPointFormat("A", 4, 6, 6, 5),
    FixedPointFormat("B", 4, 7, 7, 5),
    FixedPointFormat("C", 5, 7, 7, 6),
    FixedPointFormat("D", 5, 8, 8, 6),
    FixedPointFormat("E", 5, 8, 9, 6),
    FixedPointFormat("F", 6, 8, 8, 6),
    FixedPointFormat("G", 6, 9, 9, 7),
)


def signed_min(width: int) -> int:
    return -(1 << (width - 1))


def signed_max(width: int) -> int:
    return (1 << (width - 1)) - 1


def magnitude_max(width: int) -> int:
    return (1 << width) - 1


def saturate_signed(values, width: int) -> tuple[np.ndarray, int]:
    array = np.asarray(values, dtype=np.int64)
    lo = signed_min(width)
    hi = signed_max(width)
    clipped = np.clip(array, lo, hi).astype(np.int64)
    return clipped, int(np.count_nonzero(clipped != array))


def saturating_add(a, b, width: int) -> tuple[np.ndarray, int]:
    return saturate_signed(np.asarray(a, dtype=np.int64) + np.asarray(b, dtype=np.int64), width)


def saturating_sub(a, b, width: int) -> tuple[np.ndarray, int]:
    return saturate_signed(np.asarray(a, dtype=np.int64) - np.asarray(b, dtype=np.int64), width)


def clip_magnitude(values, width: int) -> tuple[np.ndarray, int]:
    array = np.asarray(values, dtype=np.int64)
    hi = magnitude_max(width)
    clipped = np.clip(array, 0, hi).astype(np.int64)
    return clipped, int(np.count_nonzero(clipped != array))


def beta_subtract_clamp(magnitudes, beta: int) -> np.ndarray:
    array = np.asarray(magnitudes, dtype=np.int64)
    if beta < 0:
        raise ValueError("beta must be non-negative.")
    return np.maximum(array - int(beta), 0).astype(np.int64)


def quantize_channel(llr, fmt: FixedPointFormat) -> tuple[np.ndarray, int]:
    scaled = np.rint(np.asarray(llr, dtype=np.float64) * fmt.channel_gain).astype(np.int64)
    return saturate_signed(scaled, fmt.w_ch)


def signed_from_magnitude(magnitude, negative) -> np.ndarray:
    mag = np.asarray(magnitude, dtype=np.int64)
    neg = np.asarray(negative, dtype=bool)
    return np.where(neg, -mag, mag).astype(np.int64)
