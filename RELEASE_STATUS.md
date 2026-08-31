# LDPC Decoder v1.0 Release Status

## Scope

This release freezes the production RTL decoder core for the BG1 Z=384
high-rate reference profile:

```text
P=384, B=2, DA=3, DR=3
APP banks=8
forward cache depth=8
syndrome S=8, Q=8
layer order=1,3,2,0
```

Implemented algorithm: layered 5G NR QC-LDPC Offset-Min-Sum with compressed
check state, just-in-time APP forwarding, and final-touch streaming syndrome
checking.

## Functional Status

The decoder RTL core is functionally complete and verified for the frozen
reference profile.

Accepted latency:

```text
decoder issue window = 71 cycles
syndrome boundary = 72 cycles
one-iteration controller done = 73 cycles
retry PC0-to-PC0 spacing = 74 cycles
```

XCZU67DR post-route Fmax = NOT MEASURED.

## Verification Status

Required release checks:

```text
Full Python regression: 76 passed
Phase 1 through Phase 9 RTL regression: PASS
Phase 9 three-iteration retry ping-pong: PASS
Verilator lint/elaboration: PASS
Yosys generic synthesis: PASS
Yosys xcup bounded checkpoint: PASS
```

Key preserved metrics:

```text
Phase 6 decoder_cycles = 71
Phase 7 decoder_cycles = 71
Phase 8 syndrome_completion_cycle = 72
Phase 9 timing = 71/72/73/74
```

## Synthesis Status

Free/open-source validation was performed with Icarus Verilog, Verilator, and
Yosys from OSS CAD Suite. The complete core passes Verilator static
elaboration/lint and Yosys generic synthesis.

Yosys `synth_xilinx -family xcup` was used only as an UltraScale+ technology
mapping stress check. The bounded pre-memory checkpoint passes and preserves:

```text
memories = 38
memory bits = 3023808
```

Complete final primitive mapping for the full 384-lane core is not claimed in
this release.

## Not Claimed

This public release does not claim:

```text
XCZU67DR placement/routing
static timing analysis
post-route Fmax
vendor utilization
post-route power
board-level integration
PCIe/DMA integration
general-Z production RTL
complete 5G rate-matching wrapper
```

The missing target-device physical flow is a tooling/platform validation
limitation under the project's 100% free/open-source tooling constraint. It is
not a functional decoder failure.

## Reproduction Entry Points

From the repository root:

```powershell
.\scripts\run_python_regression.ps1
.\scripts\run_phase9_regression.ps1
.\scripts\run_full_rtl_regression.ps1
.\scripts\run_verilator.ps1
.\scripts\run_yosys_generic.ps1
.\scripts\run_yosys_xcup_checkpoint.ps1
```

Set `$env:PYTHON`, `$env:IVERILOG`, `$env:VVP`, `$env:OSS_CAD_SUITE`,
`$env:YOSYS`, or `$env:VERILATOR` when the desired tools are not already on
`PATH`.

## Next External Work

The next engineering boundary is platform integration: target-specific FPGA
implementation, timing closure, host interface, DMA/buffering, and board-level
system validation.
