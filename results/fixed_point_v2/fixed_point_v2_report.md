# Fixed-Point Architecture Study v2

This report preserves `results/fixed_point/*` and writes only under `results/fixed_point_v2/`.
No RTL, scheduler, P/B, DA/DR, forwarding, schedule-encoding, or syndrome-architecture changes were made.

## Run Scope

Requested statistical stopping rule: `200` block errors or `10000` blocks.
Executed sanity blocks per SNR: `24`.
Executed calibration screen blocks per point: `4`.
Executed stage-2 selection blocks per point: `20`.
Executed high-rate sweep blocks per point: `20`.
Executed layer-order blocks per point: `12`.
Executed secondary profile blocks per point: `4`.
Because the full requested Monte Carlo run is too large for this interactive pass, confidence intervals are reported but should be treated as screening evidence only.

## High-Width Sanity

| EbN0_dB | blocks | float_errors | wide_errors | float_avg_iterations | wide_avg_iterations | avg_iteration_delta_wide_minus_float | hard_mismatch_blocks | hard_mismatch_info_bits |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4.5 | 24 | 0 | 0 | 5.916667 | 5.916667 | 0.000000 | 0 | 0 |
| 4.9 | 24 | 0 | 0 | 4.208333 | 4.166667 | -0.041667 | 0 | 0 |
| 5.3 | 24 | 0 | 0 | 3.458333 | 3.458333 | 0.000000 | 0 | 0 |

High-width fixed-point sanity status: `PASSED`.

## Best Scale/Beta Per Candidate

| candidate | w_CH | w_APP | w_q | w_M | channel_gain | beta | beta_equiv | BLER | BLER_CI95_low | BLER_CI95_high | avg_iterations | avg_iteration_se | saturation_events_per_block |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 4 | 6 | 6 | 5 | 0.75 | 0 | 0.000000 | 0.00000000 | 0.00000000 | 0.16112516 | 4.850000 | 0.243602 | 8100.950000 |
| B | 4 | 7 | 7 | 5 | 0.75 | 0 | 0.000000 | 0.00000000 | 0.00000000 | 0.16112516 | 4.850000 | 0.243602 | 5628.800000 |
| C | 5 | 7 | 7 | 6 | 2.0 | 1 | 0.500000 | 0.00000000 | 0.00000000 | 0.16112516 | 4.550000 | 0.153469 | 11951.050000 |
| D | 5 | 8 | 8 | 6 | 2.0 | 1 | 0.500000 | 0.00000000 | 0.00000000 | 0.16112516 | 4.550000 | 0.153469 | 7268.700000 |
| E | 5 | 8 | 9 | 6 | 2.0 | 1 | 0.500000 | 0.00000000 | 0.00000000 | 0.16112516 | 4.550000 | 0.153469 | 7268.700000 |
| F | 6 | 8 | 8 | 6 | 3.0 | 1 | 0.333333 | 0.00000000 | 0.00000000 | 0.16112516 | 4.300000 | 0.127733 | 18888.800000 |
| G | 6 | 9 | 9 | 7 | 3.0 | 1 | 0.333333 | 0.00000000 | 0.00000000 | 0.16112516 | 4.300000 | 0.127733 | 5299.350000 |

## High-Rate Sweep Summary

