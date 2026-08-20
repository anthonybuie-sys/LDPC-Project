from __future__ import annotations

from config.architecture import ArchitectureConfig
from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.production_v1 import (
    PRODUCTION_V1,
    production_architecture_config,
    validate_production_architecture_config,
)
from ldpc_sim.simulator import simulate_iteration
from ldpc_sim.syndrome import analyze_final_touches, simulate_syndrome_engine


def test_production_v1_config_encodes_frozen_category_a_values() -> None:
    cfg = PRODUCTION_V1

    assert cfg.P == 384
    assert cfg.B == 2
    assert cfg.D_A == 3
    assert cfg.D_R == 3
    assert cfg.num_app_banks == 8
    assert cfg.forward_cache_depth == 8
    assert cfg.num_acc_contexts == 2
    assert cfg.syndrome_S == 8
    assert cfg.syndrome_Q == 8
    assert cfg.fixed_point_format().w_ch == 6
    assert cfg.fixed_point_format().w_app == 8
    assert cfg.fixed_point_format().w_q == 8
    assert cfg.fixed_point_format().w_m == 6
    assert cfg.channel_gain == 1.32
    assert cfg.ch_to_app_shift == 1
    assert cfg.beta_int == 1
    assert cfg.saturation_rule == "asymmetric_twos_complement"
    assert cfg.reference_layer_order == (1, 3, 2, 0)
    assert cfg.iteration_policy == "non_speculative"


def test_production_tooling_rejects_historical_architecture_defaults() -> None:
    try:
        validate_production_architecture_config(ArchitectureConfig())
    except ValueError as exc:
        assert "historical ArchitectureConfig defaults" in str(exc)
    else:
        raise AssertionError("Historical ArchitectureConfig defaults were accepted.")


def test_production_architecture_config_matches_reference_schedule_metrics() -> None:
    prod = PRODUCTION_V1
    graph = load_3gpp_base_graph(
        prod.reference_BG,
        prod.reference_Z,
        i_ls=prod.reference_iLS,
        active_layer_ids=prod.reference_active_layers,
    )
    cfg = production_architecture_config(prod)
    result = simulate_iteration(graph, cfg, layer_order=prod.reference_layer_order)
    final_touch = analyze_final_touches(graph, result, cfg)
    syndrome = simulate_syndrome_engine(
        profile="BG1_first4_high_rate",
        decoder_cycles_per_iteration=result.metrics.cycles_per_iteration,
        final_touch=final_touch,
        S=prod.syndrome_S,
        queue_depth=prod.syndrome_Q,
    )

    assert result.metrics.layer_order == prod.reference_layer_order
    assert result.metrics.cycles_per_iteration == prod.reference_decoder_cycles
    assert syndrome.additional_tail_cycles == prod.reference_syndrome_tail
    assert syndrome.effective_iteration_boundary == prod.reference_effective_boundary
    assert syndrome.valid is True
