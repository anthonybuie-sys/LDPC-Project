# RTL Prototype Result Table

Physical synthesis/place-and-route was attempted on 2026-08-13 after Vivado
reported the required XCZU67DR FSVE1156 speed-grade -2 target. The selected
part was `xczu67dr-fsve1156-2-i`. The first requested run, Reconstruction DR3
at 200 MHz, stopped in `synth_design` because Vivado could not obtain a valid
license for feature `Synthesis` and/or device `xczu67dr`. Timing/resource
values are intentionally reported as N/A because no implementation completed.

| Kernel | Pipeline | Status | Passing Freq | LUT | FF | LUTRAM | BRAM | DSP | WNS | Worst Path / Failure |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| Reconstruction | DR3 | Tool failed at first 200 MHz `synth_design` | N/A | N/A | N/A | N/A | N/A | N/A | N/A | `[Common 17-345]` no valid `Synthesis` / `xczu67dr` license |
| Reconstruction | DR4 | Not started after license stop | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| Accumulation | DA3 | Not started after license stop | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| Accumulation | DA4 | Not started after license stop | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| Forward cache | NF4 | Not started after license stop | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| Forward cache | NF8 | Not started after license stop | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| APP LUT8 | 8 banks | Not started after license stop | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| Combined | DA3/DR3 + NF8 | Not started after license stop | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| Combined | DA4/DR4 + NF8 | Not started after license stop | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |

| Decision Metric | Value | Comparison |
|---|---:|---|
| `F_DR4 / F_DR3` | N/A | Cannot compare with 0.949 because no DR3/DR4 implementation completed |
| `t33 = F33 / 70` | N/A | No combined DA3/DR3 + NF8 implementation completed |
| `t44 = F44 / 78` | N/A | No combined DA4/DR4 + NF8 implementation completed |
| `F44 / F33` | N/A | Cannot compare with 0.897 because no combined implementation completed |