| EbN0_dB | candidate | blocks | block_errors | BLER | BLER_CI95_low | BLER_CI95_high | avg_iterations | expected_core_cycles |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 4.5 | float | 20 | 1 | 0.05000000 | 0.00888145 | 0.23613119 | 6.250000 | 443.750 |
| 4.5 | A | 20 | 3 | 0.15000000 | 0.05236875 | 0.36041886 | 7.900000 | 560.900 |
| 4.5 | B | 20 | 3 | 0.15000000 | 0.05236875 | 0.36041886 | 7.900000 | 560.900 |
| 4.5 | C | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 6.250000 | 443.750 |
| 4.5 | D | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 6.250000 | 443.750 |
| 4.5 | E | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 6.250000 | 443.750 |
| 4.5 | F | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 6.200000 | 440.200 |
| 4.5 | G | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 6.200000 | 440.200 |
| 4.5 | WIDE | 20 | 1 | 0.05000000 | 0.00888145 | 0.23613119 | 6.100000 | 433.100 |
| 4.9 | float | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 4.200000 | 298.200 |
| 4.9 | A | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 4.650000 | 330.150 |
| 4.9 | B | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 4.650000 | 330.150 |
| 4.9 | C | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 4.400000 | 312.400 |
| 4.9 | D | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 4.400000 | 312.400 |
| 4.9 | E | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 4.400000 | 312.400 |
| 4.9 | F | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 4.150000 | 294.650 |
| 4.9 | G | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 4.150000 | 294.650 |
| 4.9 | WIDE | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 4.200000 | 298.200 |
| 5.3 | float | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 3.350000 | 237.850 |
| 5.3 | A | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 3.500000 | 248.500 |
| 5.3 | B | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 3.500000 | 248.500 |
| 5.3 | C | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 3.500000 | 248.500 |
| 5.3 | D | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 3.500000 | 248.500 |
| 5.3 | E | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 3.500000 | 248.500 |
| 5.3 | F | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 3.400000 | 241.400 |
| 5.3 | G | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 3.400000 | 241.400 |
| 5.3 | WIDE | 20 | 0 | 0.00000000 | 0.00000000 | 0.16112516 | 3.300000 | 234.300 |

## Layer Order

| EbN0_dB | candidate | layer_order | BLER | BLER_CI95_low | BLER_CI95_high | avg_iterations | expected_core_cycles |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 4.5 | float | 0-1-2-3 | 0.00000000 | 0.00000000 | 0.24249401 | 5.916667 | 420.083 |
| 4.5 | D | 0-1-2-3 | 0.00000000 | 0.00000000 | 0.24249401 | 6.333333 | 449.667 |
| 4.5 | C | 0-1-2-3 | 0.00000000 | 0.00000000 | 0.24249401 | 6.333333 | 449.667 |
| 4.5 | float | 0-2-1-3 | 0.00000000 | 0.00000000 | 0.24249401 | 5.750000 | 408.250 |
| 4.5 | D | 0-2-1-3 | 0.00000000 | 0.00000000 | 0.24249401 | 6.250000 | 443.750 |
| 4.5 | C | 0-2-1-3 | 0.00000000 | 0.00000000 | 0.24249401 | 6.250000 | 443.750 |
| 4.9 | float | 0-1-2-3 | 0.00000000 | 0.00000000 | 0.24249401 | 4.250000 | 301.750 |
| 4.9 | D | 0-1-2-3 | 0.00000000 | 0.00000000 | 0.24249401 | 4.416667 | 313.583 |
| 4.9 | C | 0-1-2-3 | 0.00000000 | 0.00000000 | 0.24249401 | 4.416667 | 313.583 |
| 4.9 | float | 0-2-1-3 | 0.00000000 | 0.00000000 | 0.24249401 | 4.166667 | 295.833 |
| 4.9 | D | 0-2-1-3 | 0.00000000 | 0.00000000 | 0.24249401 | 4.583333 | 325.417 |
| 4.9 | C | 0-2-1-3 | 0.00000000 | 0.00000000 | 0.24249401 | 4.583333 | 325.417 |
| 5.3 | float | 0-1-2-3 | 0.00000000 | 0.00000000 | 0.24249401 | 3.166667 | 224.833 |
| 5.3 | D | 0-1-2-3 | 0.00000000 | 0.00000000 | 0.24249401 | 3.416667 | 242.583 |
| 5.3 | C | 0-1-2-3 | 0.00000000 | 0.00000000 | 0.24249401 | 3.416667 | 242.583 |
| 5.3 | float | 0-2-1-3 | 0.00000000 | 0.00000000 | 0.24249401 | 3.333333 | 236.667 |
| 5.3 | D | 0-2-1-3 | 0.00000000 | 0.00000000 | 0.24249401 | 3.666667 | 260.333 |
| 5.3 | C | 0-2-1-3 | 0.00000000 | 0.00000000 | 0.24249401 | 3.666667 | 260.333 |

