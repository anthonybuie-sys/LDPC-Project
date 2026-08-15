# DA-2B-OMS RTL Prototype Kernels

This directory contains synthesis-oriented SystemVerilog prototypes for the
first physical feasibility experiments. These files are not production decoder
RTL and do not implement a complete LDPC decoder.

Target architecture experiment:

- Platform: AMD/Xilinx Zynq RFSoC DFE ZCU670
- Device family target from architect plan: `XCZU67DR-2FSVE1156I`
- `P = 384`
- `B = 2`
- APP banks: `8`
- Forward cache depth of interest: `NF = 8`

Prototype widths:

```text
PHYSICAL PROTOTYPE WIDTHS ONLY - FIXED-POINT STUDY NOT FROZEN
Z_MAX = 384
APP_W = 8
Q_W = 8
MSG_W = 6
EDGE_ID_W = 5
SHIFT_W = 9
```

## What Is Included

- Reconstruction kernels:
  - `reconstruction/reconstruction_dr3.sv`
  - `reconstruction/reconstruction_dr4.sv`
- Accumulation kernels:
  - `accumulation/accumulation_da3.sv`
  - `accumulation/accumulation_da4.sv`
- Forward cache/mux prototype:
  - `forwarding/forward_cache_8.sv`
  - `forwarding/forward_mux_wrapper.sv`
- APP distributed-memory prototype:
  - `app_memory/app_lut8_model.sv`
  - `app_memory/app_lut8_wrapper.sv`
- Limited combined datapath wrappers:
  - `combined/da3_dr3_datapath.sv`
  - `combined/da4_dr4_datapath.sv`
- Self-checking simulation testbenches under `tb/`.
- Vivado Tcl scripts under `scripts/`.

## Local Simulation

On this machine, Icarus Verilog is available. Run:

```powershell
powershell -ExecutionPolicy Bypass -File rtl_prototypes/scripts/run_sim.ps1
```

The simulations compare DR3 vs DR4 and DA3 vs DA4 numerical outputs while
accounting for the one-cycle latency difference.

## Physical Synthesis

Vivado is required for post-route resource/timing data. The Tcl scripts query
the installed part database for a matching `XCZU67DR...FSVE1156...-2...` part
instead of guessing the exact Vivado part string.

Example:

```powershell
vivado -mode batch -source rtl_prototypes/scripts/synth_reconstruction.tcl
```

The scripts sweep clocks and emit reports under `results/rtl_prototypes/vivado/`.
Do not report isolated-kernel frequency as final decoder Fmax.

