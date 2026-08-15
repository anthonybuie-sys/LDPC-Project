"""Packed schedule microinstruction helpers.

The packed program is intentionally shift-agnostic: the schedule names a layer
and up to two local edge IDs, while APP columns and QC shifts are recovered
from the base-graph/shift tables for the selected BG/Z.
"""

from __future__ import annotations

from dataclasses import dataclass

from ldpc_sim.scheduler import AccIssueRecord, RecIssueRecord
from ldpc_sim.simulator import SimulationResult

INSTRUCTION_BITS = 36
NO_FORWARD = 0
UNUSED_EDGE = 0


@dataclass(frozen=True)
class FieldSpec:
    name: str
    offset: int
    width: int

    @property
    def mask(self) -> int:
        return (1 << self.width) - 1

    @property
    def max_value(self) -> int:
        return self.mask


FIELD_SPECS: tuple[FieldSpec, ...] = (
    FieldSpec("valid", 0, 1),
    FieldSpec("lane_mask", 1, 2),
    FieldSpec("layer_id", 3, 6),
    FieldSpec("edge0_id", 9, 5),
    FieldSpec("edge1_id", 14, 5),
    FieldSpec("qbuf", 19, 1),
    FieldSpec("qslot", 20, 4),
    FieldSpec("aux0", 24, 4),
    FieldSpec("aux1", 28, 4),
    FieldSpec("final_touch0", 32, 1),
    FieldSpec("final_touch1", 33, 1),
    FieldSpec("reserved", 34, 2),
)

FIELD_WIDTHS = {field.name: field.width for field in FIELD_SPECS}


@dataclass(frozen=True)
class PackedInstruction:
    valid: int
    lane_mask: int
    layer_id: int
    edge0_id: int
    edge1_id: int
    qbuf: int
    qslot: int
    aux0: int
    aux1: int
    final_touch0: int = 0
    final_touch1: int = 0
    reserved: int = 0

    @property
    def edge_ids(self) -> tuple[int, ...]:
        ids = (self.edge0_id, self.edge1_id)
        return tuple(edge_id for index, edge_id in enumerate(ids) if self.lane_mask & (1 << index))

    @property
    def aux_values(self) -> tuple[int, ...]:
        values = (self.aux0, self.aux1)
        return tuple(value for index, value in enumerate(values) if self.lane_mask & (1 << index))

    @property
    def final_touch_values(self) -> tuple[int, ...]:
        values = (self.final_touch0, self.final_touch1)
        return tuple(value for index, value in enumerate(values) if self.lane_mask & (1 << index))


@dataclass(frozen=True)
class PackedIssueWord:
    cycle: int
    acc: int
    rec: int

    @property
    def word72(self) -> int:
        return self.acc | (self.rec << INSTRUCTION_BITS)


def _require_fit(name: str, value: int, width: int) -> None:
    if value < 0 or value >= (1 << width):
        raise ValueError(f"{name}={value} does not fit in {width} bits.")


def _pack(fields: dict[str, int]) -> int:
    value = 0
    for spec in FIELD_SPECS:
        field_value = fields.get(spec.name, 0)
        _require_fit(spec.name, field_value, spec.width)
        value |= field_value << spec.offset
    _require_fit("instruction", value, INSTRUCTION_BITS)
    return value


def unpack_instruction(word: int) -> PackedInstruction:
    _require_fit("instruction", word, INSTRUCTION_BITS)
    values = {
        spec.name: (word >> spec.offset) & spec.mask
        for spec in FIELD_SPECS
    }
    return PackedInstruction(**values)


def _forward_code(slot: int | None) -> int:
    if slot is None:
        return NO_FORWARD
    code = slot + 1
    _require_fit("forward_slot_code", code, FIELD_WIDTHS["aux0"])
    return code


def _edge_fields(edge_ids: tuple[int, ...]) -> tuple[int, int, int]:
    if not 1 <= len(edge_ids) <= 2:
        raise ValueError(f"B=2 instruction expected one or two edges, got {edge_ids}.")
    lane_mask = (1 << len(edge_ids)) - 1
    edge0 = edge_ids[0]
    edge1 = edge_ids[1] if len(edge_ids) > 1 else UNUSED_EDGE
    return lane_mask, edge0, edge1


def encode_acc(record: AccIssueRecord) -> int:
    lane_mask, edge0, edge1 = _edge_fields(record.edge_ids)
    aux = [
        _forward_code(record.forward_slot_by_column.get(column))
        for column in record.columns
    ]
    if len(aux) == 1:
        aux.append(NO_FORWARD)
    return _pack(
        {
            "valid": 1,
            "lane_mask": lane_mask,
            "layer_id": record.layer_id,
            "edge0_id": edge0,
            "edge1_id": edge1,
            "qbuf": record.qbuf,
            "qslot": record.qslot,
            "aux0": aux[0],
            "aux1": aux[1],
        }
    )


def encode_rec(
    record: RecIssueRecord,
    final_touch_by_column: dict[int, bool] | None = None,
) -> int:
    lane_mask, edge0, edge1 = _edge_fields(record.edge_ids)
    aux = [
        _forward_code(record.forward_slot_by_column.get(column))
        for column in record.columns
    ]
    if len(aux) == 1:
        aux.append(NO_FORWARD)
    final_touch = [
        1 if final_touch_by_column and final_touch_by_column.get(column, False) else 0
        for column in record.columns
    ]
    if len(final_touch) == 1:
        final_touch.append(0)
    return _pack(
        {
            "valid": 1,
            "lane_mask": lane_mask,
            "layer_id": record.layer_id,
            "edge0_id": edge0,
            "edge1_id": edge1,
            "qbuf": record.qbuf,
            "qslot": record.qslot,
            "aux0": aux[0],
            "aux1": aux[1],
            "final_touch0": final_touch[0],
            "final_touch1": final_touch[1],
        }
    )


def build_packed_program(
    result: SimulationResult,
    rec_final_touch_by_cycle: dict[int, dict[int, bool]] | None = None,
) -> list[PackedIssueWord]:
    acc_by_cycle = {record.cycle: encode_acc(record) for record in result.acc_issues}
    rec_final_touch_by_cycle = rec_final_touch_by_cycle or {}
    rec_by_cycle = {
        record.cycle: encode_rec(
            record,
            final_touch_by_column=rec_final_touch_by_cycle.get(record.cycle),
        )
        for record in result.rec_issues
    }
    return [
        PackedIssueWord(
            cycle=cycle,
            acc=acc_by_cycle.get(cycle, 0),
            rec=rec_by_cycle.get(cycle, 0),
        )
        for cycle in range(result.metrics.cycles_per_iteration)
    ]


def decode_program(
    program: list[PackedIssueWord],
) -> tuple[dict[int, PackedInstruction], dict[int, PackedInstruction]]:
    acc = {
        word.cycle: unpack_instruction(word.acc)
        for word in program
        if unpack_instruction(word.acc).valid
    }
    rec = {
        word.cycle: unpack_instruction(word.rec)
        for word in program
        if unpack_instruction(word.rec).valid
    }
    return acc, rec
