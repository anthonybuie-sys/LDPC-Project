# Documentation Index

Recommended reading order:

1. [RESEARCH_SUMMARY.md](RESEARCH_SUMMARY.md) - concise project story,
   headline architecture, measured cycle latency, evidence, and limitations.
2. [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md) - how and why the frozen
   decoder architecture works before reading RTL.
3. [RTL_IMPLEMENTATION_GUIDE.md](RTL_IMPLEMENTATION_GUIDE.md) - production RTL
   hierarchy, module responsibilities, invariants, and verification coverage.
4. [VERIFICATION_GUIDE.md](VERIFICATION_GUIDE.md) - verification ladder,
   accepted results, and portable reproduction commands.
5. [FPGA_PHYSICAL_IMPLEMENTATION_PLAN.md](FPGA_PHYSICAL_IMPLEMENTATION_PLAN.md)
   - future target-device physical implementation plan.
6. [SYSTEM_INTEGRATION_PLAN.md](SYSTEM_INTEGRATION_PLAN.md) - future
   accelerator/platform wrapper plan.

Related release files:

- [Repository README](../README.md)
- [Release status](../RELEASE_STATUS.md)
- [Final decoder report](../results/final/final_decoder_report.md)
- [Phase 9 RTL report](../results/rtl_phase9/rtl_phase9_report.md)
- [Free-tool validation reports](../results/free_tool_validation/)

Normative implementation authority:

- Canonical RTL Implementation Specification v1.1. This handoff document is
  referenced by title because it is an external project artifact, not a
  checked-in repository file in the current tree.

If any guide here conflicts with the canonical specification or checked
repository evidence, treat the canonical specification and repository evidence
as authoritative and update the guide.
