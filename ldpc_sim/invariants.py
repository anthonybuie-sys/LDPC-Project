"""Correctness invariants for completed schedules."""

from __future__ import annotations

from ldpc_sim.metrics import STALL_CATEGORIES


def assert_all_stalls_classified(stall_counts: dict[str, int]) -> None:
    unknown = set(stall_counts) - set(STALL_CATEGORIES)
    if unknown:
        raise AssertionError(f"Unknown stall categories: {sorted(unknown)}")


def assert_edge_coverage(
    active_edges: int,
    acc_issued_edges: int,
    rec_issued_edges: int,
) -> None:
    if acc_issued_edges != active_edges:
        raise AssertionError(
            f"INV-3 failed: accumulated {acc_issued_edges}, expected {active_edges}"
        )
    if rec_issued_edges != active_edges:
        raise AssertionError(
            f"INV-4 failed: reconstructed {rec_issued_edges}, expected {active_edges}"
        )


def assert_context_limit(max_contexts_seen: int, allowed: int) -> None:
    if max_contexts_seen > allowed:
        raise AssertionError(
            f"INV-10 failed: saw {max_contexts_seen} contexts, allowed {allowed}"
        )

