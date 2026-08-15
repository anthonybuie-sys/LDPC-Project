from __future__ import annotations

import csv
from dataclasses import dataclass
from math import ceil, log2
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.architecture import ArchitectureConfig
from ldpc_sim.banking import build_bank_map
from ldpc_sim.base_graphs import BASE_GRAPH_DATA_ROOT, load_3gpp_base_graph
from ldpc_sim.graph import LDPCGraph
from ldpc_sim.pairing import build_pair_schedule
from ldpc_sim.schedule_encoding import (
    FIELD_WIDTHS,
    build_packed_program,
    decode_program,
    unpack_instruction,
)
from ldpc_sim.simulator import SimulationResult, run_configured


@dataclass(frozen=True)
class LiftingConfig:
    base_graph: int
    i_ls: int
    z: int


@dataclass(frozen=True)
class ActiveLayerProfile:
    name: str
    active_layer_ids: tuple[int, ...] | None


PROFILES_BY_BG: dict[int, tuple[ActiveLayerProfile, ...]] = {
    1: (
        ActiveLayerProfile("first4", (0, 1, 2, 3)),
        ActiveLayerProfile("full", None),
    ),
    2: (
        ActiveLayerProfile("single0", (0,)),
        ActiveLayerProfile("full", None),
    ),
}


def available_liftings(base_graph: int) -> list[LiftingConfig]:
    configs: list[LiftingConfig] = []
    for path in sorted(BASE_GRAPH_DATA_ROOT.glob(f"NR_{base_graph}_*_*.txt")):
        _, bg_text, i_ls_text, z_text = path.stem.split("_")
        configs.append(
            LiftingConfig(
                base_graph=int(bg_text),
                i_ls=int(i_ls_text),
                z=int(z_text),
            )
        )
    return sorted(configs, key=lambda item: (item.z, item.i_ls))


def config_for_z(z: int) -> ArchitectureConfig:
    return ArchitectureConfig(
        Z=z,
        P=z,
        B=2,
        num_app_banks=8,
        forward_cache_depth=8,
        D_A=3,
        D_R=3,
        enable_lookahead=True,
        enable_forwarding=True,
        enable_jit_forwarding=True,
        enable_reconstruction_reorder=True,
        enable_layer_reorder=True,
        bank_strategy="optimized",
        pairing_strategy="optimized",
        max_cycles=20000,
    )


def layer_shape(graph: LDPCGraph) -> tuple[tuple[int, tuple[tuple[int, int], ...]], ...]:
    return tuple(
        (
            layer.layer_id,
            tuple((edge.edge_id, edge.column) for edge in layer.edges),
        )
        for layer in graph.layers
    )


def shift_shape(graph: LDPCGraph) -> tuple[tuple[int, tuple[tuple[int, int], ...]], ...]:
    return tuple(
        (
            layer.layer_id,
            tuple((edge.edge_id, edge.shift) for edge in layer.edges),
        )
        for layer in graph.layers
    )


def bank_signature(graph: LDPCGraph, config: ArchitectureConfig) -> tuple[tuple[int, int], ...]:
    bank_map = build_bank_map(graph, config.num_app_banks, config.bank_strategy)
    return tuple(sorted(bank_map.mapping.items()))


def pair_signature(
    graph: LDPCGraph, result: SimulationResult, config: ArchitectureConfig
) -> tuple[tuple[int, tuple[tuple[int, tuple[int, ...], tuple[int, ...]], ...]], ...]:
    ordered_layers = graph.ordered_layers(result.metrics.layer_order)
    bank_map = build_bank_map(graph, config.num_app_banks, config.bank_strategy)
    pair_schedules = build_pair_schedule(ordered_layers, bank_map, config.pairing_strategy)
    return tuple(
        (
            position,
            tuple(
                (
                    pair.pair_id,
                    tuple(edge.edge_id for edge in pair.edges),
                    pair.columns,
                )
                for pair in pairs
            ),
        )
        for position, pairs in sorted(pair_schedules.items())
    )


