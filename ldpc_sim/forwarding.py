"""Canonical APP forwarding cache model."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class ForwardEntry:
    slot: int
    column: int
    producer_position: int
    producer_layer: int
    valid_cycle: int
    memory_safe_cycle: int
    next_consumer_position: int | None
    created_cycle: int
    consumed_cycle: int | None = None
    lifetime_recorded: bool = False

    @property
    def live(self) -> bool:
        return self.consumed_cycle is None


class ForwardCache:
    def __init__(self, depth: int, enabled: bool) -> None:
        self.depth = depth if enabled else 0
        self.enabled = enabled and depth > 0
        self.entries: list[ForwardEntry] = []
        self.max_occupancy = 0
        self.overflow_events = 0
        self.max_lifetime = 0
        self.lifetimes: list[int] = []

    def _record_lifetime(self, entry: ForwardEntry, cycle: int) -> None:
        if entry.lifetime_recorded:
            return
        lifetime = cycle - entry.created_cycle
        entry.lifetime_recorded = True
        self.lifetimes.append(lifetime)
        self.max_lifetime = max(self.max_lifetime, lifetime)

    def retire(self, cycle: int) -> None:
        kept: list[ForwardEntry] = []
        for entry in self.entries:
            consumed_and_past_cycle = (
                entry.consumed_cycle is not None and entry.consumed_cycle < cycle
            )
            memory_safe = entry.memory_safe_cycle <= cycle
            if consumed_and_past_cycle or memory_safe:
                self._record_lifetime(entry, cycle)
                continue
            kept.append(entry)
        self.entries = kept

    def live_count(self) -> int:
        return len(self.entries)

    def available_slots(self, cycle: int) -> int:
        if not self.enabled:
            return 0
        self.retire(cycle)
        return len(self._free_slots())

    def _free_slots(self) -> list[int]:
        used = {entry.slot for entry in self.entries}
        return [slot for slot in range(self.depth) if slot not in used]

    def can_allocate(self, count: int, cycle: int) -> bool:
        if count == 0:
            return True
        if not self.enabled:
            return False
        self.retire(cycle)
        return len(self._free_slots()) >= count

    def allocate_many(
        self,
        columns: list[int],
        producer_position: int,
        producer_layer: int,
        valid_cycle: int,
        memory_safe_cycle: int,
        next_consumers: dict[int, int | None],
        cycle: int,
    ) -> list[ForwardEntry]:
        if not self.can_allocate(len(columns), cycle):
            self.overflow_events += 1
            raise RuntimeError("Forward cache capacity exceeded.")
        free_slots = self._free_slots()
        allocated: list[ForwardEntry] = []
        for column in columns:
            entry = ForwardEntry(
                slot=free_slots.pop(0),
                column=column,
                producer_position=producer_position,
                producer_layer=producer_layer,
                valid_cycle=valid_cycle,
                memory_safe_cycle=memory_safe_cycle,
                next_consumer_position=next_consumers.get(column),
                created_cycle=cycle,
            )
            self.entries.append(entry)
            allocated.append(entry)
        self.max_occupancy = max(self.max_occupancy, len(self.entries))
        return allocated

    def find(self, column: int, producer_position: int, cycle: int) -> ForwardEntry | None:
        if not self.enabled:
            return None
        for entry in self.entries:
            if (
                entry.column == column
                and entry.producer_position == producer_position
                and entry.consumed_cycle is None
                and entry.valid_cycle <= cycle
            ):
                return entry
        return None

    def consume(self, entry: ForwardEntry, cycle: int) -> None:
        if entry.consumed_cycle is None:
            entry.consumed_cycle = cycle
            self._record_lifetime(entry, cycle)

    @property
    def min_lifetime(self) -> int:
        return min(self.lifetimes) if self.lifetimes else 0

    @property
    def average_lifetime(self) -> float:
        return sum(self.lifetimes) / len(self.lifetimes) if self.lifetimes else 0.0
