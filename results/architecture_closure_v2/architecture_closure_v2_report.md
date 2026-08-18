# Architecture Closure v2 - Common-Seed Layer-Order Validation

This correction writes only under `results/architecture_closure_v2/` and does not modify previous closure results.
The previous order-index seed dependency was removed: each SNR uses one seed tuple reused across every order.

## Fixed Architecture

`P=384`, `B=2`, `D_A=3`, `D_R=3`, APP banks=8, forward cache=8.
Syndrome architecture: `S=8`, `Q=8`.
Fixed-point configuration: `F1`, CH=6, APP=8, q=8, M=6, gain=1.32, shift=1, beta_int=1, asymmetric two's-complement saturation.

## Q=8 Syndrome Check

All 24 layer orders were syndrome-valid with `Q=8`: `True`.
Maximum high-rate syndrome tail across the 24 orders: `1` cycle.
This preserves the previously observed high-rate tail behavior while using the globally safe queue depth.

## Cycle Table

| cycle_rank | layer_order | decoder_cycles_per_iteration | syndrome_tail | effective_iteration_boundary | required_queue_depth |
| --- | --- | --- | --- | --- | --- |
| 1 | 0-2-1-3 | 70 | 1 | 71 | 2 |
| 2 | 3-2-1-0 | 70 | 1 | 71 | 2 |
| 3 | 1-2-3-0 | 71 | 1 | 72 | 2 |
| 4 | 1-3-2-0 | 71 | 1 | 72 | 2 |
| 5 | 3-2-0-1 | 71 | 1 | 72 | 2 |
| 6 | 0-2-3-1 | 72 | 1 | 73 | 2 |
| 7 | 1-2-0-3 | 72 | 1 | 73 | 2 |
| 8 | 0-3-2-1 | 73 | 1 | 74 | 2 |
| 9 | 1-0-3-2 | 73 | 1 | 74 | 2 |
| 10 | 2-0-3-1 | 73 | 1 | 74 | 2 |

## Stage 1 Screen

All 24 permutations were run at 4.2, 4.4, and 4.9 dB with `500` common-seed blocks/order/SNR.

| screen_rank | layer_order | quality_pass | blocks | block_errors | BLER | avg_iterations | expected_latency_cycles | fraction_reaching_max_iterations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1-3-2-0 | True | 1500 | 38 | 0.02533333 | 6.040000 | 434.880 | 0.036667 |
| 2 | 1-2-3-0 | True | 1500 | 40 | 0.02666667 | 6.099333 | 439.152 | 0.036667 |
| 3 | 1-2-0-3 | True | 1500 | 46 | 0.03066667 | 6.105333 | 445.689 | 0.040667 |
| 4 | 1-0-3-2 | True | 1500 | 41 | 0.02733333 | 6.074667 | 449.525 | 0.036667 |
| 5 | 1-3-0-2 | True | 1500 | 37 | 0.02466667 | 6.055333 | 460.205 | 0.034000 |
| 6 | 0-2-1-3 | True | 1500 | 43 | 0.02866667 | 6.537333 | 464.151 | 0.043333 |
| 7 | 3-2-1-0 | True | 1500 | 49 | 0.03266667 | 6.570667 | 466.517 | 0.046000 |
| 8 | 3-1-2-0 | True | 1500 | 47 | 0.03133333 | 6.316000 | 467.384 | 0.042667 |
| 9 | 2-1-0-3 | True | 1500 | 43 | 0.02866667 | 6.322000 | 467.828 | 0.040000 |
| 10 | 1-0-2-3 | True | 1500 | 41 | 0.02733333 | 6.101333 | 469.803 | 0.038667 |

## Confirmation

Confirmed orders: `1-3-2-0, 1-2-3-0, 1-2-0-3, 1-0-3-2, 1-3-0-2, 0-2-1-3, 3-2-1-0, 0-1-2-3`.
Each SNR used one common seed tuple across every confirmed order with `2000` blocks/order/SNR.

| confirmation_rank | layer_order | selection_quality_pass | meaningful_error_degradation | blocks | block_errors | BLER | BLER_CI95_low | BLER_CI95_high | avg_iterations | expected_latency_cycles | fraction_reaching_max_iterations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1-3-2-0 | True | False | 4000 | 169 | 0.04225000 | 0.03644285 | 0.04893552 | 7.137250 | 513.882 | 0.060750 |
| 2 | 1-2-3-0 | True | False | 4000 | 169 | 0.04225000 | 0.03644285 | 0.04893552 | 7.173000 | 516.456 | 0.060750 |
| 3 | 1-2-0-3 | True | False | 4000 | 178 | 0.04450000 | 0.03853497 | 0.05133908 | 7.187000 | 524.651 | 0.062750 |
| 4 | 1-0-3-2 | True | False | 4000 | 162 | 0.04050000 | 0.03481893 | 0.04706280 | 7.166000 | 530.284 | 0.059500 |
| 5 | 0-2-1-3 | True | False | 4000 | 195 | 0.04875000 | 0.04249863 | 0.05586727 | 7.623500 | 541.269 | 0.072250 |
| 6 | 1-3-0-2 | True | False | 4000 | 165 | 0.04125000 | 0.03551453 | 0.04786576 | 7.122750 | 541.329 | 0.056750 |
| 7 | 3-2-1-0 | True | False | 4000 | 195 | 0.04875000 | 0.04249863 | 0.05586727 | 7.654250 | 543.452 | 0.072250 |
| 8 | 0-1-2-3 | True | False | 4000 | 180 | 0.04500000 | 0.03900050 | 0.05187259 | 7.402250 | 569.973 | 0.065000 |

Paired comparisons are in `paired_order_comparison.csv`; final selection uses latency first after filtering meaningful error-correction degradation.

## Final Recommendation

Final layer order: `1-3-2-0`.
Decoder cycles/iteration: `71`.
Syndrome tail: `1`.
Effective iteration boundary: `72`.

Reaffirmed architecture items:
- Width family: `F`.
- Gain: `1.32`.
- Channel-to-APP shift: `1`.
- beta_int: `1`.
- Saturation: `asymmetric two's-complement`.
- Syndrome: `S=8`, `Q=8`.

## Raw Outputs

- `results/architecture_closure_v2/layer_order_cycle_table.csv`
- `results/architecture_closure_v2/layer_order_screen.csv`
- `results/architecture_closure_v2/layer_order_confirmation.csv`
- `results/architecture_closure_v2/paired_order_comparison.csv`
- `results/architecture_closure_v2/order_selection_summary.csv`
- `results/architecture_closure_v2/seed_manifest.csv`
