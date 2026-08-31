# Final Decoder Report

## Status

The production RTL decoder core is functionally complete for the frozen
reference profile:

```text
5G NR QC-LDPC layered Offset Min-Sum
BG1, Z=384, iLS=1, active layers 0..3
layer order = 1,3,2,0
P=384, B=2, DA=3, DR=3
ACC II=1, REC II=1
APP banks=8, forward cache depth=8
syndrome S=8, syndrome Q=8
```

The core top is `rtl/core/nr_ldpc_decoder_core.sv`.

## Fixed-Point Definition

The frozen numerical family is F:

```text
CH = 6
APP = 8
q = 8
M = 6
channel gain = 1.32
channel-to-APP shift = 1
beta_int = 1
asymmetric two's-complement saturation
```

Production RTL Phase 1 preserves:

- `APP_initial = sat8(CH6 << 1)`
- `q = sat8(APP - oldC2V)`
- `q = -128` has magnitude 128 and clips to M6 63
- `beta = max(raw_mag - 1, 0)`
- C2V negative zero suppression
- `APP = sat8(q + C2V)`

## Datapath Blocks

- ACC: `rtl/acc/nr_ldpc_acc_pipeline.sv`
- REC: `rtl/rec/nr_ldpc_rec_pipeline.sv`
- QC permutation: `rtl/qc/nr_ldpc_qc_permute.sv`
- APP memory: `rtl/storage/nr_ldpc_app_memory.sv`
- JIT forwarding: `rtl/storage/nr_ldpc_forward_cache.sv` and
  `rtl/core/nr_ldpc_app_forward_datapath.sv`
- q scratch: `rtl/storage/nr_ldpc_q_scratch.sv`
- compressed check state: `rtl/storage/nr_ldpc_check_state_store.sv`
- syndrome engine: `rtl/syndrome/nr_ldpc_syndrome_engine.sv`
- controller: `rtl/control/nr_ldpc_schedule_controller.sv`
- top-level core: `rtl/core/nr_ldpc_decoder_core.sv`

## Schedule Generation

The frozen controller profile is generated from Category-A/B artifacts and the
real BG1 Z=384 graph. It contains 71 packed 72-bit issue words, each holding one
36-bit ACC and one 36-bit REC microinstruction.

Important files:

- `scripts/generate_phase9_controller_profile.py`
- `rtl/control/nr_ldpc_controller_profile_bg1_first4.sv`
- `results/rtl_handoff_category_a/schedule_program.json`
- `results/rtl_handoff_category_b/schedule_contract_evidence.json`

## Iteration, Epoch, And Generation Behavior

- First iteration epoch: 0.
- Retry epochs: 1, then 2, etc.
- Phase 6 storage keeps old/new physical generations.
- The Phase 9 datapath adapter translates only the internal ACC old-generation
  lookup epoch to the previous iteration after iteration 0.
- ACC new-generation writes, REC reads/publications, APP forwarding, and
  syndrome final-touch metadata use the current issue epoch.
- The three-iteration deterministic mixed-sign test proves physical generation
  ping-pong reuse over epochs 0/1/2.

## Early Termination

For the reference profile:

```text
finalized columns = 26
syndrome work items = 76
first final touch = cycle 53
last final touch = cycle 71
max queue occupancy = 2
max backlog = 7
syndrome completion = cycle 72
syndrome tail = 1
```

`nr_ldpc_iteration_decide` terminates on syndrome zero, terminates on
max-iteration count, or requests retry. `max_iterations=0` is illegal; 1, 2,
12, and 15 are verified boundary values.

## Error And Abort Behavior

The core latches fatal errors until reset/clear and suppresses architectural
publication on malformed transactions. Coverage includes illegal start, illegal
max iterations, duplicate/missing APP load, decode errors, issue while not
ready, q scratch errors, check-state epoch errors, unsafe generation advance,
APP memory errors, forwarding errors, syndrome epoch/coverage errors, and
controller errors.

Synchronous abort suppresses further ACC/REC issue, clears in-flight datapath
state, suppresses terminal result publication, returns to IDLE-safe state, and
sets `aborted_o`.