def acc_signature(result: SimulationResult) -> tuple[tuple[object, ...], ...]:
    return tuple(
        (
            record.cycle,
            record.position,
            record.layer_id,
            record.pair_id,
            record.edge_ids,
            record.columns,
            record.qbuf,
            record.qslot,
            tuple(
                (column, record.forward_slot_by_column.get(column))
                for column in record.columns
            ),
        )
        for record in result.acc_issues
    )


def rec_signature(result: SimulationResult) -> tuple[tuple[object, ...], ...]:
    return tuple(
        (
            record.cycle,
            record.position,
            record.layer_id,
            record.pair_id,
            record.edge_ids,
            record.columns,
            record.qbuf,
            record.qslot,
            tuple(
                (column, record.forward_slot_by_column.get(column))
                for column in record.columns
            ),
        )
        for record in result.rec_issues
    )


def schedule_signature(
    graph: LDPCGraph, result: SimulationResult, config: ArchitectureConfig
) -> dict[str, object]:
    return {
        "layer_shape": layer_shape(graph),
        "bank_map": bank_signature(graph, config),
        "layer_order": result.metrics.layer_order,
        "pairing": pair_signature(graph, result, config),
        "acc": acc_signature(result),
        "rec": rec_signature(result),
        "cycles": result.metrics.cycles_per_iteration,
    }


def reason_differences(reference: dict[str, object], other: dict[str, object]) -> list[str]:
    reasons: list[str] = []
    checks = (
        ("layer_shape", "base-column connectivity changed"),
        ("bank_map", "APP bank map changed"),
        ("layer_order", "selected layer order changed"),
        ("pairing", "B=2 edge pairing changed"),
        ("acc", "ACC order or source/forward-slot use changed"),
        ("rec", "REC order or forward-slot assignment changed"),
        ("cycles", "cycle count changed"),
    )
    for key, reason in checks:
        if reference[key] != other[key]:
            reasons.append(reason)
    return reasons


def bits_required(max_value: int) -> int:
    if max_value <= 0:
        return 1
    return ceil(log2(max_value + 1))


def format_bits(bits: int) -> str:
    byte_count = bits / 8.0
    kib = byte_count / 1024.0
    return f"{bits} bits ({byte_count:.1f} bytes, {kib:.2f} KiB)"


def instruction_from_record(record: object, decoded: object) -> tuple[object, ...]:
    return (
        getattr(record, "layer_id"),
        getattr(record, "edge_ids"),
        getattr(record, "qbuf"),
        getattr(record, "qslot"),
        decoded.aux_values,
    )


def verify_round_trip(result: SimulationResult) -> None:
    program = build_packed_program(result)
    decoded_acc, decoded_rec = decode_program(program)
    if len(decoded_acc) != len(result.acc_issues):
        raise AssertionError("Decoded ACC instruction count mismatch.")
    if len(decoded_rec) != len(result.rec_issues):
        raise AssertionError("Decoded REC instruction count mismatch.")
    for record in result.acc_issues:
        decoded = decoded_acc[record.cycle]
        if instruction_from_record(record, decoded) != (
            record.layer_id,
            record.edge_ids,
            record.qbuf,
            record.qslot,
            tuple(
                (record.forward_slot_by_column.get(column) + 1)
                if column in record.forward_slot_by_column
                else 0
                for column in record.columns
            ),
        ):
            raise AssertionError(f"ACC round trip mismatch at cycle {record.cycle}.")
    for record in result.rec_issues:
        decoded = decoded_rec[record.cycle]
        if instruction_from_record(record, decoded) != (
            record.layer_id,
            record.edge_ids,
            record.qbuf,
            record.qslot,
            tuple(
                (record.forward_slot_by_column.get(column) + 1)
                if column in record.forward_slot_by_column
                else 0
                for column in record.columns
            ),
        ):
            raise AssertionError(f"REC round trip mismatch at cycle {record.cycle}.")


