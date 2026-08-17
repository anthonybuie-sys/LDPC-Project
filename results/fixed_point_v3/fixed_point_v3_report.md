# Fixed-Point Architecture Study v3

This report writes only under `results/fixed_point_v3/` and preserves existing v1/v2 results.
No RTL, scheduler, P/B, DA/DR, forwarding, syndrome-architecture, or schedule-encoding changes were made.

## Run Scope

Primary profile: `BG1_first4_high_rate`, BG1 Z=384 iLS=1 active rows 0..3, hardware order 0-2-1-3, max iterations 12.
Clipping calibration blocks at 4.4 dB: `64`.
Screening blocks per scale/shift/beta point at 4.4 dB: `16`.
Targeted blocks per retained point/SNR: `200`.
Layer-order blocks per point: `120`.
The targeted study uses common seed sets for every configuration at each SNR.

## Selected Configurations

| candidate | selection_rank | config_id | w_CH | w_APP | w_q | w_M | channel_gain | ch_to_app_shift | beta | beta_equiv | clip_fraction_at_4p4 | BLER | avg_iterations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C | 1 | C_ch5_app7_q7_m6_g0.759_s1_b1 | 5 | 7 | 7 | 6 | 0.759 | 1 | 1 | 0.658762 | 0.010010 | 0.00000000 | 8.312500 |
| C | 2 | C_ch5_app7_q7_m6_g0.759_s2_b1 | 5 | 7 | 7 | 6 | 0.759 | 2 | 1 | 0.329381 | 0.010010 | 0.06250000 | 6.937500 |
| D | 1 | D_ch5_app8_q8_m6_g0.759_s2_b1 | 5 | 8 | 8 | 6 | 0.759 | 2 | 1 | 0.329381 | 0.010010 | 0.00000000 | 6.687500 |
| D | 2 | D_ch5_app8_q8_m6_g0.99_s2_b1 | 5 | 8 | 8 | 6 | 0.99 | 2 | 1 | 0.252525 | 0.100027 | 0.00000000 | 6.812500 |
| F | 1 | F_ch6_app8_q8_m6_g1.32_s1_b1 | 6 | 8 | 8 | 6 | 1.32 | 1 | 1 | 0.378788 | 0.001000 | 0.00000000 | 6.562500 |
| F | 2 | F_ch6_app8_q8_m6_g1.542_s1_b1 | 6 | 8 | 8 | 6 | 1.542 | 1 | 1 | 0.324254 | 0.009968 | 0.00000000 | 6.625000 |
| G | 1 | G_ch6_app9_q9_m7_g1.32_s1_b1 | 6 | 9 | 9 | 7 | 1.32 | 1 | 1 | 0.378788 | 0.001000 | 0.00000000 | 6.562500 |
| G | 2 | G_ch6_app9_q9_m7_g1.32_s2_b2 | 6 | 9 | 9 | 7 | 1.32 | 2 | 2 | 0.378788 | 0.001000 | 0.00000000 | 6.562500 |

## Targeted Aggregate Summary

| candidate | config_id | blocks | block_errors | BLER | BLER_CI95_low | BLER_CI95_high | avg_iterations | expected_core_cycles | fraction_reaching_max_iterations | channel_quantizer_clip_count | app_init_saturation_count | q_sub_saturation_count | check_magnitude_clip_count | app_update_saturation_count |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C | C_ch5_app7_q7_m6_g0.759_s1_b1 | 800 | 91 | 0.11375000 | 0.09356926 | 0.13762242 | 7.457500 | 529.482 | 0.153750 | 115092 | 0 | 820 | 0 | 1327039 |
| C | C_ch5_app7_q7_m6_g0.759_s2_b1 | 800 | 135 | 0.16875000 | 0.14439355 | 0.19627246 | 6.965000 | 494.515 | 0.177500 | 115092 | 0 | 1179680 | 36192 | 24675485 |
| D | D_ch5_app8_q8_m6_g0.759_s2_b1 | 800 | 33 | 0.04125000 | 0.02952098 | 0.05736364 | 6.376250 | 452.714 | 0.056250 | 115092 | 0 | 3910 | 17121832 | 2875227 |
| D | D_ch5_app8_q8_m6_g0.99_s2_b1 | 800 | 39 | 0.04875000 | 0.03586442 | 0.06594852 | 6.381250 | 453.069 | 0.058750 | 940998 | 0 | 60743 | 37760734 | 8857257 |
| F | F_ch6_app8_q8_m6_g1.542_s1_b1 | 800 | 23 | 0.02875000 | 0.01923283 | 0.04277126 | 6.176250 | 438.514 | 0.033750 | 114702 | 0 | 4602 | 17606705 | 2875128 |
| F | F_ch6_app8_q8_m6_g1.32_s1_b1 | 800 | 23 | 0.02875000 | 0.01923283 | 0.04277126 | 6.208750 | 440.821 | 0.036250 | 14418 | 0 | 804 | 9161777 | 1213507 |
| G | G_ch6_app9_q9_m7_g1.32_s1_b1 | 800 | 23 | 0.02875000 | 0.01923283 | 0.04277126 | 6.208750 | 440.821 | 0.036250 | 14418 | 0 | 0 | 67283 | 512 |
| G | G_ch6_app9_q9_m7_g1.32_s2_b2 | 800 | 23 | 0.02875000 | 0.01923283 | 0.04277126 | 6.208750 | 440.821 | 0.036250 | 14418 | 0 | 804 | 9161782 | 1213641 |
| WIDE | WIDE_ch8_app12_q12_m10_g4_s0_b1 | 800 | 29 | 0.03625000 | 0.02535643 | 0.05157597 | 6.256250 | 444.194 | 0.047500 | 17 | 0 | 0 | 0 | 0 |
| float | float_beta0p25 | 800 | 28 | 0.03500000 | 0.02432471 | 0.05011964 | 6.237500 | 442.863 | 0.047500 | 0 | 0 | 0 | 0 | 0 |

