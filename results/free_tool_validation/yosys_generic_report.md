# Yosys Generic Synthesis Report

## Target

- Top module: `nr_ldpc_decoder_core`
- Frozen architecture: P=384, B=2, DA=3, DR=3, APP banks=8, forward depth=8,
  syndrome S=8 Q=8

## Tool

- Source: OSS CAD Suite `20260830`
- Path: `C:\Users\18324\.cache\oss-cad-suite-20260830\bin\yosys.exe`
- Version: `Yosys 0.68+136 (git sha1 c30457480-dirty, Release, GNU /usr/bin/x86_64-w64-mingw32-g++ 15.2.1)`
- Frontend: `read_slang --std latest --unroll-limit 20000`
- Flow: `hierarchy -top nr_ldpc_decoder_core; proc; opt; check; stat`
- Log: `results/free_tool_validation/yosys_generic.log`
- Stat artifact: `results/free_tool_validation/yosys_generic_stat.txt`

The native Yosys Verilog frontend did not accept the package/import shape of
the SystemVerilog source. The open-source `read_slang` frontend accepted the
complete production RTL hierarchy and is the recorded generic synthesis route.

## Result

```text
Build succeeded: 0 errors, 0 warnings
Found and reported 0 problems
```

Generic statistics for `nr_ldpc_decoder_core`:

```text
wires                 171418
wire bits            2307647
public wires           53879
public wire bits      932728
ports                     95
port bits               5842
memories                   38
memory bits          3023808
cells                 145928
```

Large generic cell classes:

```text
$mux        70300
$memwr_v2   13245
$lt         11576
$add         7572
$sub         6927
$eq          6096
$shiftx      4608
$gt          3855
$ge          3874
$xor         3104
```

Sequential generic cells:

```text
$sdff       1572
$sdffce     3078
$sdffe        48
$dffe        130
```

## Structural Checks

- Unsupported constructs: none after the read_slang route.
- Combinational loops: none reported by `check`.
- Multiple drivers: none reported by `check`.
- Unintended latches: none reported in the final Verilator pass; none reported
  by Yosys `proc`/`check`.
- Inferred memories: 38 memories, 3,023,808 bits.
- Reset structures: payload memories are not bulk reset; control, validity,
  epoch, pending, and error metadata are reset.
- Arithmetic inference: add/sub/compare/reduction structures are present, as
  expected for OMS arithmetic and scheduler checks.
- Mux structures: large mux counts are expected from static schedule/profile
  functions, generated QC-shift tables, active-column checks, and wide
  APP/forward selection.

## Memory Inference Notes

Approximate intended memory-bearing structures:

- APP memory: 128 columns x 384 lanes x 8 bits = 393,216 bits.
- q scratch: 2 q buffers x 10 qslots x 2 lanes x 384 lanes x 8 bits =
  122,880 bits.
- compressed check state: M1/M2/Imin/aggregate/q-sign storage across two
  generations, 64 layers, and 32 edges, approximately 2,457,600 bits.
- forward cache: 8 entries x 384 lanes x 8 bits = 24,576 bits plus tags.
- syndrome queue/profile/controller constants: small relative to the storage
  arrays.

The 3,023,808 inferred memory bits are consistent with these structures and
metadata. The generic pass preserves the intended logical storage rather than
reducing it away.

## Conclusion

Yosys generic elaboration/synthesis is complete for the full production decoder
core. No generic structural errors were reported.
