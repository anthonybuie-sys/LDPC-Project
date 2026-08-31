# RTL Implementation Guide

This guide maps the production RTL hierarchy to the frozen decoder
architecture. The Canonical RTL Implementation Specification v1.1 is the
normative implementation contract. This guide summarizes the checked-in RTL and
its regression evidence; it does not authorize architecture or timing changes.

`rtl_prototypes/` is not production RTL. It contains older physical-experiment
kernels and must not be used as the decoder-core implementation source.

## Common: `rtl/common/`

### `nr_ldpc_pkg`

Purpose: frozen constants and shared types.

Important constants:

```text
P=384, B=2, D_A=3, D_R=3
NUM_APP_BANKS=8
FORWARD_DEPTH=8
SYNDROME_S=8, SYNDROME_Q=8
W_CH=6, W_APP=8, W_Q=8, W_M=6, W_C2V=7, W_ARITH=9
CH_TO_APP_SHIFT=1, BETA_INT=1
SCHEDULE_WORD_W=36, ISSUE_WORD_W=72
REFERENCE_Z=384
```

State owned: none.

Must not change casually: any frozen constant, width, or signed typedef.

### Arithmetic primitives in `nr_ldpc_arith.sv`

Modules:

```text
nr_ldpc_sat_signed
nr_ldpc_q_sub
nr_ldpc_q_magnitude
nr_ldpc_beta_sub
nr_ldpc_c2v_reconstruct
nr_ldpc_app_add
nr_ldpc_ch_to_app_init
```

Purpose: implement the bit-exact fixed-point arithmetic contract.

Inputs/outputs: signed APP/q/C2V/channel operands, M6 magnitudes, q sign,
wide raw intermediate values, and saturated outputs.

State owned: none; these are combinational primitives.

Pipeline location: used by APP initialization, ACC A1/A2, REC R0/R1, and
C2V reconstruction paths.

Latency: combinational within the caller's registered stage.

Reset behavior: none.

Error behavior: none locally; invalid use is checked by enclosing pipelines.

Key invariants:

- `APP_initial = sat8(CH6 << 1)`.
- `q = sat8(APP - oldC2V)`.
- q magnitude uses a widened path so `q=-128` becomes raw magnitude 128 and
  clips to M6 63.
- `beta = max(raw_mag - 1, 0)`.
- C2V negative zero is suppressed.
- `APP = sat8(q + C2V)`.

Verification coverage: Phase 1 arithmetic regression.

## QC: `rtl/qc/`

### `nr_ldpc_qc_permute_core`, `nr_ldpc_qc_forward`, `nr_ldpc_qc_inverse`

Purpose: rotate 384 packed lanes between canonical APP order and check-domain
order.

Inputs/outputs: packed vector, shift, rotated vector, illegal-shift flag.

State owned: none.

Pipeline location: ACC A0 uses forward rotation; REC R2 uses inverse rotation.

Latency: combinational.

Handshake behavior: none.

Reset behavior: none.

Error behavior: `illegal_shift_o` flags shifts outside the supported range.
Simulation-only parameter checks require `P == REFERENCE_Z == 384` and
`LANE_W > 0`.

Key invariants:

```text
forward: check[k] = canonical[(k+s) mod 384]
inverse: canonical[k] = check[(k-s) mod 384]
lane k = vector[k*LANE_W +: LANE_W]
```

Verification coverage: Phase 2 SystemVerilog regression and independent Python
QC cross-check over 14208 observed lane rows.

Must not change casually: permutation direction, lane packing, combinational
operation, or unsupported general-Z status.

## Check State: `rtl/check_state/`

### `nr_ldpc_compressed_c2v_reconstruct_lane`

Purpose: reconstruct one lane's signed C2V message from compressed state.

Inputs/outputs: M1, M2, Imin, aggregate sign, q sign, local edge ID, signed
C2V output.

State owned: none.

Pipeline location: ACC old-C2V reconstruction and REC new-C2V reconstruction.

Latency: combinational.

Key invariants: use M2 when `edge_id == Imin`, otherwise M1; sign is
`aggregate_sign XOR q_sign`; zero magnitude returns numeric zero.

### `nr_ldpc_compressed_c2v_reconstruct_vector`

Purpose: apply lane reconstruction across all `P=384` lanes.

Inputs/outputs: packed M1/M2/Imin/sign/qsign arrays and packed C2V vector.

Verification coverage: Phase 3 regression with 32768 scalar cases, 116 vector
cases, and 96 explicit edge checks.

Must not change casually: owner/minimum selection semantics or negative-zero
suppression.

