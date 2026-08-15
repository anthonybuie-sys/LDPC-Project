"""Numerical Layered Offset Min-Sum decoder API."""

from __future__ import annotations

import numpy as np

from ldpc_sim.fixed_point import FixedPointFormat
from ldpc_sim.graph import LDPCGraph
from ldpc_sim.numerical_decoder import DecodeResult, decode_fixed, decode_float


class OMSGoldenModel:
    """Convenience wrapper for the floating-point Layered OMS reference."""

    def __init__(
        self,
        graph: LDPCGraph,
        *,
        beta: float = 0.0,
        max_iterations: int = 12,
        layer_order: tuple[int, ...] | None = None,
    ) -> None:
        self.graph = graph
        self.beta = beta
        self.max_iterations = max_iterations
        self.layer_order = layer_order

    def decode(
        self,
        channel_llr: np.ndarray,
        *,
        representation: str = "compressed",
        early_termination: bool = True,
    ) -> DecodeResult:
        return decode_float(
            self.graph,
            channel_llr,
            beta=self.beta,
            max_iterations=self.max_iterations,
            layer_order=self.layer_order,
            representation=representation,
            early_termination=early_termination,
        )


class FixedPointOMSModel:
    """Convenience wrapper for the bit-accurate fixed-point OMS model."""

    def __init__(
        self,
        graph: LDPCGraph,
        *,
        fmt: FixedPointFormat,
        max_iterations: int = 12,
        layer_order: tuple[int, ...] | None = None,
    ) -> None:
        self.graph = graph
        self.fmt = fmt
        self.max_iterations = max_iterations
        self.layer_order = layer_order

    def decode(
        self,
        channel_values: np.ndarray,
        *,
        representation: str = "compressed",
        early_termination: bool = True,
        channel_saturation_count: int = 0,
    ) -> DecodeResult:
        return decode_fixed(
            self.graph,
            channel_values,
            fmt=self.fmt,
            max_iterations=self.max_iterations,
            layer_order=self.layer_order,
            representation=representation,
            early_termination=early_termination,
            channel_saturation_count=channel_saturation_count,
        )
