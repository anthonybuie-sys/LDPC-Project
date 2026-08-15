# Fixed-Point Numerical OMS Pilot

This is a deterministic runtime-bounded pilot, not a publication-quality BLER curve.
The cycle scheduler, P/B choice, DA/DR choice, schedule encoding, forwarding architecture, syndrome architecture, and RTL were not modified.

## Verification Context

Verification/test count: `59 passed` from `python tests/run_tests.py`.
Calibration blocks per point: `20` or stop at `100` block errors.
High-rate sweep blocks per point: `40` or stop at `100` block errors.
Layer-order comparison blocks per point: `20` or stop at `100` block errors.
Secondary profile blocks per point: `8` or stop at `100` block errors.
BPSK all-zero convention: bit 0 maps to +1, `sigma^2 = 1/(2 R 10^(EbN0/10))`, and `LLR = 2y/sigma^2`.
High-rate BG1 uses `R=22/24`, columns 0 and 1 punctured to exactly zero LLR, and no filler bits.

## Floating Reference

Selected floating OMS beta: `0.25`.

## Best Fixed Parameters

| candidate | widths | channel_gain | beta_int | calibration_BLER | calibration_avg_iter | sat_events_per_block |
| --- | --- | --- | --- | --- | --- | --- |
| A | 4/6/6/5 | 0.75 | 0 | 0.000000 | 4.6000 | 9666.850 |
| B | 4/7/7/5 | 0.75 | 0 | 0.000000 | 4.6000 | 5825.700 |
| C | 5/7/7/6 | 1.25 | 0 | 0.000000 | 4.4000 | 5406.150 |
| D | 5/8/8/6 | 1.25 | 0 | 0.000000 | 4.4000 | 3860.100 |
| E | 5/8/9/6 | 1.25 | 0 | 0.000000 | 4.4000 | 3860.100 |
| F | 6/8/8/6 | 1.25 | 0 | 0.000000 | 4.3500 | 107.000 |
| G | 6/9/9/7 | 1.25 | 0 | 0.000000 | 4.3500 | 13.950 |

## High-Rate BLER

| EbN0 | candidate | blocks | errors | BLER |
| --- | --- | --- | --- | --- |
| 4.0 | float | 40 | 24 | 0.60000000 |
| 4.0 | A | 40 | 40 | 1.00000000 |
| 4.0 | B | 40 | 40 | 1.00000000 |
| 4.0 | C | 40 | 40 | 1.00000000 |
| 4.0 | D | 40 | 40 | 1.00000000 |
| 4.0 | E | 40 | 40 | 1.00000000 |
| 4.0 | F | 40 | 40 | 1.00000000 |
| 4.0 | G | 40 | 40 | 1.00000000 |
| 4.5 | float | 40 | 0 | 0.00000000 |
| 4.5 | A | 40 | 3 | 0.07500000 |
| 4.5 | B | 40 | 3 | 0.07500000 |
| 4.5 | C | 40 | 1 | 0.02500000 |
| 4.5 | D | 40 | 1 | 0.02500000 |
| 4.5 | E | 40 | 1 | 0.02500000 |
| 4.5 | F | 40 | 1 | 0.02500000 |
| 4.5 | G | 40 | 1 | 0.02500000 |
| 4.9 | float | 40 | 0 | 0.00000000 |
| 4.9 | A | 40 | 0 | 0.00000000 |
| 4.9 | B | 40 | 0 | 0.00000000 |
| 4.9 | C | 40 | 0 | 0.00000000 |
| 4.9 | D | 40 | 0 | 0.00000000 |
| 4.9 | E | 40 | 0 | 0.00000000 |
| 4.9 | F | 40 | 0 | 0.00000000 |
| 4.9 | G | 40 | 0 | 0.00000000 |
| 5.3 | float | 40 | 0 | 0.00000000 |
| 5.3 | A | 40 | 0 | 0.00000000 |
| 5.3 | B | 40 | 0 | 0.00000000 |
| 5.3 | C | 40 | 0 | 0.00000000 |
| 5.3 | D | 40 | 0 | 0.00000000 |
| 5.3 | E | 40 | 0 | 0.00000000 |
| 5.3 | F | 40 | 0 | 0.00000000 |
| 5.3 | G | 40 | 0 | 0.00000000 |
| 5.7 | float | 40 | 0 | 0.00000000 |
| 5.7 | A | 40 | 0 | 0.00000000 |
| 5.7 | B | 40 | 0 | 0.00000000 |
| 5.7 | C | 40 | 0 | 0.00000000 |
| 5.7 | D | 40 | 0 | 0.00000000 |
| 5.7 | E | 40 | 0 | 0.00000000 |
| 5.7 | F | 40 | 0 | 0.00000000 |
| 5.7 | G | 40 | 0 | 0.00000000 |

