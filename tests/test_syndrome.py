from __future__ import annotations

from config.architecture import ArchitectureConfig
from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.schedule_encoding import build_packed_program, decode_program
from ldpc_sim.simulator import run_configured
from ldpc_sim.syndrome import analyze_final_touches, simulate_syndrome_engine


PROFILE_CASES = (
    (1, 384, 1, (0, 1, 2, 3), "BG1_first4_high_rate"),
    (1, 384, 1, None, "BG1_full"),
    (2, 384, 1, (0,), "BG2_single0"),
    (2, 384, 1, None, "BG2_full"),
)
Q_VALUES = (2, 4, 8, 16)


def current_config() -> ArchitectureConfig:
    return ArchitectureConfig(
        Z=384,
        P=384,
        B=2,
        D_A=3,
        D_R=3,
        num_app_banks=8,
        forward_cache_depth=8,
        enable_lookahead=True,
        enable_forwarding=True,
        enable_jit_forwarding=True,
        enable_reconstruction_reorder=True,
        enable_layer_reorder=True,
        bank_strategy="optimized",
        pairing_strategy="optimized",
        max_cycles=20000,
    )


def build_profile(base_graph: int, z: int, i_ls: int, active_layer_ids):
    cfg = current_config()
    graph = load_3gpp_base_graph(
        base_graph,
        z,
        i_ls=i_ls,
        active_layer_ids=active_layer_ids,
    )
    result = run_configured(graph, cfg)
    final_touch = analyze_final_touches(graph, result, cfg)
    return graph, result, final_touch


def test_bg1_first4_final_touches_cover_every_active_column_once() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    cfg = current_config()
    result = run_configured(graph, cfg)
    final_touch = analyze_final_touches(graph, result, cfg)

    assert set(final_touch.final_by_column) == set(graph.columns)
    assert len(final_touch.final_by_column) == len(graph.columns)
    assert final_touch.total_work_items == result.metrics.active_edges
    assert final_touch.first_final_cycle >= cfg.D_R
    assert final_touch.last_final_cycle <= result.metrics.cycles_per_iteration


def test_all_supported_profiles_finalize_active_columns_once() -> None:
    for base_graph, z, i_ls, active_layer_ids, _ in PROFILE_CASES:
        graph, result, final_touch = build_profile(base_graph, z, i_ls, active_layer_ids)

        assert set(final_touch.final_by_column) == set(graph.columns)
        assert len(final_touch.final_by_column) == len(graph.columns)
        assert final_touch.total_work_items == result.metrics.active_edges


def test_syndrome_engine_consumes_every_active_qc_edge_once() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    cfg = current_config()
    result = run_configured(graph, cfg)
    final_touch = analyze_final_touches(graph, result, cfg)
    run = simulate_syndrome_engine(
        profile="BG1_first4_high_rate",
        decoder_cycles_per_iteration=result.metrics.cycles_per_iteration,
        final_touch=final_touch,
        S=4,
        queue_depth=8,
    )

    assert run.valid is True
    assert run.total_work_items == result.metrics.active_edges
    assert run.syndrome_completion_cycle >= final_touch.last_final_cycle
    assert run.effective_iteration_boundary >= result.metrics.cycles_per_iteration


def test_s8_queue_depth_sweep_executes_and_detects_overflow() -> None:
    executed: list[tuple[str, int]] = []
    for base_graph, z, i_ls, active_layer_ids, profile in PROFILE_CASES:
        _, result, final_touch = build_profile(base_graph, z, i_ls, active_layer_ids)
        for q in Q_VALUES:
            run = simulate_syndrome_engine(
                profile=profile,
                decoder_cycles_per_iteration=result.metrics.cycles_per_iteration,
                final_touch=final_touch,
                S=8,
                queue_depth=q,
            )
            executed.append((profile, q))
            assert run.valid == (run.max_finalized_queue_occupancy <= q)
            if run.valid:
                assert run.max_finalized_queue_occupancy <= run.queue_depth
            else:
                assert run.max_finalized_queue_occupancy > run.queue_depth

    assert len(executed) == len(PROFILE_CASES) * len(Q_VALUES)
    assert {q for _, q in executed} == set(Q_VALUES)


def test_s8_high_rate_bg1_expected_behavior() -> None:
    _, result, final_touch = build_profile(1, 384, 1, (0, 1, 2, 3))
    run = simulate_syndrome_engine(
        profile="BG1_first4_high_rate",
        decoder_cycles_per_iteration=result.metrics.cycles_per_iteration,
        final_touch=final_touch,
        S=8,
        queue_depth=2,
    )

    assert run.valid is True
    assert run.total_work_items == 76
    assert run.first_final_cycle == 50
    assert run.last_final_cycle == 70
    assert run.max_syndrome_backlog == 7
    assert run.max_finalized_queue_occupancy == 2
    assert run.syndrome_completion_cycle == 71
    assert run.additional_tail_cycles == 1
    assert abs(run.syndrome_engine_utilization - (76 / (8 * 21))) < 1e-12


def test_s8_bg1_full_q4_overflows() -> None:
    _, result, final_touch = build_profile(1, 384, 1, None)
    run = simulate_syndrome_engine(
        profile="BG1_full",
        decoder_cycles_per_iteration=result.metrics.cycles_per_iteration,
        final_touch=final_touch,
        S=8,
        queue_depth=4,
    )

    assert run.valid is False
    assert run.max_finalized_queue_occupancy == 8
    assert run.required_queue_depth == 8
    assert run.max_finalized_queue_occupancy_cycle >= run.first_final_cycle


def test_s8_syndrome_results_are_deterministic() -> None:
    _, result, final_touch = build_profile(2, 384, 1, None)
    first = simulate_syndrome_engine(
        profile="BG2_full",
        decoder_cycles_per_iteration=result.metrics.cycles_per_iteration,
        final_touch=final_touch,
        S=8,
        queue_depth=4,
    )
    second = simulate_syndrome_engine(
        profile="BG2_full",
        decoder_cycles_per_iteration=result.metrics.cycles_per_iteration,
        final_touch=final_touch,
        S=8,
        queue_depth=4,
    )

    assert first == second


def test_rec_packed_final_touch_flags_round_trip() -> None:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    cfg = current_config()
    result = run_configured(graph, cfg)
    final_touch = analyze_final_touches(graph, result, cfg)
    program = build_packed_program(
        result,
        rec_final_touch_by_cycle=final_touch.final_touch_by_rec_cycle,
    )
    _, decoded_rec = decode_program(program)

    flagged_columns: set[int] = set()
    for record in result.rec_issues:
        decoded = decoded_rec[record.cycle]
        expected = tuple(
            1 if final_touch.final_touch_by_rec_cycle[record.cycle].get(column, False) else 0
            for column in record.columns
        )
        assert decoded.final_touch_values == expected
        for column, flag in zip(record.columns, decoded.final_touch_values):
            if flag:
                assert column not in flagged_columns
                flagged_columns.add(column)
    assert flagged_columns == set(graph.columns)
