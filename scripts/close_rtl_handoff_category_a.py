from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.numerical_decoder import (
    compute_syndrome,
    rotate_from_check,
    rotate_to_check,
)
from ldpc_sim.production_v1 import (
    PRODUCTION_V1,
    canonical_json,
    production_architecture_config,
    sha256_json,
)
from ldpc_sim.qc_direction import (
    checked_in_matrix_profiles,
    deterministic_hard_vectors,
    deterministic_identity_vectors,
    load_profile,
    scalar_rotate_to_check,
    scalar_syndrome,
    used_shifts,
)
from ldpc_sim.schedule_encoding import build_packed_program
from ldpc_sim.simulator import simulate_iteration
from ldpc_sim.syndrome import analyze_final_touches, simulate_syndrome_engine


GENERATOR_NAME = "scripts/close_rtl_handoff_category_a.py"
GENERATOR_VERSION = "1"


def repo_head_commit(root: Path) -> str:
    head = (root / ".git" / "HEAD").read_text(encoding="utf-8").strip()
    if not head.startswith("ref: "):
        return head
    ref = head.removeprefix("ref: ").strip()
    ref_path = root / ".git" / ref
    if ref_path.exists():
        return ref_path.read_text(encoding="utf-8").strip()
    packed_refs = root / ".git" / "packed-refs"
    if packed_refs.exists():
        for line in packed_refs.read_text(encoding="utf-8").splitlines():
            if line.startswith("#") or not line.strip():
                continue
            commit, _, name = line.partition(" ")
            if name == ref:
                return commit
    return "UNKNOWN"


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def evidence_row(
    *,
    oq: str,
    test_name: str,
    status: str,
    profile: str = "",
    base_graph: object = "",
    i_ls: object = "",
    z: object = "",
    shift: object = "",
    vector_count: object = "",
    edge_count: object = "",
    details: str = "",
) -> dict[str, object]:
    return {
        "oq": oq,
        "test_name": test_name,
        "status": status,
        "profile": profile,
        "base_graph": base_graph,
        "iLS": i_ls,
        "Z": z,
        "shift": shift,
        "vector_count": vector_count,
        "edge_count": edge_count,
        "details": details,
    }