## Average Iterations And Expected Core Cycles

| EbN0 | candidate | avg_iterations | expected_core_cycles |
| --- | --- | --- | --- |
| 4.0 | float | 11.200000 | 795.200 |
| 4.0 | A | 12.000000 | 852.000 |
| 4.0 | B | 12.000000 | 852.000 |
| 4.0 | C | 12.000000 | 852.000 |
| 4.0 | D | 12.000000 | 852.000 |
| 4.0 | E | 12.000000 | 852.000 |
| 4.0 | F | 12.000000 | 852.000 |
| 4.0 | G | 12.000000 | 852.000 |
| 4.5 | float | 5.800000 | 411.800 |
| 4.5 | A | 8.000000 | 568.000 |
| 4.5 | B | 8.000000 | 568.000 |
| 4.5 | C | 7.600000 | 539.600 |
| 4.5 | D | 7.600000 | 539.600 |
| 4.5 | E | 7.600000 | 539.600 |
| 4.5 | F | 7.625000 | 541.375 |
| 4.5 | G | 7.625000 | 541.375 |
| 4.9 | float | 4.200000 | 298.200 |
| 4.9 | A | 4.600000 | 326.600 |
| 4.9 | B | 4.600000 | 326.600 |
| 4.9 | C | 4.450000 | 315.950 |
| 4.9 | D | 4.450000 | 315.950 |
| 4.9 | E | 4.450000 | 315.950 |
| 4.9 | F | 4.425000 | 314.175 |
| 4.9 | G | 4.425000 | 314.175 |
| 5.3 | float | 3.425000 | 243.175 |
| 5.3 | A | 3.450000 | 244.950 |
| 5.3 | B | 3.450000 | 244.950 |
| 5.3 | C | 3.425000 | 243.175 |
| 5.3 | D | 3.425000 | 243.175 |
| 5.3 | E | 3.425000 | 243.175 |
| 5.3 | F | 3.425000 | 243.175 |
| 5.3 | G | 3.425000 | 243.175 |
| 5.7 | float | 3.050000 | 216.550 |
| 5.7 | A | 3.025000 | 214.775 |
| 5.7 | B | 3.025000 | 214.775 |
| 5.7 | C | 3.000000 | 213.000 |
| 5.7 | D | 3.000000 | 213.000 |
| 5.7 | E | 3.000000 | 213.000 |
| 5.7 | F | 3.000000 | 213.000 |
| 5.7 | G | 3.000000 | 213.000 |

## Saturation At 4.9 dB

| EbN0 | candidate | channel | q_sub | min_clip | app_add | sat_blocks | sat_per_block |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 4.9 | A | 225153 | 118 | 0 | 175495 | 1.000000 | 10019.150000 |
| 4.9 | B | 225153 | 0 | 8770 | 1 | 1.000000 | 5848.100000 |
| 4.9 | C | 151649 | 32 | 0 | 84445 | 1.000000 | 5903.150000 |
| 4.9 | D | 151649 | 0 | 2554 | 0 | 1.000000 | 3855.075000 |
| 4.9 | E | 151649 | 0 | 2554 | 0 | 1.000000 | 3855.075000 |
| 4.9 | F | 635 | 0 | 6430 | 0 | 1.000000 | 176.625000 |
| 4.9 | G | 635 | 0 | 0 | 0 | 1.000000 | 15.875000 |

## Hardware Width Proxies

| candidate | w_CH | w_APP | w_q | w_M | W_APP_perm | W_q | W_forward_state | W_check | W_APP_perm_reduction_vs_D_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 4 | 6 | 6 | 5 | 4608 | 4608 | 18432 | 16 | 25.00 |
| B | 4 | 7 | 7 | 5 | 5376 | 5376 | 21504 | 16 | 12.50 |
| C | 5 | 7 | 7 | 6 | 5376 | 5376 | 21504 | 18 | 12.50 |
| D | 5 | 8 | 8 | 6 | 6144 | 6144 | 24576 | 18 | 0.00 |
| E | 5 | 8 | 9 | 6 | 6144 | 6912 | 24576 | 18 | 0.00 |
| F | 6 | 8 | 8 | 6 | 6144 | 6144 | 24576 | 18 | 0.00 |
| G | 6 | 9 | 9 | 7 | 6912 | 6912 | 27648 | 20 | -12.50 |

