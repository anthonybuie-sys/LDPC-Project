from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE = "BG1_first4_high_rate"
WORK_CSV = ROOT / "results" / "syndrome_work_items.csv"
BG1_Z384 = ROOT / "data" / "NR-LDPC-BG" / "NR_1_1_384.txt"
SCHEDULE_JSON = ROOT / "results" / "rtl_handoff_category_a" / "schedule_program.json"
CATEGORY_B_JSON = ROOT / "results" / "rtl_handoff_category_b" / "schedule_contract_evidence.json"
OUT = ROOT / "rtl" / "syndrome" / "nr_ldpc_syndrome_profile_bg1_first4.sv"

EXPECTED_ACTIVE_ROWS = 4
EXPECTED_ACTIVE_COLUMNS = 26
EXPECTED_WORK_ITEMS = 76
EXPECTED_FIRST_FINAL = 53
EXPECTED_LAST_FINAL = 71
EXPECTED_COMPLETION = 72
EXPECTED_TAIL = 1
EXPECTED_MAX_BACKLOG = 7
EXPECTED_MAX_QUEUE_OCCUPANCY = 2


def read_bg_first4() -> dict[tuple[int, int], tuple[int, int]]:
    rows: list[list[int]] = []
    for raw in BG1_Z384.read_text(encoding="utf-8").splitlines()[:EXPECTED_ACTIVE_ROWS]:
        rows.append([int(value) for value in raw.split()])

    edge_by_layer_column: dict[tuple[int, int], tuple[int, int]] = {}
    for layer_id, row in enumerate(rows):
        edge_id = 0
        for column, shift in enumerate(row):
            if shift >= 0:
                edge_by_layer_column[(layer_id, column)] = (edge_id, shift)
                edge_id += 1
    return edge_by_layer_column


def load_work_items(
    edge_by_layer_column: dict[tuple[int, int], tuple[int, int]]
) -> list[dict[str, int]]:
    items: list[dict[str, int]] = []
    for (layer_id, column), (edge_id, shift) in edge_by_layer_column.items():
        if column < EXPECTED_ACTIVE_COLUMNS:
            items.append(
                {
                    "column": column,
                    "layer": layer_id,
                    "edge": edge_id,
                    "shift": shift,
                    "final_cycle": 0,
                }
            )
    items.sort(key=lambda x: (x["column"], x["layer"], x["edge"]))
    if len(items) != EXPECTED_WORK_ITEMS:
        raise AssertionError(f"Expected {EXPECTED_WORK_ITEMS} BG work items, found {len(items)}")

    artifact_edges: set[tuple[int, int, int, int]] = set()
    with WORK_CSV.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["profile"] != PROFILE:
                continue
            artifact_edges.add(
                (
                    int(row["layer_id"]),
                    int(row["edge_id"]),
                    int(row["column"]),
                    int(row["shift"]),
                )
            )

    bg_edges = {(x["layer"], x["edge"], x["column"], x["shift"]) for x in items}
    if artifact_edges != bg_edges:
        raise AssertionError(
            "Checked-in syndrome_work_items.csv does not match the BG source "
            f"for {PROFILE}"
        )
    if len(bg_edges) != len(items):
        raise AssertionError("Duplicate active QC edge in generated syndrome work table")
    return items


def decode_issue_word(hex_word: str) -> dict[str, int]:
    word = int(hex_word, 16)
    return {
        "valid": word & 1,
        "mask": (word >> 1) & 0x3,
        "layer": (word >> 3) & 0x3F,
        "edge0": (word >> 9) & 0x1F,
        "edge1": (word >> 14) & 0x1F,
        "final0": (word >> 32) & 0x1,
        "final1": (word >> 33) & 0x1,
    }


def load_category_b_evidence() -> dict[str, int]:
    data = json.loads(CATEGORY_B_JSON.read_text(encoding="utf-8"))
    syndrome = data["syndrome"]
    values = {
        "first": syndrome["first_final_cycle"],
        "last": syndrome["last_final_cycle"],
        "completion": syndrome["completion_cycle"],
        "tail": syndrome["tail_cycles"],
        "max_backlog": syndrome["max_backlog"],
        "max_queue": syndrome["max_queue_occupancy"],
        "work_items": syndrome["total_work_items"],
        "decoder_cycles": data["decoder_cycles_per_iteration"],
        "effective_boundary": data["effective_iteration_boundary"],
    }
    expected = {
        "first": EXPECTED_FIRST_FINAL,
        "last": EXPECTED_LAST_FINAL,
        "completion": EXPECTED_COMPLETION,
        "tail": EXPECTED_TAIL,
        "max_backlog": EXPECTED_MAX_BACKLOG,
        "max_queue": EXPECTED_MAX_QUEUE_OCCUPANCY,
        "work_items": EXPECTED_WORK_ITEMS,
        "decoder_cycles": 71,
        "effective_boundary": 72,
    }
    if values != expected:
        raise AssertionError(f"Category-B syndrome evidence changed: {values}")
    return values


