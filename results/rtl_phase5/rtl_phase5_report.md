# Production RTL Phase 5 Report

Phase 5 implements only the isolated REC R0/R1/R2 datapath boundary for the
frozen production configuration:

```text
P = 384
B = 2
D_R = 3
II_R = 1
```

No files under `rtl_prototypes/` were modified.

Phase 5 does not implement physical q scratch, physical compressed-state
memory, physical APP memory, physical forward-cache storage, the schedule
controller/ROM, the syndrome engine, DMA/PCIe, or top-level decoder logic.

## Files

RTL:

- `rtl/rec/nr_ldpc_rec_pipeline.sv`

Testbench:

- `rtl/tb/tb_phase5_rec.sv`

Result artifacts:

- `results/rtl_phase5/rtl_phase5_report.md`
- `results/rtl_phase5/rtl_phase5_iverilog.log`

## R0/R1/R2 Semantics

For a REC token issued in cycle `c`:

- R0 (`c`): consumes supplied closed new compressed state, reconstructs new
  C2V, and exposes the q-scratch read request metadata.
- R1 (`c+1`): consumes the matching q-scratch response and computes
  `APP_check = sat8(q + newC2V)`.
- R2 (`c+2`): applies inverse QC permutation to produce canonical APP.
- Publication (`start c+3`): exposes APP write metadata, optional forwarding
  publication metadata, optional final-touch metadata, and error status.

No hidden pipeline stage was added. `D_R=3` and `II_R=1` are preserved.

## Primitive Reuse

The production REC datapath reuses:

- Phase-3 `nr_ldpc_compressed_c2v_reconstruct_vector` in R0.
- Phase-1 `nr_ldpc_app_add` in R1.
- Phase-2 `nr_ldpc_qc_inverse` in R2.

No local clone of C2V reconstruction, APP saturation arithmetic, or QC inverse
permutation was added.

## Boundary Contracts

State response validation detects missing response, invalid state, not-closed
state, wrong layer, wrong iteration epoch, and wrong generation.

q response validation detects missing response, wrong qbuf, wrong qslot, wrong
lane mask, wrong layer, and wrong iteration epoch.

Illegal inverse-QC shifts are detected in R2.

Any malformed token carries an error to the publication boundary, suppressing:

- APP write publication
- forwarding publication
- final-touch publication

`error_valid_o` is asserted for the bad token at its publication boundary. A bad
token does not corrupt following II_R=1 tokens.

## Publication Metadata

At `c+3`, each active B lane publishes:

- canonical APP vector
- base column
- layer ID
- local edge ID
- qbuf/qslot
- iteration epoch
- aux code
- final-touch flag

Forwarding publication is boundary-only. `aux=0` produces no forward event;
`aux=1..8` maps to logical forward slot `aux-1`. No forward storage is present.

Final-touch publication is boundary-only. The interface exposes the canonical
APP vector and a hard-decision vector where `APP < 0` maps to hard bit 1 and
`APP >= 0` maps to hard bit 0.

## Phase-5 Verification

Tool: Icarus Verilog 12.0 devel, `iverilog -g2012`, followed by `vvp`.

Results:

```text
PASS phase5 rec pipeline
phase5_case=0
p_lanes=32 reduced_p_sim=1
directed_cases=21 alignment_cases=0 high_rate_rec_issue_cycles=0 high_rate_active_edges=0

PASS phase5 rec pipeline
phase5_case=0
p_lanes=384 reduced_p_sim=0
directed_cases=21 alignment_cases=1 high_rate_rec_issue_cycles=40 high_rate_active_edges=76

PASS phase5 rec pipeline
phase5_case=1
p_lanes=384 reduced_p_sim=0
directed_cases=21 alignment_cases=0 high_rate_rec_issue_cycles=0 high_rate_active_edges=0

PASS phase5 rec pipeline
phase5_case=2
p_lanes=384 reduced_p_sim=0
directed_cases=0 alignment_cases=1 high_rate_rec_issue_cycles=0 high_rate_active_edges=0

PASS phase5 rec pipeline
phase5_case=3
p_lanes=384 reduced_p_sim=0
directed_cases=0 alignment_cases=0 high_rate_rec_issue_cycles=40 high_rate_active_edges=76
```

The directed tests cover ordinary non-Imin C2V, Imin-selects-M2, aggregate-sign
XOR q-sign negative C2V, zero-magnitude negative suppression, `+63` and `-63`
C2V, positive and negative APP saturation, inverse shifts 0/1/383, B=2
different shifts, singleton lane0, aux=0, aux=1 and aux=8 forward-slot mapping,
final-touch hard decisions for positive/negative/zero APP, missing q response,
q metadata mismatch, new-state mismatch, malformed zero-lane tokens, missing
new-state response, illegal shift, and consecutive II_R=1 response alignment.

The strengthened consecutive II_R=1 alignment test drives three graph-valid REC
tokens on adjacent issue cycles with distinct layer IDs, qslots, local edge IDs,
QC shifts, base columns, aux values, final-touch flags, compressed-state
payloads, and q payloads. Each token is checked at its own publication boundary
for exact layer, edge IDs, qbuf/qslot, base columns, aux, final-touch flags,
APP payload, forwarding metadata, final-touch metadata, and hard-decision bits.
The inspected APP values are intentionally unmistakable:

```text
A lane0:  14 = sat8(  3 +  11)
B lane0:  23 = sat8( -5 +  28)
B lane1:  -2 = sat8(  7 +  -9)
C lane0: -23 = sat8(-40 +  17)
C lane1: -13 = sat8( 20 + -33)
```

Token A selects M1, token B selects M2 through Imin on lane0, and token C
selects M2 through Imin on lane1, so a one-cycle compressed-state or q-response
swap produces a wrong APP result. Token A has no forwarding or final-touch
publication, token B has forwarding plus final-touch on lane0, and token C has
forwarding on both lanes plus final-touch on lane1.

The high-rate trace drives the 40 checked-in REC issue tokens from
`results/rtl_handoff_category_a/schedule_program.json`, with layer/edge-derived
base columns and QC shifts cross-checked against
`results/rtl_handoff_category_a/qc_shift_table.json`.

## Regression Results

```text
Phase 1 SV: PASS phase1 arithmetic primitives
Phase 2 SV: PASS phase2 qc permutation
Phase 2 Python QC: PASS, 14208 observed SV lane rows checked
Phase 3 SV: PASS phase3 compressed c2v reconstruction
Phase 3 counts: scalar_cases=32768, vector_cases=116, explicit_edges_checked=96
Category-B closure: CATEGORY B CLOSED - INTEGRATED DATAPATH RTL AUTHORIZED
Phase 4 min-update: PASS, order_independence_cases=16384
Phase 4 reduced-P pipeline: PASS
Phase 4 P=384 cases 3/6/7/8/9: PASS
Phase 4 ACC high-rate: PASS, high_rate_acc_issue_cycles=40, high_rate_active_edges=76
Full Python regression: 76 passed
```

## Discrepancy / Questions

No discrepancy was found against the Phase-5 REC datapath contract.

No Phase-6 work was started.
