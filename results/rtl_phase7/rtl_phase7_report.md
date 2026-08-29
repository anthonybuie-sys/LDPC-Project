# Production RTL Phase 7 - Integrated Forwarding Boundary Correction

## Scope

This blocker-only correction closes the Phase-7 integrated APP memory and
forward-cache boundary without changing the 71-cycle schedule, adding latency,
or beginning Phase 8. No files under `rtl_prototypes/` were modified.

Frozen architecture parameters remain:

- P = 384
- B = 2
- DA = 3
- DR = 3
- II_A = 1
- II_R = 1
- APP width = 8
- APP banks = 8
- forward cache depth = 8
- decoder schedule = 71 cycles

## Corrected Boundary

`nr_ldpc_rec_pipeline` now exposes an additive forward-only R2 candidate:

- `forward_candidate_valid_o`
- `forward_candidate_lane0_o`
- `forward_candidate_lane1_o`
- `forward_candidate_base_column0_o`
- `forward_candidate_base_column1_o`
- `forward_candidate_iteration_epoch_o`
- `forward_candidate_aux0_o`
- `forward_candidate_aux1_o`

The candidate is derived only from existing R2 state and the existing inverse-QC
canonical APP result. Existing Phase-5 REC outputs are unchanged:
`rec_app_write_*`, `rec_forward_*`, `rec_final_touch_*`, and `error_valid_o`
remain the registered architectural publication interface.

For a REC issue accepted at edge c:

- edge c+2: R2 registers become active.
- cycle c+2 -> c+3: the R2 forward candidate settles combinationally.
- immediately before edge c+3: forward-cache candidate bypass is valid.
- edge c+3: dependent ACC A0 captures the forwarded APP; the cache may store
  the candidate; registered REC architectural publication is produced.
- cycle c+3: an ordinary APP read of the same column still sees the old APP.
- cycle c+4: ordinary APP memory sees the new APP through the registered
  write/pending path.

The R2 candidate is not an architectural early REC publication. It is used only
for dependency forwarding. APP memory writes still use registered
`rec_app_write_*`, not `forward_candidate_*`.

## Cycle 15 To 18 Trace

The first real forwarding dependency is closed in the actual integrated wrapper:

```text
REC issue cycle 15:
  layer=1 edges=2/3 qbuf=0 qslot=1 aux=1/2 epoch=6
  columns=3/4 shifts=73/288
  reserve slots=0/1

Before cycle-18 rising edge:
  forward_candidate_valid=2'b11
  forward_candidate slots=0/1
  forward_candidate columns=3/4
  forward_candidate epoch=6

ACC issue cycle 18:
  layer=3 edges=2/3 qbuf=1 qslot=3 aux=1/2 epoch=6
  debug_acc_source_forwarded=2'b11
  debug_acc_source_valid=2'b11

At cycle-18 rising edge:
  ACC A0 captures both forwarded canonical APP vectors.
  Forward cache stores the candidate payloads for c+4 consumers.
  Registered REC architectural publication becomes valid.

After cycle-18 edge:
  registered rec_app_write/rec_forward publication is valid.
  ordinary APP memory still resolves same-column reads to the old generation.

Cycle 19:
  ordinary APP memory resolves the registered update as the new generation.
```

## Implementation Notes

- `rtl/rec/nr_ldpc_rec_pipeline.sv` adds only the forward-candidate outputs.
- `rtl/core/nr_ldpc_acc_rec_datapath.sv` passes those outputs through without
  changing existing REC publication timing.
- `rtl/core/nr_ldpc_app_forward_datapath.sv` uses the candidate for forward
  cache publication and bypass, while APP memory uses registered
  `rec_app_write_*`.
- Candidate preflight is combinational: aux must be in 1..8 for forwarded
  slots, active columns must be valid, duplicate lane slot publication is
  rejected, and the forward cache still checks reserved slot, column tag, and
  epoch before accepting or bypassing.