def load_touches(
    edge_by_layer_column: dict[tuple[int, int], tuple[int, int]],
    issue_words: list[dict[str, object]] | None = None,
) -> dict[int, dict[str, int]]:
    touches: dict[int, dict[str, int]] = {}
    if issue_words is None:
        schedule = json.loads(SCHEDULE_JSON.read_text(encoding="utf-8"))
        issue_words = schedule["issue_words"]
    for issue in issue_words:
        cycle = int(issue["cycle"])
        rec = decode_issue_word(issue["rec36_hex"])
        if not rec["valid"]:
            continue
        if rec["final0"]:
            if not (rec["mask"] & 1):
                raise AssertionError(f"REC cycle {cycle} has final0 on an inactive lane")
            edge_key = (rec["layer"], rec["edge0"])
            matches = [
                column
                for (layer, column), (edge, _shift) in edge_by_layer_column.items()
                if layer == edge_key[0] and edge == edge_key[1]
            ]
            if len(matches) != 1:
                raise AssertionError(f"Cannot resolve REC final lane0 {edge_key}")
            column = matches[0]
            if column in touches:
                raise AssertionError(f"Column {column} finalized twice in REC schedule")
            touches[column] = {
                "final_layer": rec["layer"],
                "final_edge": rec["edge0"],
                "rec_issue_cycle": cycle,
                "final_cycle": cycle + 3,
                "work_count": 0,
            }
        if rec["final1"]:
            if not (rec["mask"] & 2):
                raise AssertionError(f"REC cycle {cycle} has final1 on an inactive lane")
            edge_key = (rec["layer"], rec["edge1"])
            matches = [
                column
                for (layer, column), (edge, _shift) in edge_by_layer_column.items()
                if layer == edge_key[0] and edge == edge_key[1]
            ]
            if len(matches) != 1:
                raise AssertionError(f"Cannot resolve REC final lane1 {edge_key}")
            column = matches[0]
            if column in touches:
                raise AssertionError(f"Column {column} finalized twice in REC schedule")
            touches[column] = {
                "final_layer": rec["layer"],
                "final_edge": rec["edge1"],
                "rec_issue_cycle": cycle,
                "final_cycle": cycle + 3,
                "work_count": 0,
            }

    if len(touches) != EXPECTED_ACTIVE_COLUMNS:
        raise AssertionError(f"Expected {EXPECTED_ACTIVE_COLUMNS} final touches, found {len(touches)}")
    if set(touches) != set(range(EXPECTED_ACTIVE_COLUMNS)):
        raise AssertionError(f"Unexpected active columns: {sorted(touches)}")
    first_final = min(touch["final_cycle"] for touch in touches.values())
    last_final = max(touch["final_cycle"] for touch in touches.values())
    if first_final != EXPECTED_FIRST_FINAL or last_final != EXPECTED_LAST_FINAL:
        raise AssertionError(f"Unexpected final cycle range {first_final}..{last_final}")
    return touches


def encode_rec_word(
    *,
    mask: int,
    layer: int,
    edge0: int = 0,
    edge1: int = 0,
    final0: int = 0,
    final1: int = 0,
) -> str:
    word = 1
    word |= (mask & 0x3) << 1
    word |= (layer & 0x3F) << 3
    word |= (edge0 & 0x1F) << 9
    word |= (edge1 & 0x1F) << 14
    word |= (final0 & 0x1) << 32
    word |= (final1 & 0x1) << 33
    return f"0x{word:09x}"


def validate_duplicate_rejection(edge_by_layer_column: dict[tuple[int, int], tuple[int, int]]) -> None:
    schedule = json.loads(SCHEDULE_JSON.read_text(encoding="utf-8"))
    issue_words = list(schedule["issue_words"])
    duplicate_lane0 = issue_words + [
        {
            "cycle": 999,
            "rec36_hex": encode_rec_word(mask=1, layer=0, edge0=0, final0=1),
        }
    ]
    duplicate_lane1 = issue_words + [
        {
            "cycle": 1000,
            "rec36_hex": encode_rec_word(mask=2, layer=0, edge1=0, final1=1),
        }
    ]

    for name, mutated in (
        ("duplicate lane0", duplicate_lane0),
        ("duplicate lane1", duplicate_lane1),
    ):
        try:
            load_touches(edge_by_layer_column, mutated)
        except AssertionError as exc:
            if "finalized twice" not in str(exc):
                raise
        else:
            raise AssertionError(f"{name} finalization was not rejected")


