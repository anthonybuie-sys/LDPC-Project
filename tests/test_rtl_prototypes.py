from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def test_rtl_prototype_required_files_exist() -> None:
    required = [
        "rtl_prototypes/common/qc_permute.sv",
        "rtl_prototypes/reconstruction/reconstruction_dr3.sv",
        "rtl_prototypes/reconstruction/reconstruction_dr4.sv",
        "rtl_prototypes/accumulation/accumulation_da3.sv",
        "rtl_prototypes/accumulation/accumulation_da4.sv",
        "rtl_prototypes/forwarding/forward_cache_8.sv",
        "rtl_prototypes/app_memory/app_lut8_model.sv",
        "rtl_prototypes/combined/da3_dr3_datapath.sv",
        "rtl_prototypes/combined/da4_dr4_datapath.sv",
        "rtl_prototypes/scripts/synth_reconstruction.tcl",
        "rtl_prototypes/scripts/synth_accumulation.tcl",
        "rtl_prototypes/scripts/synth_forwarding.tcl",
        "rtl_prototypes/scripts/synth_combined.tcl",
        "results/rtl_prototypes/experiment_log.md",
    ]
    for path in required:
        assert (ROOT / path).exists(), path


def test_vector_generator_outputs_reference_vectors() -> None:
    output_dir = ROOT / "results" / "rtl_prototypes" / "test_vectors"
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    subprocess.run(
        [
            sys.executable,
            str(ROOT / "rtl_prototypes" / "scripts" / "generate_vectors.py"),
            "--cases",
            "4",
            "--output-dir",
            str(output_dir),
        ],
        check=True,
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    recon_path = output_dir / "reconstruction_vectors.jsonl"
    accum_path = output_dir / "accumulation_vectors.jsonl"
    recon = [json.loads(line) for line in recon_path.read_text(encoding="utf-8").splitlines()]
    accum = [json.loads(line) for line in accum_path.read_text(encoding="utf-8").splitlines()]
    assert len(recon) == 4
    assert len(accum) == 4
    assert "expected" in recon[0]
    assert "expected" in accum[0]
    assert len(recon[0]["q_a"]) == 384
    assert len(accum[0]["app_a"]) == 384


def test_rtl_simulations_pass_when_iverilog_is_available() -> None:
    if shutil.which("iverilog") is None or shutil.which("vvp") is None:
        return
    result = subprocess.run(
        [
            "powershell",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "rtl_prototypes" / "scripts" / "run_sim.ps1"),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=True,
    )
    assert "PASS reconstruction" in result.stdout
    assert "PASS accumulation" in result.stdout
    assert "PASS forwarding/app" in result.stdout


def test_vivado_scripts_query_target_part_and_do_not_guess_results() -> None:
    common = (ROOT / "rtl_prototypes" / "scripts" / "synth_common.tcl").read_text(
        encoding="utf-8"
    )
    log = (ROOT / "results" / "rtl_prototypes" / "experiment_log.md").read_text(
        encoding="utf-8"
    )
    assert "get_parts -quiet *zu67dr*fsve1156*-2*" in common
    assert "Vivado is unavailable" in log
    assert "No timing or resource values have been fabricated" in log
