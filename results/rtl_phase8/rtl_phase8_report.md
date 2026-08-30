# Production RTL Phase 8 - Streaming Syndrome and Iteration Decision

## Scope

Phase 8 adds the frozen final-touch streaming syndrome subsystem and an isolated
iteration-decision block for the accepted high-rate production configuration:

```text
P = 384
B = 2
D_A = 3
D_R = 3
APP banks = 8
forward cache depth = 8
syndrome S = 8
syndrome Q = 8
decoder schedule = 71 cycles
effective iteration boundary = 72 cycles
```

No files under `rtl_prototypes/` were modified. No full schedule controller,
top-level decoder FSM, PCIe/DMA, general-Z support, or production RTL redesign
was started.

## Files

RTL:

- `rtl/syndrome/nr_ldpc_syndrome_profile_bg1_first4.sv`
- `rtl/syndrome/nr_ldpc_syndrome_engine.sv`
- `rtl/control/nr_ldpc_iteration_decide.sv`
- `rtl/core/nr_ldpc_syndrome_datapath.sv`

Testbench and generation:

- `rtl/tb/tb_phase8_syndrome.sv`
- `scripts/generate_phase8_syndrome_profile.py`

Result artifacts:

- `results/rtl_phase8/rtl_phase8_report.md`
- `results/rtl_phase8/rtl_phase8_iverilog.log`

## Generated Syndrome Profile

`scripts/generate_phase8_syndrome_profile.py` mechanically emits the static
BG1 first-four-layer syndrome profile from:

- `data/NR-LDPC-BG/NR_1_1_384.txt`
- `results/syndrome_work_items.csv`
- `results/rtl_handoff_category_a/schedule_program.json`
- `results/rtl_handoff_category_b/schedule_contract_evidence.json`

The generated profile checks the BG edge incidence and shifts against the
checked-in syndrome work CSV, derives final touches from the accepted packed
REC final-touch flags, and gates against the Category-B authoritative syndrome
timing:

```text
total_work_items = 76
first_final_cycle = 53
last_final_cycle = 71
syndrome_completion_cycle = 72
syndrome_tail = 1
max_syndrome_backlog = 7
max_queue_occupancy = 2
```

## Syndrome Engine

`nr_ldpc_syndrome_engine` consumes only the registered Phase-7 final-touch
interface:

```text
rec_final_touch_valid_o
rec_final_touch_base_column0_o
rec_final_touch_base_column1_o
rec_final_touch_iteration_epoch_o
rec_final_touch_hard0_o
rec_final_touch_hard1_o
```

It does not use `forward_candidate_*`. The engine has a physical eight-entry
finalized-column queue. Up to two finalized columns are admitted before the
same cycle consumes up to eight QC edge contributions. Same-row consumed
contributions are XOR-reduced into one architectural row update.

The finalized-column hard-vector payload array is not bulk-cleared on reset or
iteration start, and vacated queue payload entries are not zeroed during normal
queue compaction. Architectural validity is determined by queue metadata,
principally `queue_count_q` and the per-entry work iterator. The syndrome row
accumulators are still physically cleared at iteration start, which is permitted
by the Category-B logical-zero contract.

Completion asserts only after all 26 active columns are finalized exactly once,
all 76 active QC edges are consumed exactly once, the queue is empty, and the
final row update has been included in `syndrome_zero_o`.

Sticky error detection covers queue overflow, duplicate final column,
inactive/illegal final column, epoch mismatch, malformed dual-lane
finalization, duplicate work, invalid work-table lookup, impossible iterator
state, and completion coverage mismatch.

## Iteration Decision

`nr_ldpc_iteration_decide` is an isolated combinational decision block. It does
not launch the next iteration. Its decision order is:

1. If `syndrome_zero_i`, terminate successfully.
2. Else if `completed_iterations_i + 1 >= max_iterations_i`, terminate due to
   maximum iterations.
3. Else request retry of the next iteration.

`max_iterations_i = 0` is illegal. Boundary cases 1, 2, 12, and 15 are covered,
including success precedence when `syndrome_zero_i` is true on the final
allowed iteration.

## Phase-8 Verification

Compile:

```text
iverilog -g2012 -I rtl\common -o results\rtl_phase8\tb_phase8_syndrome.vvp ...
```

Run:

```text
vvp results\rtl_phase8\tb_phase8_syndrome.vvp
```

Result:

```text
PASS phase8 streaming syndrome
phase8_case=0
syndrome_directed_cases=17 decision_cases=33 integrated_cases=2
finalized_columns=26 consumed_work_items=76
first_final_touch_cycle=53 last_final_touch_cycle=71
max_queue_occupancy=2 max_syndrome_backlog=7
decoder_cycles=71 syndrome_completion_cycle=72 syndrome_tail=1 effective_boundary=72
high_rate_acc_issue_cycles=40 high_rate_rec_issue_cycles=40
high_rate_acc_active_edges=76 high_rate_rec_active_edges=76
positive_final_hard_bits ones=0 zeros=9984
mixed_final_hard_bits ones=5383 zeros=4601
```

The integrated Phase-8 case drives the accepted 71-cycle high-rate schedule
through `nr_ldpc_syndrome_datapath`, which wraps the accepted Phase-7
APP/forward datapath and feeds the syndrome engine from registered final-touch
outputs. The testbench independently scores the final canonical hard vectors
against the generated active QC edge table and compares all four active
syndrome rows at completion.

Additional final-cleanup coverage:

- S=8 FIFO/iterator test seeds three finalized columns with 10 total work items.
  Cycle 1 consumes exactly 8 items: all four column-0 edges, all three column-1
  edges, and the first column-2 edge. The queue then holds column 2 with
  `next_work=1`. Cycle 2 consumes the remaining two column-2 edges, verifies row
  XOR updates, and empties the queue.
- Iteration-reset coverage seeds a distinctive nonzero hard-vector payload, then
  starts a new iteration and verifies `queue_count=0`, no stale work is consumed,
  and the architectural syndrome rows are logically zero without requiring the
  payload storage bits themselves to clear.
- The positive integrated run verifies the high-rate all-zero syndrome path:
  `syndrome_zero=1`, 26 finalized columns, 76 consumed work items, first/last
  final touch cycles 53/71, completion 72, tail 1, and effective boundary 72.
- The mixed-sign integrated run drives deterministic nontrivial APP8 values
  through APP/FWD, ACC, q/check-state, REC, registered final touch, and syndrome.
  It observes both final hard-decision values, with 5383 one bits and 4601 zero
  bits, requires a nonzero expected syndrome, verifies `syndrome_zero=0`, and
  compares all four 384-bit RTL syndrome rows against the independent scoreboard.
- The syndrome profile generator rejects duplicate final-touch assignment for
  both REC lane 0 and REC lane 1. Regeneration leaves
  `rtl/syndrome/nr_ldpc_syndrome_profile_bg1_first4.sv` unchanged.

## Preserved Regression Results

```text
Phase 1 SV:
PASS phase1 arithmetic primitives

Phase 2 SV:
PASS phase2 qc permutation

Phase 2 Python QC:
PASS
14208 observed SV lane rows checked
vector_direction_shift_groups=37

Phase 3 SV:
PASS phase3 compressed c2v reconstruction
scalar_cases=32768
vector_cases=116
explicit_edges_checked=96

Category B:
CATEGORY B CLOSED - INTEGRATED DATAPATH RTL AUTHORIZED
decoder cycles = 71
effective boundary = 72
R2-aligned same-bank APP cycles = 4
max live forward entries = 8
q max reads/writes = 1/1
q max slot = 9
syndrome completion = 72

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
directed_cases=20
selected_numeric_checks=60
distinct_payload_checks=50
close_boundary_checks=4
high_rate_acc_issue_cycles=40
high_rate_rec_issue_cycles=40
high_rate_acc_active_edges=76
high_rate_rec_active_edges=76
decoder_cycles=71

Phase 7:
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
numerical_dependency_checks=32

PASS phase7 app forward integration
phase7_case=5
forward_allocations=50
forwarded_reads=27
normal_reads=49
max_live_forward_entries=8
same_bank_collisions=4
decoder_cycles=71
source_modes OO=15 OF=10 FO=5 FF=6 singleton_ordinary_lane0=4

PASS phase7 app forward integration
phase7_case=6
forward_allocations=50
forwarded_reads=27
normal_reads=49
max_live_forward_entries=8
same_bank_collisions=4
decoder_cycles=71
source_modes OO=15 OF=10 FO=5 FF=6 singleton_ordinary_lane0=4

Full Python:
76 passed
```

## Status

Phase 8 is complete as an isolated streaming syndrome and iteration-decision
implementation. The accepted high-rate timing is preserved:

```text
decoder_cycles = 71
syndrome_completion_cycle = 72
syndrome_tail = 1
effective_iteration_boundary = 72
```

No Phase 9 work was started.