def case_function(name: str, input_name: str, width: int, entries: dict[int, int], default: int) -> list[str]:
    lines = [
        f"  function automatic logic [{width - 1}:0] {name}(input logic [6:0] {input_name});",
        "    begin",
        f"      {name} = {width}'d{default};",
        f"      case ({input_name})",
    ]
    for key, value in sorted(entries.items()):
        lines.append(f"        7'd{key}: {name} = {width}'d{value};")
    lines.extend(["        default: begin end", "      endcase", "    end", "  endfunction", ""])
    return lines


def emit_package(items: list[dict[str, int]], touches: dict[int, dict[str, int]]) -> str:
    column_counts: dict[int, int] = {}
    column_starts: dict[int, int] = {}
    column_final_cycles: dict[int, int] = {}
    start = 0
    for column in range(EXPECTED_ACTIVE_COLUMNS):
        count = sum(1 for item in items if item["column"] == column)
        if touches[column]["work_count"] not in (0, count):
            raise AssertionError(f"Column {column} work-count mismatch")
        touches[column]["work_count"] = count
        column_counts[column] = count
        column_starts[column] = start
        column_final_cycles[column] = touches[column]["final_cycle"]
        start += count

    if start != EXPECTED_WORK_ITEMS:
        raise AssertionError("Column work starts do not cover all work items")

    rows = {idx: item["layer"] for idx, item in enumerate(items)}
    edges = {idx: item["edge"] for idx, item in enumerate(items)}
    columns = {idx: item["column"] for idx, item in enumerate(items)}
    shifts = {idx: item["shift"] for idx, item in enumerate(items)}

    lines = [
        "`ifndef NR_LDPC_SYNDROME_PROFILE_BG1_FIRST4_SV",
        "`define NR_LDPC_SYNDROME_PROFILE_BG1_FIRST4_SV",
        "",
        "// Generated by scripts/generate_phase8_syndrome_profile.py.",
        "// Source: data/NR-LDPC-BG/NR_1_1_384.txt plus checked-in syndrome artifacts.",
        "package nr_ldpc_syndrome_profile_bg1_first4_pkg;",
        f"  localparam int PHASE8_ACTIVE_ROWS = {EXPECTED_ACTIVE_ROWS};",
        f"  localparam int PHASE8_ACTIVE_COLUMNS = {EXPECTED_ACTIVE_COLUMNS};",
        f"  localparam int PHASE8_WORK_ITEMS = {EXPECTED_WORK_ITEMS};",
        f"  localparam int PHASE8_FIRST_FINAL_CYCLE = {EXPECTED_FIRST_FINAL};",
        f"  localparam int PHASE8_LAST_FINAL_CYCLE = {EXPECTED_LAST_FINAL};",
        f"  localparam int PHASE8_EXPECTED_COMPLETION_CYCLE = {EXPECTED_COMPLETION};",
        f"  localparam int PHASE8_EXPECTED_TAIL = {EXPECTED_TAIL};",
        f"  localparam int PHASE8_EXPECTED_MAX_BACKLOG = {EXPECTED_MAX_BACKLOG};",
        f"  localparam int PHASE8_EXPECTED_MAX_QUEUE_OCCUPANCY = {EXPECTED_MAX_QUEUE_OCCUPANCY};",
        "",
        "  function automatic logic phase8_active_column(input logic [6:0] column);",
        "    begin",
        "      phase8_active_column = (column < 7'd26);",
        "    end",
        "  endfunction",
        "",
        "  function automatic logic [4:0] phase8_column_index(input logic [6:0] column);",
        "    begin",
        "      phase8_column_index = column[4:0];",
        "    end",
        "  endfunction",
        "",
    ]
    lines += case_function("phase8_column_work_count", "column", 5, column_counts, 0)
    lines += case_function("phase8_column_work_start", "column", 7, column_starts, EXPECTED_WORK_ITEMS)
    lines += case_function("phase8_column_final_cycle", "column", 7, column_final_cycles, 0)
    lines += case_function("phase8_work_row", "work_id", 2, rows, 0)
    lines += case_function("phase8_work_edge", "work_id", 5, edges, 0)
    lines += case_function("phase8_work_column", "work_id", 7, columns, 0)
    lines += case_function("phase8_work_shift", "work_id", 9, shifts, 0)
    lines += [
        "  function automatic logic phase8_work_valid(input logic [6:0] work_id);",
        "    begin",
        "      phase8_work_valid = (work_id < 7'd76);",
        "    end",
        "  endfunction",
        "endpackage",
        "",
        "`endif",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    load_category_b_evidence()
    edge_by_layer_column = read_bg_first4()
    validate_duplicate_rejection(edge_by_layer_column)
    items = load_work_items(edge_by_layer_column)
    touches = load_touches(edge_by_layer_column)
    OUT.write_text(emit_package(items, touches), encoding="utf-8")
    print("Generator duplicate validation PASS")
    print(f"Generated {OUT.relative_to(ROOT)} with {len(items)} work items.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