## Width Comparisons

| comparison | left_candidate | left_BLER | left_avg_iterations | right_candidate | right_BLER | right_avg_iterations | delta_BLER_right_minus_left | delta_avg_iterations_right_minus_left |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C_vs_D | C | 0.11375000 | 7.457500 | D | 0.04125000 | 6.376250 | -0.07250000 | -1.081250 |
| D_vs_F | D | 0.04125000 | 6.376250 | F | 0.02875000 | 6.176250 | -0.01250000 | -0.200000 |
| F_vs_G | F | 0.02875000 | 6.176250 | G | 0.02875000 | 6.208750 | 0.00000000 | 0.032500 |

## Shift Comparison From Screening

| candidate | best_shift0_config_id | best_shift0_BLER | best_shift0_avg_iterations | best_nonzero_config_id | best_nonzero_shift | best_nonzero_BLER | best_nonzero_avg_iterations | delta_BLER_nonzero_minus_shift0 | delta_avg_iterations_nonzero_minus_shift0 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C | C_ch5_app7_q7_m6_g1.137_s0_b0 | 0.18750000 | 8.687500 | C_ch5_app7_q7_m6_g0.759_s1_b1 | 1 | 0.00000000 | 8.312500 | -0.18750000 | -0.375000 |
| D | D_ch5_app8_q8_m6_g1.137_s0_b0 | 0.18750000 | 8.687500 | D_ch5_app8_q8_m6_g0.759_s2_b1 | 2 | 0.00000000 | 6.687500 | -0.18750000 | -2.000000 |
| F | F_ch6_app8_q8_m6_g2.311_s0_b1 | 0.00000000 | 6.687500 | F_ch6_app8_q8_m6_g1.32_s1_b1 | 1 | 0.00000000 | 6.562500 | 0.00000000 | -0.125000 |
| G | G_ch6_app9_q9_m7_g2.311_s0_b1 | 0.00000000 | 6.687500 | G_ch6_app9_q9_m7_g1.32_s1_b1 | 1 | 0.00000000 | 6.562500 | 0.00000000 | -0.125000 |

## Layer Order Delta

| EbN0_dB | candidate | delta_BLER_opt_minus_nat | delta_avg_iter_opt_minus_nat |
| --- | --- | --- | --- |
| 4.4 | F | 0.00000000 | 0.183334 |
| 4.4 | float | 0.00000000 | 0.216666 |
| 4.4 | D | 0.00000000 | 0.141667 |
| 4.9 | F | 0.00000000 | 0.258334 |
| 4.9 | float | 0.00000000 | 0.258333 |
| 4.9 | D | 0.00000000 | 0.233333 |

## Required Questions

- Does channel-to-APP rescaling materially improve fixed-point OMS? `Yes in screening for at least one candidate; see shift_comparison.csv.`
- Can CH=5 now approximate floating OMS without extreme channel clipping? `Best CH5 is D with BLER 0.04125000 and average iterations 6.376250; selected CH5 clipping targets avoid the v2 extreme clipping regime.`
- Is 7-bit APP still viable? `No for this v3 target; C aggregate BLER 0.11375000 and average iterations 7.457500 lag D materially.`
- Does CH=6 provide meaningful benefit after scaling is decoupled? `D vs F delta average iterations is -0.200000 and delta BLER is -0.01250000.`
- Is G's extra width actually useful? `F vs G delta average iterations is 0.032500 and delta BLER is 0.00000000.`
- Does optimized layer order have a repeatable convergence penalty? `No BLER penalty appeared, but optimized order showed a repeatable positive average-iteration delta in this common-seed layer recheck.`
- Can we now select C, D, F, G, or NONE? `F`.

## Recommendation

Final recommendation: `F`.
Selected by the runtime-bounded v3 aggregate because BLER and average iterations were close to floating OMS.

Raw CSVs:
- `results/fixed_point_v3/gain_clipping_calibration.csv`
- `results/fixed_point_v3/screening.csv`
- `results/fixed_point_v3/selected_configs.csv`
- `results/fixed_point_v3/shift_comparison.csv`
- `results/fixed_point_v3/targeted_sweep.csv`
- `results/fixed_point_v3/targeted_summary.csv`
- `results/fixed_point_v3/width_comparison.csv`
- `results/fixed_point_v3/layer_order_comparison.csv`
- `results/fixed_point_v3/layer_order_delta.csv`
