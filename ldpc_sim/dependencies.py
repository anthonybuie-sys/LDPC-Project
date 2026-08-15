"""Layer dependency analysis."""

from __future__ import annotations

from ldpc_sim.graph import Layer
from ldpc_sim.pairing import EdgePair


def layer_overlap(a: Layer, b: Layer) -> frozenset[int]:
    return a.columns.intersection(b.columns)


def overlap_matrix(layers: tuple[Layer, ...]) -> dict[tuple[int, int], frozenset[int]]:
    overlaps: dict[tuple[int, int], frozenset[int]] = {}
    for left in layers:
        for right in layers:
            if left.layer_id == right.layer_id:
                continue
            overlaps[(left.layer_id, right.layer_id)] = layer_overlap(left, right)
    return overlaps


def overlap_count_matrix(layers: tuple[Layer, ...]) -> list[list[int]]:
    return [
        [len(left.columns.intersection(right.columns)) for right in layers]
        for left in layers
    ]


def independent_transition_capacity(
    producer_layer: Layer,
    consumer_layer: Layer,
    consumer_pairs: tuple[EdgePair, ...],
) -> dict[str, int]:
    dependent_columns = producer_layer.columns.intersection(consumer_layer.columns)
    independent_edges = [
        edge for edge in consumer_layer.edges if edge.column not in producer_layer.columns
    ]
    fully_independent_pairs = [
        pair
        for pair in consumer_pairs
        if all(column not in producer_layer.columns for column in pair.columns)
    ]
    partially_independent_pairs = [
        pair
        for pair in consumer_pairs
        if any(column not in producer_layer.columns for column in pair.columns)
        and not all(column not in producer_layer.columns for column in pair.columns)
    ]
    return {
        "from_layer": producer_layer.layer_id,
        "to_layer": consumer_layer.layer_id,
        "overlap": len(dependent_columns),
        "independent_edges": len(independent_edges),
        "dependent_edges": len(dependent_columns),
        "fully_independent_pairs": len(fully_independent_pairs),
        "partially_independent_pairs": len(partially_independent_pairs),
        "total_pairs": len(consumer_pairs),
    }


def latest_prior_producer(
    ordered_layers: tuple[Layer, ...], layer_position: int, column: int
) -> int | None:
    for pos in range(layer_position - 1, -1, -1):
        if column in ordered_layers[pos].columns:
            return pos
    return None


def next_consumer(
    ordered_layers: tuple[Layer, ...], producer_position: int, column: int
) -> int | None:
    for pos in range(producer_position + 1, len(ordered_layers)):
        if column in ordered_layers[pos].columns:
            return pos
    return None


def lookahead_safe(edge_column: int, unfinished_previous_layer: Layer) -> bool:
    return edge_column not in unfinished_previous_layer.columns