def run_qc_direction_evidence() -> tuple[list[dict[str, object]], dict[str, int]]:
    rows: list[dict[str, object]] = []

    z = 8
    canonical = np.zeros(z, dtype=np.int64)
    canonical[3] = 7
    expected = np.zeros(z, dtype=np.int64)
    expected[(3 - 1) % z] = 7
    if not np.array_equal(rotate_to_check(canonical, 1), expected):
        raise AssertionError("s=1 one-hot direction check failed.")
    if not np.array_equal(scalar_rotate_to_check(canonical, 1), expected):
        raise AssertionError("s=1 scalar direction reference failed.")
    rows.append(
        evidence_row(
            oq="OQ-01",
            test_name="s=1 one-hot direction",
            status="PASS",
            z=z,
            shift=1,
            vector_count=1,
            details="Scalar expected destination index is (source_index - s) mod Z.",
        )
    )

    canonical = np.zeros(z, dtype=np.int64)
    canonical[0] = 11
    expected = np.zeros(z, dtype=np.int64)
    expected[(0 - (z - 1)) % z] = 11
    if not np.array_equal(rotate_to_check(canonical, z - 1), expected):
        raise AssertionError("s=Z-1 wraparound direction check failed.")
    if not np.array_equal(scalar_rotate_to_check(canonical, z - 1), expected):
        raise AssertionError("s=Z-1 scalar wraparound reference failed.")
    rows.append(
        evidence_row(
            oq="OQ-01",
            test_name="s=Z-1 one-hot wraparound",
            status="PASS",
            z=z,
            shift=z - 1,
            vector_count=1,
            details="Scalar expected destination index wraps through lane 1.",
        )
    )

    identity_shift_count = 0
    syndrome_vector_count = 0
    profiles = checked_in_matrix_profiles()
    for profile in profiles:
        graph = load_profile(profile)
        shifts = used_shifts(graph)
        for shift in shifts:
            seed = profile.base_graph * 1_000_000 + profile.i_ls * 10_000 + profile.z + shift
            vectors = deterministic_identity_vectors(profile.z, seed)
            for _, vector in vectors:
                if not np.array_equal(rotate_from_check(rotate_to_check(vector, shift), shift), vector):
                    raise AssertionError(f"Forward/inverse identity failed for {profile.identity}, shift {shift}.")
            identity_shift_count += 1
            rows.append(
                evidence_row(
                    oq="OQ-01",
                    test_name="forward/inverse identity",
                    status="PASS",
                    profile=profile.identity,
                    base_graph=profile.base_graph,
                    i_ls=profile.i_ls,
                    z=profile.z,
                    shift=shift,
                    vector_count=len(vectors),
                    details="one-hot and randomized deterministic vectors",
                )
            )

        seed = profile.base_graph * 1_000_000 + profile.i_ls * 10_000 + profile.z
        hard_vectors = deterministic_hard_vectors(graph, seed)
        edge_count = sum(layer.degree for layer in graph.layers)
        for vector_name, hard_bits in hard_vectors:
            expected_syndrome = scalar_syndrome(graph, hard_bits)
            actual_syndrome = compute_syndrome(graph, hard_bits)
            if not np.array_equal(actual_syndrome, expected_syndrome):
                raise AssertionError(f"Scalar syndrome mismatch for {profile.identity}, {vector_name}.")
            syndrome_vector_count += 1
        rows.append(
            evidence_row(
                oq="OQ-01",
                test_name="independent scalar syndrome",
                status="PASS",
                profile=profile.identity,
                base_graph=profile.base_graph,
                i_ls=profile.i_ls,
                z=profile.z,
                vector_count=len(hard_vectors),
                edge_count=edge_count,
                details="scalar k reads variable lane (k+s) mod Z; no rotate_to_check in expected path",
            )
        )

    summary = {
        "profile_count": len(profiles),
        "identity_shift_count": identity_shift_count,
        "syndrome_vector_count": syndrome_vector_count,
    }
    return rows, summary


