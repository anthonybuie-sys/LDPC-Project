from ldpc_sim.forwarding import ForwardCache


def test_forward_entry_valid_only_after_valid_cycle() -> None:
    cache = ForwardCache(depth=1, enabled=True)
    (entry,) = cache.allocate_many(
        columns=[7],
        producer_position=0,
        producer_layer=0,
        valid_cycle=10,
        memory_safe_cycle=11,
        next_consumers={7: 1},
        cycle=6,
    )
    assert cache.find(7, 0, 9) is None
    assert cache.find(7, 0, 10) is entry


def test_forward_cache_capacity_is_finite() -> None:
    cache = ForwardCache(depth=1, enabled=True)
    cache.allocate_many([1], 0, 0, 4, 5, {1: 1}, 0)
    assert not cache.can_allocate(1, 1)


def test_forward_lifetime_metrics() -> None:
    cache = ForwardCache(depth=1, enabled=True)
    (entry,) = cache.allocate_many([1], 0, 0, 4, 5, {1: 1}, 0)
    cache.consume(entry, 4)
    assert cache.min_lifetime == 4
    assert cache.max_lifetime == 4
    assert cache.average_lifetime == 4
