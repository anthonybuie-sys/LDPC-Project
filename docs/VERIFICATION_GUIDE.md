# Verification And Reproduction Guide

This guide explains how the decoder was verified and how to reproduce the
release checks. The repository itself is the authority for commands and
artifacts; the Canonical RTL Implementation Specification v1.1 remains the
normative design contract.

## Verification Ladder

The project uses a staged ladder so each production block is proven before it
is integrated:

```text
Python numerical and scheduler reference
Phase 1 arithmetic primitives
Phase 2 QC permutation
Phase 2 Python QC cross-check
Phase 3 compressed C2V reconstruction
Phase 4 ACC min-update and ACC pipeline
Phase 5 REC pipeline
Phase 6 q scratch and check-state storage integration
Phase 7 APP memory and JIT forwarding integration
Phase 8 streaming syndrome and iteration decision
Phase 9 schedule controller and full decoder core
Verilator static elaboration/lint
Yosys generic synthesis
Yosys xcup bounded checkpoint
```

## Accepted Release Results

```text
Full Python regression: 76 passed
Phase 1 through Phase 9 RTL: PASS
Verilator lint/elaboration: PASS
Yosys generic synthesis: PASS
Yosys xcup bounded checkpoint: PASS
```

Preserved timing and metrics:

```text
decoder issue window = 71 cycles
syndrome boundary = 72 cycles
one-iteration controller done = 73 cycles
retry PC0-to-PC0 = 74 cycles
```

Phase 9 three-iteration evidence:

```text
PC0 sequence = 0,74,148
terminal done = 221
epochs = 0,1,2
generation advances = 2
ACC = 120 issues / 228 edges
REC = 120 issues / 228 edges
```

## Tool Setup

The portable scripts resolve tools from environment variables or `PATH`:

```powershell
$env:PYTHON = "python"
$env:IVERILOG = "iverilog"
$env:VVP = "vvp"
$env:OSS_CAD_SUITE = "<path-to-oss-cad-suite>"
$env:YOSYS = "yosys"
$env:VERILATOR = "verilator_bin.exe"
```

When using OSS CAD Suite on Windows:

```powershell
. "$env:OSS_CAD_SUITE\environment.ps1"
```

The scripts write local logs and simulator binaries under `results/`; generated
logs and `*.vvp` files are ignored by git unless intentionally tracked.

## One-Command Release Checks

Python only:

```powershell
.\scripts\run_python_regression.ps1
```

Phase 9 selected-case sweep only:

```powershell
.\scripts\run_phase9_regression.ps1
```

RTL Phase 1 through Phase 9:

```powershell
.\scripts\run_full_rtl_regression.ps1
```

Python plus RTL:

```powershell
.\scripts\run_full_regression.ps1
```

Verilator:

```powershell
.\scripts\run_verilator.ps1
```

Yosys generic:

```powershell
.\scripts\run_yosys_generic.ps1
```

Yosys xcup bounded checkpoint:

```powershell
.\scripts\run_yosys_xcup_checkpoint.ps1
```

## What Each Layer Proves

### Python Numerical And Scheduler Reference

The Python tests cover real BG1/BG2 graph loading, schedule construction,
fixed-point behavior, syndrome queue modeling, packed schedule encoding, and
regression fixtures. The accepted release count is `76 passed`.

### Phase 1: Arithmetic

Phase 1 verifies signed saturation, q subtraction, q magnitude, beta offset,
C2V reconstruction, APP addition, and channel-to-APP initialization. It proves
the fixed-point semantics used by later stages.

Expected:

```text
PASS phase1 arithmetic primitives
```

### Phase 2: QC Permutation

Phase 2 verifies the production lane packing and rotation equations:

```text
forward: check[k] = canonical[(k+s) mod 384]
inverse: canonical[k] = check[(k-s) mod 384]
```

The independent Python cross-check verifies 14208 observed SV lane rows.

Expected:

```text
PASS phase2 qc permutation
PASS
14208 observed SV lane rows checked
```

### Phase 3: C2V Reconstruction

Phase 3 verifies compressed C2V reconstruction from M1/M2/Imin/aggregate sign
and q sign, including scalar and vector scoreboards.

