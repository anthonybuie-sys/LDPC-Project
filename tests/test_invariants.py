from ldpc_sim.invariants import assert_context_limit, assert_edge_coverage


def test_edge_coverage_invariant_fails_loudly() -> None:
    try:
        assert_edge_coverage(active_edges=4, acc_issued_edges=3, rec_issued_edges=4)
    except AssertionError as exc:
        assert "INV-3" in str(exc)
    else:
        raise AssertionError("Expected INV-3 assertion.")


def test_context_limit_invariant() -> None:
    try:
        assert_context_limit(max_contexts_seen=3, allowed=2)
    except AssertionError as exc:
        assert "INV-10" in str(exc)
    else:
        raise AssertionError("Expected INV-10 assertion.")
