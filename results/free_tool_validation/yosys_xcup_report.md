# Yosys UltraScale+ xcup Mapping Report

## Target

- Top module: `nr_ldpc_decoder_core`
- Requested mapping command family: `synth_xilinx -family xcup`
- Interpretation: open-source UltraScale+ technology-mapping analysis only
- Not claimed: XCZU67DR placement, routing, STA, Fmax, power, or vendor
  utilization

## Tool

- Source: OSS CAD Suite `20260830`
- Path: `C:\Users\18324\.cache\oss-cad-suite-20260830\bin\yosys.exe`
- Version: `Yosys 0.68+136 (git sha1 c30457480-dirty, Release, GNU /usr/bin/x86_64-w64-mingw32-g++ 15.2.1)`

Installed Yosys help confirms the requested family option exists:

```text
synth_xilinx -family xcup
supported values:
- xcup: Ultrascale Plus
```

The same help text also says the command creates netlists "compatible with
7-Series Xilinx devices" at the moment, so this result is treated as an
open-source synthesis/mapping stress check, not a device signoff result.

## Runs

### Full xcup Run With Inferred Memories

Log:

```text
results/free_tool_validation/yosys_xcup_full_memory_attempt_stalled.log
```

Observed status:

```text
Build succeeded: 0 errors, 0 warnings
Found and reported 0 problems before memory mapping
Flow reached MEMORY / OPT_MEM_PRIORITY and did not complete in practical time
```

### Full xcup Run With Implicit Memories Disabled

Artifacts:

```text
results/free_tool_validation/yosys_xcup.log
results/free_tool_validation/yosys_xcup_console.txt
```

Observed status:

```text
Build succeeded: 0 errors, 0 warnings
terminate called after throwing an instance of 'std::bad_alloc'
what():  std::bad_alloc
```

This is classified as a Yosys/host-memory scaling limit encountered when the
full 384-lane storage fabric is forced toward explicit logic.

### Bounded xcup Checkpoint

Artifacts:

```text
results/free_tool_validation/yosys_xcup_prememory.log
results/free_tool_validation/yosys_xcup_prememory_stat.txt
```

Observed status:

```text
Build succeeded: 0 errors, 0 warnings
Found and reported 0 problems
```

Pre-memory xcup checkpoint statistics:

```text
wires                 169853
wire bits            2140879
public wires           53873
public wire bits      932683
ports                     95
port bits               5842
memories                   38
memory bits          3023808
cells                 145904
Estimated LCs              0
```

`Estimated LCs = 0` is expected at this checkpoint because memory mapping, LUT
mapping, FF legalization, and final primitive mapping have not completed. It is
not a resource estimate.

## Resource Estimate Status

The project does not currently have a complete YOSYS TECHNOLOGY-MAPPED ESTIMATE
for LUT, FF, carry, LUTRAM, BRAM, DSP48E2, SRL, or mux resources from the full
decoder core. The only numeric xcup evidence committed here is the pre-memory
structural checkpoint.

## Physical Intent Inspection

- APP storage is present as inferred memory and was not optimized away.
- q scratch is present as inferred memory and was not optimized away.
- check-state M1/M2/Imin/aggregate/q-sign storage dominates inferred memory
  bits and was not optimized away.
- forward cache remains small relative to APP/check-state/q storage.
- controller schedule/profile data appears as generated functions and static
  mux/case logic rather than a separate vendor ROM primitive in this pass.
- syndrome queue and row state remain explicit small state structures.

Known structural concerns for a later vendor or mature physical flow:

- The full 384-lane APP/forward and check-state paths create large mux/compare
  structures.
- APP memory requires c+3 forwarding visibility and c+4 ordinary memory
  visibility; a vendor implementation may need explicit memory wrappers.
- q scratch and check-state RAM banking/replication must preserve metadata,
  epoch, and bypass semantics.
- This open-source xcup run did not prove BRAM/LUTRAM packing.

## Open-Source Physical-Flow Limitation

Authoritative source anchors:

- Yosys documentation: `https://yosyshq.readthedocs.io/`
- OSS CAD Suite releases: `https://github.com/YosysHQ/oss-cad-suite-build`
- Project X-Ray: `https://github.com/f4pga/prjxray`
- Project U-Ray: `https://github.com/f4pga/prjuray`

Open-source Yosys synthesis and xcup technology-mapping support are available.
Project X-Ray documents the 7-series bitstream/database flow. UltraScale and
UltraScale+ bitstream documentation work exists in Project U-Ray, but this
validation does not establish a complete production-signoff XCZU67DR
place-and-route, static timing, device-specific utilization, power, or
post-route Fmax flow under the project's 100% free/open-source constraint.

## Conclusion

Yosys xcup analysis was run on the complete production decoder core. The design
passed frontend elaboration and bounded xcup structural checking, but full final
primitive mapping did not complete because of Yosys/host-memory scaling on the
large inferred storage fabric. No XCZU67DR Fmax, post-route timing, vendor
utilization, or power result is claimed.
