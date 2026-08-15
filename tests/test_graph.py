from ldpc_sim.base_graphs import (
    load_3gpp_base_graph,
    load_bg1_z384_four_layer_actual,
    load_bg1_z384_four_layer_fixture,
)


def test_fixture_has_four_19_edge_layers() -> None:
    graph = load_bg1_z384_four_layer_fixture()
    assert graph.is_synthetic
    assert len(graph.layers) == 4
    assert [layer.degree for layer in graph.layers] == [19, 19, 19, 19]
    assert "TEST FIXTURE ONLY" in graph.source_note


def test_actual_bg1_z384_four_layer_graph_loads_from_traceable_source() -> None:
    graph = load_bg1_z384_four_layer_actual()
    assert not graph.is_synthetic
    assert graph.base_graph == 1
    assert graph.i_ls == 1
    assert graph.Z == 384
    assert [layer.degree for layer in graph.layers] == [19, 19, 19, 19]
    assert graph.layers[0].edges[0].column == 0
    assert graph.layers[0].edges[0].shift == 307
    assert "ACTUAL 5G NR BG1 DATA" in graph.source_note
    assert graph.source_commit


def test_actual_bg2_z384_graph_loads() -> None:
    graph = load_3gpp_base_graph(2, 384, i_ls=1, active_layer_ids=(0,))
    assert not graph.is_synthetic
    assert graph.base_graph == 2
    assert graph.i_ls == 1
    assert len(graph.layers) == 1
