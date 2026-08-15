from ldpc_sim.memory import QScratch


def test_q_buffer_read_requires_write_cycle() -> None:
    qscratch = QScratch()
    qscratch.reserve_write(0, 3, 0, 0, 3, written_cycle=8, cycle=4)
    assert not qscratch.can_read(0, 3, 7)
    assert qscratch.can_read(0, 3, 8)


def test_q_buffer_cannot_overwrite_before_reconstruction_release() -> None:
    qscratch = QScratch()
    qscratch.reserve_write(0, 1, 0, 0, 1, written_cycle=4, cycle=0)
    qscratch.mark_read(0, 1, release_cycle=10)
    assert not qscratch.can_reserve(0, 1, 9)
    assert qscratch.can_reserve(0, 1, 10)