def build_production_artifacts(out_dir: Path, source_commit: str) -> dict[str, Any]:
    prod = PRODUCTION_V1
    cfg = production_architecture_config(prod)
    graph = load_3gpp_base_graph(
        prod.reference_BG,
        prod.reference_Z,
        i_ls=prod.reference_iLS,
        active_layer_ids=prod.reference_active_layers,
    )
    result = simulate_iteration(graph, cfg, layer_order=prod.reference_layer_order)
    final_touch = analyze_final_touches(graph, result, cfg)
    syndrome = simulate_syndrome_engine(
        profile="BG1_first4_high_rate",
        decoder_cycles_per_iteration=result.metrics.cycles_per_iteration,
        final_touch=final_touch,
        S=prod.syndrome_S,
        queue_depth=prod.syndrome_Q,
    )

    if result.metrics.cycles_per_iteration != prod.reference_decoder_cycles:
        raise AssertionError("Production schedule cycle count does not match frozen config.")
    if syndrome.additional_tail_cycles != prod.reference_syndrome_tail:
        raise AssertionError("Production syndrome tail does not match frozen config.")
    if syndrome.effective_iteration_boundary != prod.reference_effective_boundary:
        raise AssertionError("Production effective boundary does not match frozen config.")
    if not syndrome.valid:
        raise AssertionError("Production syndrome queue is invalid.")

    program = build_packed_program(
        result,
        rec_final_touch_by_cycle=final_touch.final_touch_by_rec_cycle,
    )
    schedule_artifact = {
        "artifact_type": "schedule_program",
        "format": "packed_acc_rec_72b_issue_program_v1",
        "source_repository_commit": source_commit,
        "generator": {"name": GENERATOR_NAME, "version": GENERATOR_VERSION},
        "architecture_config_identity": prod.identity_hash,
        "profile_identity": "BG1_Z384_iLS1_layers_0_1_2_3_order_1_3_2_0",
        "program_length": len(program),
        "expected_metrics": {
            "decoder_cycles_per_iteration": result.metrics.cycles_per_iteration,
            "ACC_issue_cycles": result.metrics.ACC_issue_cycles,
            "REC_issue_cycles": result.metrics.REC_issue_cycles,
            "active_edges": result.metrics.active_edges,
            "syndrome_tail": syndrome.additional_tail_cycles,
            "effective_iteration_boundary": syndrome.effective_iteration_boundary,
        },
        "issue_words": [
            {
                "cycle": word.cycle,
                "acc36_hex": f"0x{word.acc:09x}",
                "rec36_hex": f"0x{word.rec:09x}",
                "word72_hex": f"0x{word.word72:018x}",
            }
            for word in program
        ],
    }

    qc_shift_table = {
        "artifact_type": "qc_shift_table",
        "format": "layer_local_edge_to_app_column_shift_v1",
        "source_repository_commit": source_commit,
        "generator": {"name": GENERATOR_NAME, "version": GENERATOR_VERSION},
        "architecture_config_identity": prod.identity_hash,
        "profile_identity": "BG1_Z384_iLS1_layers_0_1_2_3",
        "qc_direction": {
            "check_lane_k_reads": "canonical_lane_(k+s)_mod_Z",
            "canonical_lane_k_reads_inverse": "check_lane_(k-s)_mod_Z",
        },
        "rows": [
            {
                "layer_id": edge.layer_id,
                "local_edge_id": edge.edge_id,
                "app_column": edge.column,
                "shift": edge.shift,
            }
            for layer in graph.layers
            for edge in layer.edges
        ],
    }

    profile_metadata = {
        "artifact_type": "profile_metadata",
        "format": "production_profile_metadata_v1",
        "source_repository_commit": source_commit,
        "generator": {"name": GENERATOR_NAME, "version": GENERATOR_VERSION},
        "architecture_config_identity": prod.identity_hash,
        "profile": {
            "base_graph": prod.reference_BG,
            "Z": prod.reference_Z,
            "iLS": prod.reference_iLS,
            "active_layers": list(prod.reference_active_layers),
            "layer_order": list(prod.reference_layer_order),
            "base_graph_source_path": graph.source_path,
            "base_graph_source_url": graph.source_url,
            "base_graph_source_commit": graph.source_commit,
            "base_graph_source_note": graph.source_note,
        },
        "expected_schedule_metrics": schedule_artifact["expected_metrics"],
        "syndrome": {
            "S": prod.syndrome_S,
            "Q": prod.syndrome_Q,
            "first_final_cycle": syndrome.first_final_cycle,
            "last_final_cycle": syndrome.last_final_cycle,
            "completion_cycle": syndrome.syndrome_completion_cycle,
            "required_queue_depth": syndrome.required_queue_depth,
        },
    }

    artifact_specs = (
        ("schedule_program", out_dir / "schedule_program.json", schedule_artifact, len(program)),
        ("qc_shift_table", out_dir / "qc_shift_table.json", qc_shift_table, len(qc_shift_table["rows"])),
        ("profile_metadata", out_dir / "profile_metadata.json", profile_metadata, 1),
    )
    for _, path, data, _ in artifact_specs:
        write_json(path, data)

    profile_identity = {
        "base_graph": prod.reference_BG,
        "Z": prod.reference_Z,
        "iLS": prod.reference_iLS,
        "active_layers": list(prod.reference_active_layers),
        "layer_order": list(prod.reference_layer_order),
    }
    manifest = {
        "manifest_type": "production_v1_artifact_manifest",
        "source_repository_commit": source_commit,
        "generator": {"name": GENERATOR_NAME, "version": GENERATOR_VERSION},
        "architecture_configuration_identity": {
            "sha256": prod.identity_hash,
            "content": prod.identity_dict(),
        },
        "profile_identity": {
            "sha256": sha256_json(profile_identity),
            "content": profile_identity,
        },
        "validation_flow": [
            "Construct ProductionV1Config; do not consume config.architecture.ArchitectureConfig defaults.",
            "Validate converted ArchitectureConfig against frozen production-v1 fields.",
            "Load checked-in actual 3GPP BG1 Z=384 iLS=1 active layers 0..3.",
            "Generate selected layer-order schedule for 1-3-2-0.",
            "Generate packed 72-bit issue program and QC shift table as JSON artifacts.",
            "Hash every artifact with SHA-256 over deterministic JSON bytes.",
            "Check expected decoder cycles, syndrome tail, and effective boundary.",
        ],
        "expected_schedule_metrics": schedule_artifact["expected_metrics"],
        "artifacts": [
            {
                "kind": kind,
                "path": str(path.relative_to(ROOT)).replace("\\", "/"),
                "sha256": file_sha256(path),
                "size_bytes": path.stat().st_size,
                "record_count": record_count,
            }
            for kind, path, _, record_count in artifact_specs
        ],
    }
    write_json(out_dir / "artifact_manifest.json", manifest)
    return {
        "manifest": manifest,
        "result": result,
        "syndrome": syndrome,
        "graph": graph,
    }


