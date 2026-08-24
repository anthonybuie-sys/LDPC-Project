# Production RTL Phase 2 Report

Phase 2 implemented only the frozen-reference QC forward/inverse permutation network, isolated QC verification, and this report. Production RTL Phase 1 remains at commit `0ee8909e6c96ce8adf25859533400f3c9d5f0bf9`; Category A is closed.

No files under `rtl_prototypes/` were modified. No ACC, REC, APP memory, q scratch, check-state storage, forwarding, schedule controller, syndrome engine, top-level decoder, or integrated datapath RTL was implemented.

## Files Created

RTL:

- `rtl/qc/nr_ldpc_qc_permute.sv`

Testbench:

- `rtl/tb/tb_phase2_qc.sv`

Result artifacts:

- `results/rtl_phase2/rtl_phase2_report.md`
- `results/rtl_phase2/rtl_phase2_iverilog.log`
- `results/rtl_phase2/qc_sv_observed.csv`
- `results/rtl_phase2/qc_python_crosscheck.json`

## Supported Phase-2 Contract

- Supported Phase-2 datapath: `P=384`, `Z=384`.
- General `Z<384` support is **NOT** closed by Phase 2.
- `OQ-05` remains open Category C.
- Shift input is 9 bits so legal shifts `0..383` and illegal shift `384` are representable.
- Illegal shifts assert `illegal_shift_o`; the output vector is cleared when `illegal_shift_o=1` so no illegal modulo/wrap behavior is defined.
- The network is combinational: no clock, no reset, no valid state, no pipeline stage.
- Parameter sanity checks for `P==REFERENCE_Z==384` and `LANE_W>0` are simulation-only and guarded with `` `ifndef SYNTHESIS``.

## Equations

Forward canonical to check:

```text
check[k] = canonical[(k+s) mod 384]
```

Implemented without divider/modulo:

```text
src = k + s
if src >= 384:
    src = src - 384
```

Inverse check to canonical:

```text
canonical[k] = check[(k-s) mod 384]
```

Implemented without divider/modulo:

```text
src = k - s
if src < 0:
    src = src + 384
```

Because `0 <= k,s <= 383`, only one add/subtract correction is required.

## Lane Packing

Packed-vector convention:

```text
lane k <-> vector[k*LANE_W +: LANE_W]
```

Lane values are atomic. The QC network never reverses bits inside a lane. The testbench explicitly checks lane `0`, lane `1`, and lane `383`.

Primary production Phase-2 use is `LANE_W=8`, giving `384 x 8 = 3072` bits. The testbench also instantiates `LANE_W=16` with distinct lane labels `0..383` to make direction mistakes visible even though production APP lanes are 8-bit.

## Verification

Self-checking SystemVerilog testbench:

```text
rtl/tb/tb_phase2_qc.sv
```

Compile/elaboration command:

```text
iverilog -g2012 -I rtl\common -o results\rtl_phase2\tb_phase2_qc.vvp rtl\common\nr_ldpc_pkg.sv rtl\qc\nr_ldpc_qc_permute.sv rtl\tb\tb_phase2_qc.sv
```

Simulation command:

```text
vvp results\rtl_phase2\tb_phase2_qc.vvp
```

Simulation result:

```text
PASS phase2 qc permutation
```

Coverage:

| Area | Coverage |
| --- | --- |
| Directed shifts | `0`, `1`, `2`, `17`, `127`, `191`, `255`, `383` |
| Exhaustive legal shifts | All `s=0..383` |
| Production lane width | `LANE_W=8` structured and deterministic randomized vectors |
| Distinct lane labels | `LANE_W=16`, lane labels `0..383` |
| Round trips | `inverse(forward(x,s),s)==x` and `forward(inverse(x,s),s)==x` |
| Independent SV reference | Testbench scalar source-index construction, not DUT reuse |
| Illegal shift | `s=384` asserts illegal flag for forward and inverse |
| Lane packing | Explicit lane `0`, `1`, `383` checks |

## Python Frozen-Model Cross-Check

The SV testbench emitted selected observed lane outputs to:

```text
results/rtl_phase2/qc_sv_observed.csv
```

Python cross-check compared those SV observations against:

- `ldpc_sim.qc_direction.scalar_rotate_to_check`
- `ldpc_sim.qc_direction.scalar_rotate_from_check`
- `ldpc_sim.numerical_decoder.rotate_to_check`
- `ldpc_sim.numerical_decoder.rotate_from_check`

Result:

```text
PASS
observed_rows = 14208
vector_direction_shift_groups = 37
```

The SV expected calculation remains independent; the Python model is a second reference.

## Synthesis / Elaboration Sanity

Icarus Verilog `iverilog -g2012` compiled/elaborated the isolated combinational QC network and testbench successfully. No physical synthesis was run, and no Fmax, area, power, or physical topology result is frozen by Phase 2.

## Existing Regressions

Phase-1 arithmetic regression:

```text
PASS phase1 arithmetic primitives
```

Python regression:

```text
76 passed
```

## Discrepancy / Questions

No discrepancy was found against the frozen QC direction or Phase-2 P/Z=384 contract.

No new Phase-2 implementation question was discovered. `OQ-05` remains open Category C for masked `P=384` operation and production support of `Z<384`.
