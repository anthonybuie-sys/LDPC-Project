from ldpc_sim.pipeline import TokenPipeline


def test_pipeline_completion_cycle_uses_parameterized_depth() -> None:
    pipeline = TokenPipeline("ACC", depth=4)
    token = pipeline.issue(7, layer_id=1, pair_id=2)
    assert token.done_cycle == 11
    assert pipeline.can_issue(8)

