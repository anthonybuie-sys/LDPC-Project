from __future__ import annotations

import csv
import inspect
from pathlib import Path

from config.benchmark_bg1_z384 import DEFAULT_CONFIG, DEFAULT_GRAPH
from ldpc_sim import simulator
from ldpc_sim.simulator import (
    PIPELINE_SWEEP_DEPTHS,
    pipeline_depth_sweep,
    write_pipeline_depth_sweep_csv,
)

_ROWS: list[dict[str, object]] | None = None


def rows() -> list[dict[str, object]]:
    global _ROWS
    if _ROWS is None:
        _ROWS = pipeline_depth_sweep(DEFAULT_GRAPH, DEFAULT_CONFIG)
    return _ROWS


def row_for(d_a: int, d_r: int) -> dict[str, object]:
    for row in rows():
        if row["D_A"] == d_a and row["D_R"] == d_r:
            return row
    raise AssertionError(f"Missing sweep point {(d_a, d_r)}")


def test_real_bg1_pipeline_sweep_executes_all_25_points() -> None:
    result_rows = rows()
    assert len(result_rows) == 25
    assert {
        (row["D_A"], row["D_R"]) for row in result_rows
    } == {
        (d_a, d_r)
        for d_a in PIPELINE_SWEEP_DEPTHS
        for d_r in PIPELINE_SWEEP_DEPTHS
    }


def test_real_bg1_pipeline_sweep_is_deterministic() -> None:
    first = [
        (row["D_A"], row["D_R"], row["cycles_per_iteration"], row["best_layer_order"])
        for row in rows()
    ]
    second_rows = pipeline_depth_sweep(DEFAULT_GRAPH, DEFAULT_CONFIG)
    second = [
        (row["D_A"], row["D_R"], row["cycles_per_iteration"], row["best_layer_order"])
        for row in second_rows
    ]
    assert first == second


def test_pipeline_sweep_current_reference_is_reproduced() -> None:
    reference = row_for(4, 4)
    assert reference["cycles_per_iteration"] == 78
    assert reference["max_live_forward_vectors"] <= 8


def test_pipeline_sweep_csv_contains_all_25_entries() -> None:
    output_path = Path("results/pipeline_depth_sweep_real_bg1.csv")
    write_pipeline_depth_sweep_csv(rows(), output_path)
    with output_path.open(newline="", encoding="utf-8") as handle:
        csv_rows = list(csv.DictReader(handle))
    assert len(csv_rows) == 25
    assert {row["D_A"] for row in csv_rows} == {"2", "3", "4", "5", "6"}
    assert {row["D_R"] for row in csv_rows} == {"2", "3", "4", "5", "6"}


def test_pipeline_sweep_uses_real_bg1_data() -> None:
    assert DEFAULT_GRAPH.is_synthetic is False
    assert all(row["graph_is_synthetic"] is False for row in rows())
    assert all("ACTUAL 5G NR BG1 DATA" in str(row["graph_source_note"]) for row in rows())


def test_pipeline_sweep_invariant_checks_remain_enabled() -> None:
    source = inspect.getsource(simulator.simulate_iteration)
    assert "assert_edge_coverage" in source
    assert "assert_context_limit" in source
    assert "assert_all_stalls_classified" in source
