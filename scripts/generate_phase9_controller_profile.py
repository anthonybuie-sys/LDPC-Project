from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCHEDULE_JSON = ROOT / "results" / "rtl_handoff_category_a" / "schedule_program.json"
PROFILE_JSON = ROOT / "results" / "rtl_handoff_category_a" / "profile_metadata.json"
QC_SHIFT_JSON = ROOT / "results" / "rtl_handoff_category_a" / "qc_shift_table.json"
CATEGORY_B_JSON = ROOT / "results" / "rtl_handoff_category_b" / "schedule_contract_evidence.json"
BG1_Z384 = ROOT / "data" / "NR-LDPC-BG" / "NR_1_1_384.txt"
OUT = ROOT / "rtl" / "control" / "nr_ldpc_controller_profile_bg1_first4.sv"

EXPECTED_LAYER_ORDER = [1, 3, 2, 0]
EXPECTED_ACTIVE_LAYERS = [0, 1, 2, 3]
EXPECTED_ACTIVE_COLUMNS = 26
EXPECTED_PROGRAM_LENGTH = 71
EXPECTED_ACC_ISSUES = 40
EXPECTED_REC_ISSUES = 40
EXPECTED_ACC_EDGES = 76
EXPECTED_REC_EDGES = 76
EXPECTED_DEGREE = 19
EXPECTED_SYNDROME_COMPLETION = 72
EXPECTED_SYNDROME_TAIL = 1


def decode_instruction(hex_word: str) -> dict[str, int]:
    word = int(hex_word, 16)
    return {
        "valid": word & 1,
        "lane_mask": (word >> 1) & 0x3,
        "layer_id": (word >> 3) & 0x3F,
        "edge0_id": (word >> 9) & 0x1F,
        "edge1_id": (word >> 14) & 0x1F,
        "qbuf": (word >> 19) & 0x1,
        "qslot": (word >> 20) & 0xF,
        "aux0": (word >> 24) & 0xF,
        "aux1": (word >> 28) & 0xF,
        "final_touch0": (word >> 32) & 0x1,
        "final_touch1": (word >> 33) & 0x1,
        "reserved": (word >> 34) & 0x3,
    }


def lane_count(inst: dict[str, int]) -> int:
    return (inst["lane_mask"] & 1) + ((inst["lane_mask"] >> 1) & 1)


def read_bg_edges() -> dict[tuple[int, int], tuple[int, int]]:
    rows = [
        [int(value) for value in raw.split()]
        for raw in BG1_Z384.read_text(encoding="utf-8").splitlines()[:4]
    ]
    edges: dict[tuple[int, int], tuple[int, int]] = {}
    for layer_id, row in enumerate(rows):
        edge_id = 0
        for column, shift in enumerate(row[:EXPECTED_ACTIVE_COLUMNS]):
            if shift >= 0:
                edges[(layer_id, edge_id)] = (column, shift)
                edge_id += 1
        if edge_id != EXPECTED_DEGREE:
            raise AssertionError(f"degree(layer{layer_id})={edge_id}, expected {EXPECTED_DEGREE}")
    return edges


