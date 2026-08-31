# 5G NR QC-LDPC Decoder Core

This repository contains a production-oriented SystemVerilog implementation and
Python architecture/numerical model for a frozen 5G NR QC-LDPC layered
Offset-Min-Sum decoder core.

The production RTL target is intentionally narrow and fully specified:

```text
Base graph: BG1
Lifting size: Z=384
iLS: 1
Active layers: 0,1,2,3
Layer order: 1,3,2,0
Parallelism P: 384 lanes
Issue width B: 2 QC edges/cycle
ACC depth DA: 3
REC depth DR: 3
APP banks: 8
Forward cache depth: 8
Syndrome engine: S=8, Q=8
```

The core top is:

```text
rtl/core/nr_ldpc_decoder_core.sv
```

## What Is Implemented

The RTL implements the frozen high-rate decoder-core datapath and controller:

- signed fixed-point Layered OMS arithmetic
- QC forward/inverse permutation for P=Z=384
- compressed C2V reconstruction
- ACC min-update pipeline
- REC APP-update pipeline
- q scratch storage
- compressed check-state storage
- canonical APP memory
- just-in-time dependency forwarding
- final-touch streaming syndrome engine
- generated 71-cycle schedule controller
- full decoder-core top-level control, retry, done, abort, and error handling

The Python model and scripts under `ldpc_sim/`, `scripts/`, and `tests/` remain
the architecture, scheduling, numerical, and regression reference.

## Graph Data

The real BG1/BG2 graph tables are loaded from:

```text
data/NR-LDPC-BG
```

The checked-in graph source was cloned from:

```text
https://github.com/manuts/NR-LDPC-BG
```

at commit:

```text
910ecbc9e81d43e318079aec535dc9a166a76b2a
```

The production RTL reference uses `NR_1_1_384.txt`, active layers 0..3.

Synthetic scheduler fixtures remain for regression tests only and must not be
reported as 3GPP base-graph results.

## Fixed-Point Profile

The frozen numerical profile is width family F:

```text
CH = 6
APP = 8
q = 8
M = 6
channel gain = 1.32
channel-to-APP shift = 1
beta_int = 1
saturation = asymmetric two's-complement
```

Important arithmetic semantics:

- `APP_initial = sat8(CH6 << 1)`
- `q = sat8(APP - oldC2V)`
- `q = -128` converts to magnitude 128 and clips to M6 63
- `beta = max(raw_mag - 1, 0)`
- C2V negative zero is suppressed
- `APP = sat8(q + C2V)`

## RTL Layout

```text
rtl/common/       package and arithmetic primitives
rtl/qc/           QC permutation network
rtl/check_state/  compressed C2V reconstruction
rtl/acc/          ACC min-update/context/pipeline
rtl/rec/          REC pipeline
rtl/storage/      q scratch, check-state store, APP memory, forward cache
rtl/syndrome/     streaming syndrome engine and generated BG1 profile
rtl/control/      iteration decision and generated schedule controller profile
rtl/core/         integrated datapaths and decoder-core top level
rtl/tb/           phase testbenches
```

`rtl_prototypes/` contains older isolated physical-experiment kernels. Those
files are not the production decoder RTL.

## Latency

Functional RTL simulation measures:

```text
decoder issue window = 71 cycles
syndrome boundary = 72 cycles
one-iteration controller done = 73 cycles
retry PC0-to-PC0 spacing = 74 cycles
```

The accepted retry interval for this functional freeze is 74 cycles. Physical
latency is therefore:

```text
71 / Fclock
72 / Fclock
73 / Fclock
74 / Fclock
```

with `Fclock` awaiting a supported target FPGA implementation flow.

XCZU67DR post-route Fmax = NOT MEASURED.

## Verification Status

Current accepted regression evidence:

