# Production RTL Phase 3 Report

Phase 3 implemented only exact compressed C2V reconstruction, a vectorized `P=384` production reconstruction block, isolated verification, and this report.

Production RTL Phase 2 is complete at commit `26f3f1af502ac23e8c2d920df187874c82f96ac3`. Production RTL Phase 1 is complete at commit `0ee8909e6c96ce8adf25859533400f3c9d5f0bf9`. Category A is closed.

No files under `rtl_prototypes/` were modified. No A2 min1/min2/Imin accumulation, ACC pipeline, REC pipeline, APP memory, q scratch, check-state physical storage, forwarding, schedule controller, syndrome engine, top-level decoder, or integrated datapath RTL was implemented.

## Files Created

RTL:

- `rtl/check_state/nr_ldpc_c2v_reconstruct.sv`

Testbench:

- `rtl/tb/tb_phase3_c2v.sv`

Result artifacts:

- `results/rtl_phase3/rtl_phase3_report.md`
- `results/rtl_phase3/rtl_phase3_iverilog.log`

## Reconstruction Equation

For each lane `k` and selected local edge `e`:

```text
selected_magnitude[k] =
    M2[k] if local_edge_id == Imin[k]
    M1[k] otherwise

negative[k] = aggregate_sign[k] XOR q_sign[e,k]

if selected_magnitude[k] == 0:
    C2V[k] = 0
else if negative[k]:
    C2V[k] = -selected_magnitude[k]
else:
    C2V[k] = +selected_magnitude[k]
```

Output is signed 7-bit C2V in `-63..+63`. Zero magnitude always produces numeric zero; negative-zero encoding is suppressed by the reused Phase-1 arithmetic primitive.

## Lane Packing

Packed-vector convention:

```text
M1 lane k:   m1_i[k*W_M +: W_M]
M2 lane k:   m2_i[k*W_M +: W_M]
Imin lane k: imin_i[k*5 +: 5]
C2V lane k:  c2v_o[k*W_C2V +: W_C2V]
```

`aggregate_sign_i[k]` and `q_sign_i[k]` are one bit per lane. Bits are not reversed inside any lane.

## Phase-1 Primitive Reuse

The Phase-3 lane wrapper reuses the reviewed Phase-1 `nr_ldpc_c2v_reconstruct` primitive for `magnitude + negative -> signed C2V7`. Phase 3 adds only:

- `local_edge_id == Imin` selection between M1 and M2.
- `aggregate_sign XOR q_sign`.
- Vectorization across `P=384` lanes.

This avoids duplicating sign/magnitude arithmetic.

## Verification

Self-checking SystemVerilog testbench:

```text
rtl/tb/tb_phase3_c2v.sv
```

Compile/elaboration command:

```text
iverilog -g2012 -I rtl\common -o results\rtl_phase3\tb_phase3_c2v.vvp rtl\common\nr_ldpc_pkg.sv rtl\common\nr_ldpc_arith.sv rtl\check_state\nr_ldpc_c2v_reconstruct.sv rtl\tb\tb_phase3_c2v.sv
```

Simulation command:

```text
vvp results\rtl_phase3\tb_phase3_c2v.vvp
```

Simulation result:

```text
phase3 scalar_cases=32768
phase3 vector_cases=116
phase3 explicit_edges_checked=96
PASS phase3 compressed c2v reconstruction
```

Coverage:

| Area | Coverage |
| --- | --- |
| Directed cases | Non-Imin, Imin, positive sign, negative sign, zero negative suppression, maximum magnitude, duplicate minima, all-zero M1/M2 |
| Exhaustive scalar sweep | `64 x 64 x 2 x 2 x 2 = 32768` cases |
| Vector module | `P=384` lane-distinct state |
| Local edge IDs | `0`, `1`, `3`, `18`, `31` in lane-distinct vector cases |
| Lane packing | Explicit checks for lane `0`, lane `1`, and lane `383` |
| Explicit-C2V equivalence | 3 deterministic randomized compressed states, every selected edge ID `0..31`, all 384 lanes |

The testbench expected values use independent integer calculations and do not instantiate or call the DUT arithmetic.

## Existing Regressions

Phase-1 arithmetic regression:

```text
PASS phase1 arithmetic primitives
```

Phase-2 QC regression:

```text
PASS phase2 qc permutation
```

Phase-2 Python QC cross-check:

```text
PASS
14208 observed SV lane rows checked
```

Python regression:

```text
76 passed
```

## Boundaries

Phase 3 does **NOT** implement A2 min1/min2/Imin generation. It consumes already-closed M1/M2/Imin state and therefore does not introduce a tie-breaking rule.

Phase 3 does **NOT** close check-state physical storage `OQ-04`; storage, generation ownership, epoch/valid handling, and memory primitive choices remain later integration responsibilities.

Phase 3 does **NOT** implement first-iteration zero-state ownership or oldC2V=0 bypass logic. That remains later ACC/check-state integration work.

## Discrepancy / Questions

No discrepancy was found against the compressed C2V reconstruction contract.

No new Phase-3 implementation question was discovered.
