from config.benchmark_bg1_z384 import DEFAULT_CONFIG, DEFAULT_GRAPH
from ldpc_sim.banking import modulo_bank_map, optimized_bank_map
from ldpc_sim.base_graphs import load_bg1_z384_four_layer_fixture
from ldpc_sim.simulator import bank_sweep


def test_modulo_bank_mapping() -> None:
    graph = load_bg1_z384_four_layer_fixture()
    bank_map = modulo_bank_map(graph, 8)
    assert bank_map.bank(10) == 2


def test_optimized_bank_mapping_maps_every_fixture_column() -> None:
    graph = load_bg1_z384_four_layer_fixture()
    bank_map = optimized_bank_map(graph, 8)
    assert graph.columns == frozenset(bank_map.mapping)


def test_bank_sweep_reports_unschedulable_cases() -> None:
    rows = bank_sweep(DEFAULT_GRAPH, DEFAULT_CONFIG)
    assert any(row["status"].startswith("UNSCHEDULABLE") for row in rows)
    assert any(
        row["num_app_banks"] == 8
        and row["strategy"] == "optimized"
        and row["status"] == "OK"
        for row in rows
    )
