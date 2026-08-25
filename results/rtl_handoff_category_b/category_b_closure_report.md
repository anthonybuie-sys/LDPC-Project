# Category-B Production Interface Closure

This closure writes no RTL and does not modify `rtl_prototypes/`. It analyzes the checked-in Category-A program and freezes the interface contracts needed before integrated ACC/REC datapath RTL.

## Source Baseline

- Phase 1 production RTL commit: `0ee8909e6c96ce8adf25859533400f3c9d5f0bf9`.
- Phase 2 production RTL commit: `26f3f1af502ac23e8c2d920df187874c82f96ac3`.
- Phase 3 production RTL commit: `e344d54233526888e173fa97289bf67c48c20467`.
- Schedule: `results\rtl_handoff_category_a\schedule_program.json`.
- Profile metadata: `results\rtl_handoff_category_a\profile_metadata.json`.
- Evidence hash: `7d4091e0dde8b21e00253d44460de9599d6c6c0983315a4d52db38cb19d7fedb`.

## Frozen Reference Profile

- Profile: `BG1_Z384_iLS1_layers_0_1_2_3_order_1_3_2_0`.
- Layer order: `1-3-2-0`.
- Program length / decoder cycles: `71` / `71`.
- Syndrome tail / effective boundary: `1` / `72`.
- ACC / REC issue cycles: `40` / `40`.
- Active edges / active columns: `76` / `26`.

## Closure Table

| OQ | decision | evidence | affected RTL phases | status |
|---|---|---|---|---|
| OQ-02 | APP logical memory contract: 8 banks, 3072-bit canonical column vectors, c+4 ordinary visibility, c+3 forwarding, physical wrapper must absorb R2-aligned same-bank read/write collisions. | 2 reads, 2 writes max at issue boundary; 4 R2-aligned same-bank cycles require 1R1W/equivalent wrapper. | APP memory, ACC A0, REC R2, schedule_ctrl | CLOSED |
| OQ-04 | Two logical check-state generations with epoch/valid/closed metadata; first iteration oldC2V is a zero override, not fake M sentinel values. | Layer close cycles from program: {0: 59, 1: 15, 2: 46, 3: 29}; REC first cycles: {1: 15, 3: 29, 2: 46, 0: 59}. | ACC A2, REC R0, check-state storage | CLOSED |
| OQ-09 | Active-high synchronous core reset; deterministic IDLE after reset; sticky done level; synchronous abort invalidates epochs and suppresses output; fatal errors latch until clear/reset. | Matches spec reset-visible behavior while avoiding large payload-RAM reset networks. | top-level FSM, schedule_ctrl, all validity metadata | CLOSED |
| OQ-10 | max_iterations is 4 bits, legal 1..15, default 12, zero illegal; DECIDE uses completed_next=completed_iterations+1, then success, max-count, or retry in that order. | Boundary tests for max_iterations 1, 2, 12, and 15 pass and preserve the non-speculative policy. | configuration registers, top-level FSM | CLOSED |
| OQ-12 | REC c produces forward-visible canonical APP at c+3; ordinary APP memory is safe at c+4; ACC aux selects forward vs stored APP exactly. | Forward depth 8, 27 forwarded reads, max live 8. | forward_fabric, ACC A0, REC R2, APP wrapper | CLOSED |
| OQ-14 | Syndrome S=8 Q=8; row collision XOR-combine before accumulator update; completion requires full final-touch and edge-consumption coverage. | S=8/Q=8 high-rate queue peak 2, completion 72, tail 1. | syndrome engine, top-level DECIDE | CLOSED |
| OQ-15 | q scratch uses two ping-pong buffers, qslots 0..9, one B-vector write and one B-vector read per cycle; check-state ports are explicit for ACC old, A2 new, REC new. | q max reads/writes 1/1; check-state maxima {'acc_old_layer_vector_reads': 1, 'acc_old_qsign_edge_reads': 2, 'rec_new_layer_vector_reads': 1, 'rec_new_qsign_edge_reads': 2, 'a2_new_qsign_edge_writes': 2, 'a2_context_updates': 1, 'layer_close_commits': 1}. | q scratch, check-state storage, ACC A2, REC R0 | CLOSED |

## Logical Read Latency Table