## ACC: `rtl/acc/`

### `nr_ldpc_acc_min_update`

Purpose: update min1, min2, Imin, and aggregate sign for up to two candidate
QC edges in one ACC cycle.

Inputs/outputs: old context state, lane mask, two candidate magnitudes/signs,
edge IDs, updated extrema/sign/count, and error indication.

State owned: none.

Pipeline location: ACC A2 combinational reduction.

Latency: combinational.

Key invariants: equal minima select the lowest local edge ID; duplicate minima
preserve `M2=M1`; inactive lanes do not contribute; result is independent of
candidate order and pair grouping.

Verification coverage: Phase 4 exhaustive min-update regression with
`order_independence_cases=16384`.

### `nr_ldpc_acc_context`

Purpose: hold one live layer accumulation context.

Inputs/outputs: start/update/close controls, candidate fields, closed minima
and sign vectors, context-open/closed status, error output.

State owned: running M1/M2/Imin/aggregate sign, edge count, layer ID,
generation, epoch, and context validity.

Pipeline location: ACC A2 context state.

Latency: updates on the clock edge driven by A2.

Handshake behavior: context allocation is controlled by the ACC pipeline and
schedule controller.

Reset behavior: clears valid/open metadata; payload values are meaningful only
when valid.

Error behavior: invalid starts, duplicate close/update misuse, and invalid
edge-count transitions are flagged.

### `nr_ldpc_acc_pipeline`

Purpose: implement the three-stage ACC datapath.

Inputs/outputs: schedule issue token, APP vectors, shifts, old state response,
q scratch write, q-sign write, layer close write, old-state request, ready and
error outputs.

State owned: A0/A1/A2 pipeline registers and two ACC contexts.

Pipeline location:

```text
A0: issue capture, APP source, QC forward rotation
A1: old C2V, q subtraction, q magnitude/sign
A2: min update, q write, sign write, layer close
```

Latency: accepted issue at cycle `c` produces A2 outputs at `c+3`.

Handshake behavior: `issue_ready_o` is asserted for the static schedule; the
controller still checks valid issue against readiness.

Reset behavior: clears pipeline valid bits and context/control state.

Error behavior: context, source, old-state, q-write, edge, and close errors
propagate to enclosing datapaths.

Verification coverage: Phase 4 reduced-P and P=384 cases, plus high-rate ACC
trace with 40 issue cycles and 76 active edges.

Must not change casually: DA=3 stage allocation, II=1, B=2 min-update
semantics, q write timing, layer-close generation, or old-generation contract.

## REC: `rtl/rec/`

### `nr_ldpc_rec_pipeline`

Purpose: reconstruct new C2V, update APP, publish forwarding data, and emit
final-touch hard decisions.

Inputs/outputs: REC issue token, q read data, compressed new state, shifts,
APP write vectors, forward-candidate vectors, final-touch vectors, q release,
ready and error outputs.

State owned: R0/R1/R2/publication pipeline registers.

Pipeline location:

```text
R0: q/new-state read and C2V reconstruction
R1: q + C2V APP update
R2: inverse QC, APP/forward publication, final-touch hard bits
```

Latency: accepted issue at cycle `c` publishes APP/forward/final-touch outputs
at `c+3`.

Handshake behavior: `issue_ready_o` is asserted for the static schedule; q and
state validity are checked by integration logic.

Reset behavior: clears valid and metadata registers.

Error behavior: malformed zero-lane or missing-state-response cases suppress
APP, forward, and final-touch publication and assert the expected REC error.

Verification coverage: Phase 5 reduced-P and P=384 regressions, strengthened
alignment cases, and high-rate REC trace with 40 issue cycles and 76 active
edges.

Must not change casually: DR=3 latency, final-touch timing, publication
suppression on malformed transactions, or numerical C2V/APP association.

## Storage: `rtl/storage/`

### `nr_ldpc_q_scratch`

Purpose: store q vectors from ACC until the matching REC issue consumes them.

Inputs/outputs: write, read, release, generation advance, q vectors, metadata,
live count, error fields.

State owned: two q buffers, ten q slots per buffer, lane payloads, valid bits,
layer/slot/epoch ownership metadata.

Pipeline location: between ACC A2 and REC R0.

Latency: synchronous storage with explicit valid/read/release sequencing.

Reset behavior: clears validity and metadata; payload arrays are not bulk
cleared.

Error behavior: invalid q slots, overwrite, invalid read, metadata mismatch,
release misuse, and unsafe advance with live q are rejected.

Verification coverage: Phase 6 storage regression.

### `nr_ldpc_check_state_store`

