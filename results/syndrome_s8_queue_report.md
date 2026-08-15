# Final-Touch Syndrome Queue Sizing

Fixed architecture: real BG1/BG2 schedules, `P=384`, `B=2`, `D_A=3`, `D_R=3`, optimized banking/pairing, JIT forwarding, final-touch REC flags, and syndrome parallelism fixed at `S=8`.
The decoder scheduler, schedule encoding, pipeline depths, forwarding behavior, and RTL were not modified.

## Queue Depth Sweep

| Queue depth | All profiles valid? | Max occupancy | Worst tail | Worst profile |
|---:|---|---:|---:|---|
| 2 | no | 8 | 9 | BG1_full |
| 4 | no | 8 | 9 | BG1_full |
| 8 | yes | 8 | 9 | BG1_full |
| 16 | yes | 8 | 9 | BG1_full |

## Global Queue Result

Maximum observed queue occupancy is `8`.
Producer profile: `BG1_full` (`BG1`, active layers `all`, `Z=384`, program length `288` cycles).
First cycle where this maximum occurs: `288`.
Minimum globally safe finalized-column queue depth: `Q=8`.

## Syndrome Tail Characterization

Worst tested profile tail at the minimum safe queue is `9` cycles.
Worst profile: `BG1_full` (`BG1`, active layers `all`, `Z=384`).

| Metric | Value |
|---|---:|
| Total syndrome work items | 316 |
| First finalized-column cycle | 77 |
| Last finalized-column cycle | 288 |
| Maximum syndrome backlog | 71 |
| Maximum finalized-column queue occupancy | 8 |
| Queue peak cycle | 288 |
| Syndrome completion cycle | 297 |
| Tail cycles | 9 |

## High-Rate BG1 Reference

| Metric | Value |
|---|---:|
| Queue depth | 2 |
| Queue peak | 2 |
| Total work items | 76 |
| Syndrome engine utilization | 0.452381 |
| Syndrome completion cycle | 71 |
| Final tail | 1 |

## Profile Results At Minimum Safe Queue

| Profile | BG | Active Layers | Z | Program Length | Max Queue | Peak Cycle | Max Backlog | Completion | Tail | Layer Order |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| BG1_first4_high_rate | BG1 | 0-1-2-3 | 384 | 70 | 2 | 56 | 7 | 71 | 1 | 0-2-1-3 |
| BG1_full | BG1 | all | 384 | 288 | 8 | 288 | 71 | 297 | 9 | 0-1-2-3-4-5-6-7-8-9-10-11-12-13-14-15-16-17-18-19-20-21-22-23-24-25-26-27-28-29-30-31-32-33-34-35-36-37-38-39-40-41-42-43-44-45 |
| BG2_single0 | BG2 | 0 | 384 | 12 | 2 | 9 | 2 | 13 | 1 | 0 |
| BG2_full | BG2 | all | 384 | 228 | 4 | 223 | 51 | 235 | 7 | 0-1-2-3-4-5-6-7-8-9-10-11-12-13-14-15-16-17-18-19-20-21-22-23-24-25-26-27-28-29-30-31-32-33-34-35-36-37-38-39-40-41 |

## Final Recommendation

Recommended syndrome architecture: `S=8`.
Recommended finalized-column queue: `Q=8`.
High-rate BG1 tail: `L_tail=1`.
Worst tested profile tail: `L_tail,max=9`.
Worst tested profile: `BG1_full`.
Yes. With `S=8` and `Q=8`, all currently completing real BG1/BG2 profiles are correct under the no-stall queue model. The high-rate BG1 benchmark remains at a 1-cycle syndrome tail; the longer 9-cycle full-BG1 tail is a latency characterization, not a queue-correctness failure.

Raw CSV: `results\syndrome_s8_queue_sweep.csv`.