Expected:

```text
PASS phase3 compressed c2v reconstruction
scalar_cases=32768
vector_cases=116
explicit_edges_checked=96
```

### Phase 4: ACC

Phase 4 verifies order-independent min update and the ACC pipeline. It covers
reduced-P directed tests and accepted P=384 high-rate cases.

Expected key results:

```text
PASS phase4 acc min-update exhaustive
order_independence_cases=16384
high_rate_acc_issue_cycles=40
high_rate_active_edges=76
```

### Phase 5: REC

Phase 5 verifies REC reconstruction, APP update, final-touch propagation, and
alignment of q/state responses. The strengthened alignment test preserves the
numeric association among consecutive II=1 REC tokens.

Expected key results:

```text
PASS phase5 rec pipeline
directed_cases=21
high_rate_rec_issue_cycles=40
high_rate_active_edges=76
```

### Phase 6: Storage Integration

Phase 6 verifies q scratch, compressed check-state storage, ACC/REC
integration, distinct-payload behavior, close boundaries, invalid q slots, and
safe/unsafe generation advance.

Expected key results:

```text
PASS phase6 acc rec storage
directed_cases=20
selected_numeric_checks=60
distinct_payload_checks=50
close_boundary_checks=4
decoder_cycles=71
```

### Phase 7: APP Memory And Forwarding

Phase 7 verifies APP memory, forward-cache allocation/read/publication, c+3
forward visibility, c+4 ordinary APP visibility, same-bank collisions, and
source-mode accounting.

Expected key results:

```text
PASS phase7 app forward integration
numerical_dependency_checks=32
forward_allocations=50
forwarded_reads=27
normal_reads=49
max_live_forward_entries=8
same_bank_collisions=4
decoder_cycles=71
```

### Phase 8: Streaming Syndrome

Phase 8 verifies final-touch streaming syndrome behavior, queue occupancy,
backlog, row scoreboard matching, and iteration decision boundaries.

Expected key results:

```text
PASS phase8 streaming syndrome
syndrome_directed_cases=17
decision_cases=33
integrated_cases=2
first_final_touch_cycle=53
last_final_touch_cycle=71
syndrome_completion_cycle=72
syndrome_tail=1
effective_boundary=72
```

### Phase 9: Controller And Full Core

Phase 9 verifies the generated schedule controller, APP load coverage, abort
and error cases, full-core positive and mixed-sign integrated cases, retry,
and three-iteration generation ping-pong reuse.

The selected-case sweep uses `+phase9_case=1` through `+phase9_case=14`
because the monolithic P=384 all-case run is much slower under Icarus.

Expected key results:

```text
PASS phase9 decoder core controller
one_iteration_terminal_done=73
pc0_sequence=0/74/148
terminal_done=221
generation_advances=2
epochs=0/1/2
acc_issues=120 rec_issues=120 acc_edges=228 rec_edges=228
decoder_schedule_cycles=71 syndrome_completion_cycle=72 syndrome_decision_cycle=73 controller_retry_pc0_to_pc0=74
```

### Verilator

Verilator checks static elaboration/lint over the full production hierarchy.
The accepted report classifies remaining `-Wall` warnings as intentional
debug/interface/naming-shape warnings, with no latch, width, multiple-driver,
or fatal warnings remaining.

### Yosys Generic Synthesis

Yosys with `read_slang` elaborates and synthesizes the full production core:

```text
Build succeeded: 0 errors, 0 warnings
Found and reported 0 problems
memories = 38
memory bits = 3023808
cells = 145928
```

### Yosys xcup Bounded Checkpoint

The xcup run is an UltraScale+ technology-mapping stress check, not a
target-device place-and-route result. The bounded pre-memory checkpoint passes
and preserves:

```text
memories = 38
memory bits = 3023808
```

No XCZU67DR Fmax, post-route timing, vendor utilization, or power result is
claimed.

## Regression Discipline

Do not weaken a testbench, expected count, scoreboard, timing assertion, or
error-injection case to make a later RTL change pass. If a future change fails
one of these checks, decide whether it is a real RTL bug, a changed frozen
contract requiring architecture review, or a testbench issue with independent
evidence.
