# Final Numerical / Schedule Architecture Closure

This report writes only under `results/architecture_closure/` and preserves existing v1/v2/v3 result directories.
No RTL, P/B, D_A/D_R, forwarding, syndrome architecture, or scheduler behavior was changed.

## Architecture Model

Scheduler: `P=384`, `B=2`, `D_A=3`, `D_R=3`, APP banks=8, forward cache=8, optimized bank map/pairing/JIT forwarding.
Syndrome architecture held fixed at `S=8`, `Q=2`.
Layer-order optimization used provisional `F2` because v3 selected it within the F family.

## Cycle And Syndrome Boundary

| cycle_rank | layer_order | decoder_cycles_per_iteration | syndrome_tail | effective_iteration_boundary | syndrome_valid | required_queue_depth |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 0-2-1-3 | 70 | 1 | 71 | True | 2 |
| 2 | 3-2-1-0 | 70 | 1 | 71 | True | 2 |
| 3 | 1-2-3-0 | 71 | 1 | 72 | True | 2 |
| 4 | 1-3-2-0 | 71 | 1 | 72 | True | 2 |
| 5 | 3-2-0-1 | 71 | 1 | 72 | True | 2 |
| 6 | 0-2-3-1 | 72 | 1 | 73 | True | 2 |
| 7 | 1-2-0-3 | 72 | 1 | 73 | True | 2 |
| 8 | 0-3-2-1 | 73 | 1 | 74 | True | 2 |

## Stage 1 Layer-Order Screen

All 24 permutations were evaluated with 200 common-seed blocks/order/SNR at 4.2, 4.4, and 4.9 dB.
Quality pass was enforced before latency ranking using aggregate BLER and per-SNR BLER margins.

| stage1_latency_rank | layer_order | stage1_quality_pass | blocks | block_errors | BLER | avg_iterations | expected_latency_cycles | fraction_reaching_max_iterations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1-3-0-2 | True | 600 | 15 | 0.02500000 | 6.002000 | 450.173 | 0.033333 |
| 2 | 3-2-1-0 | True | 600 | 10 | 0.01666667 | 6.458333 | 458.542 | 0.023333 |
| 3 | 1-2-3-0 | False | 600 | 18 | 0.03000000 | 5.950000 | 428.400 | 0.040000 |
| 4 | 1-3-2-0 | False | 600 | 20 | 0.03333333 | 6.036667 | 434.640 | 0.038333 |
| 5 | 1-2-0-3 | False | 600 | 25 | 0.04166667 | 6.086667 | 444.327 | 0.041667 |
| 6 | 1-0-3-2 | False | 600 | 19 | 0.03166667 | 6.048333 | 447.577 | 0.050000 |
| 7 | 0-2-1-3 | False | 600 | 23 | 0.03833333 | 6.448333 | 457.832 | 0.050000 |
| 8 | 3-1-2-0 | False | 600 | 21 | 0.03500000 | 6.193333 | 458.307 | 0.038333 |

## Stage 2 Layer-Order Confirmation

Confirmed orders: `1-3-0-2, 3-2-1-0, 1-2-3-0, 0-2-1-3, 0-1-2-3`.

| layer_order | blocks | block_errors | BLER | BLER_CI95_low | BLER_CI95_high | avg_iterations | expected_latency_cycles | fraction_reaching_max_iterations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0-1-2-3 | 2000 | 112 | 0.05600000 | 0.04674833 | 0.06695400 | 7.339000 | 565.103 | 0.077500 |
| 0-2-1-3 | 2000 | 118 | 0.05900000 | 0.04949422 | 0.07019661 | 7.598000 | 539.458 | 0.079500 |
| 1-2-3-0 | 2000 | 106 | 0.05300000 | 0.04401046 | 0.06370338 | 7.189500 | 517.644 | 0.072000 |
| 1-3-0-2 | 2000 | 81 | 0.04050000 | 0.03270494 | 0.05005682 | 7.043000 | 535.268 | 0.061500 |
| 3-2-1-0 | 2000 | 101 | 0.05050000 | 0.04173547 | 0.06098795 | 7.652000 | 543.292 | 0.080500 |

Selected layer order: `1-3-0-2` with effective boundary `76` cycles.

## Final Fixed-Point Comparison

| layer_order | config_name | blocks | block_errors | BLER | BLER_CI95_low | BLER_CI95_high | avg_iterations | expected_latency_cycles | fraction_reaching_max_iterations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1-3-0-2 | F1 | 2000 | 82 | 0.04100000 | 0.03315349 | 0.05060636 | 7.143500 | 542.906 | 0.058500 |
| 1-3-0-2 | F2 | 2000 | 93 | 0.04650000 | 0.03810907 | 0.05662969 | 7.147000 | 543.172 | 0.063500 |
| 1-3-0-2 | float | 2000 | 117 | 0.05850000 | 0.04903604 | 0.06965671 | 7.249000 | 550.924 | 0.080000 |
| 1-3-0-2 | D | 2000 | 136 | 0.06800000 | 0.05777463 | 0.07988170 | 7.415000 | 563.540 | 0.092500 |
| 3-2-1-0 | F1 | 2000 | 103 | 0.05150000 | 0.04264472 | 0.06207487 | 7.677000 | 545.067 | 0.072500 |
| 3-2-1-0 | F2 | 2000 | 111 | 0.05550000 | 0.04629145 | 0.06641281 | 7.643500 | 542.688 | 0.078000 |
| 3-2-1-0 | float | 2000 | 141 | 0.07050000 | 0.06008497 | 0.08256177 | 7.734000 | 549.114 | 0.100000 |
| 3-2-1-0 | D | 2000 | 157 | 0.07850000 | 0.06750432 | 0.09111176 | 7.941000 | 563.811 | 0.110500 |

## Saturation Rule Comparison

| config_name | saturation_rule | blocks | block_errors | BLER | BLER_CI95_low | BLER_CI95_high | avg_iterations | expected_latency_cycles | fraction_reaching_max_iterations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| F1 | asymmetric | 2000 | 95 | 0.04750000 | 0.03901402 | 0.05772091 | 7.142000 | 542.792 | 0.060500 |
| F1 | symmetric | 2000 | 95 | 0.04750000 | 0.03901402 | 0.05772091 | 7.142000 | 542.792 | 0.060500 |
| F2 | asymmetric | 2000 | 97 | 0.04850000 | 0.03992009 | 0.05881100 | 7.125000 | 541.500 | 0.063500 |
| F2 | symmetric | 2000 | 97 | 0.04850000 | 0.03992009 | 0.05881100 | 7.125000 | 541.500 | 0.063500 |

Symmetric and asymmetric saturation were materially equivalent in this narrow check; retain the current asymmetric two's-complement rule.

## Explicit Recommendations

- Final width family: `F`.
- Final gain: `1.32`.
- Final channel-to-APP shift: `1`.
- Final beta_int: `1`.
- Final layer order: `1-3-0-2`.
- Final saturation rule: `asymmetric two's-complement`.

## Raw Outputs

- `results/architecture_closure/layer_order_cycle_table.csv`
- `results/architecture_closure/layer_order_screen.csv`
- `results/architecture_closure/layer_order_confirmation.csv`
- `results/architecture_closure/final_fixed_point_comparison.csv`
- `results/architecture_closure/saturation_rule_comparison.csv`
