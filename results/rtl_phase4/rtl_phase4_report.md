# Production RTL Phase 4 Report

Phase 4 implements the stateful ACC A0/A1/A2 datapath boundary, exact B=2
min/sign accumulation contexts, q publication, q_sign publication, and
layer-close compressed-state publication.

No files under `rtl_prototypes/` were modified. Phase 4 does not implement REC,
physical APP memory, physical forward cache, physical q scratch, physical
check-state memory, controller/schedule ROM, syndrome, or top level.

## Files

RTL:

- `rtl/acc/nr_ldpc_acc_min_update.sv`
- `rtl/acc/nr_ldpc_acc_context.sv`
- `rtl/acc/nr_ldpc_acc_pipeline.sv`

Testbenches:

- `rtl/tb/tb_phase4_acc_min_update.sv`
- `rtl/tb/tb_phase4_acc.sv`

Result artifacts:

- `results/rtl_phase4/rtl_phase4_report.md`
- `results/rtl_phase4/rtl_phase4_iverilog.log`

## Production Reuse

`nr_ldpc_acc_pipeline` is the Phase-4 top. Its production datapath reuses the
reviewed primitives rather than local arithmetic copies:

- Phase-2 `nr_ldpc_qc_forward` for A0 canonical-to-check APP permutation.
- Phase-3 `nr_ldpc_compressed_c2v_reconstruct_vector` for A1 old C2V
  reconstruction.
- Phase-1 `nr_ldpc_q_sub` for `q = sat8(APP_check - oldC2V)`.
- Phase-1 `nr_ldpc_q_magnitude` for q sign and M6 magnitude, preserving
  `q=-128 -> abs 128 -> M6 63`.
- Phase-1 `nr_ldpc_beta_sub` for M1/M2 offset publication at close.
- Phase-4 `nr_ldpc_acc_min_update` as the actual per-lifted-lane production
  reducer inside `nr_ldpc_acc_context`.

Invalid old generation is still handled outside the Phase-3 primitive:
`old_generation_valid_i == 0` selects an exact zero oldC2V vector. No compressed
state sentinel was introduced.

## Timing

- Issue accepted in cycle `c` enters A0.
- A0 consumes already-selected canonical APP vectors, performs forward QC, and
  asserts the old-state request boundary during cycle `c`.
- A1 consumes the matching old compressed state/q_sign response in `c+1`.
- A1 computes q, q sign, and M6 magnitude.
- A2 performs the context update in `c+2`.
- q write, q_sign write, and optional layer close are registered visible at the
  start of `c+3`.

Consecutive valid issues are accepted with `issue_ready_o=1`, preserving
`II_A=1` and `D_A=3`.

## Context Rules

There are exactly two contexts. The context ID is `layer_position mod 2`.

On `start_layer`, the selected context starts from `edge_count=0` and
`aggregate_sign=0`. Stored min/Imin bit patterns are not interpreted as
sentinels before edge-count validity establishes real values, so the first real
candidate can be magnitude 63.

Malformed usage raises `error_valid_o`: zero active lanes, start into an open
context, continuation without an open context, continuation of the wrong layer,
degree overflow, or unsupported close with fewer than two edges.

The context accumulates raw minima only. Beta is applied once, at layer close:

```text
M1 = max(raw_min1 - 1, 0)
M2 = max(raw_min2 - 1, 0)
```

Layer close is determined only by `edge_count_before + popcount(lane_mask) ==
layer_degree`.

## Reducer Semantics

The instantiated reducer preserves:

- First candidate magnitude 63 establishes min1=63 and the real local edge ID.
- First pair `{63,63}` establishes min1=63, min2=63, and the lower edge ID owns
  Imin.
- Equal min1 candidates set `min2=min1`.
- Equal-magnitude ownership goes to the lowest local edge ID.
- Two active B lanes are reduced in local-edge-ID order.
- Masked lanes contribute nothing.
- Aggregate sign XORs active q signs only.
- No numerical sentinel is used for M1/M2/Imin validity.
- Overflow is `edge_count_new > layer_degree`.

## Added Cleanup Tests

The structural cleanup added:

- A production context/pipeline all-63 degree-7 test with non-monotonic edge
  IDs, verifying every relevant lifted lane closes with M1/M2 offset 62 and
  lowest-edge Imin.
- A consecutive II_A=1 old-state response alignment test, verifying request
  metadata and that token A and token B consume their matching c+1 responses
  without cross-token mixing.
- A missing old-state response test, verifying publication suppression,
  boundary error assertion, no context mutation, and successful later reuse of
  the same context.

## Verification

Tool: Icarus Verilog 12.0 devel, `iverilog -g2012`, followed by `vvp`.

Raw log:

```text
results/rtl_phase4/rtl_phase4_iverilog.log
```

Results:

```text
PASS phase4 acc min-update exhaustive
order_independence_cases=16384

PASS phase4 acc pipeline
phase4_case=0
p_lanes=32 reduced_p_sim=1
directed_cases=26 order_independence_cases=0 random_layers=0 pipeline_checks=52 high_rate_acc_issue_cycles=40 high_rate_active_edges=76

PASS phase4 acc pipeline
phase4_case=3
p_lanes=384 reduced_p_sim=0

PASS phase4 acc pipeline
phase4_case=6
p_lanes=384 reduced_p_sim=0

PASS phase4 acc pipeline
phase4_case=7
p_lanes=384 reduced_p_sim=0

PASS phase4 acc pipeline
phase4_case=8
p_lanes=384 reduced_p_sim=0

PASS phase4 acc pipeline
phase4_case=9
p_lanes=384 reduced_p_sim=0
high_rate_acc_issue_cycles=40 high_rate_active_edges=76
```

The default production-width P=384 bench compiled cleanly. Because the expanded
primitive hierarchy is slow under Icarus, the complete directed pipeline suite
also has a testbench-only reduced-P mode for fast full-suite execution. The
cleanup-specific all-63, response-alignment, missing-response, nonzero
arithmetic, and high-rate trace cases were run at P=384.

The exhaustive 16,384-case reducer test validates the exact scalar reducer
module instantiated by the production context. It is not claimed as an
exhaustive proof of unrelated pipeline logic.

## Regression Results

```text
Phase 1 SV: PASS phase1 arithmetic primitives
Phase 2 SV: PASS phase2 qc permutation
Phase 2 Python QC: PASS, 14208 observed SV lane rows checked
Phase 3 SV: PASS phase3 compressed c2v reconstruction
Phase 3 counts: scalar_cases=32768, vector_cases=116, explicit_edges_checked=96
Category-B closure: CATEGORY B CLOSED - INTEGRATED DATAPATH RTL AUTHORIZED
Full Python regression: 76 passed
```

Preserved schedule metrics from Category B:

```text
decoder cycles = 71
effective boundary = 72
R2-aligned same-bank APP cycles = 4
max live forward entries = 8
q max reads/writes = 1/1
q max slot = 9
syndrome completion = 72
```

## Discrepancy / Questions

No discrepancy was found against the Phase-4 ACC contract.

No new Phase-4 implementation question was discovered.
