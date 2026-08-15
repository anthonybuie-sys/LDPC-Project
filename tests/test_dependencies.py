from ldpc_sim.base_graphs import load_bg1_z384_four_layer_fixture
from ldpc_sim.banking import modulo_bank_map
from ldpc_sim.dependencies import (
    independent_transition_capacity,
    latest_prior_producer,
    layer_overlap,
    lookahead_safe,
    overlap_count_matrix,
)
from ldpc_sim.pairing import sequential_pairing


def test_layer_overlap_detection() -> None:
    graph = load_bg1_z384_four_layer_fixture()
    assert layer_overlap(graph.layers[0], graph.layers[1]) == frozenset(range(8, 19))


def test_overlap_count_matrix() -> None:
    graph = load_bg1_z384_four_layer_fixture()
    matrix = overlap_count_matrix(graph.layers)
    assert matrix[0][0] == 19
    assert matrix[0][1] == 11


def test_independent_transition_capacity() -> None:
    graph = load_bg1_z384_four_layer_fixture()
    bank_map = modulo_bank_map(graph, 8)
    pairs = sequential_pairing(graph.layers[1])
    row = independent_transition_capacity(graph.layers[0], graph.layers[1], pairs)
    assert row["overlap"] == 11
    assert row["independent_edges"] == 8
    assert row["total_pairs"] == 10


def test_latest_prior_producer() -> None:
    graph = load_bg1_z384_four_layer_fixture()
    layers = graph.ordered_layers((0, 1, 2, 3))
    assert latest_prior_producer(layers, 2, 16) == 1
    assert latest_prior_producer(layers, 2, 40) is None


def test_lookahead_rule_blocks_previous_layer_columns() -> None:
    graph = load_bg1_z384_four_layer_fixture()
    previous = graph.layers[0]
    assert not lookahead_safe(8, previous)
    assert lookahead_safe(30, previous)