def load_authoritative() -> tuple[list[dict[str, object]], dict[tuple[int, int], tuple[int, int]]]:
    schedule = json.loads(SCHEDULE_JSON.read_text(encoding="utf-8"))
    profile = json.loads(PROFILE_JSON.read_text(encoding="utf-8"))
    qc_shift = json.loads(QC_SHIFT_JSON.read_text(encoding="utf-8"))
    category_b = json.loads(CATEGORY_B_JSON.read_text(encoding="utf-8"))

    if profile["profile"]["layer_order"] != EXPECTED_LAYER_ORDER:
        raise AssertionError(f"layer order changed: {profile['profile']['layer_order']}")
    if profile["profile"]["active_layers"] != EXPECTED_ACTIVE_LAYERS:
        raise AssertionError(f"active layers changed: {profile['profile']['active_layers']}")
    if profile["profile"]["base_graph"] != 1 or profile["profile"]["Z"] != 384 or profile["profile"]["iLS"] != 1:
        raise AssertionError("profile identity changed")

    expected = schedule["expected_metrics"]
    if expected["decoder_cycles_per_iteration"] != EXPECTED_PROGRAM_LENGTH:
        raise AssertionError("schedule decoder cycle count changed")
    if expected["ACC_issue_cycles"] != EXPECTED_ACC_ISSUES:
        raise AssertionError("schedule ACC issue count changed")
    if expected["REC_issue_cycles"] != EXPECTED_REC_ISSUES:
        raise AssertionError("schedule REC issue count changed")
    if expected["active_edges"] != EXPECTED_ACC_EDGES:
        raise AssertionError("schedule active edge count changed")

    if category_b["program_length"] != EXPECTED_PROGRAM_LENGTH:
        raise AssertionError("Category-B program length changed")
    if category_b["acc_issue_cycles"] != EXPECTED_ACC_ISSUES:
        raise AssertionError("Category-B ACC issue count changed")
    if category_b["rec_issue_cycles"] != EXPECTED_REC_ISSUES:
        raise AssertionError("Category-B REC issue count changed")
    if category_b["acc_edges"] != EXPECTED_ACC_EDGES or category_b["rec_edges"] != EXPECTED_REC_EDGES:
        raise AssertionError("Category-B edge count changed")
    if category_b["layer_order"] != EXPECTED_LAYER_ORDER:
        raise AssertionError("Category-B layer order changed")
    if category_b["decoder_cycles_per_iteration"] != EXPECTED_PROGRAM_LENGTH:
        raise AssertionError("Category-B decoder cycles changed")
    if category_b["syndrome"]["completion_cycle"] != EXPECTED_SYNDROME_COMPLETION:
        raise AssertionError("Category-B syndrome completion changed")
    if category_b["syndrome"]["tail_cycles"] != EXPECTED_SYNDROME_TAIL:
        raise AssertionError("Category-B syndrome tail changed")

    issue_words = schedule["issue_words"]
    if len(issue_words) != EXPECTED_PROGRAM_LENGTH:
        raise AssertionError(f"program length {len(issue_words)} != {EXPECTED_PROGRAM_LENGTH}")

    acc_issues = 0
    rec_issues = 0
    acc_edges = 0
    rec_edges = 0
    for expected_cycle, issue in enumerate(issue_words):
        if int(issue["cycle"]) != expected_cycle:
            raise AssertionError(f"non-contiguous cycle at {expected_cycle}: {issue['cycle']}")
        acc = decode_instruction(issue["acc36_hex"])
        rec = decode_instruction(issue["rec36_hex"])
        if acc["reserved"] != 0 or rec["reserved"] != 0:
            raise AssertionError(f"reserved bit set at cycle {expected_cycle}")
        if acc["valid"]:
            acc_issues += 1
            acc_edges += lane_count(acc)
        if rec["valid"]:
            rec_issues += 1
            rec_edges += lane_count(rec)
        if int(issue["word72_hex"], 16) != (int(issue["acc36_hex"], 16) | (int(issue["rec36_hex"], 16) << 36)):
            raise AssertionError(f"word72 mismatch at cycle {expected_cycle}")

    if (acc_issues, rec_issues, acc_edges, rec_edges) != (
        EXPECTED_ACC_ISSUES,
        EXPECTED_REC_ISSUES,
        EXPECTED_ACC_EDGES,
        EXPECTED_REC_EDGES,
    ):
        raise AssertionError((acc_issues, rec_issues, acc_edges, rec_edges))

    bg_edges = read_bg_edges()
    qc_edges = {
        (int(row["layer_id"]), int(row["local_edge_id"])): (
            int(row["app_column"]),
            int(row["shift"]),
        )
        for row in qc_shift["rows"]
    }
    if qc_edges != bg_edges:
        raise AssertionError("qc_shift_table.json does not match NR_1_1_384.txt")

    for issue in issue_words:
        for key in ("acc36_hex", "rec36_hex"):
            inst = decode_instruction(issue[key])
            if not inst["valid"]:
                continue
            if inst["layer_id"] not in EXPECTED_ACTIVE_LAYERS:
                raise AssertionError(f"invalid layer in {key}: {inst}")
            if inst["lane_mask"] not in (1, 2, 3):
                raise AssertionError(f"invalid lane mask in {key}: {inst}")
            if inst["lane_mask"] & 1 and (inst["layer_id"], inst["edge0_id"]) not in bg_edges:
                raise AssertionError(f"missing lane0 edge in {key}: {inst}")
            if inst["lane_mask"] & 2 and (inst["layer_id"], inst["edge1_id"]) not in bg_edges:
                raise AssertionError(f"missing lane1 edge in {key}: {inst}")

    return issue_words, bg_edges


def case_function(
    name: str,
    input_decl: str,
    input_name: str,
    width: int,
    entries: dict[int, int],
    default: int,
) -> list[str]:
    lines = [
        f"  function automatic logic [{width - 1}:0] {name}({input_decl});",
        "    begin",
        f"      {name} = {width}'d{default};",
        f"      case ({input_name})",
    ]
    for key, value in sorted(entries.items()):
        lines.append(f"        {key}: {name} = {width}'d{value};")
    lines.extend(["        default: begin end", "      endcase", "    end", "  endfunction", ""])
    return lines


