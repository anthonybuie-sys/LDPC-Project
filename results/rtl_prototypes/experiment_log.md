# RTL Prototype Experiment Log

## 2026-08-11 Initial Scaffold

- Vivado version: N/A, `vivado` is not available on PATH in this environment.
- Target part: intended `XCZU67DR-2FSVE1156I`; exact Vivado part string not selected because Vivado is unavailable locally.
- Kernels created:
  - Reconstruction DR3 / DR4
  - Accumulation DA3 / DA4
  - Forward cache/mux NF-parameterized, NF8 default
  - APP LUT8 distributed-memory model
  - Combined DA3/DR3 and DA4/DR4 datapath prototypes
- Parameters: `P=384`, `B=2`, `APP_W=8`, `Q_W=8`, `MSG_W=6`, `EDGE_ID_W=5`, `SHIFT_W=9`.
- Clock constraints: Tcl scripts cover 200, 250, 280, 300, 320, and 350 MHz.
- Synthesis result: N/A.
- Implementation result: N/A.
- WNS/TNS/resources: N/A.
- Local simulation:
  - Icarus Verilog available at `C:\iverilog\bin\iverilog.exe`.
  - `run_sim.ps1` passed reconstruction DR3/DR4 equivalence for 512 streamed cases.
  - `run_sim.ps1` passed accumulation DA3/DA4 equivalence for 512 streamed cases.
  - `run_sim.ps1` passed forwarding mux and APP LUT8 readback smoke tests.
  - Python vector generator produced 2048 reconstruction and 2048 accumulation 384-lane reference vectors in `results/rtl_prototypes/vectors/`.
  - Icarus elaboration succeeded for full-default 384-lane reconstruction DR3/DR4 and accumulation DA3/DA4 kernels.
  - Icarus elaboration succeeded for full-default 384-lane combined DA3/DR3 and DA4/DR4 datapath wrappers.
- Notes: Vivado Tcl scripts query the installed part database for a real matching ZCU670 part. No timing or resource values have been fabricated.

## 2026-08-11 Vivado XCZU67DR Discovery Attempt

- Targeted discovery checked PATH plus normal AMD/Xilinx Windows install roots:
  - `C:\Xilinx`
  - `C:\AMDUnified`
  - `C:\AMD`
  - `C:\AMDDesignTools`
  - `C:\Program Files\Xilinx`
  - `C:\Program Files\AMD`
  - `C:\Program Files\AMD Vivado`
- `vivado`, `vivado.bat`, and `settings64.bat` were not visible on PATH.
- Registry uninstall records showed Xilinx Design Tools/Vivado entries under `C:\Xilinx`.
- Usable Vivado launcher found at `C:\Xilinx\2025.1\Vivado\bin\vivado.bat`.
- Vivado version: 2025.1, SW build 6140274.
- Part support query:
  - `get_parts -quiet *xczu67dr*`: no matches.
  - `get_parts -quiet *zu67dr*`: no matches.
  - `get_parts -quiet *zu67dr*fsve1156*-2*`: no matches.
- Raw Vivado query outputs:
  - `results/rtl_prototypes/vivado/part_query/query_xczu67dr_parts.log`
  - `results/rtl_prototypes/vivado/part_query/query_xczu67dr_parts.jou`
- Physical synthesis/place-and-route was not run because the installed Vivado device database does not contain the required XCZU67DR FSVE1156 speed grade -2 target. No alternate part was substituted.
- Fresh verification after discovery:
  - `C:\Users\18324\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe tests\run_tests.py`: 33 passed.
  - `powershell -ExecutionPolicy Bypass -File rtl_prototypes\scripts\run_sim.ps1`: reconstruction, accumulation, and forwarding/APP RTL simulations passed. Icarus reported two non-fatal sensitivity-list warnings in `forward_cache_8.sv`.
- Recommendation: H. Physical experiment unavailable until Vivado has the appropriate XCZU67DR RFSoC DFE device support installed.

## 2026-08-13 Vivado XCZU67DR Physical Attempt

- Reran `rtl_prototypes\scripts\query_xczu67dr_parts.tcl` with `C:\Xilinx\2025.1\Vivado\bin\vivado.bat`.
- Vivado version: 2025.1, SW build 6140274.
- All `*xczu67dr*` matches reported by Vivado:
  - `xczu67dr-ffve1156-1-i`
  - `xczu67dr-ffve1156-1LV-i`
  - `xczu67dr-ffve1156-2-i`
  - `xczu67dr-ffve1156-2LVI-i`
  - `xczu67dr-fsve1156-1-i`
  - `xczu67dr-fsve1156-1LV-i`
  - `xczu67dr-fsve1156-2-i`
  - `xczu67dr-fsve1156-2LVI-i`
- All `*zu67dr*fsve1156*-2*` matches reported by Vivado:
  - `xczu67dr-fsve1156-2-i`
  - `xczu67dr-fsve1156-2LVI-i`
- Exact target selected for the requested XCZU67DR FSVE1156 speed-grade -2 experiment: `xczu67dr-fsve1156-2-i`.
- Physical flow driver added at `rtl_prototypes\scripts\run_physical_experiments.tcl`; it does not modify RTL or architecture. It pins the exact part above, runs kernel-level out-of-context Vivado implementation, and writes raw reports under `results\rtl_prototypes\vivado\`.
- Physical flow order was started as requested. The first run was Reconstruction DR3 at 200 MHz.
- Actual stop condition:
  - Vivado failed during `synth_design -top reconstruction_dr3 -part xczu67dr-fsve1156-2-i -mode out_of_context -flatten_hierarchy rebuilt`.
  - Error: `[Common 17-345] A valid license was not found for feature 'Synthesis' and/or device 'xczu67dr'.`
  - No synthesis, placement, route, timing, or resource results were produced.
- Raw artifacts preserved:
  - `results\rtl_prototypes\vivado\part_query\query_xczu67dr_parts.log`
  - `results\rtl_prototypes\vivado\part_query\query_xczu67dr_parts.jou`
  - `results\rtl_prototypes\vivado\physical_experiments.log`
  - `results\rtl_prototypes\vivado\physical_experiments.jou`
  - `results\rtl_prototypes\vivado\physical_run_status.csv`
  - `results\rtl_prototypes\vivado\reconstruction\DR3\200MHz\failure.txt`
- DR3 vs DR4 frequency ratio `F_DR4 / F_DR3`: N/A, because neither implementation completed.
- Combined iteration-time comparison:
  - `t33 = F33 / 70`: N/A.
  - `t44 = F44 / 78`: N/A.
  - `F44 / F33` versus 0.897 break-even: N/A.
- No RTL redesign, floorplanning, B=4 test, or complete-decoder work was started.
