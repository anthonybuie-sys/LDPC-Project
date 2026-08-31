# Production RTL Phase 9 - Schedule Controller and Decoder Core

## Scope

Phase 9 adds the frozen high-rate decoder-core control shell for:

```text
BG1, Z=384, iLS=1, active layers 0..3
layer order = 1,3,2,0
P = 384
B = 2
D_A = 3
D_R = 3
APP banks = 8
forward cache depth = 8
syndrome S = 8
syndrome Q = 8
```

No files under `rtl_prototypes/` were modified. No PCIe/DMA, general-Z
support, rate matching, filler removal, synthesis, or post-Phase-9 RTL work was
started.

## Files

RTL:

- `rtl/control/nr_ldpc_controller_profile_bg1_first4.sv`
- `rtl/control/nr_ldpc_schedule_controller.sv`
- `rtl/core/nr_ldpc_decoder_core.sv`
- `rtl/core/nr_ldpc_syndrome_datapath.sv`
- `rtl/core/nr_ldpc_acc_rec_datapath.sv`

Testbench and generation:

- `rtl/tb/tb_phase8_syndrome.sv`
- `rtl/tb/tb_phase9_decoder_core.sv`
- `scripts/generate_phase9_controller_profile.py`

Result artifacts:

- `results/rtl_phase9/rtl_phase9_report.md`
- `results/rtl_phase9/rtl_phase9_iverilog.log`

## Generated Controller Profile

`scripts/generate_phase9_controller_profile.py` mechanically emits the static
controller profile from the authoritative Category-A/B artifacts and the real
BG1 Z=384 table:

- `results/rtl_handoff_category_a/schedule_program.json`
- `results/rtl_handoff_category_a/profile_metadata.json`
- `results/rtl_handoff_category_a/qc_shift_table.json`
- `results/rtl_handoff_category_b/schedule_contract_evidence.json`
- `data/NR-LDPC-BG/NR_1_1_384.txt`

The generator cross-checks the frozen schedule metrics before writing RTL:

```text
program_length = 71
acc_issues = 40
rec_issues = 40
acc_edges = 76
rec_edges = 76
layer_order = 1,3,2,0
layer_position: 1->0, 3->1, 2->2, 0->3
first four active layer degrees = 19,19,19,19
```

The packed issue format is the accepted 72-bit program word containing one
36-bit ACC microinstruction and one 36-bit REC microinstruction per issue
cycle. The controller decodes the accepted fields directly and derives
layer-position, layer-degree, starts-layer, edge base column, and QC shift from
the generated profile rather than encoding them in the program word.

Regeneration was checked twice. The generated profile SHA-256 remained:

```text
D15373D52F4C37AF2ACAAE9D8C1B2219F6232AFC4559E9C1E9E7323E418E37E0
```

## Controller Behavior

`nr_ldpc_schedule_controller` implements:

```text
IDLE
BLOCK_LOAD
ITERATION_START
RUN_PROGRAM
WAIT_SYNDROME
DONE
ERROR
```

It accepts one block start in IDLE, loads active APP columns 0..25 exactly once,
automatically launches the first iteration, issues PC0..PC70 without dynamic
stalls, waits for the streaming syndrome decision, and either terminates or
retries according to `nr_ldpc_iteration_decide`.

Fatal controller checks cover illegal `max_iterations`, start while busy, APP
load outside `BLOCK_LOAD`, inactive/duplicate APP loads, packed schedule decode
errors, nonzero reserved instruction bits, valid issue when the datapath is not
ready, unsafe generation advance, and datapath errors.

Synchronous abort suppresses further ACC/REC issue, pulses the datapath block
clear, suppresses terminal result publication, returns to IDLE-safe state, and
sets `aborted_o`.

## Retry Epoch Handoff

The external ACC/REC issue metadata follows the Phase-9 epoch rule:

```text
first iteration epoch = 0
second iteration epoch = 1
```

The existing Phase-6 check-state store keeps closed layer/q-sign metadata under
the producing iteration epoch. To preserve that storage contract without
modifying the store, `nr_ldpc_acc_rec_datapath` translates only the internal
ACC old-generation lookup epoch to the previous epoch after iteration 0. ACC
new-generation q/check-state writes, REC reads/publications, APP forwarding,
and syndrome final-touch metadata continue to use the current issue epoch.

This avoided changing `nr_ldpc_check_state_store.sv` and preserves the accepted
Phase-6 through Phase-8 regressions.

## Phase 9 Verification

Icarus Verilog compile:

```text
PASS
```

The Phase-9 testbench was run as a selected-case sweep using
`+phase9_case=1` through `+phase9_case=14` because the monolithic all-case
P=384 run repeats the same full-core reset/integration work and is very slow
under Icarus. The selected-case sweep uses the same compiled testbench and
exercises all directed and integrated cases.

Directed controller cases:

```text
cases 1..10 PASS
```

Integrated positive all-zero hard decision:

