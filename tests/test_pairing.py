from ldpc_sim.banking import modulo_bank_map
from ldpc_sim.graph import Edge, LDPCGraph, Layer
from ldpc_sim.pairing import optimized_pairing, sequential_pairing


def test_19_edges_require_10_pair_slots() -> None:
    layer = Layer(0, tuple(Edge(0, i, i, 0) for i in range(19)))
    assert len(sequential_pairing(layer)) == 10


def test_optimized_pairing_can_outperform_naive_bank_pairing() -> None:
    layer = Layer(
        0,
        (
            Edge(0, 0, 0, 0),
            Edge(0, 1, 2, 0),
            Edge(0, 2, 1, 0),
            Edge(0, 3, 3, 0),
        ),
    )
    graph = LDPCGraph("constructed", (layer,), 8, True, "constructed")
    bank_map = modulo_bank_map(graph, 2)
    naive_conflicts = sum(
        1 for pair in sequential_pairing(layer) if bank_map.has_conflict(list(pair.columns))
    )
    opt_conflicts = sum(
        1 for pair in optimized_pairing(layer, bank_map) if bank_map.has_conflict(list(pair.columns))
    )
    assert naive_conflicts == 2
    assert opt_conflicts == 0
