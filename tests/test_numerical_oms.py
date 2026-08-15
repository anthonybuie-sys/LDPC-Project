from __future__ import annotations

import numpy as np

from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.channel import awgn_llr_all_zero, high_rate_bg1_config, quantize_channel_sample
from ldpc_sim.fixed_point import (
    FixedPointFormat,
    beta_subtract_clamp,
    clip_magnitude,
    saturate_signed,
    saturating_add,
    saturating_sub,
    signed_from_magnitude,
)
from ldpc_sim.numerical_decoder import (
    assert_full_compressed_fixed_equivalent,
    assert_full_compressed_float_equivalent,
    compute_syndrome,
    decode_fixed,
    decode_float,
    min_sum_state_fixed,
    min_sum_state_float,
    rotate_from_check,
    rotate_to_check,
    syndrome_passes,
)


def test_saturating_signed_arithmetic() -> None:
    values, count = saturate_signed(np.array([-20, -8, 0, 7, 20]), 4)
    assert values.tolist() == [-8, -8, 0, 7, 7]
    assert count == 2

    summed, add_count = saturating_add(np.array([7, -8]), np.array([3, -3]), 4)
    assert summed.tolist() == [7, -8]
    assert add_count == 2

    diffed, sub_count = saturating_sub(np.array([-8, 7]), np.array([3, -3]), 4)
    assert diffed.tolist() == [-8, 7]
    assert sub_count == 2


def test_magnitude_clipping_and_beta_clamp() -> None:
    clipped, count = clip_magnitude(np.array([0, 31, 32, 99]), 5)
    assert clipped.tolist() == [0, 31, 31, 31]
    assert count == 2
    assert beta_subtract_clamp(np.array([0, 1, 4]), 2).tolist() == [0, 0, 2]


def test_min1_min2_unique_minimum() -> None:
    q = np.array([[3.0, -7.0], [-2.0, 5.0], [4.0, 1.0]])
    m1, m2, imin, total_sign, signs = min_sum_state_float(q, beta=0.5)
    assert np.allclose(m1, [1.5, 0.5])
    assert np.allclose(m2, [2.5, 4.5])
    assert imin.tolist() == [1, 2]
    assert total_sign.tolist() == [True, True]
    assert signs[1, 0]


def test_min1_min2_equal_minima() -> None:
    fmt = FixedPointFormat("T", 5, 8, 8, 6, beta_int=1)
    q = np.array([[2, -3], [-2, 3], [5, 7]], dtype=np.int64)
    m1, m2, imin, total_sign, _, clip_count = min_sum_state_fixed(q, fmt)
    assert m1.tolist() == [1, 2]
    assert m2.tolist() == [1, 2]
    assert imin.tolist() == [0, 0]
    assert total_sign.tolist() == [True, True]
    assert clip_count == 0


def test_sign_reconstruction() -> None:
    signed = signed_from_magnitude(np.array([0, 3, 4]), np.array([False, True, False]))
    assert signed.tolist() == [0, -3, 4]


def test_qc_rotation_correctness() -> None:
    values = np.arange(8)
    shifted = rotate_to_check(values, 3)
    assert shifted.tolist() == [3, 4, 5, 6, 7, 0, 1, 2]
    assert rotate_from_check(shifted, 3).tolist() == values.tolist()


def test_one_layer_oms_update_runs() -> None:
    graph = load_3gpp_base_graph(2, 384, i_ls=1, active_layer_ids=(0,))
    llr = np.full((12, graph.Z), 5.0)
    llr[:2, :] = 0.0
    result = decode_float(graph, llr, beta=0.5, max_iterations=1, early_termination=False)
    assert result.iterations == 1
    assert result.app.shape == (12, graph.Z)
    assert np.all(result.app[2:] > 0)


def test_one_iteration_fixed_update_runs() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    fmt = FixedPointFormat("D", 5, 8, 8, 6, channel_gain=1.0, beta_int=1)
    values = np.full((26, graph.Z), 6, dtype=np.int64)
    values[:2, :] = 0
    result = decode_fixed(
        graph,
        values,
        fmt=fmt,
        max_iterations=1,
        layer_order=(0, 2, 1, 3),
        early_termination=False,
    )
    assert result.iterations == 1
    assert result.app.shape == (26, graph.Z)


def test_compressed_vs_full_float_equivalence() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    rng = np.random.default_rng(123)
    llr = rng.normal(size=(26, graph.Z))
    llr[:2, :] = 0.0
    assert_full_compressed_float_equivalent(
        graph,
        llr,
        beta=0.5,
        max_iterations=2,
        layer_order=(0, 2, 1, 3),
    )