## Measured Cycle Latency

```text
decoder issue window = 71 cycles
syndrome boundary = 72 cycles
one-iteration controller done = 73 cycles
retry PC0-to-PC0 spacing = 74 cycles
```

Physical time remains:

```text
71 / Fclock
72 / Fclock
73 / Fclock
74 / Fclock
```

`Fclock` awaits a supported target FPGA implementation flow.

XCZU67DR post-route Fmax = NOT MEASURED.

## Verification

Functional regression status:

```text
Phase 1: PASS phase1 arithmetic primitives
Phase 2: PASS phase2 qc permutation
Phase 2 Python QC: PASS, 14208 observed SV lane rows checked
Phase 3: PASS phase3 compressed c2v reconstruction
  scalar_cases=32768, vector_cases=116, explicit_edges_checked=96
Category B: CATEGORY B CLOSED - INTEGRATED DATAPATH RTL AUTHORIZED
Phase 4: PASS, order_independence_cases=16384, high-rate 40/76
Phase 5: PASS, high-rate 40/76
Phase 6: PASS, decoder_cycles=71, ACC/REC high-rate 40/76
Phase 7: PASS, decoder_cycles=71, max live forward entries=8
Phase 8: PASS, syndrome completion=72, syndrome tail=1
Phase 9: PASS selected-case sweep including three-iteration ping-pong reuse
Full Python: 76 passed
```

Phase 9 key integrated results:

```text
one iteration terminal done = 73
two-iteration PC0 sequence = 0,74
two-iteration terminal done = 147
three-iteration PC0 sequence = 0,74,148
three-iteration terminal done = 221
generation advances = 2
epochs = 0,1,2
ACC = 120 issues / 228 edges
REC = 120 issues / 228 edges
```

## Verilator

Verilator static elaboration/lint completed on the full production hierarchy.
Remaining `-Wall` warnings are classified as intentional interface/debug
visibility or naming-style warnings. No latch, width, multiple-driver, or fatal
warnings remain.

Report: `results/free_tool_validation/verilator_report.md`

## Yosys Generic Synthesis

Yosys with `read_slang` completed generic synthesis/elaboration:

```text
Build succeeded: 0 errors, 0 warnings
Found and reported 0 problems
memories = 38
memory bits = 3023808
cells = 145928
```

Report: `results/free_tool_validation/yosys_generic_report.md`

## Yosys xcup Mapping

Yosys `synth_xilinx -family xcup` was run as an UltraScale+ mapping analysis.
The design elaborates cleanly and passes a bounded pre-memory xcup checkpoint.
The full primitive-mapping run does not complete on this host/toolchain: one
run stalls in memory mapping and the no-implicit-memory run terminates with
`std::bad_alloc`.

No complete LUT/FF/BRAM/DSP/SRL YOSYS TECHNOLOGY-MAPPED ESTIMATE is claimed for
the full core. The available xcup evidence is a structural checkpoint, not final
mapped utilization.

Report: `results/free_tool_validation/yosys_xcup_report.md`

## Physical-Flow Limitation

This project is constrained to 100% free/open-source tooling. Vivado was not
used, no proprietary implementation artifact is claimed, and no paid/eval
license was requested.

Authoritative source anchors:

- Yosys documentation: `https://yosyshq.readthedocs.io/`
- OSS CAD Suite: `https://github.com/YosysHQ/oss-cad-suite-build`
- Project X-Ray: `https://github.com/f4pga/prjxray`
- Project U-Ray: `https://github.com/f4pga/prjuray`

Open-source Yosys synthesis and xcup technology-mapping support are available.
However, this validation does not establish authoritative XCZU67DR
placement/routing, static timing analysis, post-route Fmax, vendor utilization,
or post-route power. That is a tooling/platform validation limitation, not a
functional decoder failure.

## Remaining External Integration

- PCIe/DMA and host-visible buffering are not implemented in this decoder core.
- General-Z support, complete 5G rate matching, filler handling, and multi-code
  block throughput are outside the frozen reference RTL.
- Target-device physical implementation, timing closure, power, and board-level
  integration remain external work.