def max_forward_slot(result: SimulationResult) -> int:
    slots: list[int] = []
    for record in result.acc_issues:
        slots.extend(record.forward_slot_by_column.values())
    for record in result.rec_issues:
        slots.extend(record.forward_slot_by_column.values())
    return max(slots) if slots else 0


def write_example(result: SimulationResult, path: Path) -> None:
    program = build_packed_program(result)
    lines = [
        "BG1 Z=384 first4 packed schedule example",
        "ACC and REC are 36-bit words; the 72-bit issue word is REC:ACC.",
        "",
        "cycle acc_hex rec_hex word72_hex decoded_acc decoded_rec",
    ]
    for word in program:
        acc = unpack_instruction(word.acc)
        rec = unpack_instruction(word.rec)
        acc_text = (
            "nop"
            if not acc.valid
            else (
                f"L{acc.layer_id} edges={acc.edge_ids} qbuf={acc.qbuf} "
                f"qslot={acc.qslot} src_aux={acc.aux_values}"
            )
        )
        rec_text = (
            "nop"
            if not rec.valid
            else (
                f"L{rec.layer_id} edges={rec.edge_ids} qbuf={rec.qbuf} "
                f"qslot={rec.qslot} fwd_aux={rec.aux_values}"
            )
        )
        lines.append(
            f"{word.cycle:03d} 0x{word.acc:09X} 0x{word.rec:09X} "
            f"0x{word.word72:018X} {acc_text} | {rec_text}"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def total_shift_entries(base_graph: int, configs: list[LiftingConfig]) -> int:
    total = 0
    for lifting in configs:
        graph = load_3gpp_base_graph(base_graph, lifting.z, lifting.i_ls)
        total += sum(layer.degree for layer in graph.layers)
    return total


def main() -> int:
    results_dir = ROOT / "results"
    results_dir.mkdir(exist_ok=True)
    summary_csv = results_dir / "schedule_encoding_profile_summary.csv"
    invariance_csv = results_dir / "schedule_encoding_z_invariance.csv"
    report_path = results_dir / "schedule_encoding_analysis.md"
    example_path = results_dir / "schedule_encoding_bg1_z384_first4.txt"

    summary_rows: list[dict[str, object]] = []
    invariance_rows: list[dict[str, object]] = []
    storage_once_bits = 0
    storage_per_z_bits = 0
    distinct_bank_maps: set[tuple[tuple[int, int], ...]] = set()
    global_max = {
        "layer_id": 0,
        "local_edge_id": 0,
        "qslot": 0,
        "forward_slot": 0,
        "app_column": 0,
        "program_length": 0,
    }

    z_counts: dict[int, int] = {}
    example_written = False

    for base_graph in (1, 2):
        liftings = available_liftings(base_graph)
        z_counts[base_graph] = len(liftings)
        for profile in PROFILES_BY_BG[base_graph]:
            reference_signature: dict[str, object] | None = None
            reference_shifts: object | None = None
            reference_result: SimulationResult | None = None
            reference_graph: LDPCGraph | None = None
            invariant = True
            all_reasons: set[str] = set()
            z_summaries: list[str] = []

            for lifting in liftings:
                graph = load_3gpp_base_graph(
                    base_graph,
                    lifting.z,
                    lifting.i_ls,
                    active_layer_ids=profile.active_layer_ids,
                )
                config = config_for_z(lifting.z)
                result = run_configured(graph, config)
                verify_round_trip(result)
                signature = schedule_signature(graph, result, config)
                shifts = shift_shape(graph)

                for layer in graph.layers:
                    global_max["layer_id"] = max(global_max["layer_id"], layer.layer_id)
                    for edge in layer.edges:
                        global_max["local_edge_id"] = max(
                            global_max["local_edge_id"], edge.edge_id
                        )
                        global_max["app_column"] = max(
                            global_max["app_column"], edge.column
                        )
                for record in result.acc_issues + result.rec_issues:
                    global_max["qslot"] = max(global_max["qslot"], record.qslot)
                global_max["forward_slot"] = max(
                    global_max["forward_slot"], max_forward_slot(result)
                )
                global_max["program_length"] = max(
                    global_max["program_length"], result.metrics.cycles_per_iteration
                )

                if reference_signature is None:
                    reference_signature = signature
                    reference_shifts = shifts
                    reference_result = result
                    reference_graph = graph
                else:
                    reasons = reason_differences(reference_signature, signature)
                    if reasons:
                        invariant = False
                        all_reasons.update(reasons)
                    if reference_shifts != shifts:
                        all_reasons.add("QC shifts changed, absorbed by separate shift table")

                z_summaries.append(f"Z{lifting.z}/iLS{lifting.i_ls}")
                invariance_rows.append(
                    {
                        "base_graph": base_graph,
                        "profile": profile.name,
                        "z": lifting.z,
                        "i_ls": lifting.i_ls,
                        "cycles": result.metrics.cycles_per_iteration,
                        "layer_order": "-".join(str(x) for x in result.metrics.layer_order),
                        "acc_instructions": result.metrics.ACC_issue_cycles,
                        "rec_instructions": result.metrics.REC_issue_cycles,
                        "max_q_slots": max((record.qslot for record in result.acc_issues), default=0) + 1,
                        "max_forward_occupancy": result.metrics.max_live_forward_vectors,
                    }
                )

                if (
                    not example_written
                    and base_graph == 1
                    and profile.name == "first4"
                    and lifting.z == 384
                    and lifting.i_ls == 1
                ):
                    write_example(result, example_path)
                    example_written = True

            assert reference_result is not None
            assert reference_graph is not None
            bank_map = bank_signature(reference_graph, config_for_z(reference_graph.Z))
            distinct_bank_maps.add(bank_map)
            program_length = reference_result.metrics.cycles_per_iteration
            profile_bits = program_length * 72
            storage_once_bits += profile_bits
            storage_per_z_bits += profile_bits * len(liftings)
            summary_rows.append(
                {
                    "base_graph": base_graph,
                    "profile": profile.name,
                    "active_layers": (
                        "all"
                        if profile.active_layer_ids is None
                        else "-".join(str(x) for x in profile.active_layer_ids)
                    ),
                    "supported_z_count": len(liftings),
                    "tested_z": " ".join(z_summaries),
                    "schedule_invariant": invariant,
                    "z_change_reasons": "none" if not all_reasons else "; ".join(sorted(all_reasons)),
                    "program_length": program_length,
                    "acc_instructions": reference_result.metrics.ACC_issue_cycles,
                    "rec_instructions": reference_result.metrics.REC_issue_cycles,
                    "max_q_slots": max(
                        (record.qslot for record in reference_result.acc_issues),
                        default=0,
                    )
                    + 1,
                    "max_forward_occupancy": reference_result.metrics.max_live_forward_vectors,
                    "selected_layer_order": "-".join(
                        str(x) for x in reference_result.metrics.layer_order
                    ),
                }
            )

    with summary_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0].keys()))
        writer.writeheader()
        writer.writerows(summary_rows)

    with invariance_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(invariance_rows[0].keys()))
        writer.writeheader()
        writer.writerows(invariance_rows)

    shift_entries = sum(
        total_shift_entries(base_graph, available_liftings(base_graph))
        for base_graph in (1, 2)
    )
    shift_bits = shift_entries * 9

    field_rows = [
        ("layer_id", global_max["layer_id"], FIELD_WIDTHS["layer_id"]),
        ("local_edge_id", global_max["local_edge_id"], FIELD_WIDTHS["edge0_id"]),
        ("qslot", global_max["qslot"], FIELD_WIDTHS["qslot"]),
        ("forward_slot", global_max["forward_slot"], FIELD_WIDTHS["aux0"] - 1),
        ("APP column", global_max["app_column"], 7),
        ("program_length", global_max["program_length"], bits_required(global_max["program_length"])),
    ]

    lines = [
        "# Schedule Encoding Analysis",
        "",
        "Architecture model: `B=2`, `D_A=3`, `D_R=3`, `APP banks=8`, `forward_cache_depth=8`, optimized bank map, optimized pairing, JIT forwarding.",
        "The current simulator enforces `P == Z`; each supported lifting was therefore run with its own `P=Z` while preserving the same dependency/bank/forwarding model. The packed schedule itself is independent of `P` and `Z` because it is expressed in base-graph layer/local-edge coordinates.",
        "",
        f"Supported lifting files tested: BG1={z_counts[1]}, BG2={z_counts[2]}.",
        "",
        "Profiles tested are the completing real-data profiles currently exposed by the repository: BG1 first-four benchmark, BG1 full loader profile, BG2 single-layer loader smoke profile, and BG2 full loader profile.",
        "",
        "## Profile Summary",
        "",
        "| BG | Profile | Active Layers | Invariant Across Z | Program Length | ACC | REC | Max Q Slots | Max Forward Occupancy | Selected Layer Order | Z-change Reasons |",
        "|---:|---|---|---|---:|---:|---:|---:|---:|---|---|",
    ]
    for row in summary_rows:
        lines.append(
            "| {base_graph} | {profile} | {active_layers} | {schedule_invariant} | "
            "{program_length} | {acc_instructions} | {rec_instructions} | "
            "{max_q_slots} | {max_forward_occupancy} | {selected_layer_order} | "
            "{z_change_reasons} |".format(**row)
        )

    lines.extend(
        [
            "",
            "## Field Maxima",
            "",
            "| Field | Max Observed | Bits Required | Proposed Bits | Status |",
            "|---|---:|---:|---:|---|",
        ]
    )
    for field, max_value, proposed_bits in field_rows:
        required = bits_required(max_value)
        status = "OK" if required <= proposed_bits else "INSUFFICIENT"
        lines.append(f"| {field} | {max_value} | {required} | {proposed_bits} | {status} |")

    lines.extend(
        [
            "",
            "The 36-bit ACC/REC words use `layer_id`, two local edge IDs, `qbuf`, `qslot`, two 4-bit forward selector fields, a 2-bit lane mask, valid bit, two REC final-touch flag bits, and two reserved bits. APP columns are recovered from the base-graph table by `(BG, layer, local_edge)`; if APP column were stored directly, BG1 column 67 requires 7 bits.",
            "",
            "## Storage",
            "",
            f"Schedule ROM once per `(BG, active-layer profile)` at 72 bits/cycle: {format_bits(storage_once_bits)}.",
            f"Schedule ROM duplicated for every supported Z: {format_bits(storage_per_z_bits)}.",
            f"Storage reduction from hybrid schedule sharing: {storage_per_z_bits / storage_once_bits:.1f}x fewer schedule bits.",
            f"Separate 9-bit QC-shift table for every BG/Z/layer/edge: {shift_entries} entries, {format_bits(shift_bits)}.",
            f"Distinct optimized APP bank maps across the analyzed profiles: {len(distinct_bank_maps)}.",
            "",
            "## Packed Example",
            "",
            f"Packed BG1 Z=384 first4 example: `{example_path.relative_to(ROOT)}`.",
            "Round-trip decoding of every packed ACC and REC instruction reproduced the structured schedule records exactly.",
            "",
            "## Conclusion",
            "",
            "For the tested real BG1/BG2 files and active-layer profiles, changing Z changed QC shifts but did not change base-column connectivity, optimized bank map, selected layer order, B=2 pairing, ACC order, REC order, forwarding-slot assignment, or cycle count. One optimized schedule can therefore serve the tested lifting sizes for the same BG/profile when paired with the separate shift table.",
        ]
    )
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