## Natural Vs Hardware Layer Order

| EbN0 | candidate | order | BLER | avg_iter | failures |
| --- | --- | --- | --- | --- | --- |
| 4.5 | float | 0-1-2-3 | 0.00000000 | 5.200000 | 0 |
| 4.5 | D | 0-1-2-3 | 0.05000000 | 6.600000 | 1 |
| 4.5 | C | 0-1-2-3 | 0.05000000 | 6.600000 | 1 |
| 4.5 | float | 0-2-1-3 | 0.00000000 | 5.350000 | 0 |
| 4.5 | D | 0-2-1-3 | 0.00000000 | 6.650000 | 0 |
| 4.5 | C | 0-2-1-3 | 0.00000000 | 6.650000 | 0 |
| 4.9 | float | 0-1-2-3 | 0.00000000 | 4.050000 | 0 |
| 4.9 | D | 0-1-2-3 | 0.00000000 | 4.200000 | 0 |
| 4.9 | C | 0-1-2-3 | 0.00000000 | 4.200000 | 0 |
| 4.9 | float | 0-2-1-3 | 0.00000000 | 4.250000 | 0 |
| 4.9 | D | 0-2-1-3 | 0.00000000 | 4.400000 | 0 |
| 4.9 | C | 0-2-1-3 | 0.00000000 | 4.400000 | 0 |
| 5.3 | float | 0-1-2-3 | 0.00000000 | 3.300000 | 0 |
| 5.3 | D | 0-1-2-3 | 0.00000000 | 3.400000 | 0 |
| 5.3 | C | 0-1-2-3 | 0.00000000 | 3.400000 | 0 |
| 5.3 | float | 0-2-1-3 | 0.00000000 | 3.450000 | 0 |
| 5.3 | D | 0-2-1-3 | 0.00000000 | 3.600000 | 0 |
| 5.3 | C | 0-2-1-3 | 0.00000000 | 3.600000 | 0 |

## Secondary Profile Stress

| profile | candidate | blocks | BLER | avg_iter | failures | sat_per_block |
| --- | --- | --- | --- | --- | --- | --- |
| BG1_full | float | 8 | 0.00000000 | 2.875000 | 0 | 0.000000 |
| BG1_full | C | 8 | 0.00000000 | 3.000000 | 0 | 46413.375000 |
| BG1_full | D | 8 | 0.00000000 | 3.000000 | 0 | 114773.000000 |
| BG1_full | E | 8 | 0.00000000 | 3.000000 | 0 | 111833.500000 |
| BG2_full | float | 8 | 0.00000000 | 3.000000 | 0 | 0.000000 |
| BG2_full | C | 8 | 0.00000000 | 3.000000 | 0 | 11693.125000 |
| BG2_full | D | 8 | 0.00000000 | 3.000000 | 0 | 39153.500000 |
| BG2_full | E | 8 | 0.00000000 | 3.000000 | 0 | 39009.750000 |

## Compressed-State Equivalence

The unit tests exercise floating and fixed full-C2V versus compressed-state equivalence after every layer, after every iteration, and at final APP/hard-decision/syndrome boundaries. No numerical mismatch was observed in the deterministic tests used for this report.

## Recommendation

Recommended v1.0 width set: `NONE - more study required`.
The completed run is a small deterministic pilot. It is useful for correctness, ordering, and saturation screening, but too small to freeze a v1.0 width set.
All fixed-point candidates were materially worse than the floating reference at 4.0 dB in this pilot, and the narrow candidates show high saturation telemetry.
Candidate F and G greatly reduce saturation relative to C/D/E, but the present sample count is not enough to justify paying the width cost or to rule out retuning gain/beta.
Recommended channel_gain: `N/A`.
Recommended beta_int: `N/A`.
Recommended latency-focused Nmax default: `6`.
Recommended stronger-error-correction Nmax default: `12`.

Raw outputs:
- `results\fixed_point\calibration.csv`
- `results\fixed_point\high_rate_sweep.csv`
- `results\fixed_point\layer_order_comparison.csv`
- `results\fixed_point\secondary_profiles.csv`
- `results\fixed_point\hardware_width_proxy.csv`
