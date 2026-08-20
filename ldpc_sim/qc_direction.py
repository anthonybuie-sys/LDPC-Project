"""Independent QC permutation checks for the frozen Python convention."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re

import numpy as np

from ldpc_sim.base_graphs import BASE_GRAPH_DATA_ROOT, load_3gpp_base_graph
from ldpc_sim.graph import LDPCGraph


MATRIX_NAME_RE = re.compile(r"^NR_(?P<bg>[12])_(?P<ils>\d+)_(?P<z>\d+)\.txt$")


@dataclass(frozen=True)
class MatrixProfile:
    base_graph: int
    i_ls: int
    z: int
    path: Path

    @property
    def identity(self) -> str:
        return f"BG{self.base_graph}_iLS{self.i_ls}_Z{self.z}"


def checked_in_matrix_profiles(
    data_root: Path = BASE_GRAPH_DATA_ROOT,
) -> tuple[MatrixProfile, ...]:
    """Return every checked-in BG1/BG2 matrix profile."""

    profiles: list[MatrixProfile] = []
    for path in sorted(data_root.glob("NR_*.txt")):
        match = MATRIX_NAME_RE.match(path.name)
        if not match:
            continue
        profiles.append(
            MatrixProfile(
                base_graph=int(match.group("bg")),
                i_ls=int(match.group("ils")),
                z=int(match.group("z")),
                path=path,
            )
        )
    return tuple(profiles)


def scalar_rotate_to_check(values: np.ndarray, shift: int) -> np.ndarray:
    """Reference forward QC mapping: check[k] = canonical[(k+s) mod Z]."""

    vector = np.asarray(values)
    z = int(vector.shape[0])
    s = int(shift) % z
    out = np.empty_like(vector)
    for k in range(z):
        out[k] = vector[(k + s) % z]
    return out


def scalar_rotate_from_check(values: np.ndarray, shift: int) -> np.ndarray:
    """Reference inverse QC mapping: canonical[k] = check[(k-s) mod Z]."""

    vector = np.asarray(values)
    z = int(vector.shape[0])
    s = int(shift) % z
    out = np.empty_like(vector)
    for k in range(z):
        out[k] = vector[(k - s) % z]
    return out


def scalar_syndrome(graph: LDPCGraph, hard_bits: np.ndarray) -> np.ndarray:
    """Independent syndrome reference that does not call rotate_to_check()."""

    hard = np.asarray(hard_bits, dtype=np.bool_)
    rows: list[np.ndarray] = []
    for layer in graph.layers:
        syndrome = np.zeros(graph.Z, dtype=np.bool_)
        for edge in layer.edges:
            for k in range(graph.Z):
                syndrome[k] ^= bool(hard[edge.column, (k + edge.shift) % graph.Z])
        rows.append(syndrome)
    if not rows:
        return np.zeros((0, graph.Z), dtype=np.bool_)
    return np.stack(rows, axis=0)


def used_shifts(graph: LDPCGraph) -> tuple[int, ...]:
    shifts = {edge.shift for layer in graph.layers for edge in layer.edges}
    return tuple(sorted(shifts))


def deterministic_identity_vectors(z: int, seed: int) -> tuple[tuple[str, np.ndarray], ...]:
    rng = np.random.default_rng(seed)
    hot0 = np.zeros(z, dtype=np.int64)
    hot0[0] = 1
    hot_mid = np.zeros(z, dtype=np.int64)
    hot_mid[(z * 2 + 1) // 3] = -3
    random = rng.integers(-31, 32, size=z, dtype=np.int64)
    return (("one_hot_0", hot0), ("one_hot_mid", hot_mid), ("random", random))


def deterministic_hard_vectors(
    graph: LDPCGraph,
    seed: int,
) -> tuple[tuple[str, np.ndarray], ...]:
    n_cols = max(graph.columns) + 1 if graph.columns else 0
    zeros = np.zeros((n_cols, graph.Z), dtype=np.bool_)
    one_hot = zeros.copy()
    if n_cols:
        one_hot[min(graph.columns), 0] = True
    rng = np.random.default_rng(seed)
    random = rng.integers(0, 2, size=(n_cols, graph.Z), dtype=np.int8).astype(np.bool_)
    return (("all_zero", zeros), ("one_hot", one_hot), ("random", random))


def load_profile(profile: MatrixProfile) -> LDPCGraph:
    return load_3gpp_base_graph(
        profile.base_graph,
        profile.z,
        i_ls=profile.i_ls,
        active_layer_ids=None,
    )