def emit_package(issue_words: list[dict[str, object]], edges: dict[tuple[int, int], tuple[int, int]]) -> str:
    program = {int(issue["cycle"]): int(issue["word72_hex"], 16) for issue in issue_words}
    layer_positions = {1: 0, 3: 1, 2: 2, 0: 3}
    layer_order = {0: 1, 1: 3, 2: 2, 3: 0}
    degrees = {layer: EXPECTED_DEGREE for layer in EXPECTED_ACTIVE_LAYERS}
    edge_columns = {(layer << 5) | edge: column for (layer, edge), (column, _shift) in edges.items()}
    edge_shifts = {(layer << 5) | edge: shift for (layer, edge), (_column, shift) in edges.items()}
    edge_valid = {(layer << 5) | edge: 1 for layer, edge in edges}

    lines = [
        "`ifndef NR_LDPC_CONTROLLER_PROFILE_BG1_FIRST4_SV",
        "`define NR_LDPC_CONTROLLER_PROFILE_BG1_FIRST4_SV",
        "",
        "// Generated by scripts/generate_phase9_controller_profile.py.",
        "// Sources: Category-A schedule/profile/QC-shift artifacts, Category-B evidence, and NR_1_1_384.txt.",
        "package nr_ldpc_controller_profile_bg1_first4_pkg;",
        f"  localparam int PHASE9_PROGRAM_LENGTH = {EXPECTED_PROGRAM_LENGTH};",
        f"  localparam int PHASE9_ACC_ISSUES = {EXPECTED_ACC_ISSUES};",
        f"  localparam int PHASE9_REC_ISSUES = {EXPECTED_REC_ISSUES};",
        f"  localparam int PHASE9_ACC_EDGES = {EXPECTED_ACC_EDGES};",
        f"  localparam int PHASE9_REC_EDGES = {EXPECTED_REC_EDGES};",
        f"  localparam int PHASE9_ACTIVE_COLUMNS = {EXPECTED_ACTIVE_COLUMNS};",
        f"  localparam int PHASE9_LAYER_DEGREE = {EXPECTED_DEGREE};",
        f"  localparam int PHASE9_SYNDROME_COMPLETION_CYCLE = {EXPECTED_SYNDROME_COMPLETION};",
        f"  localparam int PHASE9_SYNDROME_TAIL = {EXPECTED_SYNDROME_TAIL};",
        "",
    ]
    lines += case_function(
        "phase9_program_word",
        "input logic [8:0] pc",
        "pc",
        72,
        program,
        0,
    )
    lines += [
        "  function automatic logic phase9_active_layer(input logic [5:0] layer_id);",
        "    begin",
        "      case (layer_id)",
        "        6'd0, 6'd1, 6'd2, 6'd3: phase9_active_layer = 1'b1;",
        "        default: phase9_active_layer = 1'b0;",
        "      endcase",
        "    end",
        "  endfunction",
        "",
    ]
    lines += case_function(
        "phase9_layer_position",
        "input logic [5:0] layer_id",
        "layer_id",
        6,
        {k: v for k, v in layer_positions.items()},
        63,
    )
    lines += case_function(
        "phase9_layer_order",
        "input logic [1:0] position",
        "position",
        6,
        {k: v for k, v in layer_order.items()},
        63,
    )
    lines += case_function(
        "phase9_layer_degree",
        "input logic [5:0] layer_id",
        "layer_id",
        6,
        degrees,
        0,
    )
    lines += case_function(
        "phase9_edge_base_column",
        "input logic [5:0] layer_id, input logic [4:0] local_edge_id",
        "{layer_id, local_edge_id}",
        7,
        edge_columns,
        127,
    )
    lines += case_function(
        "phase9_edge_shift",
        "input logic [5:0] layer_id, input logic [4:0] local_edge_id",
        "{layer_id, local_edge_id}",
        9,
        edge_shifts,
        0,
    )
    lines += [
        "  function automatic logic phase9_edge_valid(input logic [5:0] layer_id, input logic [4:0] local_edge_id);",
        "    begin",
        "      phase9_edge_valid = 1'b0;",
        "      case ({layer_id, local_edge_id})",
    ]
    for key in sorted(edge_valid):
        lines.append(f"        {key}: phase9_edge_valid = 1'b1;")
    lines.extend(
        [
            "        default: begin end",
            "      endcase",
            "    end",
            "  endfunction",
            "endpackage",
            "",
            "`endif",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    issue_words, edges = load_authoritative()
    OUT.write_text(emit_package(issue_words, edges), encoding="utf-8")
    print("Phase9 controller profile validation PASS")
    print(f"Generated {OUT.relative_to(ROOT)} with {len(issue_words)} schedule words.")
    print("layer_order=1,3,2,0 program_length=71 acc_issues=40 rec_issues=40 edges=76")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
