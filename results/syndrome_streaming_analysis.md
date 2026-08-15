# Final-Touch Streaming Syndrome Analysis

Architecture model: real BG1/BG2 schedules, `P=384`, `B=2`, `D_A=3`, `D_R=3`, `APP banks=8`, `forward_cache_depth=8`, optimized bank map, optimized pairing, JIT forwarding.
The decoder schedule is observed after construction; decoder issue order, forwarding, banking, and pipeline behavior are unchanged.

## Profile Timing

| Profile | BG | Active Layers | Decoder Iteration Cycles | QC Work Items | First Final Cycle | Last Final Cycle | Selected Layer Order |
|---|---:|---|---:|---:|---:|---:|---|
| BG1_first4_high_rate | BG1 | 0-1-2-3 | 70 | 76 | 50 | 70 | 0-2-1-3 |
| BG1_full | BG1 | all | 288 | 316 | 77 | 288 | 0-1-2-3-4-5-6-7-8-9-10-11-12-13-14-15-16-17-18-19-20-21-22-23-24-25-26-27-28-29-30-31-32-33-34-35-36-37-38-39-40-41-42-43-44-45 |
| BG2_single0 | BG2 | 0 | 12 | 8 | 9 | 12 | 0 |
| BG2_full | BG2 | all | 228 | 197 | 45 | 228 | 0-1-2-3-4-5-6-7-8-9-10-11-12-13-14-15-16-17-18-19-20-21-22-23-24-25-26-27-28-29-30-31-32-33-34-35-36-37-38-39-40-41 |

## High-Rate BG1 Tail Sweep

| S | Q | Valid | Max Backlog | Max Queue Occupancy | Utilization | Completion | Tail | Effective Boundary |
|---:|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | 2 | False | 56 | 19 | 1.000000 | 126 | 56 | 126 |
| 1 | 4 | False | 56 | 19 | 1.000000 | 126 | 56 | 126 |
| 1 | 8 | False | 56 | 19 | 1.000000 | 126 | 56 | 126 |
| 1 | 16 | False | 56 | 19 | 1.000000 | 126 | 56 | 126 |
| 2 | 2 | False | 39 | 13 | 0.950000 | 90 | 20 | 90 |
| 2 | 4 | False | 39 | 13 | 0.950000 | 90 | 20 | 90 |
| 2 | 8 | False | 39 | 13 | 0.950000 | 90 | 20 | 90 |
| 2 | 16 | True | 39 | 13 | 0.950000 | 90 | 20 | 90 |
| 4 | 2 | False | 23 | 8 | 0.730769 | 76 | 6 | 76 |
| 4 | 4 | False | 23 | 8 | 0.730769 | 76 | 6 | 76 |
| 4 | 8 | True | 23 | 8 | 0.730769 | 76 | 6 | 76 |
| 4 | 16 | True | 23 | 8 | 0.730769 | 76 | 6 | 76 |
| 8 | 2 | True | 7 | 2 | 0.452381 | 71 | 1 | 71 |
| 8 | 4 | True | 7 | 2 | 0.452381 | 71 | 1 | 71 |
| 8 | 8 | True | 7 | 2 | 0.452381 | 71 | 1 | 71 |
| 8 | 16 | True | 7 | 2 | 0.452381 | 71 | 1 | 71 |
| 16 | 2 | True | 7 | 2 | 0.226190 | 71 | 1 | 71 |
| 16 | 4 | True | 7 | 2 | 0.226190 | 71 | 1 | 71 |
| 16 | 8 | True | 7 | 2 | 0.226190 | 71 | 1 | 71 |
| 16 | 16 | True | 7 | 2 | 0.226190 | 71 | 1 | 71 |

## Minimums

Minimum high-rate BG1 configuration with `L_syndrome-tail <= 1`: S=8, Q=2, tail=1.
Minimum configuration with `L_syndrome-tail <= 4` across all tested profiles: S=16, Q=4.

## Cross-Section

| S | W_syndrome at Z=384 | Compare to 3072-bit APP permutation path |
|---:|---:|---:|
| 1 | 384 | 0.125x |
| 2 | 768 | 0.250x |
| 4 | 1536 | 0.500x |
| 8 | 3072 | 1.000x |
| 16 | 6144 | 2.000x |

## All-Profile Recommended Row

| Profile | S | Q | Valid | Tail | Required Queue | Max Backlog | Utilization |
|---|---:|---:|---|---:|---:|---:|---:|
| BG1_first4_high_rate | 16 | 4 | True | 1 | 2 | 7 | 0.226190 |
| BG1_full | 16 | 4 | True | 3 | 4 | 42 | 0.092290 |
| BG2_single0 | 16 | 4 | True | 1 | 2 | 2 | 0.125000 |
| BG2_full | 16 | 4 | True | 3 | 4 | 38 | 0.066196 |

## Recommendation

Recommended option for the high-rate early-termination objective: `S=8` with finalized-column queue depth `2`.
A dedicated post-iteration pass is not required for the high-rate BG1 four-layer benchmark if that architecture is acceptable.

Raw sweep CSV: `results\syndrome_streaming_sweep.csv`.
Per-column final-touch CSV: `results\syndrome_final_touches.csv`.
REC A/B final-touch flag CSV: `results\syndrome_rec_final_touch_flags.csv`.
Per-edge syndrome work CSV: `results\syndrome_work_items.csv`.
