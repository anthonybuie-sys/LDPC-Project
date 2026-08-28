# Production RTL Phase 6 Report

Phase 6 implements the logical storage subsystem between the reviewed
production ACC and REC pipelines for the frozen high-rate configuration:

```text
P = 384
B = 2
D_A = 3
D_R = 3
II_A = 1
II_R = 1
```

No files under `rtl_prototypes/` were modified. Phase 6 does not implement APP
memory, forward-cache storage, syndrome, controller ROM, top-level decoder,
PCIe/DMA, or general-Z support.

## Files

RTL:

- `rtl/storage/nr_ldpc_q_scratch.sv`
- `rtl/storage/nr_ldpc_check_state_store.sv`
- `rtl/core/nr_ldpc_acc_rec_datapath.sv`

Testbench:

- `rtl/tb/tb_phase6_acc_rec_storage.sv`

Result artifacts:

- `results/rtl_phase6/rtl_phase6_report.md`
- `results/rtl_phase6/rtl_phase6_iverilog.log`

## q Scratch

`nr_ldpc_q_scratch` implements two logical q buffers with ten valid qslots per
buffer. Slots `0..9` are legal and slots `10..15` are rejected. Each slot stores
two P-lane signed q vectors plus owner metadata:

```text
valid
live
iteration_epoch
layer_id
qbuf
qslot
lane_mask
```

The module accepts one B-vector write and one B-vector read request per cycle.
Read request metadata is checked against the live slot owner. The response is
registered for the next cycle, matching REC R0 request to R1 response timing.

The q payload arrays are not bulk-cleared during reset or block start. Reset and
block-start invalidation clear only architectural metadata, release-pipeline
valids, response valids, and error/status registers. Stale payload contents are
therefore inaccessible unless the valid/live/epoch/layer/mask metadata accepts
the transaction.

Slot release is delayed until the REC transaction reaches the publication
boundary. A read accepted in REC R0 schedules release three cycles later, so the
slot remains owned throughout the R0/R1/R2/publication path.

Detected q errors include invalid qslot, overwrite before release, read before
valid, metadata mismatch, invalid release, and iteration advance with live q
state. Invalid qslot handling clamps the internal array index before any payload
or metadata dereference, so rejected `qbuf=1, qslot=10..15` requests cannot form
an out-of-range storage address. Invalid writes do not mutate payload or owner
metadata.

The q scratch also exports combinational `write_accept_o`:

```text
write_accept_o = write_valid && legal qslot && no overwrite-before-release conflict
```

The attempted write is still presented to q scratch so the precise q error code
is reported.

## Check State

`nr_ldpc_check_state_store` implements two logical generations. Per
generation/layer it stores:

```text
M1[5:0]
M2[5:0]
Imin[4:0]
aggregate_sign
valid
closed
iteration_epoch
```

Per generation/layer/local-edge it stores a P-lane q_sign vector with epoch and
valid metadata. No numerical sentinel is used. The M1/M2/Imin/aggregate/q_sign
payload arrays are not bulk-cleared during reset, block start, or generation
advance; validity and epoch metadata provide the architectural invalidation.

At block start, both generations are invalidated and the old generation is
logically invalid. ACC old-state reads of invalid old generation return
`old_generation_valid=0` and zero payload, causing the Phase-4 ACC pipeline to
use exact `oldC2V = 0`.

At iteration advance, the completed new generation becomes old and the previous
old generation becomes the next write target. The next write generation metadata
is cleared without bulk payload RAM clearing.

## ACC Path

The integration wrapper `nr_ldpc_acc_rec_datapath` connects the Phase-4
`nr_ldpc_acc_pipeline` old-state request directly to the check-state store.

ACC issue `c` produces the old-state request in A0. The store registers the
matching old generation response for A1 at `c+1`. The wrapper tracks the
request layer and epoch and asserts a distinct old-state alignment error if the
response metadata does not match the delayed ACC token.

ACC A2 publication at start `c+3` writes:

- q vectors to q scratch
- active q_sign edge vectors to the new generation
- closed layer M1/M2/Imin/aggregate_sign to the new generation when the layer
  closes

The stored M1/M2 vectors are the beta-offset values produced by Phase 4; Phase
6 does not reapply beta.

ACC storage publication is atomic in the integration wrapper. The q scratch
preflight accept result gates the matching check-state q_sign writes and layer
close. If q scratch rejects an ACC q write, the q payload/metadata do not
mutate, q_sign does not mutate, and the compressed layer close does not publish.
This adds no pipeline bubble.

## REC Path

The Phase-5 `nr_ldpc_rec_pipeline` q request drives the q scratch read port.
The q scratch response is returned in the next cycle for REC R1.

The wrapper also tracks REC edge IDs and target generation for the REC R0
token. The check-state store returns newly closed generation state and q_sign
vectors during REC R0. Generation, layer, epoch, edge, and close metadata are
checked before a valid REC state response is emitted.

If an ACC layer close and the first REC issue for that layer meet at the exact
close boundary, the check-state store provides a latency-neutral close/qsign
bypass. A closing ACC issue at `x` is visible at start `x+3`; a REC issue at
`r=x+3` consumes the newly closed state without a bubble.

