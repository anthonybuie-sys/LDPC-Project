# Production RTL Phase 1 Report

Phase 1 implemented only the frozen-v1 package/types, fixed-point arithmetic primitives, and directed arithmetic verification. The attached v1.1 DOCX was treated as reference material; the active implementation scope was the pasted Phase 1 request plus the Category-A closure artifacts at commit `6ced7a66348c3bda8882431e0efafdd63006cf06`.

No files under `rtl_prototypes/` were modified. No QC permutation, ACC, REC, APP memory, q scratch, check-state memory, forwarding, schedule controller, syndrome engine, top-level FSM, PCIe/DMA, or integrated datapath RTL was implemented.

## Files Created

- `rtl/common/nr_ldpc_pkg.sv`
- `rtl/common/nr_ldpc_arith.sv`
- `rtl/tb/tb_phase1_arith.sv`
- `results/rtl_phase1/rtl_phase1_iverilog.log`
- `results/rtl_phase1/rtl_phase1_report.md`

## Frozen Package Constants

`nr_ldpc_pkg.sv` freezes only currently authorized production values:

| Constant | Value |
| --- | ---: |
| `P` | 384 |
| `B` | 2 |
| `D_A` | 3 |
| `D_R` | 3 |
| `NUM_APP_BANKS` | 8 |
| `FORWARD_DEPTH` | 8 |
| `NUM_ACC_CONTEXTS` | 2 |
| `SYNDROME_S` | 8 |
| `SYNDROME_Q` | 8 |
| `W_CH` | 6 |
| `W_APP` | 8 |
| `W_Q` | 8 |
| `W_M` | 6 |
| `W_C2V` | 7 |
| `W_ARITH` | 9 |
| `CH_TO_APP_SHIFT` | 1 |
| `BETA_INT` | 1 |
| `SCHEDULE_WORD_W` | 36 |
| `ISSUE_WORD_W` | 72 |
| `REFERENCE_Z` | 384 |

Typedefs are explicit about signedness:

- `ch_t`: signed CH6
- `app_t`: signed APP8
- `q_t`: signed q8
- `mag_t`: unsigned M6 magnitude
- `c2v_t`: signed C2V7
- `arith_t`: signed 9-bit arithmetic intermediate
- `arith_mag_t`: unsigned 9-bit absolute-value intermediate

No still-open Category B/C/D physical choices were encoded as frozen package constants.

Package compilation model: `nr_ldpc_pkg.sv` is compiled exactly once as a SystemVerilog package before dependent compilation units. Production RTL modules and testbenches import package symbols with `import nr_ldpc_pkg::*;` and do not textually include the package source.

## Primitive Interfaces

- `nr_ldpc_sat_signed #(IN_W=9, OUT_W=8)`: clamps signed wider input to signed destination range.
- `nr_ldpc_q_sub`: `q = sat8(APP - oldC2V)`, with explicit 8/7-bit sign extension into 9-bit subtraction.
- `nr_ldpc_q_magnitude`: computes `sign = q < 0`, 9-bit widened absolute value, and M6 clamp to 63.
- `nr_ldpc_beta_sub`: computes `offset_mag = max(raw_mag - BETA_INT, 0)` for unsigned M6 values.
- `nr_ldpc_c2v_reconstruct`: maps M6 magnitude plus negative bit into signed 7-bit C2V, suppressing negative zero.
- `nr_ldpc_app_add`: `APP_new = sat8(q + newC2V)`, with explicit 8/7-bit sign extension into 9-bit addition.
- `nr_ldpc_ch_to_app_init`: decoder-core initialization `APP_initial = sat8(CH6 << 1)`.

The installed Icarus simulator had limited support for package typedefs in primitive port lists, so primitive ports use explicit frozen bit widths while the package still defines the authoritative typedefs. Internal arithmetic uses package constants and typed 9-bit intermediates.

## Verification

Self-checking SystemVerilog testbench: `rtl/tb/tb_phase1_arith.sv`.

Simulator/tool:

```text
iverilog -g2012 -I rtl\common -o results\rtl_phase1\tb_phase1_arith.vvp rtl\common\nr_ldpc_pkg.sv rtl\common\nr_ldpc_arith.sv rtl\tb\tb_phase1_arith.sv
vvp results\rtl_phase1\tb_phase1_arith.vvp
```

Result:

```text
PASS phase1 arithmetic primitives
```

Coverage:

| Area | Test coverage |
| --- | --- |
| Package constants | Direct equality checks for every frozen Phase 1 constant |
| Signed saturation | Exhaustive 9-bit signed input range `-256..255` into 8-bit signed output |
| q subtraction | Mandatory rail vectors plus exhaustive `APP=-128..127`, `oldC2V=-63..63` |
| q magnitude | Mandatory q values plus exhaustive `q=-128..127`, including `q=-128 -> abs=128 -> M6=63` |
| Beta subtract | Mandatory `0,1,2,63` plus exhaustive `0..63` |
| C2V reconstruct | Exhaustive magnitudes `0..63` for both signs, including negative-zero suppression |
| APP add | Mandatory rail vectors plus exhaustive `q=-128..127`, `C2V=-63..63` |
| CH6 init | Exhaustive `CH6=-32..31` |

Section 13 min-selection vectors (`tie` and `M6 maximum start`) were identified in the DOCX, but not implemented as RTL in Phase 1 because min1/min2/imin selection is outside the authorized primitive list and belongs with later ACC/check-state logic. The Phase 1 testbench covers every Section 13 arithmetic vector that maps to an authorized Phase 1 primitive.

## Python Regression

Command:

```text
C:\Users\18324\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe tests\run_tests.py
```

Result:

```text
76 passed
```

## Discrepancy / Questions

No discrepancy was found against the Phase 1 arithmetic contracts. No new implementation question was discovered for package/types or arithmetic primitives.
