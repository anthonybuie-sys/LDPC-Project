# Verilator Static Elaboration Report

## Target

- Top module: `nr_ldpc_decoder_core`
- Production profile: BG1, Z=384, iLS=1, active layers 0..3
- Frozen layer order: 1,3,2,0

## Tool

- Source: OSS CAD Suite `20260830`
- Path policy: resolved from `$env:VERILATOR`, `$env:OSS_CAD_SUITE`, or `PATH`
- Version: `Verilator 5.051 devel rev v5.050-294-gc81be029a (mod)`
- Log: `results/free_tool_validation/verilator_lint.log`

## Result

Verilator elaborated the complete production RTL hierarchy for
`nr_ldpc_decoder_core`. The final `-Wall -Wno-fatal` pass exited successfully
after the synthesis-portability cleanup.

```text
UNUSEDSIGNAL      111
UNUSEDPARAM        25
PINCONNECTEMPTY     7
DECLFILENAME        5
fatal errors         0
latch warnings       0
width warnings       0
multiple drivers     0
```

Verilator summary:

```text
Built from 2.817 MB sources in 31 modules.
Generated 72.843 MB across 49 C++ files.
Walltime 12.326 s.
Peak allocation reported by Verilator: 851.188 MB.
```

## Warning Classification

Genuine RTL problems fixed:

- `nr_ldpc_qc_permute.sv`: added a default source-index assignment in the
  combinational rotate loop to remove an inferred-latch warning.
- `nr_ldpc_syndrome_engine.sv`: separated loop temporaries by role and added
  explicit defaults/casts so queue planning and row XOR logic elaborate cleanly.
- `nr_ldpc_schedule_controller.sv`: sized generated profile constants.
- `nr_ldpc_arith.sv`, `nr_ldpc_check_state_store.sv`, and
  `nr_ldpc_acc_min_update.sv`: removed tool-sensitive unsized/header-import
  constructs and replaced them with module-local imports or sized helper
  return types.

Intentional constructs:

- `UNUSEDSIGNAL`: debug observability ports, validation-only issue fields, or
  exported profile/interface fields retained for integration.
- `UNUSEDPARAM`: generated profile packages intentionally carry reference
  counts and expected timing constants that not every consumer uses.
- `PINCONNECTEMPTY`: reducer/helper outputs that are not needed in a particular
  pipeline stage are intentionally left open.
- `DECLFILENAME`: files containing multiple small modules or a generated
  package whose package name includes `_pkg`.

Tool limitations:

- No remaining Verilator warning is classified as a tool limitation hiding a
  functional or synthesizability issue.

## Conclusion

Verilator static elaboration is complete for the production decoder core. The
remaining warnings are style/interface-shape warnings and do not change
arithmetic, latency, storage, forwarding, syndrome, or controller behavior.
