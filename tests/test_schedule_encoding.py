from __future__ import annotations

from config.architecture import ArchitectureConfig
from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.schedule_encoding import (
    INSTRUCTION_BITS,
    build_packed_program,
    decode_program,
)
from ldpc_sim.simulator import run_configured


def current_config(z: int) -> ArchitectureConfig:
    return ArchitectureConfig(
        Z=z,
        P=z,
        B=2,
        D_A=3,
        D_R=3,
        num_app_banks=8,
        forward_cache_depth=8,
        enable_layer_reorder=True,
        bank_strategy="optimized",
        pairing_strategy="optimized",
    )


def expected_aux(record: object) -> tuple[int, ...]:
    return tuple(
        (record.forward_slot_by_column[column] + 1)
        if column in record.forward_slot_by_column
        else 0
        for column in record.columns
    )


def assert_round_trip(base_graph: int, z: int, i_ls: int, active_layers: tuple[int, ...]) -> None:
    graph = load_3gpp_base_graph(base_graph, z, i_ls=i_ls, active_layer_ids=active_layers)
    result = run_configured(graph, current_config(z))
    program = build_packed_program(result)
    decoded_acc, decoded_rec = decode_program(program)

    assert len(program) == result.metrics.cycles_per_iteration
    assert len(decoded_acc) == result.metrics.ACC_issue_cycles
    assert len(decoded_rec) == result.metrics.REC_issue_cycles
    assert all(word.acc < (1 << INSTRUCTION_BITS) for word in program)
    assert all(word.rec < (1 << INSTRUCTION_BITS) for word in program)

    for record in result.acc_issues:
        decoded = decoded_acc[record.cycle]
        assert decoded.layer_id == record.layer_id
        assert decoded.edge_ids == record.edge_ids
        assert decoded.qbuf == record.qbuf
        assert decoded.qslot == record.qslot
        assert decoded.aux_values == expected_aux(record)

    for record in result.rec_issues:
        decoded = decoded_rec[record.cycle]
        assert decoded.layer_id == record.layer_id
        assert decoded.edge_ids == record.edge_ids
        assert decoded.qbuf == record.qbuf
        assert decoded.qslot == record.qslot
        assert decoded.aux_values == expected_aux(record)


def test_bg1_z384_first4_packed_schedule_round_trips() -> None:
    assert_round_trip(1, 384, 1, (0, 1, 2, 3))


def test_bg2_z384_single_layer_packed_schedule_round_trips() -> None:
    assert_round_trip(2, 384, 1, (0,))