- The Phase-7 wrapper debug collision metric is R2-aligned to the candidate
  boundary, matching the Category-B contract. The APP memory direct unit still
  exposes its own registered-write collision behavior.
- The packed high-rate driver now applies the checked-in Category-B first ACC
  cycles by layer (`1@0`, `3@1`, `2@22`, `0@38`) instead of deriving
  `start_layer` from q-slot number. This changes testbench control decoding
  only; issue cycles and packed schedule words are unchanged.

## Phase-7 Results

```text
PASS phase7 app forward integration
phase7_case=1
directed_cases=5

PASS phase7 app forward integration
phase7_case=2
directed_cases=8

PASS phase7 app forward integration
phase7_case=3
directed_cases=2

PASS phase7 app forward integration
phase7_case=4
directed_cases=1 numerical_dependency_checks=32

PASS phase7 app forward integration
phase7_case=5
high_rate_acc_issue_cycles=40 high_rate_rec_issue_cycles=40
high_rate_acc_active_edges=76 high_rate_rec_active_edges=76
forward_allocations=50 forwarded_reads=27 normal_reads=49 max_live_forward_entries=8
same_bank_collisions=4 decoder_cycles=71
source_modes OO=15 OF=10 FO=5 FF=6 singleton_ordinary_lane0=4

PASS phase7 app forward integration
phase7_case=6
high_rate_acc_issue_cycles=40 high_rate_rec_issue_cycles=40
high_rate_acc_active_edges=76 high_rate_rec_active_edges=76
forward_allocations=50 forwarded_reads=27 normal_reads=49 max_live_forward_entries=8
same_bank_collisions=4 decoder_cycles=71
source_modes OO=15 OF=10 FO=5 FF=6 singleton_ordinary_lane0=4
```

The four R2-aligned same-bank collision cycles remain:

```text
21
37
53
56
```

## Regressions

Rerun evidence:

```text
Phase 1 SV:
PASS phase1 arithmetic primitives

Phase 2 SV:
PASS phase2 qc permutation

Phase 2 Python QC cross-check:
PASS
14208 observed SV lane rows checked
vector_direction_shift_groups=37

Phase 3 SV:
PASS phase3 compressed c2v reconstruction
scalar_cases=32768
vector_cases=116
explicit_edges_checked=96

Phase 4:
PASS phase4 acc min-update exhaustive
order_independence_cases=16384
PASS phase4 acc pipeline reduced-P
PASS phase4 acc pipeline P=384 cases 3/6/7/8/9
high_rate_acc_issue_cycles=40
high_rate_active_edges=76

Phase 5:
PASS phase5 rec pipeline reduced-P
PASS phase5 rec pipeline P=384 combined
PASS phase5 rec pipeline P=384 standalone directed/alignment/high-rate
directed_cases=21
alignment_cases=1
high_rate_rec_issue_cycles=40
high_rate_active_edges=76

Phase 6:
PASS phase6 acc rec storage
directed_cases=20 selected_numeric_checks=60 distinct_payload_checks=50 close_boundary_checks=4
high_rate_acc_issue_cycles=40 high_rate_rec_issue_cycles=40
high_rate_acc_active_edges=76 high_rate_rec_active_edges=76
decoder_cycles=71

Full Python:
76 passed
```

The checked-in Category-B closure artifact remains:

```text
CATEGORY B CLOSED - INTEGRATED DATAPATH RTL AUTHORIZED
decoder cycles = 71
effective boundary = 72
R2-aligned same-bank APP cycles = 4
max live forward entries = 8
q max reads/writes = 1/1
q max slot = 9
syndrome completion = 72
max_iterations boundary tests 1, 2, 12, 15 PASS
```

## Status

The Phase-7 integrated forwarding boundary is closed. The R2 candidate provides
the required combinational dependency-forwarding value before the c+3 ACC
capture edge, while registered REC publication and APP ordinary-memory
visibility remain at c+3 and c+4 respectively. No Phase 8 work was started.
