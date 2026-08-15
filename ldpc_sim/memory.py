"""q scratch, sign-generation, and APP memory helpers."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class QSlotRecord:
    qbuf: int
    qslot: int
    layer_position: int
    layer_id: int
    pair_id: int
    written_cycle: int
    release_cycle: int | None = None


class QScratch:
    def __init__(self, num_buffers: int = 2) -> None:
        self.num_buffers = num_buffers
        self.records: dict[tuple[int, int], QSlotRecord] = {}

    def qbuf_for_position(self, layer_position: int) -> int:
        return layer_position % self.num_buffers

    def can_reserve(self, qbuf: int, qslot: int, cycle: int) -> bool:
        record = self.records.get((qbuf, qslot))
        return record is None or (
            record.release_cycle is not None and record.release_cycle <= cycle
        )

    def reserve_write(
        self,
        qbuf: int,
        qslot: int,
        layer_position: int,
        layer_id: int,
        pair_id: int,
        written_cycle: int,
        cycle: int,
    ) -> None:
        if not self.can_reserve(qbuf, qslot, cycle):
            raise RuntimeError(
                f"q buffer overwrite before reconstruction completed: QBUF{qbuf} slot {qslot}"
            )
        self.records[(qbuf, qslot)] = QSlotRecord(
            qbuf=qbuf,
            qslot=qslot,
            layer_position=layer_position,
            layer_id=layer_id,
            pair_id=pair_id,
            written_cycle=written_cycle,
        )

    def can_read(self, qbuf: int, qslot: int, cycle: int) -> bool:
        record = self.records.get((qbuf, qslot))
        return record is not None and record.written_cycle <= cycle

    def mark_read(self, qbuf: int, qslot: int, release_cycle: int) -> None:
        record = self.records.get((qbuf, qslot))
        if record is None:
            raise RuntimeError(f"q buffer read before write: QBUF{qbuf} slot {qslot}")
        record.release_cycle = release_cycle


@dataclass
class SignGenerationState:
    old_generation: int = 0
    new_generation: int = 1

    def swap(self) -> None:
        self.old_generation, self.new_generation = (
            self.new_generation,
            self.old_generation,
        )

