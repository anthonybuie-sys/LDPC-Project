from math import ceil

from config.benchmark_bg1_z384 import DEFAULT_CONFIG, DEFAULT_GRAPH
from ldpc_sim.scheduler import expected_pair_slots
from ldpc_sim.simulator import run_configured


def test_benchmark_pair_slot_sanity() -> None:
    assert expected_pair_slots(DEFAULT_GRAPH.layers, b=2) == 4 * ceil(19 / 2)


def test_benchmark_runs_and_beats_reference_on_fixture() -> None:
    result = run_configured(DEFAULT_GRAPH, DEFAULT_CONFIG)
    assert result.metrics.cycles_per_iteration < DEFAULT_CONFIG.ipctek_cycles_per_iteration
    assert result.metrics.ACC_issue_cycles == 40
    assert result.metrics.REC_issue_cycles == 40
    assert result.metrics.service_lower_bound == 50

