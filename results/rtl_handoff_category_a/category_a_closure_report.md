# Category-A RTL Handoff Closure

This report treats the attached Canonical RTL Implementation Specification v1.1 as source material only. The executed instructions are the user-requested Category-A closure tasks.

No production RTL was written. The decoder architecture, scheduler, fixed-point widths, forwarding, syndrome architecture, P/B, and D_A/D_R were not redesigned.

## Source Baseline

- Source repository commit: `7e1e07f9c2a3f8722cf48ada49521736435ea89e`.
- Generator: `scripts/close_rtl_handoff_category_a.py` version `1`.

## OQ-01 - QC Direction Verification

Status: `CLOSED`.

Frozen Python convention:

```text
check[k] = canonical[(k+s) mod Z]
canonical[k] = check[(k-s) mod Z]
```

- Checked-in matrix profiles verified: `102`.
- Forward/inverse identity graph-shift cases: `5792`.
- Independent scalar syndrome vectors: `306`.
- Evidence: `results/rtl_handoff_category_a/qc_direction_tests.csv`.

The prototype RTL is not treated as authoritative for this closure. The Python direction is ready to be labeled `FROZEN`.

## OQ-03 - Input Quantization Boundary

Status: `CLOSED`.

Production v1 freezes channel gain `1.32` outside the decoder core. The decoder core accepts already-quantized signed `CH6` values and initializes:

```text
APP_initial = sat8(CH6 << 1)
```

The upstream demapper/rate-recovery environment is responsible for:

```text
CH6 = sat6(round_to_nearest_even(1.32 * real_LLR))
```

Production decoder RTL must not implement a `1.32` multiplier or nearest-even real-LLR quantizer.

## OQ-13 - Frozen V1 Configuration / Artifact Flow

Status: `CLOSED`.

A dedicated production-v1 model/tooling representation is defined in `ldpc_sim/production_v1.py`. Historical `config/architecture.py` defaults remain available for exploration, but production artifact tooling validates and rejects those defaults.

Frozen production v1 configuration:

- `P=384`, `B=2`, `D_A=3`, `D_R=3`.
- APP banks `8`, forward depth `8`, ACC contexts `2`.
- Syndrome `S=8`, `Q=8`.
- Width family F: `CH=6`, `APP=8`, `q=8`, `M=6`.
- Gain `1.32`, CH-to-APP shift `1`, beta_int `1`.
- Saturation rule `asymmetric_twos_complement`.
- Reference BG/Z/iLS: BG1, Z=384, iLS=1.
- Active layers `(0, 1, 2, 3)`, layer order `(1, 3, 2, 0)`.
- Decoder cycles `71`, syndrome tail `1`, effective boundary `72`.
- Iteration policy `non_speculative`.

Deterministic artifacts generated for the reference profile:

- `results/rtl_handoff_category_a/schedule_program.json`.
- `results/rtl_handoff_category_a/qc_shift_table.json`.
- `results/rtl_handoff_category_a/profile_metadata.json`.
- `results/rtl_handoff_category_a/artifact_manifest.json`.

The manifest records source commit, generator identity, architecture configuration identity, profile identity, SHA-256 checksums, and expected schedule metrics. No RTL ROM modules were built.

Still-open Category B/C/D items were not assigned production values in this closure.

## Category-A Status

`CATEGORY A = CLOSED`.

## Base-Graph Source

- ACTUAL 5G NR BG1 DATA from https://github.com/manuts/NR-LDPC-BG commit 910ecbc9e81d43e318079aec535dc9a166a76b2a; file NR_1_1_384.txt; iLS=1; Z=384.