```text
Phase 1: PASS phase1 arithmetic primitives
Phase 2: PASS phase2 qc permutation
Phase 2 Python QC: PASS, 14208 observed SV lane rows checked
Phase 3: PASS phase3 compressed c2v reconstruction
  scalar_cases=32768
  vector_cases=116
  explicit_edges_checked=96
Category B: CATEGORY B CLOSED - INTEGRATED DATAPATH RTL AUTHORIZED
Phase 4: PASS phase4 ACC, order_independence_cases=16384
Phase 5: PASS phase5 REC
Phase 6: PASS phase6 storage, decoder_cycles=71
Phase 7: PASS phase7 APP forwarding, decoder_cycles=71
Phase 8: PASS phase8 streaming syndrome, syndrome_completion_cycle=72
Phase 9: PASS selected-case decoder-core sweep including three-iteration retry
Full Python: 76 passed
```

Phase 9 verifies:

```text
one-iteration terminal done = 73
two-iteration PC0 sequence = 0,74
two-iteration terminal done = 147
three-iteration PC0 sequence = 0,74,148
three-iteration terminal done = 221
generation advances = 2
epochs = 0,1,2
ACC = 120 issues / 228 active edges
REC = 120 issues / 228 active edges
```

## Reproducing Python Tests

Use the bundled Python runtime if available:

```powershell
C:\Users\18324\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe tests\run_tests.py
```

Expected:

```text
76 passed
```

## Reproducing RTL Simulation

The production RTL phase tests use Icarus Verilog 12 with explicit
package-first compile order. Example Phase 1:

```powershell
iverilog -g2012 -I rtl\common `
  -o results\rtl_phase1\tb_phase1_arith.vvp `
  rtl\common\nr_ldpc_pkg.sv `
  rtl\common\nr_ldpc_arith.sv `
  rtl\tb\tb_phase1_arith.sv

vvp results\rtl_phase1\tb_phase1_arith.vvp
```

The P=384 integrated Phase 9 cases are intentionally run as selected cases:

```powershell
vvp results\rtl_phase9\tb_phase9_decoder_core.vvp +phase9_case=1
...
vvp results\rtl_phase9\tb_phase9_decoder_core.vvp +phase9_case=14
```

The monolithic all-case P=384 run repeats the same full-core reset/integration
work and is much slower under Icarus.

## Free/Open-Source Tool Validation

No Vivado result is claimed in this repository state.

The free/open-source validation used OSS CAD Suite:

```text
C:\Users\18324\.cache\oss-cad-suite-20260830
```

Recorded tools:

```text
Python 3.12.13
Icarus Verilog 12.0 devel
Verilator 5.051 devel
Yosys 0.68+136
```

See:

```text
results/free_tool_validation/toolchain_versions.md
results/free_tool_validation/verilator_report.md
results/free_tool_validation/yosys_generic_report.md
results/free_tool_validation/yosys_xcup_report.md
```

## Reproducing Yosys Generic Synthesis

In PowerShell:

```powershell
. C:\Users\18324\.cache\oss-cad-suite-20260830\environment.ps1
$env:VERILATOR_ROOT='C:\Users\18324\.cache\oss-cad-suite-20260830\share\verilator'

yosys -l results\free_tool_validation\yosys_generic.log -p "read_slang --std latest --unroll-limit 20000 --top nr_ldpc_decoder_core rtl/common/nr_ldpc_pkg.sv rtl/syndrome/nr_ldpc_syndrome_profile_bg1_first4.sv rtl/control/nr_ldpc_controller_profile_bg1_first4.sv rtl/common/nr_ldpc_arith.sv rtl/check_state/nr_ldpc_c2v_reconstruct.sv rtl/acc/nr_ldpc_acc_min_update.sv rtl/acc/nr_ldpc_acc_context.sv rtl/acc/nr_ldpc_acc_pipeline.sv rtl/rec/nr_ldpc_rec_pipeline.sv rtl/qc/nr_ldpc_qc_permute.sv rtl/storage/nr_ldpc_q_scratch.sv rtl/storage/nr_ldpc_check_state_store.sv rtl/storage/nr_ldpc_app_memory.sv rtl/storage/nr_ldpc_forward_cache.sv rtl/control/nr_ldpc_iteration_decide.sv rtl/control/nr_ldpc_schedule_controller.sv rtl/syndrome/nr_ldpc_syndrome_engine.sv rtl/core/nr_ldpc_acc_rec_datapath.sv rtl/core/nr_ldpc_app_forward_datapath.sv rtl/core/nr_ldpc_syndrome_datapath.sv rtl/core/nr_ldpc_decoder_core.sv; hierarchy -top nr_ldpc_decoder_core; proc; opt; check; stat; tee -o results/free_tool_validation/yosys_generic_stat.txt stat"
```