def write_report(
    out_dir: Path,
    source_commit: str,
    qc_summary: dict[str, int],
    artifact_info: dict[str, Any],
) -> Path:
    prod = PRODUCTION_V1
    result = artifact_info["result"]
    syndrome = artifact_info["syndrome"]
    graph = artifact_info["graph"]
    manifest = artifact_info["manifest"]

    oq01_closed = qc_summary["profile_count"] > 0
    oq03_closed = True
    oq13_closed = (
        result.metrics.cycles_per_iteration == prod.reference_decoder_cycles
        and syndrome.additional_tail_cycles == prod.reference_syndrome_tail
        and syndrome.effective_iteration_boundary == prod.reference_effective_boundary
        and syndrome.valid
        and len(manifest["artifacts"]) == 3
    )
    category_a_closed = oq01_closed and oq03_closed and oq13_closed

    lines = [
        "# Category-A RTL Handoff Closure",
        "",
        "This report treats the attached Canonical RTL Implementation Specification v1.1 as source material only. The executed instructions are the user-requested Category-A closure tasks.",
        "",
        "No production RTL was written. The decoder architecture, scheduler, fixed-point widths, forwarding, syndrome architecture, P/B, and D_A/D_R were not redesigned.",
        "",
        "## Source Baseline",
        "",
        f"- Source repository commit: `{source_commit}`.",
        f"- Generator: `{GENERATOR_NAME}` version `{GENERATOR_VERSION}`.",
        "",
        "## OQ-01 - QC Direction Verification",
        "",
        f"Status: `{'CLOSED' if oq01_closed else 'UNRESOLVED'}`.",
        "",
        "Frozen Python convention:",
        "",
        "```text",
        "check[k] = canonical[(k+s) mod Z]",
        "canonical[k] = check[(k-s) mod Z]",
        "```",
        "",
        f"- Checked-in matrix profiles verified: `{qc_summary['profile_count']}`.",
        f"- Forward/inverse identity graph-shift cases: `{qc_summary['identity_shift_count']}`.",
        f"- Independent scalar syndrome vectors: `{qc_summary['syndrome_vector_count']}`.",
        "- Evidence: `results/rtl_handoff_category_a/qc_direction_tests.csv`.",
        "",
        "The prototype RTL is not treated as authoritative for this closure. The Python direction is ready to be labeled `FROZEN`.",
        "",
        "## OQ-03 - Input Quantization Boundary",
        "",
        f"Status: `{'CLOSED' if oq03_closed else 'UNRESOLVED'}`.",
        "",
        "Production v1 freezes channel gain `1.32` outside the decoder core. The decoder core accepts already-quantized signed `CH6` values and initializes:",
        "",
        "```text",
        "APP_initial = sat8(CH6 << 1)",
        "```",
        "",
        "The upstream demapper/rate-recovery environment is responsible for:",
        "",
        "```text",
        "CH6 = sat6(round_to_nearest_even(1.32 * real_LLR))",
        "```",
        "",
        "Production decoder RTL must not implement a `1.32` multiplier or nearest-even real-LLR quantizer.",
        "",
        "## OQ-13 - Frozen V1 Configuration / Artifact Flow",
        "",
        f"Status: `{'CLOSED' if oq13_closed else 'UNRESOLVED'}`.",
        "",
        "A dedicated production-v1 model/tooling representation is defined in `ldpc_sim/production_v1.py`. Historical `config/architecture.py` defaults remain available for exploration, but production artifact tooling validates and rejects those defaults.",
        "",
        "Frozen production v1 configuration:",
        "",
        f"- `P={prod.P}`, `B={prod.B}`, `D_A={prod.D_A}`, `D_R={prod.D_R}`.",
        f"- APP banks `{prod.num_app_banks}`, forward depth `{prod.forward_cache_depth}`, ACC contexts `{prod.num_acc_contexts}`.",
        f"- Syndrome `S={prod.syndrome_S}`, `Q={prod.syndrome_Q}`.",
        f"- Width family F: `CH={prod.w_CH}`, `APP={prod.w_APP}`, `q={prod.w_q}`, `M={prod.w_M}`.",
        f"- Gain `{prod.channel_gain}`, CH-to-APP shift `{prod.ch_to_app_shift}`, beta_int `{prod.beta_int}`.",
        f"- Saturation rule `{prod.saturation_rule}`.",
        f"- Reference BG/Z/iLS: BG{prod.reference_BG}, Z={prod.reference_Z}, iLS={prod.reference_iLS}.",
        f"- Active layers `{prod.reference_active_layers}`, layer order `{prod.reference_layer_order}`.",
        f"- Decoder cycles `{result.metrics.cycles_per_iteration}`, syndrome tail `{syndrome.additional_tail_cycles}`, effective boundary `{syndrome.effective_iteration_boundary}`.",
        f"- Iteration policy `{prod.iteration_policy}`.",
        "",
        "Deterministic artifacts generated for the reference profile:",
        "",
        "- `results/rtl_handoff_category_a/schedule_program.json`.",
        "- `results/rtl_handoff_category_a/qc_shift_table.json`.",
        "- `results/rtl_handoff_category_a/profile_metadata.json`.",
        "- `results/rtl_handoff_category_a/artifact_manifest.json`.",
        "",
        "The manifest records source commit, generator identity, architecture configuration identity, profile identity, SHA-256 checksums, and expected schedule metrics. No RTL ROM modules were built.",
        "",
        "Still-open Category B/C/D items were not assigned production values in this closure.",
        "",
        "## Category-A Status",
        "",
        f"`CATEGORY A = {'CLOSED' if category_a_closed else 'UNRESOLVED'}`.",
        "",
        "## Base-Graph Source",
        "",
        f"- {graph.source_note}",
    ]
    report_path = out_dir / "category_a_closure_report.md"
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return report_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Close Category-A RTL handoff evidence.")
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=ROOT / "results" / "rtl_handoff_category_a",
    )
    args = parser.parse_args()

    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    source_commit = repo_head_commit(ROOT)
    qc_rows, qc_summary = run_qc_direction_evidence()
    write_csv(
        out_dir / "qc_direction_tests.csv",
        qc_rows,
        [
            "oq",
            "test_name",
            "status",
            "profile",
            "base_graph",
            "iLS",
            "Z",
            "shift",
            "vector_count",
            "edge_count",
            "details",
        ],
    )
    artifact_info = build_production_artifacts(out_dir, source_commit)
    report_path = write_report(out_dir, source_commit, qc_summary, artifact_info)
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