def test_compressed_vs_full_fixed_equivalence() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    rng = np.random.default_rng(456)
    values = rng.integers(-6, 7, size=(26, graph.Z), dtype=np.int64)
    values[:2, :] = 0
    fmt = FixedPointFormat("D", 5, 8, 8, 6, channel_gain=1.0, beta_int=1)
    assert_full_compressed_fixed_equivalent(
        graph,
        values,
        fmt=fmt,
        max_iterations=2,
        layer_order=(0, 2, 1, 3),
    )


def test_float_vs_high_width_fixed_sanity() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    llr = np.full((26, graph.Z), 9.0)
    llr[:2, :] = 0.0
    fmt = FixedPointFormat("wide", 8, 12, 12, 10, channel_gain=1.0, beta_int=1)
    fixed = decode_fixed(
        graph,
        np.rint(llr).astype(np.int64),
        fmt=fmt,
        max_iterations=4,
        layer_order=(0, 2, 1, 3),
    )
    floating = decode_float(
        graph,
        llr,
        beta=1.0,
        max_iterations=4,
        layer_order=(0, 2, 1, 3),
    )
    assert np.array_equal(fixed.hard_bits, floating.hard_bits)
    assert fixed.syndrome_passed == floating.syndrome_passed


def test_punctured_llr_initialization() -> None:
    rate = high_rate_bg1_config()
    sample = awgn_llr_all_zero(
        rng=np.random.default_rng(7),
        z=384,
        rate_match=rate,
        ebn0_db=4.9,
    )
    assert np.all(sample.llr[0] == 0.0)
    assert np.all(sample.llr[1] == 0.0)
    assert np.any(sample.llr[2] != 0.0)


def test_all_zero_no_noise_convergence() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    llr = np.full((26, graph.Z), 20.0)
    llr[:2, :] = 0.0
    result = decode_float(
        graph,
        llr,
        beta=0.5,
        max_iterations=12,
        layer_order=(0, 2, 1, 3),
    )
    assert result.syndrome_passed
    assert result.iterations == 1
    assert not np.any(result.hard_bits)


def test_layer_order_determinism() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    rng = np.random.default_rng(99)
    llr = rng.normal(size=(26, graph.Z))
    llr[:2, :] = 0.0
    first = decode_float(graph, llr, beta=0.5, max_iterations=3, layer_order=(0, 2, 1, 3))
    second = decode_float(graph, llr, beta=0.5, max_iterations=3, layer_order=(0, 2, 1, 3))
    assert np.array_equal(first.hard_bits, second.hard_bits)
    assert np.allclose(first.app, second.app)


def test_syndrome_correctness() -> None:
    graph = load_3gpp_base_graph(2, 384, i_ls=1, active_layer_ids=(0,))
    hard = np.zeros((12, graph.Z), dtype=np.bool_)
    assert syndrome_passes(graph, hard)
    edge = graph.layers[0].edges[0]
    hard[edge.column, edge.shift] = True
    syndrome = compute_syndrome(graph, hard)
    assert np.count_nonzero(syndrome) == 1
    assert not syndrome_passes(graph, hard)


def test_repeatability_with_fixed_seeds() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    rate = high_rate_bg1_config()
    fmt = FixedPointFormat("D", 5, 8, 8, 6, channel_gain=1.0, beta_int=1)
    sample_a = awgn_llr_all_zero(
        rng=np.random.default_rng(1001),
        z=graph.Z,
        rate_match=rate,
        ebn0_db=4.9,
    )
    sample_b = awgn_llr_all_zero(
        rng=np.random.default_rng(1001),
        z=graph.Z,
        rate_match=rate,
        ebn0_db=4.9,
    )
    assert np.array_equal(sample_a.llr, sample_b.llr)
    q_a = quantize_channel_sample(sample_a, fmt)
    q_b = quantize_channel_sample(sample_b, fmt)
    first = decode_fixed(
        graph,
        q_a.values,
        fmt=fmt,
        max_iterations=3,
        layer_order=(0, 2, 1, 3),
        channel_saturation_count=q_a.channel_saturation_count,
    )
    second = decode_fixed(
        graph,
        q_b.values,
        fmt=fmt,
        max_iterations=3,
        layer_order=(0, 2, 1, 3),
        channel_saturation_count=q_b.channel_saturation_count,
    )
    assert np.array_equal(first.app, second.app)
    assert first.saturation == second.saturation