Observed generic result:

```text
Build succeeded: 0 errors, 0 warnings
Found and reported 0 problems
memories = 38
memory bits = 3023808
cells = 145928
```

## Reproducing Yosys xcup Analysis

Bounded UltraScale+ mapping checkpoint:

```powershell
. C:\Users\18324\.cache\oss-cad-suite-20260830\environment.ps1
$env:VERILATOR_ROOT='C:\Users\18324\.cache\oss-cad-suite-20260830\share\verilator'

yosys -l results\free_tool_validation\yosys_xcup_prememory.log -p "read_slang --std latest --unroll-limit 20000 --top nr_ldpc_decoder_core rtl/common/nr_ldpc_pkg.sv rtl/syndrome/nr_ldpc_syndrome_profile_bg1_first4.sv rtl/control/nr_ldpc_controller_profile_bg1_first4.sv rtl/common/nr_ldpc_arith.sv rtl/check_state/nr_ldpc_c2v_reconstruct.sv rtl/acc/nr_ldpc_acc_min_update.sv rtl/acc/nr_ldpc_acc_context.sv rtl/acc/nr_ldpc_acc_pipeline.sv rtl/rec/nr_ldpc_rec_pipeline.sv rtl/qc/nr_ldpc_qc_permute.sv rtl/storage/nr_ldpc_q_scratch.sv rtl/storage/nr_ldpc_check_state_store.sv rtl/storage/nr_ldpc_app_memory.sv rtl/storage/nr_ldpc_forward_cache.sv rtl/control/nr_ldpc_iteration_decide.sv rtl/control/nr_ldpc_schedule_controller.sv rtl/syndrome/nr_ldpc_syndrome_engine.sv rtl/core/nr_ldpc_acc_rec_datapath.sv rtl/core/nr_ldpc_app_forward_datapath.sv rtl/core/nr_ldpc_syndrome_datapath.sv rtl/core/nr_ldpc_decoder_core.sv; synth_xilinx -family xcup -top nr_ldpc_decoder_core -noiopad -noclkbuf -run begin:map_dsp; check; stat -tech xilinx; tee -o results/free_tool_validation/yosys_xcup_prememory_stat.txt stat -tech xilinx"
```

Observed bounded result:

```text
Build succeeded: 0 errors, 0 warnings
Found and reported 0 problems
memories = 38
memory bits = 3023808
```

Full final primitive mapping did not complete on this host/toolchain. One run
stalled in memory mapping; another no-implicit-memory run terminated with
`std::bad_alloc`. The project therefore does not claim complete YOSYS
TECHNOLOGY-MAPPED ESTIMATE numbers for LUT, FF, carry, LUTRAM, BRAM, DSP48E2,
SRL, or mux resources for the full core.

## FPGA Physical Implementation Status

The decoder RTL core is functionally complete and verified.

Free/open-source synthesis and UltraScale+ technology mapping analysis have
been performed.

XCZU67DR-specific placement/routing, timing closure, post-route Fmax, vendor
utilization, and power remain unmeasured because the required target-specific
physical implementation flow is outside the project's 100% free/open-source
tooling constraint.

This is a tooling/platform validation limitation, not a functional decoder
failure.

## Industrial Reference

The architecture studies compare against:

```text
L_IPCTEK = 78 + 133N cycles
```

For `N=6`, this is 876 cycles. The production reference core's accepted retry
spacing is 74 cycles/iteration, so iteration-dependent latency is measured in
the RTL, but physical clock frequency is not yet measured.
