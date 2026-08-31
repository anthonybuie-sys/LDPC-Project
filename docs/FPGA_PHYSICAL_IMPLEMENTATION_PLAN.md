# FPGA Physical Implementation Plan

This is a future-work plan. It is not a completed physical implementation
result. The decoder RTL core is functionally complete, but XCZU67DR-specific
placement/routing, timing closure, post-route Fmax, vendor utilization, and
power are not measured in this repository.

## Objective

Optimize real physical latency:

```text
latency_ns = cycles / Fclock
```

Do not optimize cycle count in isolation if the resulting architecture reduces
Fclock enough to increase latency in nanoseconds. The accepted functional
cycle counts are:

```text
decoder issue window = 71
syndrome boundary = 72
one-iteration done = 73
retry PC0-to-PC0 = 74
```

## Starting Point

Frozen architecture:

```text
P=384, B=2, DA=3, DR=3
APP banks=8
forward cache depth=8
syndrome S=8, Q=8
layer order=1,3,2,0
```

Open-source checks completed:

```text
Verilator lint/elaboration: PASS
Yosys generic synthesis: PASS
Yosys xcup bounded checkpoint: PASS
```

Yosys generic reports 38 memories, 3023808 memory bits, and 145928 generic
cells. These are not vendor utilization numbers.

## Physical Flow

### 1. Synthesis

- Compile the production source list package/profile first.
- Preserve SystemVerilog package/import semantics.
- Confirm no inferred latches, multiple drivers, or unsupported constructs.
- Preserve memory payload arrays without unintended bulk reset.
- Check that debug-only outputs do not prevent useful optimization in a
  production build variant.

### 2. Memory Inference Review

Inspect how each logical memory maps:

- APP memory: active-column canonical APP storage.
- q scratch: two buffers by q slot and B lane.
- compressed check-state store: M1/M2/Imin/aggregate sign and q signs.
- forward cache: eight full-vector entries plus tags.
- controller/profile data: generated static schedule and metadata.
- syndrome queue/profile: finalized-column queue and row work mapping.

Questions to answer:

- Which arrays infer BRAM, URAM, LUTRAM, or registers?
- Are read/write ports sufficient for the accepted timing?
- Does APP read-during-write behavior match the c+4 ordinary visibility
  contract?
- Are q and check-state generations preserved exactly?
- Are memories duplicated unintentionally by wide muxing or debug visibility?

### 3. Timing Constraints

- Define the core clock and reset assumptions.
- Add false-path or multicycle constraints only with design evidence.
- Keep CDC outside the core unless a wrapper introduces separate clock domains.
- Constrain input/output interfaces according to the eventual accelerator
  shell.

### 4. Placement

Physically cluster:

- ACC pipeline near q scratch and check-state read/write structures.
- REC pipeline near check-state/q reads and APP writeback.
- APP memory and forward cache near APP source selection muxing.
- Syndrome engine near final-touch outputs.
- Controller/profile logic where fanout to ACC/REC can be managed.

### 5. Routing

Focus on the wide 384-lane paths:

- APP to QC forward rotate.
- REC R2 inverse rotate to APP memory and forward cache.
- final-touch hard-bit vectors to syndrome.
- q scratch B-lane vectors.
- check-state packed M1/M2/Imin/sign outputs.

### 6. Static Timing Analysis

Analyze:

- ACC A0 APP/forward selection plus QC forward rotate.
- ACC A1 old-C2V reconstruction and q arithmetic.
- ACC A2 min update and compressed-state close.
- REC R0 C2V reconstruction.
- REC R1 APP add/saturation.
- REC R2 inverse QC, APP/forward publication, final-touch hard-bit generation.
- Syndrome S=8 row XOR and queue planning.
- Controller/profile decode and issue fanout.

### 7. Critical Path Analysis

For every top critical path, classify whether it is:

- arithmetic depth,
- wide muxing,
- memory address/data timing,
- QC permutation routing,
- syndrome XOR routing,
- generated profile decode,
- high-fanout control/reset,
- debug observability,
- or a tool inference issue.

Architecture-preserving fixes should be preferred before changing the frozen
cycle schedule.

### 8. Floorplanning

Only after unconstrained synthesis/place timing is understood:

- Consider pblocks or placement constraints for wide datapath regions.
- Align memory banks with consuming pipeline regions.
- Avoid floorplans that improve one path by damaging the APP/forward path.
- Re-run full functional regression after any RTL wrapper or hierarchy change.

### 9. Fmax Optimization

Permitted future options must preserve functional behavior unless a new
architecture review explicitly changes the contract:

- Vendor memory wrappers preserving c+3/c+4 visibility.
- Register duplication for high-fanout control.
- Hierarchy attributes for memory and mux containment.
- Debug-output pruning in a production synthesis configuration.
- Retiming only when it preserves DA=3, DR=3 externally visible behavior.

Do not report an Fmax until target-device implementation and STA complete.

### 10. Power

Power characterization should use post-implementation switching activity where
possible. First-order estimates from generic synthesis are not adequate for a
release power claim.

## Specific Risks To Investigate

APP memory:

- Eight-bank logical mapping.
- R2 write and dependent ACC read timing.
- Potential need for explicit RAM wrappers or replication.

q scratch:

- Two-buffer, ten-slot organization.
- Release and generation semantics.
- Avoiding large FF inference.

Compressed check-state storage:

- Largest logical memory contributor.
- M1/M2/Imin/aggregate/q-sign packing.
- Old/new generation read/write locality.

APP forwarding muxing:

- 384 lanes x 8 bits per vector.
- Eight-entry forward cache lookup and tag/epoch checks.
- c+3 availability without same-edge combinational bypass.

384-lane QC routing:

- Wide barrel-style permutation networks can dominate routing delay.
- Forward and inverse networks must preserve the frozen direction.

Syndrome XOR network:

- S=8 contribution throughput.
- Row update fanout and routing from final-touch hard vectors.

Controller/profile mux structures:

- Generated schedule/profile decode can create large mux/case logic.
- Consider ROM-style implementation only if it preserves exact issue fields.

High-fanout control/reset:

- start, advance, epoch, valid, reset, and error clear signals may need
  buffering or duplication.

## Deliverables For A Future Physical Pass

- Synthesis logs and reports.
- Memory inference report.
- Timing constraints.
- Placement/routing reports.
- STA summary and failing paths.
- Fmax with exact device, part, speed grade, and tool version.
- Vendor utilization.
- Power report and activity assumptions.
- Physical issue log linking each fix to regression evidence.
