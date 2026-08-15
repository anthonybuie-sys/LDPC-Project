"""Floating-point and fixed-point layered OMS decoders."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from ldpc_sim.fixed_point import (
    FixedPointFormat,
    SaturationStats,
    beta_subtract_clamp,
    clip_magnitude,
    saturate_signed,
    saturating_add,
    saturating_sub,
    signed_from_magnitude,
)
from ldpc_sim.graph import Edge, LDPCGraph, Layer


def rotate_to_check(values: np.ndarray, shift: int) -> np.ndarray:
    return np.roll(values, -int(shift))


def rotate_from_check(values: np.ndarray, shift: int) -> np.ndarray:
    return np.roll(values, int(shift))


def compute_syndrome(graph: LDPCGraph, hard_bits: np.ndarray) -> np.ndarray:
    rows: list[np.ndarray] = []
    for layer in graph.layers:
        syndrome = np.zeros(graph.Z, dtype=np.bool_)
        for edge in layer.edges:
            syndrome ^= rotate_to_check(hard_bits[edge.column], edge.shift).astype(np.bool_)
        rows.append(syndrome)
    if not rows:
        return np.zeros((0, graph.Z), dtype=np.bool_)
    return np.stack(rows, axis=0)


def syndrome_passes(graph: LDPCGraph, hard_bits: np.ndarray) -> bool:
    return not bool(np.any(compute_syndrome(graph, hard_bits)))


def _min1_min2_argmin(magnitudes: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    if magnitudes.ndim != 2:
        raise ValueError("magnitudes must have shape (degree, Z).")
    degree = magnitudes.shape[0]
    if degree < 1:
        raise ValueError("A check node must have at least one edge.")
    argmin = np.argmin(magnitudes, axis=0)
    min1 = np.take_along_axis(magnitudes, argmin[None, :], axis=0)[0]
    if degree == 1:
        min2 = min1.copy()
    else:
        masked = magnitudes.copy()
        if np.issubdtype(masked.dtype, np.floating):
            replacement = np.inf
        else:
            replacement = np.iinfo(masked.dtype).max
        masked[argmin, np.arange(magnitudes.shape[1])] = replacement
        min2 = np.min(masked, axis=0)
    return min1, min2, argmin.astype(np.int64)


def min_sum_state_float(q_check: np.ndarray, beta: float) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    signs = q_check < 0.0
    magnitudes = np.abs(q_check)
    min1, min2, argmin = _min1_min2_argmin(magnitudes)
    total_sign = np.logical_xor.reduce(signs, axis=0)
    m1 = np.maximum(min1 - beta, 0.0)
    m2 = np.maximum(min2 - beta, 0.0)
    return m1, m2, argmin, total_sign, signs


def min_sum_state_fixed(
    q_check: np.ndarray,
    fmt: FixedPointFormat,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, int]:
    signs = q_check < 0
    magnitudes_raw = np.abs(q_check.astype(np.int64))
    magnitudes, clip_count = clip_magnitude(magnitudes_raw, fmt.w_m)
    min1, min2, argmin = _min1_min2_argmin(magnitudes)
    total_sign = np.logical_xor.reduce(signs, axis=0)
    m1 = beta_subtract_clamp(min1, fmt.beta_int)
    m2 = beta_subtract_clamp(min2, fmt.beta_int)
    return m1, m2, argmin, total_sign, signs, clip_count


@dataclass
class CompressedFloatLayerState:
    m1: np.ndarray
    m2: np.ndarray
    imin: np.ndarray
    total_sign: np.ndarray
    q_signs: tuple[np.ndarray, ...]

    @classmethod
    def zeros(cls, degree: int, z: int) -> "CompressedFloatLayerState":
        return cls(
            m1=np.zeros(z, dtype=np.float64),
            m2=np.zeros(z, dtype=np.float64),
            imin=np.zeros(z, dtype=np.int64),
            total_sign=np.zeros(z, dtype=np.bool_),
            q_signs=tuple(np.zeros(z, dtype=np.bool_) for _ in range(degree)),
        )


@dataclass
class CompressedFixedLayerState:
    m1: np.ndarray
    m2: np.ndarray
    imin: np.ndarray
    total_sign: np.ndarray
    q_signs: tuple[np.ndarray, ...]

    @classmethod
    def zeros(cls, degree: int, z: int) -> "CompressedFixedLayerState":
        return cls(
            m1=np.zeros(z, dtype=np.int64),
            m2=np.zeros(z, dtype=np.int64),
            imin=np.zeros(z, dtype=np.int64),
            total_sign=np.zeros(z, dtype=np.bool_),
            q_signs=tuple(np.zeros(z, dtype=np.bool_) for _ in range(degree)),
        )


@dataclass(frozen=True)
class DecodeResult:
    app: np.ndarray
    hard_bits: np.ndarray
    iterations: int
    syndrome_passed: bool
    reached_max_iterations: bool
    saturation: SaturationStats


def _n_cols_for(graph: LDPCGraph, llr: np.ndarray) -> int:
    required = max(graph.columns) + 1 if graph.columns else 0
    return max(required, llr.shape[0])


def _ordered_layers(graph: LDPCGraph, layer_order: tuple[int, ...] | None) -> tuple[Layer, ...]:
    return graph.ordered_layers(layer_order)


def _full_float_layer(
    app: np.ndarray,
    r_state: dict[tuple[int, int], np.ndarray],
    layer: Layer,
    beta: float,
) -> None:
    q_vars: list[np.ndarray] = []
    q_checks: list[np.ndarray] = []
    for edge in layer.edges:
        old = r_state[(edge.layer_id, edge.edge_id)]
        q = app[edge.column] - old
        q_vars.append(q)
        q_checks.append(rotate_to_check(q, edge.shift))
    q_check = np.stack(q_checks, axis=0)
    m1, m2, imin, total_sign, q_signs = min_sum_state_float(q_check, beta)
    for index, edge in enumerate(layer.edges):
        mag = np.where(imin == index, m2, m1)
        sign = np.logical_xor(total_sign, q_signs[index])
        r_check = np.where(sign, -mag, mag)
        r_var = rotate_from_check(r_check, edge.shift)
        app[edge.column] = q_vars[index] + r_var
        r_state[(edge.layer_id, edge.edge_id)] = r_var


def _compressed_float_old_r(
    state: CompressedFloatLayerState,
    edge_index: int,
    edge: Edge,
) -> np.ndarray:
    mag = np.where(state.imin == edge_index, state.m2, state.m1)
    sign = np.logical_xor(state.total_sign, state.q_signs[edge_index])
    return rotate_from_check(np.where(sign, -mag, mag), edge.shift)


def _compressed_float_layer(
    app: np.ndarray,
    states: dict[int, CompressedFloatLayerState],
    layer: Layer,
    beta: float,
) -> None:
    state = states[layer.layer_id]
    q_vars: list[np.ndarray] = []
    q_checks: list[np.ndarray] = []
    for index, edge in enumerate(layer.edges):
        old = _compressed_float_old_r(state, index, edge)
        q = app[edge.column] - old
        q_vars.append(q)
        q_checks.append(rotate_to_check(q, edge.shift))
    q_check = np.stack(q_checks, axis=0)
    m1, m2, imin, total_sign, q_signs = min_sum_state_float(q_check, beta)
    new_state = CompressedFloatLayerState(
        m1=m1,
        m2=m2,
        imin=imin,
        total_sign=total_sign,
        q_signs=tuple(q_signs[index].copy() for index in range(len(layer.edges))),
    )
    states[layer.layer_id] = new_state
    for index, edge in enumerate(layer.edges):
        mag = np.where(imin == index, m2, m1)
        sign = np.logical_xor(total_sign, q_signs[index])
        r_var = rotate_from_check(np.where(sign, -mag, mag), edge.shift)
        app[edge.column] = q_vars[index] + r_var


def decode_float(
    graph: LDPCGraph,
    channel_llr: np.ndarray,
    *,
    beta: float,
    max_iterations: int,
    layer_order: tuple[int, ...] | None = None,
    representation: str = "compressed",
    early_termination: bool = True,
) -> DecodeResult:
    if max_iterations < 1:
        raise ValueError("max_iterations must be positive.")
    llr = np.asarray(channel_llr, dtype=np.float64)
    n_cols = _n_cols_for(graph, llr)
    app = np.zeros((n_cols, graph.Z), dtype=np.float64)
    app[: llr.shape[0], :] = llr
    ordered_layers = _ordered_layers(graph, layer_order)
    if representation == "full":
        r_state = {
            (edge.layer_id, edge.edge_id): np.zeros(graph.Z, dtype=np.float64)
            for layer in graph.layers
            for edge in layer.edges
        }
        states = None
    elif representation == "compressed":
        states = {
            layer.layer_id: CompressedFloatLayerState.zeros(layer.degree, graph.Z)
            for layer in graph.layers
        }
        r_state = None
    else:
        raise ValueError("representation must be 'full' or 'compressed'.")

    passed = False
    iterations = max_iterations
    for iteration in range(1, max_iterations + 1):
        for layer in ordered_layers:
            if representation == "full":
                assert r_state is not None
                _full_float_layer(app, r_state, layer, beta)
            else:
                assert states is not None
                _compressed_float_layer(app, states, layer, beta)
        hard = app < 0.0
        passed = syndrome_passes(graph, hard)
        if early_termination and passed:
            iterations = iteration
            break
    else:
        hard = app < 0.0
    return DecodeResult(
        app=app,
        hard_bits=hard,
        iterations=iterations,
        syndrome_passed=passed,
        reached_max_iterations=iterations == max_iterations and not passed,
        saturation=SaturationStats(),
    )


def _full_fixed_layer(
    app: np.ndarray,
    r_state: dict[tuple[int, int], np.ndarray],
    layer: Layer,
    fmt: FixedPointFormat,
    stats: SaturationStats,
) -> None:
    q_vars: list[np.ndarray] = []
    q_checks: list[np.ndarray] = []
    for edge in layer.edges:
        old = r_state[(edge.layer_id, edge.edge_id)]
        q, count = saturating_sub(app[edge.column], old, fmt.w_q)
        stats.q_sub += count
        q_vars.append(q)
        q_checks.append(rotate_to_check(q, edge.shift))
    q_check = np.stack(q_checks, axis=0)
    m1, m2, imin, total_sign, q_signs, clip_count = min_sum_state_fixed(q_check, fmt)
    stats.min_input_clip += clip_count
    for index, edge in enumerate(layer.edges):
        mag = np.where(imin == index, m2, m1)
        sign = np.logical_xor(total_sign, q_signs[index])
        r_check = signed_from_magnitude(mag, sign)
        r_var = rotate_from_check(r_check, edge.shift)
        new_app, count = saturating_add(q_vars[index], r_var, fmt.w_app)
        stats.app_add += count
        app[edge.column] = new_app
        r_state[(edge.layer_id, edge.edge_id)] = r_var


def _compressed_fixed_old_r(
    state: CompressedFixedLayerState,
    edge_index: int,
    edge: Edge,
) -> np.ndarray:
    mag = np.where(state.imin == edge_index, state.m2, state.m1)
    sign = np.logical_xor(state.total_sign, state.q_signs[edge_index])
    return rotate_from_check(signed_from_magnitude(mag, sign), edge.shift)


def _compressed_fixed_layer(
    app: np.ndarray,
    states: dict[int, CompressedFixedLayerState],
    layer: Layer,
    fmt: FixedPointFormat,
    stats: SaturationStats,
) -> None:
    state = states[layer.layer_id]
    q_vars: list[np.ndarray] = []
    q_checks: list[np.ndarray] = []
    for index, edge in enumerate(layer.edges):
        old = _compressed_fixed_old_r(state, index, edge)
        q, count = saturating_sub(app[edge.column], old, fmt.w_q)
        stats.q_sub += count
        q_vars.append(q)
        q_checks.append(rotate_to_check(q, edge.shift))
    q_check = np.stack(q_checks, axis=0)
    m1, m2, imin, total_sign, q_signs, clip_count = min_sum_state_fixed(q_check, fmt)
    stats.min_input_clip += clip_count
    new_state = CompressedFixedLayerState(
        m1=m1,
        m2=m2,
        imin=imin,
        total_sign=total_sign,
        q_signs=tuple(q_signs[index].copy() for index in range(len(layer.edges))),
    )
    states[layer.layer_id] = new_state
    for index, edge in enumerate(layer.edges):
        mag = np.where(imin == index, m2, m1)
        sign = np.logical_xor(total_sign, q_signs[index])
        r_var = rotate_from_check(signed_from_magnitude(mag, sign), edge.shift)
        new_app, count = saturating_add(q_vars[index], r_var, fmt.w_app)
        stats.app_add += count
        app[edge.column] = new_app


def decode_fixed(
    graph: LDPCGraph,
    channel_values: np.ndarray,
    *,
    fmt: FixedPointFormat,
    max_iterations: int,
    layer_order: tuple[int, ...] | None = None,
    representation: str = "compressed",
    early_termination: bool = True,
    channel_saturation_count: int = 0,
) -> DecodeResult:
    if max_iterations < 1:
        raise ValueError("max_iterations must be positive.")
    channel = np.asarray(channel_values, dtype=np.int64)
    n_cols = _n_cols_for(graph, channel)
    app = np.zeros((n_cols, graph.Z), dtype=np.int64)
    initial, init_sat = saturate_signed(channel, fmt.w_app)
    app[: channel.shape[0], :] = initial
    stats = SaturationStats(channel=channel_saturation_count + init_sat)
    ordered_layers = _ordered_layers(graph, layer_order)
    if representation == "full":
        r_state = {
            (edge.layer_id, edge.edge_id): np.zeros(graph.Z, dtype=np.int64)
            for layer in graph.layers
            for edge in layer.edges
        }
        states = None
    elif representation == "compressed":
        states = {
            layer.layer_id: CompressedFixedLayerState.zeros(layer.degree, graph.Z)
            for layer in graph.layers
        }
        r_state = None
    else:
        raise ValueError("representation must be 'full' or 'compressed'.")

    passed = False
    iterations = max_iterations
    for iteration in range(1, max_iterations + 1):
        for layer in ordered_layers:
            if representation == "full":
                assert r_state is not None
                _full_fixed_layer(app, r_state, layer, fmt, stats)
            else:
                assert states is not None
                _compressed_fixed_layer(app, states, layer, fmt, stats)
        hard = app < 0
        passed = syndrome_passes(graph, hard)
        if early_termination and passed:
            iterations = iteration
            break
    else:
        hard = app < 0
    return DecodeResult(
        app=app,
        hard_bits=hard,
        iterations=iterations,
        syndrome_passed=passed,
        reached_max_iterations=iterations == max_iterations and not passed,
        saturation=stats,
    )


def assert_full_compressed_float_equivalent(
    graph: LDPCGraph,
    channel_llr: np.ndarray,
    *,
    beta: float,
    max_iterations: int,
    layer_order: tuple[int, ...] | None = None,
) -> None:
    llr = np.asarray(channel_llr, dtype=np.float64)
    n_cols = _n_cols_for(graph, llr)
    app_full = np.zeros((n_cols, graph.Z), dtype=np.float64)
    app_compressed = np.zeros((n_cols, graph.Z), dtype=np.float64)
    app_full[: llr.shape[0], :] = llr
    app_compressed[: llr.shape[0], :] = llr
    r_state = {
        (edge.layer_id, edge.edge_id): np.zeros(graph.Z, dtype=np.float64)
        for layer in graph.layers
        for edge in layer.edges
    }
    states = {
        layer.layer_id: CompressedFloatLayerState.zeros(layer.degree, graph.Z)
        for layer in graph.layers
    }
    for iteration in range(max_iterations):
        for layer in _ordered_layers(graph, layer_order):
            _full_float_layer(app_full, r_state, layer, beta)
            _compressed_float_layer(app_compressed, states, layer, beta)
            if not np.allclose(app_full, app_compressed, rtol=0.0, atol=1e-12):
                raise AssertionError(
                    "Floating full and compressed APP states differ after "
                    f"iteration {iteration + 1}, layer {layer.layer_id}."
                )
        hard_full = app_full < 0.0
        hard_compressed = app_compressed < 0.0
        if not np.array_equal(hard_full, hard_compressed):
            raise AssertionError(
                f"Floating hard decisions differ after iteration {iteration + 1}."
            )
        if syndrome_passes(graph, hard_full) != syndrome_passes(graph, hard_compressed):
            raise AssertionError(
                f"Floating syndrome status differs after iteration {iteration + 1}."
            )


def assert_full_compressed_fixed_equivalent(
    graph: LDPCGraph,
    channel_values: np.ndarray,
    *,
    fmt: FixedPointFormat,
    max_iterations: int,
    layer_order: tuple[int, ...] | None = None,
    channel_saturation_count: int = 0,
) -> None:
    channel = np.asarray(channel_values, dtype=np.int64)
    n_cols = _n_cols_for(graph, channel)
    initial, init_sat = saturate_signed(channel, fmt.w_app)
    app_full = np.zeros((n_cols, graph.Z), dtype=np.int64)
    app_compressed = np.zeros((n_cols, graph.Z), dtype=np.int64)
    app_full[: channel.shape[0], :] = initial
    app_compressed[: channel.shape[0], :] = initial
    full_stats = SaturationStats(channel=channel_saturation_count + init_sat)
    compressed_stats = SaturationStats(channel=channel_saturation_count + init_sat)
    r_state = {
        (edge.layer_id, edge.edge_id): np.zeros(graph.Z, dtype=np.int64)
        for layer in graph.layers
        for edge in layer.edges
    }
    states = {
        layer.layer_id: CompressedFixedLayerState.zeros(layer.degree, graph.Z)
        for layer in graph.layers
    }
    for iteration in range(max_iterations):
        for layer in _ordered_layers(graph, layer_order):
            _full_fixed_layer(app_full, r_state, layer, fmt, full_stats)
            _compressed_fixed_layer(app_compressed, states, layer, fmt, compressed_stats)
            if not np.array_equal(app_full, app_compressed):
                raise AssertionError(
                    "Fixed full and compressed APP states differ after "
                    f"iteration {iteration + 1}, layer {layer.layer_id}."
                )
            if full_stats != compressed_stats:
                raise AssertionError(
                    "Fixed full and compressed saturation telemetry differs after "
                    f"iteration {iteration + 1}, layer {layer.layer_id}."
                )
        hard_full = app_full < 0
        hard_compressed = app_compressed < 0
        if not np.array_equal(hard_full, hard_compressed):
            raise AssertionError(
                f"Fixed hard decisions differ after iteration {iteration + 1}."
            )
        if syndrome_passes(graph, hard_full) != syndrome_passes(graph, hard_compressed):
            raise AssertionError(
                f"Fixed syndrome status differs after iteration {iteration + 1}."
            )