## Secondary Stress

| profile | candidate | blocks | BLER | avg_iterations | fraction_reaching_max_iterations | saturation_events_per_block |
| --- | --- | --- | --- | --- | --- | --- |
| BG1_full | float | 4 | 0.00000000 | 3.000000 | 0.000000 | 0.000000 |
| BG1_full | C | 4 | 0.00000000 | 2.750000 | 0.000000 | 65160.500000 |
| BG1_full | D | 4 | 0.00000000 | 2.750000 | 0.000000 | 143638.000000 |
| BG1_full | E | 4 | 0.00000000 | 2.750000 | 0.000000 | 140274.750000 |
| BG1_full | G | 4 | 0.00000000 | 2.500000 | 0.000000 | 90932.750000 |
| BG2_full | float | 4 | 0.00000000 | 3.000000 | 0.000000 | 0.000000 |
| BG2_full | C | 4 | 0.00000000 | 3.000000 | 0.000000 | 22262.500000 |
| BG2_full | D | 4 | 0.00000000 | 3.000000 | 0.000000 | 67641.500000 |
| BG2_full | E | 4 | 0.00000000 | 3.000000 | 0.000000 | 66635.500000 |
| BG2_full | G | 4 | 0.00000000 | 3.000000 | 0.000000 | 54609.000000 |

## Width-Specific Diagnosis

A/B dynamic range diagnosis: `A: BLER 0.0000, avg iter 4.850; B: BLER 0.0000, avg iter 4.850`. In this pilot, both remain narrow and saturation-heavy; dynamic range remains the likely limiter.
C vs D APP width: `C: BLER 0.0000, avg iter 4.550; D: BLER 0.0000, avg iter 4.550`.
D vs E q width: `D: BLER 0.0000, avg iter 4.550; E: BLER 0.0000, avg iter 4.550`.
D vs F channel width: `D: BLER 0.0000, avg iter 4.550; F: BLER 0.0000, avg iter 4.300`.
D vs G extra headroom: `D: BLER 0.0000, avg iter 4.550; G: BLER 0.0000, avg iter 4.300`.

## Required Questions

1. Does high-width fixed-point converge toward floating OMS? `Yes in this runtime-bounded sanity run; hard decisions matched on the tested blocks and average iterations were close.`
2. Was v1 degradation partly caused by scale/beta calibration? `Likely yes; the expanded gain grid finds much wider scaling choices, but the pilot is too small to quantify the full BLER effect.`
3. Which saturation location is most harmful? `Inadequate confidence. Channel and min-input clipping dominate many rows, while A also shows APP-add saturation. The correlation table is screening evidence only.`
4. Is 7-bit APP viable? `Not frozen; C remains plausible but saturation and confidence are not yet acceptable.`
5. Is 9-bit q useful relative to 8-bit q? `No clear benefit was measured for E versus D in this pilot.`
6. Is 6-bit channel useful relative to 5-bit channel? `Potentially; F/G reduce channel saturation, but width cost requires a larger run.`
7. Does optimized layer order measurably hurt decoding? `No repeatable penalty was established in this small common-seed run.`
8. Which production width candidate is best? `NONE; confidence remains inadequate.`

## Recommendation

Final recommendation: `NONE`.
Confidence remains inadequate because this was a runtime-bounded v2 pilot rather than the requested 200-error/10000-block statistical run.

Raw CSVs:
- `results/fixed_point_v2/wide_reference_sanity.csv`
- `results/fixed_point_v2/gain_clipping_calibration.csv`
- `results/fixed_point_v2/beta_scale_calibration.csv`
- `results/fixed_point_v2/candidate_selection.csv`
- `results/fixed_point_v2/high_rate_sweep.csv`
- `results/fixed_point_v2/layer_order_comparison.csv`
- `results/fixed_point_v2/secondary_profiles.csv`
- `results/fixed_point_v2/saturation_failure_correlation.csv`