```text
PASS
iterations = 1
syndrome_zero = 1
hard ones = 0
hard zeros = 9984
ACC issues / edges = 40 / 76
REC issues / edges = 40 / 76
first final touch = 53
last final touch = 71
syndrome completion = 72
terminal done = 73
max queue = 2
max backlog = 7
```

Integrated mixed-sign max-iteration case:

```text
PASS
iterations = 1
syndrome_zero = 0
hard ones = 5383
hard zeros = 4601
ACC issues / edges = 40 / 76
REC issues / edges = 40 / 76
terminal done = 73
all four RTL syndrome rows match the independent scoreboard
```

Integrated real retry case:

```text
PASS
iterations = 2
generation advances = 1
second iteration epoch = 1
PC0 sequence = 0,74
terminal done = 147
ACC issues / edges = 80 / 152
REC issues / edges = 80 / 152
```

Integrated three-iteration ping-pong case:

```text
PASS
iterations = 3
generation advances = 2
iteration epochs = 0,1,2
PC0 sequence = 0,74,148
retry intervals = 74,74
terminal done = 221
ACC issues / edges = 120 / 228
REC issues / edges = 120 / 228
no controller, old-state alignment, check-state epoch, q scratch, unsafe
advance, forward, APP memory, APP forwarding, storage, or syndrome errors
```

Measured timing terminology:

```text
decoder issue window = 71 cycles
syndrome/effective iteration boundary = 72 cycles
controller terminal done boundary for one iteration = 73 cycles
retry PC0-to-PC0 interval = 74 cycles
```

The 74-cycle retry interval is the accepted functional RTL value for Phase 9.
A 72/73-cycle retry optimization is deferred until after synthesis/STA, when
the cycle-count versus Fmax tradeoff can be evaluated with physical timing.

## Phase 8 TB Diff

`git diff -- rtl/tb/tb_phase8_syndrome.sv` shows one Phase-9 compatibility
edit:

```text
+  logic debug_advance_accept_o;
```

This is required because Phase 9 exposes the existing accepted-advance debug
signal through `nr_ldpc_syndrome_datapath.sv`. The Phase-8 testbench uses a
wildcard port connection, so it needs a matching local signal for the added
debug-only pass-through port to elaborate. No Phase-8 syndrome behavior changed.

## Regression Results

```text
Phase 1 SV: PASS phase1 arithmetic primitives

Phase 2 SV: PASS phase2 qc permutation

Phase 2 Python QC: PASS
14208 observed SV lane rows checked

Phase 3 SV: PASS phase3 compressed c2v reconstruction
scalar_cases=32768
vector_cases=116
explicit_edges_checked=96

Category B: CATEGORY B CLOSED - INTEGRATED DATAPATH RTL AUTHORIZED

Phase 4 SV: PASS phase4 acc min-update exhaustive
order_independence_cases=16384
reduced-P ACC pipeline PASS
P=384 cases 3/6/7/8/9 PASS
high_rate_acc_issue_cycles=40
high_rate_active_edges=76

Phase 5 SV: PASS phase5 rec pipeline
reduced-P PASS
P=384 combined PASS
standalone directed/alignment/high-rate PASS
high_rate_rec_issue_cycles=40
high_rate_active_edges=76

Phase 6 SV: PASS phase6 acc rec storage
directed_cases=20
selected_numeric_checks=60
distinct_payload_checks=50
close_boundary_checks=4
high_rate_acc_issue_cycles=40
high_rate_rec_issue_cycles=40
high_rate_acc_active_edges=76
high_rate_rec_active_edges=76
decoder_cycles=71

Phase 7 SV: PASS phase7 app forward integration
directed_cases=18
numerical_dependency_checks=32
forward_allocations=50
forwarded_reads=27
normal_reads=49
max_live_forward_entries=8
same_bank_collisions=4
decoder_cycles=71
source_modes OO=15 OF=10 FO=5 FF=6 singleton_ordinary_lane0=4

Phase 8 SV: PASS phase8 streaming syndrome
syndrome_directed_cases=17
decision_cases=33
integrated_cases=2
first_final_touch_cycle=53
last_final_touch_cycle=71
decoder_cycles=71
syndrome_completion_cycle=72
syndrome_tail=1
effective_boundary=72
high_rate_acc_issue_cycles=40
high_rate_rec_issue_cycles=40
high_rate_acc_active_edges=76
high_rate_rec_active_edges=76

Full Python: 76 passed
```

## Status

Phase 9 is functionally complete for the frozen BG1 Z=384 first-four-layer
production target. The controller, generated schedule profile, and decoder-core
top-level pass the directed and integrated verification sweep. The accepted
controller-visible timing is:

```text
PC0-to-PC0 retry interval = 74 cycles
effective single-iteration boundary = 72 cycles
extra synchronous-control overhead = 2 cycles
```

No commit, push, synthesis, PCIe/DMA, general-Z support, rate matching, filler
removal, or later production RTL phase was started.
