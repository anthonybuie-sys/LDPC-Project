"""B=2 edge pairing."""

from __future__ import annotations

from dataclasses import dataclass
from itertools import combinations

from ldpc_sim.banking import BankMap
from ldpc_sim.graph import Edge, Layer


@dataclass(frozen=True)
class EdgePair:
    layer_id: int
    pair_id: int
    edges: tuple[Edge, ...]

    @property
    def columns(self) -> tuple[int, ...]:
        return tuple(edge.column for edge in self.edges)

    @property
    def lane_count(self) -> int:
        return len(self.edges)

    def banks(self, bank_map: BankMap, forwarded_columns: set[int] | None = None) -> tuple[int, ...]:
        forwarded_columns = forwarded_columns or set()
        return tuple(
            bank_map.bank(column)
            for column in self.columns
            if column not in forwarded_columns
        )


def sequential_pairing(layer: Layer) -> tuple[EdgePair, ...]:
    pairs: list[EdgePair] = []
    for pair_id, start in enumerate(range(0, len(layer.edges), 2)):
        pairs.append(
            EdgePair(
                layer_id=layer.layer_id,
                pair_id=pair_id,
                edges=tuple(layer.edges[start : start + 2]),
            )
        )
    return tuple(pairs)


def optimized_pairing(
    layer: Layer,
    bank_map: BankMap,
    previous_columns: set[int] | frozenset[int] | None = None,
) -> tuple[EdgePair, ...]:
    previous_columns = previous_columns or set()
    remaining = list(layer.edges)
    pairs: list[EdgePair] = []

    def pair_score(a: Edge, b: Edge) -> tuple[int, int, int, int]:
        a_independent = a.column not in previous_columns
        b_independent = b.column not in previous_columns
        bank_compatible = bank_map.bank(a.column) != bank_map.bank(b.column)
        both_independent = a_independent and b_independent
        both_dependent = (not a_independent) and (not b_independent)
        return (
            1000 if bank_compatible else -1000,
            400 if both_independent else 150 if both_dependent else 0,
            -abs(a.edge_id - b.edge_id),
            -(a.edge_id + b.edge_id),
        )

    while len(remaining) >= 2:
        best = max(combinations(remaining, 2), key=lambda item: pair_score(*item))
        edges = tuple(sorted(best, key=lambda edge: edge.edge_id))
        pairs.append(
            EdgePair(layer_id=layer.layer_id, pair_id=len(pairs), edges=edges)
        )
        for edge in edges:
            remaining.remove(edge)

    if remaining:
        pairs.append(
            EdgePair(
                layer_id=layer.layer_id,
                pair_id=len(pairs),
                edges=(remaining[0],),
            )
        )
    return tuple(pairs)


def build_pair_schedule(
    ordered_layers: tuple[Layer, ...],
    bank_map: BankMap,
    strategy: str,
) -> dict[int, tuple[EdgePair, ...]]:
    schedules: dict[int, tuple[EdgePair, ...]] = {}
    for position, layer in enumerate(ordered_layers):
        previous_columns = (
            ordered_layers[position - 1].columns if position > 0 else frozenset()
        )
        if strategy == "sequential":
            schedules[position] = sequential_pairing(layer)
        elif strategy == "optimized":
            schedules[position] = optimized_pairing(layer, bank_map, previous_columns)
        else:
            raise ValueError(f"Unknown pairing strategy: {strategy}")
    return schedules

