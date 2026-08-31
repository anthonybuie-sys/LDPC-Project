STATUS: COMPLETE

# Overnight LDPC Completion Status

Current mission: complete verified decoder-core closure with open-source
tooling evidence.

Current git SHA: ecb6c0a5983660dae9fc92d33039b3656727392d

Completed steps:
- Phase-9 controller/core implementation exists in the working tree.
- Phase-9 selected cases, including the three-iteration mixed-sign ping-pong reuse case, have passed in prior validation.
- Regression sweep has passed through Phase 1, Phase 2, Phase 2 Python QC, Phase 3, Category B, Phase 4, Phase 5, Phase 6, Phase 7, Phase 8, Phase 9, and full Python regression.
- Phase 9 committed and pushed: ecb6c0a5983660dae9fc92d33039b3656727392d.
- Free/open-source toolchain discovered and recorded in `results/free_tool_validation/toolchain_versions.md`.
- Verilator static elaboration/lint completed with only classified style,
  unused-interface/debug, and open-pin warnings.
- Yosys generic elaboration/synthesis completed with 0 reported problems.
- Yosys xcup analysis completed through a bounded pre-memory checkpoint; full
  primitive mapping hit a Yosys/host-memory scaling limitation and no Fmax or
  final mapped utilization is claimed.
- Final report drafted.
- Phase-9 standalone case 14 rerun passed: completed iterations 3, PC0 sequence
  0/74/148, terminal done 221, generation advances 2, epochs 0/1/2, ACC/REC
  120 issues and 228 active edges each.
- Final Python regression rerun passed: 76 passed.
- README updated.

Active command: none

Regression state:
- Phase 1: PASS phase1 arithmetic primitives
- Phase 2: PASS phase2 qc permutation
- Phase 2 Python QC: PASS, 14208 observed SV lane rows checked
- Phase 3: PASS phase3 compressed c2v reconstruction, scalar_cases=32768, vector_cases=116, explicit_edges_checked=96
- Category B: CLOSED
- Phase 4: PASS, order_independence_cases=16384, high-rate 40 issues / 76 edges
- Phase 5: PASS, high-rate 40 issues / 76 edges
- Phase 6: PASS, decoder_cycles=71, ACC/REC 40 issues / 76 edges
- Phase 7: PASS, decoder_cycles=71, max_live_forward_entries=8
- Phase 8: PASS, syndrome_completion_cycle=72, syndrome_tail=1
- Phase 9: PASS selected-case sweep including max_iter=3 ping-pong reuse
- Full Python: 76 passed

Synthesis state:
- Verilator validation: COMPLETE, no fatal/latch/width/multidriver issues after
  synthesis-portability cleanup
- Yosys generic synthesis: COMPLETE, 0 errors/warnings from read_slang, 0
  problems from Yosys check, 38 memories, 3,023,808 memory bits
- Yosys xcup mapping: PARTIAL TOOL LIMITATION, frontend and bounded xcup
  checkpoint complete, full final primitive mapping did not complete because
  the inferred-memory path stalled and the no-implicit-memory path hit
  `std::bad_alloc`

Blockers:
- No functional or regression blocker.
- No Vivado, post-route Fmax, device utilization, or power result is claimed
  under the 100% free/open-source tooling constraint.

Next action: final commit and push of the completed closure artifacts.