Purpose: own compressed C2V state and q-sign generations.

Inputs/outputs: ACC q-sign writes, layer close writes, ACC old-state requests,
REC new-state requests, generation advance, packed minima/sign outputs, error
fields.

State owned: two logical generations for layer state and q signs, closed flags,
epoch metadata, old-state response registers.

Pipeline location: ACC A1 old-state source and REC R0 new-state source.

Latency: integrated with the DA/DR stage timing and epoch adapter.

Reset behavior: clears validity/closed/epoch metadata; payload arrays are not
bulk cleared.

Error behavior: bad generation, epoch mismatch, rec-not-closed, q-sign errors,
and unsafe advance are flagged.

Verification coverage: Phase 6 distinct-payload, close-boundary, invalid-slot,
and generation-advance checks.

### `nr_ldpc_app_memory`

Purpose: store canonical APP vectors for active columns.

Inputs/outputs: block-start/load/read/write controls, column IDs, packed APP
vectors, bank IDs, accept flags, same-bank collision flag, error fields.

State owned: APP payload memory, column valid/load tracking, pending write
state, and error code.

Pipeline location: source for ACC APP reads and sink for REC APP writeback.

Latency: ordinary APP reads follow the conservative c+4 visibility model used
by the schedule.

Reset behavior: clears validity/pending/error metadata.

Error behavior: inactive column, duplicate write, invalid read, and missing
load conditions are flagged.

Verification coverage: Phase 7 APP/forwarding integration.

### `nr_ldpc_forward_cache`

Purpose: hold just-produced APP vectors for dependency-aware c+3 forwarding.

Inputs/outputs: reserve/allocate/publish/read controls, column IDs, slots,
epochs, packed APP vectors, live count, error fields.

State owned: eight forward entries, valid bits, column/slot/epoch tags, and
payload vectors.

Pipeline location: REC R2 publication to ACC A0 source selection.

Latency: REC issue at `c` can satisfy a dependent ACC through forward cache at
`c+3`.

Reset behavior: clears valid/tag/error metadata on reset, block start, or
advance.

Error behavior: duplicate allocation, overwrite, invalid read, tag mismatch,
epoch mismatch, and publish-tag mismatch are flagged.

Verification coverage: Phase 7 dependency timing and integrated forwarding
cases.

Must not change casually: eight-slot depth, c+3 visibility, tag/epoch checks,
or the distinction between forwarded and ordinary APP sources.

## Syndrome: `rtl/syndrome/`

### `nr_ldpc_syndrome_profile_bg1_first4_pkg`

Purpose: generated profile constants and work tables for the BG1 Z=384 first
four active layers.

State owned: none.

Must not change casually: active-row/column/work-item constants, expected
final-touch timing, and edge work mapping unless regenerated from the
authoritative graph/schedule artifacts.

### `nr_ldpc_syndrome_engine`

Purpose: consume final-touch columns and compute the streaming syndrome.

Inputs/outputs: start/iteration epoch, final-touch valid columns and hard-bit
vectors, row syndrome vectors, done/zero status, queue/backlog counters, and
error fields.

State owned: finalized-column queue, row accumulators, consumed-work tracking,
column coverage bits, counters, done/error state.

Pipeline location: observes REC R2 final-touch outputs and feeds the iteration
decision.

Latency: for the reference profile, first final touch at 53, last at 71,
completion at 72.

Handshake behavior: final-touch vectors are accepted as they appear; queue
overflow is an error rather than a main-decoder stall in the modeled release.

Reset behavior: clears queue, coverage, counters, row accumulators, and
done/error metadata.

Error behavior: queue overflow, duplicate/inactive column, epoch mismatch,
malformed dual-lane final touch, duplicate work, invalid work table, impossible
iterator state, and completion mismatch.

Verification coverage: Phase 8 directed cases, decision cases, positive and
mixed-sign integrated scoreboards.

Must not change casually: S=8, Q=8, final-touch-only input source, completion
criteria, or row-scoreboard semantics.

## Control: `rtl/control/`

### `nr_ldpc_controller_profile_bg1_first4_pkg`

Purpose: generated 71-cycle schedule/profile package for the frozen profile.

Contents: program length, issue counts, active-column count, layer degree,
syndrome timing, 72-bit issue words, layer order, base columns, shifts, and
final-touch metadata.

State owned: none.

Verification coverage: Phase 9 profile-generation hash and controller tests.

### `nr_ldpc_iteration_decide`

Purpose: convert syndrome/max-iteration state into terminate or retry control.

