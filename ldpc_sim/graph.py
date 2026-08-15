"""Base graph data structures."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class Edge:
    layer_id: int
    edge_id: int
    column: int
    shift: int


@dataclass(frozen=True)
class Layer:
    layer_id: int
    edges: tuple[Edge, ...]

    @property
    def degree(self) -> int:
        return len(self.edges)

    @property
    def columns(self) -> frozenset[int]:
        return frozenset(edge.column for edge in self.edges)

    def edge_by_column(self, column: int) -> Edge:
        for edge in self.edges:
            if edge.column == column:
                return edge
        raise KeyError(f"Layer {self.layer_id} does not contain column {column}.")


@dataclass(frozen=True)
class LDPCGraph:
    name: str
    layers: tuple[Layer, ...]
    Z: int
    is_synthetic: bool
    source_note: str
    base_graph: int | None = None
    i_ls: int | None = None
    source_path: str | None = None
    source_url: str | None = None
    source_commit: str | None = None

    def __post_init__(self) -> None:
        layer_ids = [layer.layer_id for layer in self.layers]
        if len(layer_ids) != len(set(layer_ids)):
            raise ValueError("Layer IDs must be unique.")
        for layer in self.layers:
            edge_ids = [edge.edge_id for edge in layer.edges]
            if len(edge_ids) != len(set(edge_ids)):
                raise ValueError(f"Layer {layer.layer_id} has duplicate edge IDs.")

    def layer(self, layer_id: int) -> Layer:
        for layer in self.layers:
            if layer.layer_id == layer_id:
                return layer
        raise KeyError(f"Unknown layer_id {layer_id}.")

    @property
    def layer_ids(self) -> tuple[int, ...]:
        return tuple(layer.layer_id for layer in self.layers)

    @property
    def columns(self) -> frozenset[int]:
        cols: set[int] = set()
        for layer in self.layers:
            cols.update(layer.columns)
        return frozenset(cols)

    def ordered_layers(self, order: Iterable[int] | None = None) -> tuple[Layer, ...]:
        if order is None:
            return self.layers
        return tuple(self.layer(layer_id) for layer_id in order)
