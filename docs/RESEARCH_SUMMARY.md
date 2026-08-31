# Research Summary

## Problem

5G NR QC-LDPC decoding can dominate receiver latency. A high-throughput
decoder is not enough if the architecture requires many cycles per iteration
or waits until after the iteration to begin syndrome checking.

## Design Objective

The project objective was to minimize actual decoding latency for a frozen
high-rate reference case while keeping the implementation bit-exact and
verifiable:

```text
BG1, Z=384, active layers 0,1,2,3
P=384, B=2
layer order = 1,3,2,0
```

## Headline Architecture

Dependency-Aware Dual-Block Layered OMS:

- 384-lane full-QC processing.
- Two QC edges per ACC/REC issue cycle.
- Three-stage ACC and REC pipelines.
- Static generated schedule with dependency-aware ACC/REC overlap.
- Just-in-time forwarding for c+3 APP dependencies.
- Final-touch streaming syndrome engine.
- Compressed check-state storage for Offset Min-Sum messages.

## Algorithm Selection

Layered Offset Min-Sum was chosen because layered updates reduce iteration
latency and OMS maps cleanly to fixed-point min/sign hardware. The frozen
fixed-point family is:

```text
CH6 / APP8 / q8 / M6
gain = 1.32
channel-to-APP shift = 1
beta_int = 1
asymmetric two's-complement saturation
```

## Key Innovations

- Joint schedule/control flow that overlaps ACC and REC while respecting q,
  check-state, APP bank, and forwarding constraints.
- JIT forwarding that exposes REC results at c+3 without relying on ordinary
  APP memory visibility before c+4.
- Final-touch syndrome checking that begins as soon as columns become final,
  reducing termination overhead to a one-cycle syndrome tail for the reference
  profile.
- Compressed C2V state using M1/M2/Imin/aggregate sign plus q signs, avoiding
  full C2V vector storage.
- Three-iteration ping-pong verification proving generation reuse across
  epochs 0, 1, and 2.

## Measured Cycle Latency

Functional RTL simulation measures:

```text
71 issue cycles
72 syndrome boundary
73 one-iteration done
74 retry PC0-to-PC0
```

Physical time is `cycles / Fclock`.

XCZU67DR Fmax = NOT MEASURED.

## Verification Evidence

The release passes the staged RTL verification ladder from arithmetic through
the full decoder controller. Phase 9 verifies:

```text
PC0 sequence = 0,74,148
terminal done = 221
epochs = 0,1,2
generation advances = 2
ACC = 120 issues / 228 edges
REC = 120 issues / 228 edges
```

The Python reference regression reports `76 passed`.

## Synthesis Evidence

Free/open-source validation completed:

```text
Verilator lint/elaboration: PASS
Yosys generic synthesis: PASS
Yosys xcup bounded checkpoint: PASS
```

Yosys generic synthesis reports:

```text
memories = 38
memory bits = 3023808
cells = 145928
```

The xcup result is a bounded UltraScale+ technology-mapping checkpoint. It is
not a vendor place-and-route result and does not provide authoritative device
utilization or Fmax.

## Limitations

This repository does not claim:

- XCZU67DR placement/routing, STA, post-route Fmax, power, or vendor
  utilization.
- PCIe/DMA or host accelerator wrapper implementation.
- General-Z production RTL.
- Full 5G rate matching, filler handling, or codeblock orchestration.
- Complete final primitive-mapped resource estimates for the full 384-lane
  core.

## Next Technical Step

The next step is target-device physical implementation and platform
integration: memory inference review, timing constraints, placement/routing,
critical-path analysis, Fmax/resource/power characterization, and a host/DMA
wrapper around the verified decoder core.