| Structure | Request/address cycle | Data-valid cycle | Consumer stage | Same-cycle read required | One-cycle sync read allowed | Prefetch required | Bypass requirement |
|---|---|---|---|---|---|---|---|
| APP ordinary read | ACC issue c / A0 | during A0 cycle c | A0 source selection and forward QC permutation; A0 result is registered for A1 at c+1 | True | False | False | If ACC aux selects a forward slot, APP memory is not read; the forward slot APP follows the same A0 timing and must be available during c for QC permutation. |
| old compressed layer-state read | ACC issue c / A0 | c+1 | A1 reconstructs oldC2V with old q_sign | False | True | False | If the old generation is invalid for the current block/epoch, reconstruction returns logical zero; no M1/M2/Imin sentinel is observed. |
| old q_sign read | ACC issue c / A0 | c+1 | A1 reconstructs oldC2V sign | False | True | False | Same invalid-old-generation zero rule as old compressed layer state. |
| new compressed layer-state read | REC issue c / R0 | during R0 cycle c | R0 reconstructs newC2V | True | False | False | If closing ACC issues at x, new state is visible at start x+3; a REC issued at c=x+3 may consume that newly published state during R0 c. |
| new q_sign read | REC issue c / R0 | during R0 cycle c | R0 reconstructs newC2V sign | True | False | False | Must match the new compressed layer-state generation and iteration epoch; mismatch is fatal. |
| q scratch read | REC issue c / R0 | c+1 | R1 computes APP update with q and newC2V | False | True | False | A read at the q write-visible boundary must return the written q vector or be proven absent by schedule validation; no hidden cycle is allowed. |

## Important Port-Timing Result

At the scheduler issue boundary, the canonical program has no APP bank conflict: up to two ordinary ACC reads and two REC writes occur globally, and no bank sees more than one issue-aligned operation.

At the physical R2 boundary, APP writes occur three cycles after REC issue. The script found same-bank read/write physical cycles, so the APP wrapper contract is intentionally stronger than a single one-operation-per-bank RAM. The implementation shall use per-bank 1R1W capability, a write buffer, register shadowing, or equivalent latency-neutral realization. It shall not insert a new decoder cycle.

## Generation And Lifetime Decisions

- APP storage remains canonical. Forwarding carries a pending canonical shadow only until ordinary APP memory is safe.
- Compressed check state uses old/new ping-pong generations with epoch and valid metadata. If the old generation is invalid for the current block/epoch, reconstructed oldC2V is exactly zero. No M1/M2/Imin sentinel is permitted.
- q scratch uses qbuf=`layer_position mod 2`, qslot=`pair_id`, qslots `0..9` only. A slot is owned from ACC issue until REC issue plus `D_R`.
- Layer-close visibility is exact: closing ACC issue `c` makes the new generation visible to REC at `c+3`.
- Forward slots contain `valid`, `column_id_tag`, `iteration_epoch`, and the canonical 384x8 APP vector. REC R2 writes the tag at c+3; ACC A0 compares against the expected column and current epoch; mismatch is fatal and does not fall back to APP memory.

## Max-Iterations Semantics

`completed_next = completed_iterations + 1` for the iteration whose syndrome decision just completed. The architectural completed-iteration counter records `completed_iterations_after_decide = completed_next` for success, max-iteration termination, and retry. If `syndrome_zero`, terminate successfully. Else if `completed_next >= max_iterations`, terminate due to maximum iterations. Otherwise launch the next iteration. Thus `max_iterations=1` executes exactly one iteration and `max_iterations=12` executes at most twelve.

## Syndrome Contract

- S=8, Q=8 are retained. For this reference program, total syndrome work is `76`, first final cycle is `53`, last final cycle is `71`, queue peak is `2`, completion is `72`, and tail is `1`.
- Same-row collisions among the S consumed items are resolved by XOR reduction before the architectural row accumulator update, or by an equivalent collision-safe multiwrite implementation.
- At each iteration start, syndrome accumulators behave as architectural zero before any work item is consumed. Stale prior-iteration state is inaccessible and establishing this logical zero consumes no decoder cycle.

## Validation

Validation evidence artifact: `results\rtl_handoff_category_b\validation_evidence.json`.

| Check | Expected | Observed |
|---|---|---|
| Phase 1 SV | PASS phase1 arithmetic primitives | PASS |
| Phase 2 SV | PASS phase2 qc permutation | PASS |
| Phase 2 Python QC | PASS, 14208 rows | PASS, 14208 rows |
| Phase 3 SV | PASS phase3 compressed c2v reconstruction | PASS; scalar=32768, vector=116, explicit=96 |
| Full Python regression | 76 passed | 76 passed |
| max_iterations boundary tests | 1, 2, 12, 15 pass | PASS |

## Output Artifacts

- `memory_interface_contract.json`
- `forwarding_timing_contract.json`
- `control_semantics_contract.json`
- `schedule_contract_evidence.json`
- `validation_evidence.json`
- `category_b_closure_report.md`

## Decision Gate

CATEGORY B CLOSED — INTEGRATED DATAPATH RTL AUTHORIZED
