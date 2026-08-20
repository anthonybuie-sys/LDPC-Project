from __future__ import annotations

import numpy as np

from ldpc_sim.numerical_decoder import (
    compute_syndrome,
    rotate_from_check,
    rotate_to_check,
)
from ldpc_sim.qc_direction import (
    checked_in_matrix_profiles,
    deterministic_hard_vectors,
    deterministic_identity_vectors,
    load_profile,
    scalar_rotate_to_check,
    scalar_syndrome,
    used_shifts,
)


def test_s1_one_hot_direction_uses_scalar_expected() -> None:
    z = 8
    shift = 1
    source_index = 3
    canonical = np.zeros(z, dtype=np.int64)
    canonical[source_index] = 7
    expected = np.zeros(z, dtype=np.int64)
    expected[(source_index - shift) % z] = 7

    assert np.array_equal(rotate_to_check(canonical, shift), expected)
    assert np.array_equal(scalar_rotate_to_check(canonical, shift), expected)


def test_z_minus_one_one_hot_wraparound_uses_scalar_expected() -> None:
    z = 8
    shift = z - 1
    source_index = 0
    canonical = np.zeros(z, dtype=np.int64)
    canonical[source_index] = 11
    expected = np.zeros(z, dtype=np.int64)
    expected[(source_index - shift) % z] = 11

    assert np.array_equal(rotate_to_check(canonical, shift), expected)
    assert np.array_equal(scalar_rotate_to_check(canonical, shift), expected)


def test_forward_inverse_identity_for_all_checked_in_bg_shifts() -> None:
    profiles = checked_in_matrix_profiles()
    assert profiles
    checked_pairs = 0

    for profile in profiles:
        graph = load_profile(profile)
        for shift in used_shifts(graph):
            seed = profile.base_graph * 1_000_000 + profile.i_ls * 10_000 + profile.z + shift
            for _, vector in deterministic_identity_vectors(profile.z, seed):
                check = rotate_to_check(vector, shift)
                canonical = rotate_from_check(check, shift)
                assert np.array_equal(canonical, vector)
            checked_pairs += 1

    assert checked_pairs > 0


def test_independent_scalar_syndrome_matches_numerical_syndrome_actual_graphs() -> None:
    profiles = checked_in_matrix_profiles()
    assert profiles
    checked_vectors = 0

    for profile in profiles:
        graph = load_profile(profile)
        assert graph.is_synthetic is False
        seed = profile.base_graph * 1_000_000 + profile.i_ls * 10_000 + profile.z
        for _, hard_bits in deterministic_hard_vectors(graph, seed):
            expected = scalar_syndrome(graph, hard_bits)
            actual = compute_syndrome(graph, hard_bits)
            assert np.array_equal(actual, expected)
            checked_vectors += 1

    assert checked_vectors == len(profiles) * 3