## Error Handling

Storage errors are explicit. They are exposed separately from ACC and REC
pipeline errors:

```text
q_scratch_error_valid_o
check_state_error_valid_o
old_state_alignment_error_o
unsafe_advance_error_o
storage_error_valid_o
```

Invalid q writes do not modify q scratch state. Invalid q reads suppress the q
response so Phase 5 suppresses architectural REC publication through its normal
token error path. Invalid check-state reads suppress the REC state response or
mark the state invalid/uncached, again letting Phase 5 suppress output.

Iteration advance is also atomic at the wrapper. A requested advance is accepted
only when there are no live q entries and no accepted ACC/REC tokens still in
flight before their storage/publication boundaries. Unsafe advance asserts an
integration/storage error and leaves old/new generation pointers unchanged. A
safe advance performs exactly one generation swap.

## Directed Tests

The Phase-6 testbench covers:

- first-iteration invalid old generation gives exact zero oldC2V behavior
- synchronous A0 to A1 old-state response
- q write then registered q read
- q read/write in the same qbuf with different slots
- q overwrite-before-release error
- invalid qslot errors for `qbuf=0, qslot=10`, `qbuf=1, qslot=10`, and
  `qbuf=1, qslot=15`
- q read before valid error
- q metadata mismatch error
- layer close publication
- exact close `c+3` to REC same-cycle consumption
- REC before layer close error
- old/new generation separation and iteration generation swap
- epoch mismatch rejection
- all-M6 `63` close-state storage
- duplicate-minimum Imin value preserved through storage
- B=2 q_sign write/read alignment
- rejected q write does not partially commit q_sign or layer-close state
- unsafe advance with a live q entry leaves generation pointers unchanged
- unsafe advance with an ACC token in flight leaves generation pointers
  unchanged
- safe advance with no live/in-flight work swaps generations exactly once
- distinct-payload P=384 ACC -> q scratch/check-state -> REC path verifies
  qslot0 `+10/-20`, qslot1 `+30/+40`, q_sign association, stored
  `M1=9/M2=19/Imin=0/aggregate=1`, exact close-boundary REC consumption, and
  final APPs `-9/-11/21/31`
- singleton lane0 q/q_sign storage through the high-rate trace

## High-Rate Schedule

The integrated test drives the checked-in real high-rate schedule:

```text
BG1
Z = 384
active layers = 0,1,2,3
order = 1,3,2,0
program length = 71 cycles
```

Both real ACC and REC issue streams are driven for the full schedule. APP
inputs are deterministic nonzero canonical vectors. The test independently
checks selected numerical values across ACC, storage, and REC:

- first-iteration old generation invalidation gives `oldC2V = 0`
- selected ACC q writes store `q = 20`
- selected closed M1/M2 beta-offset values are `19`
- selected q scratch reads return stored `q = 20`
- selected REC APP publication gives `APP = sat8(20 + 19) = 39`

The exact close-to-REC boundary is checked for all four layer closes:

```text
layer 1 -> cycle 15
layer 3 -> cycle 29
layer 2 -> cycle 46
layer 0 -> cycle 59
```

## Phase-6 Result

```text
PASS phase6 acc rec storage
directed_cases=20 selected_numeric_checks=60 distinct_payload_checks=50 close_boundary_checks=4
high_rate_acc_issue_cycles=40 high_rate_rec_issue_cycles=40
high_rate_acc_active_edges=76 high_rate_rec_active_edges=76
decoder_cycles=71
```

Preserved architecture:

```text
D_A = 3 preserved
D_R = 3 preserved
II_A = 1 preserved
II_R = 1 preserved
decoder schedule = 71 cycles preserved
```

## Regression Results

```text
Phase 1 SV: PASS phase1 arithmetic primitives
Phase 2 SV: PASS phase2 qc permutation
Phase 2 Python QC: PASS, 14208 observed SV lane rows checked
Phase 3 SV: PASS phase3 compressed c2v reconstruction
Phase 3 counts: scalar_cases=32768, vector_cases=116, explicit_edges_checked=96
Category-B closure: CATEGORY B CLOSED - INTEGRATED DATAPATH RTL AUTHORIZED
Phase 4 min-update: PASS, order_independence_cases=16384
Phase 4 reduced-P ACC pipeline: PASS, high_rate_acc_issue_cycles=40, high_rate_active_edges=76
Phase 4 P=384 cases 3/6/7/8/9: PASS
Phase 5 reduced-P REC pipeline: PASS, directed_cases=21
Phase 5 P=384 combined: PASS, directed_cases=21, alignment_cases=1, high_rate_rec_issue_cycles=40, high_rate_active_edges=76
Phase 5 P=384 standalone directed/alignment/high-rate: PASS
Full Python regression: 76 passed
```

## Physical Notes

This phase freezes production logical storage behavior and validates timing at
the RTL boundary. It is still not final FPGA physical memory signoff. The q
scratch and check-state arrays are written as explicit logical stores with
metadata and bypass semantics; final BRAM/LUTRAM/register mapping can be chosen
later only if it preserves the same visible timing and ports.

No Phase 7 work was started.
