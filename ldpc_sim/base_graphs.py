"""Base graph loading and reduced fixtures.

Actual 3GPP base graph data should be added here as explicit tables or parsed
from checked-in reference files. The included four-layer fixture is synthetic
and exists only to validate scheduling mechanics.
"""

from __future__ import annotations

from pathlib import Path

from ldpc_sim.graph import Edge, LDPCGraph, Layer

REPO_ROOT = Path(__file__).resolve().parents[1]
BASE_GRAPH_DATA_ROOT = REPO_ROOT / "data" / "NR-LDPC-BG"
BASE_GRAPH_SOURCE_URL = "https://github.com/manuts/NR-LDPC-BG"

SYNTHETIC_FIXTURE_NOTE = (
    "TEST FIXTURE ONLY - NOT 3GPP BASE GRAPH DATA. "
    "The fixture preserves four 19-edge active layers for architecture "
    "scheduler validation only."
)


def _make_layer(layer_id: int, columns: list[int], z: int) -> Layer:
    edges = tuple(
        Edge(
            layer_id=layer_id,
            edge_id=edge_id,
            column=column,
            shift=((layer_id + 1) * 17 + edge_id * 29) % z,
        )
        for edge_id, column in enumerate(columns)
    )
    return Layer(layer_id=layer_id, edges=edges)


def load_bg1_z384_four_layer_fixture() -> LDPCGraph:
    """Return the required 4x19-edge synthetic benchmark fixture."""

    z = 384
    columns_by_layer = [
        list(range(0, 19)),
        list(range(8, 27)),
        list(range(16, 35)),
        list(range(4, 13)) + list(range(27, 37)),
    ]
    layers = tuple(
        _make_layer(layer_id, columns, z)
        for layer_id, columns in enumerate(columns_by_layer)
    )
    return LDPCGraph(
        name="BG1_Z384_four_layer_synthetic_fixture",
        layers=layers,
        Z=z,
        is_synthetic=True,
        source_note=SYNTHETIC_FIXTURE_NOTE,
        base_graph=1,
        i_ls=None,
    )


def _base_graph_shape(base_graph: int) -> tuple[int, int]:
    if base_graph == 1:
        return 46, 68
    if base_graph == 2:
        return 42, 52
    raise ValueError("base_graph must be 1 or 2.")


def _read_source_commit(data_root: Path = BASE_GRAPH_DATA_ROOT) -> str | None:
    commit_file = data_root / "SOURCE_COMMIT.txt"
    if commit_file.exists():
        text = commit_file.read_text(encoding="utf-8").strip()
        if text:
            return text

    git_dir = data_root / ".git"
    head = git_dir / "HEAD"
    if not head.exists():
        return None
    text = head.read_text(encoding="utf-8").strip()
    if text.startswith("ref: "):
        ref_path = git_dir / text.removeprefix("ref: ").strip()
        if ref_path.exists():
            return ref_path.read_text(encoding="utf-8").strip()
        packed_refs = git_dir / "packed-refs"
        if packed_refs.exists():
            ref_name = text.removeprefix("ref: ").strip()
            for line in packed_refs.read_text(encoding="utf-8").splitlines():
                if line.startswith("#") or not line.strip():
                    continue
                commit, _, ref = line.partition(" ")
                if ref == ref_name:
                    return commit
        return None
    return text or None


def _resolve_base_graph_file(
    base_graph: int,
    z: int,
    i_ls: int | None,
    data_root: Path = BASE_GRAPH_DATA_ROOT,
) -> tuple[Path, int]:
    if i_ls is not None:
        path = data_root / f"NR_{base_graph}_{i_ls}_{z}.txt"
        if not path.exists():
            raise FileNotFoundError(f"Missing base-graph matrix file: {path}")
        return path, i_ls

    matches = sorted(data_root.glob(f"NR_{base_graph}_*_{z}.txt"))
    if not matches:
        raise FileNotFoundError(
            f"No base-graph matrix file for BG{base_graph}, Z={z} under {data_root}."
        )
    if len(matches) > 1:
        raise ValueError(
            f"Ambiguous lifting-set index for BG{base_graph}, Z={z}: "
            f"{[path.name for path in matches]}"
        )
    parts = matches[0].stem.split("_")
    return matches[0], int(parts[2])


def _parse_matrix_file(path: Path, rows: int, cols: int) -> list[list[int]]:
    values = [int(token) for token in path.read_text(encoding="utf-8").split()]
    expected = rows * cols
    if len(values) != expected:
        raise ValueError(
            f"{path} contains {len(values)} entries; expected {expected} "
            f"for a {rows}x{cols} matrix."
        )
    return [values[row * cols : (row + 1) * cols] for row in range(rows)]


def load_3gpp_base_graph(
    base_graph: int,
    z: int,
    i_ls: int | None = None,
    active_layer_ids: tuple[int, ...] | None = None,
    data_root: Path = BASE_GRAPH_DATA_ROOT,
) -> LDPCGraph:
    """Load a BG1/BG2 shifted base matrix from checked traceable table files."""

    rows, cols = _base_graph_shape(base_graph)
    path, resolved_i_ls = _resolve_base_graph_file(base_graph, z, i_ls, data_root)
    matrix = _parse_matrix_file(path, rows, cols)
    selected_rows = active_layer_ids if active_layer_ids is not None else tuple(range(rows))
    layers: list[Layer] = []
    for layer_id in selected_rows:
        row = matrix[layer_id]
        edges = tuple(
            Edge(layer_id=layer_id, edge_id=edge_id, column=column, shift=shift)
            for edge_id, (column, shift) in enumerate(
                (column, shift) for column, shift in enumerate(row) if shift != -1
            )
        )
        layers.append(Layer(layer_id=layer_id, edges=edges))

    commit = _read_source_commit(data_root)
    commit_text = f" commit {commit}" if commit else ""
    note = (
        f"ACTUAL 5G NR BG{base_graph} DATA from {BASE_GRAPH_SOURCE_URL}"
        f"{commit_text}; file {path.name}; iLS={resolved_i_ls}; Z={z}."
    )
    return LDPCGraph(
        name=f"BG{base_graph}_Z{z}_iLS{resolved_i_ls}",
        layers=tuple(layers),
        Z=z,
        is_synthetic=False,
        source_note=note,
        base_graph=base_graph,
        i_ls=resolved_i_ls,
        source_path=str(path),
        source_url=BASE_GRAPH_SOURCE_URL,
        source_commit=commit,
    )


def load_bg1_z384_four_layer_actual() -> LDPCGraph:
    return load_3gpp_base_graph(
        base_graph=1,
        z=384,
        i_ls=1,
        active_layer_ids=(0, 1, 2, 3),
    )