Inputs/outputs: syndrome done/zero, current iteration count, max iterations,
decision valid, success/max/retry/error outputs.

State owned: none or minimal decision combinational state, depending on caller
registering.

Error behavior: illegal max-iteration boundary is checked by controller-level
tests.

Verification coverage: Phase 8 decision cases and Phase 9 controller cases.

### `nr_ldpc_schedule_controller`

Purpose: top-level schedule FSM, block load coordination, program counter,
ACC/REC issue decode, iteration retry/done sequencing, abort, and controller
error containment.

Inputs/outputs: start/abort/max iterations, APP load handshake, datapath ready
and error inputs, syndrome status, ACC/REC issue fields, status/debug outputs.

State owned: FSM state, program counter, APP load coverage, iteration epoch,
completed iterations, terminal status, error/abort state, and issue metadata.

Pipeline location: drives ACC and REC issue every RUN_PROGRAM cycle.

Latency: PC0 through PC70 covers 71 issue cycles; one-iteration done is 73;
retry PC0-to-PC0 is 74.

Handshake behavior: accepts start only in IDLE, loads active APP columns in
BLOCK_LOAD, checks datapath readiness during issue, and advances only after a
valid syndrome decision.

Reset behavior: returns to IDLE-safe state, clears counters/status/error.

Error behavior: illegal start/load/max iterations, duplicate/inactive/missing
loads, decode/reserved-bit errors, issue when not ready, unsafe generation
advance, datapath errors, syndrome errors, and controller errors.

Verification coverage: Phase 9 directed cases and integrated one-, two-, and
three-iteration cases.

Must not change casually: FSM timing, profile decode, non-speculative retry
policy, or accepted 74-cycle retry interval.

## Core: `rtl/core/`

### `nr_ldpc_acc_rec_datapath`

Purpose: integrate ACC, REC, q scratch, and check-state storage.

State owned: integrated generation/epoch adapter state and block-clear
plumbing; submodules own payload state.

Pipeline location: ACC/REC storage boundary.

Key invariant: only the internal ACC old-state lookup epoch is translated to
the previous epoch after iteration 0; writes, REC reads, APP forwarding, and
syndrome metadata stay on the current issue epoch.

Verification coverage: Phase 6 and Phase 9 retry tests.

### `nr_ldpc_app_forward_datapath`

Purpose: add APP memory and forward-cache source selection/publication around
the ACC/REC storage datapath.

State owned: APP memory and forward-cache submodule state.

Pipeline location: APP source path before ACC A0 and APP/forward publication
after REC R2.

Key invariant: REC c+3 forward candidate may satisfy a dependent ACC while
ordinary APP memory is still considered old until c+4.

Verification coverage: Phase 7 timing-directed and integrated cases.

### `nr_ldpc_syndrome_datapath`

Purpose: add final-touch syndrome checking around APP/forward/ACC/REC.

State owned: syndrome-engine state plus integrated datapath submodule state.

Pipeline location: REC final-touch output to syndrome engine to iteration
decision.

Verification coverage: Phase 8 and Phase 9.

### `nr_ldpc_decoder_core`

Purpose: production top module for the frozen decoder core.

Inputs/outputs: clock/reset, start/abort/max iterations, APP load interface,
busy/done/success/max/abort/error status, completed iteration/epoch/program
debug, syndrome rows/status, final-touch debug, and selected datapath debug
signals.

State owned: schedule controller and integrated datapath hierarchy.

Pipeline location: whole core.

Latency: 71 issue, 72 syndrome boundary, 73 one-iteration done, 74 retry
PC0-to-PC0.

Handshake behavior: load active APP columns before start execution, run static
schedule, wait for syndrome, terminate or retry.

Reset behavior: controller and datapath return to an IDLE-safe state.

Error behavior: fatal errors are latched and suppress architectural
publication until reset/clear.

Verification coverage: Phase 9 selected-case sweep, including three-iteration
ping-pong.

Must not change casually: top-level contract, frozen profile constants, debug
signals used by regression scoreboards, and accepted timing.

## Testbenches: `rtl/tb/`

Phase testbenches verify the ladder:

```text
tb_phase1_arith.sv
tb_phase2_qc.sv
tb_phase3_c2v.sv
tb_phase4_acc_min_update.sv
tb_phase4_acc.sv
tb_phase5_rec.sv
tb_phase6_acc_rec_storage.sv
tb_phase7_app_forward.sv
tb_phase8_syndrome.sv
tb_phase9_decoder_core.sv
```

These testbenches are regression assets. Do not weaken expected counts,
timing, scoreboard comparisons, or error-injection checks to make RTL changes
pass.
