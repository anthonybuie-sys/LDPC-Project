# DA-2B-OMS Scheduler Simulator

This repository contains a Python architecture/scheduling simulator for a
Dependency-Aware Dual-Block Layered Offset Min-Sum (DA-2B-OMS) LDPC decoder
candidate.

The simulator is a cycle-level architectural validation tool. It is not RTL,
not a production decoder, and not a numerical LDPC reference model. Its purpose
is to expose whether a single-code-block, `P = 384`, `B = 2` layered OMS
architecture can get close to the approximately 50-cycle service lower bound
while respecting pipeline, dependency, forwarding, q-buffer, and APP-bank
constraints.

## Graph Data

The default BG1 benchmark loads actual checked table data from
`data/NR-LDPC-BG`, cloned from `https://github.com/manuts/NR-LDPC-BG` at commit
`910ecbc9e81d43e318079aec535dc9a166a76b2a`. The source repository README states
that files are named as `NR_X_Y_Z.txt`, where `X` selects BG1 or BG2, `Y` is
`iLS`, and `Z` is `zC`.

The first benchmark uses `NR_1_1_384.txt`, active layers 0 through 3, and
therefore uses real BG1 Z=384 connectivity and shifts for the four 19-edge
layers.

The synthetic fixture remains available for regression tests only. It is labeled
`TEST FIXTURE ONLY - NOT 3GPP BASE GRAPH DATA` and must not be reported as a
5G result.

## Modeled

- 5G NR-style QC-LDPC active layers and QC edges.
- Layered OMS scheduling at pair granularity.
- Dual-block issue width `B = 2`.
- Independent accumulation and reconstruction issue streams.
- Accumulation and reconstruction pipeline depths `D_A` and `D_R`.
- Two accumulation contexts for one-layer look-ahead.
- Random-addressable ping-pong q scratch buffers.
- Old/new sign-state generation tracking.
- Banked APP memory with one ordinary operation per bank per cycle.
- Canonical APP forwarding with configurable forward-cache depth.
- Producer-consumer coordinated just-in-time forwarding.
- Static dependency-aware greedy joint ACC/REC scheduling.
- Exhaustive four-layer order search.
- Layer-overlap matrix and independent edge/pair transition capacity reports.

## Not Modeled Yet

- Full numerical Offset Min-Sum decoding.
- Full lifted lane-value vectors.
- Synthesis, timing closure, or FPGA Fmax.
- Multi-code-block throughput.

The `OMSGoldenModel` API exists as a placeholder and explicitly reports
`NOT YET IMPLEMENTED`.

## Terms

- `Z`: LDPC lifting size.
- `P`: vector parallelism. The baseline uses one full `Z = 384` vector per
  operation.
- `B`: number of QC edges serviced per issue slot. The baseline uses `B = 2`.
- `D_A`: accumulation pipeline depth.
- `D_R`: reconstruction pipeline depth.
- APP bank: a base-column memory bank. The model permits one ordinary operation
  per bank per cycle.
- Forward cache: a statically addressed canonical APP forwarding structure, not
  a general associative CPU cache.

## Stall Categories

Every idle issue opportunity is classified as one of:

- `STALL_RAW`
- `STALL_APP_BANK`
- `STALL_Q_BUFFER`
- `STALL_FORWARD_CAPACITY`
- `STALL_CONTEXT`
- `STALL_REC_NOT_CLOSED`
- `STALL_PIPE_RESOURCE`
- `STALL_PAIRING`
- `STALL_OTHER`

The reported stall counts are idle issue opportunities, so accumulation and
reconstruction can each contribute a stall classification in the same clock.

## Forwarding Rule

If a reconstruction pair issues at cycle `t_R`, its canonical APP value becomes
forward-valid at:

```text
t_R + D_R
```

Memory-safe time is modeled separately as:

```text
t_R + D_R + app_commit_delay
```

A dependent accumulation operand sources forwarding first when a valid forward
entry exists. Otherwise it may read APP memory only after the memory-safe cycle.
No same-cycle unregistered producer-to-consumer forwarding is modeled.
Forward entries may be retired once the APP value is memory-safe; after that,
the operand is correct through APP memory and no forward slot remains live.

The reconstruction scheduler does not allocate forward slots eagerly for every
future consumer. It scores producer/consumer urgency and allocates forwarding
only when a slot is useful and available. Otherwise the reconstructed value still
commits to APP memory, and the consumer waits for the memory-safe cycle.

The simulator reports forwarding lifetime as `tau_f` min/average/max.

## Look-Ahead Rule

Only one-layer look-ahead is modeled. With two accumulation contexts, layer
`L(i+1)` may begin before `L(i)` closes only for edges whose APP columns are not
present in unfinished `L(i)`. The simulator never permits three unfinished
accumulation layers.

## Running

Run the main benchmark:

```powershell
python scripts/run_bg1_benchmark.py
```

Run with a detailed human-readable cycle trace:

```powershell
python scripts/run_bg1_benchmark.py --trace
```

Run the required sweeps:

```powershell
python scripts/sweep_pipeline_depth.py
python scripts/sweep_banks.py
python scripts/sweep_forward_cache.py
```

`sweep_pipeline_depth.py` is the real-BG1 pipeline-depth experiment. It fixes
`APP banks = 8`, `forward cache = 8`, uses actual `NR_1_1_384.txt` layers 0..3,
and sweeps `D_A, D_R in {2, 3, 4, 5, 6}`. It prints cycle/stall/forward
matrices and writes the full 25-point result set to
`results/pipeline_depth_sweep_real_bg1.csv`.

`sweep_forward_cache.py` covers depths `2, 4, 8, 16`. `sweep_banks.py` reports
unschedulable banking choices explicitly instead of hiding them.

Run tests:

```powershell
python tests/run_tests.py
```

The tests use only the Python standard library. They are also compatible with
pytest if it is installed separately.

## RTL Prototypes

The `rtl_prototypes/` tree contains isolated synthesis-oriented SystemVerilog
kernels for the first physical DA-2B-OMS feasibility experiment. They are not a
complete decoder and are not production RTL.

Local Icarus simulations can be run with:

```powershell
powershell -ExecutionPolicy Bypass -File rtl_prototypes/scripts/run_sim.ps1
```

Vivado Tcl scripts are provided under `rtl_prototypes/scripts/` for
reconstruction, accumulation, forwarding/APP memory, and combined datapath
experiments. If Vivado is unavailable, resource/timing fields must remain `N/A`;
do not invent physical results.

## Industrial Reference

The comparison point is:

```text
L_IPCTEK = 78 + 133N cycles
```

For `N = 6`, this is 876 cycles. This simulator reports both the candidate
cycles per iteration and the candidate iteration-dependent cycles for a
configurable iteration count. If a clock frequency is supplied, it converts
cycles to time, but it does not claim timing closure or Fmax.
