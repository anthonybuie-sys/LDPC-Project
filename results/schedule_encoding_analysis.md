# Schedule Encoding Analysis

Architecture model: `B=2`, `D_A=3`, `D_R=3`, `APP banks=8`, `forward_cache_depth=8`, optimized bank map, optimized pairing, JIT forwarding.
The current simulator enforces `P == Z`; each supported lifting was therefore run with its own `P=Z` while preserving the same dependency/bank/forwarding model. The packed schedule itself is independent of `P` and `Z` because it is expressed in base-graph layer/local-edge coordinates.

Supported lifting files tested: BG1=51, BG2=51.

Profiles tested are the completing real-data profiles currently exposed by the repository: BG1 first-four benchmark, BG1 full loader profile, BG2 single-layer loader smoke profile, and BG2 full loader profile.

## Profile Summary

| BG | Profile | Active Layers | Invariant Across Z | Program Length | ACC | REC | Max Q Slots | Max Forward Occupancy | Selected Layer Order | Z-change Reasons |
|---:|---|---|---|---:|---:|---:|---:|---:|---|---|
| 1 | first4 | 0-1-2-3 | True | 70 | 40 | 40 | 10 | 8 | 0-2-1-3 | QC shifts changed, absorbed by separate shift table |
| 1 | full | all | True | 288 | 173 | 173 | 10 | 8 | 0-1-2-3-4-5-6-7-8-9-10-11-12-13-14-15-16-17-18-19-20-21-22-23-24-25-26-27-28-29-30-31-32-33-34-35-36-37-38-39-40-41-42-43-44-45 | QC shifts changed, absorbed by separate shift table |
| 2 | single0 | 0 | True | 12 | 4 | 4 | 4 | 0 | 0 | QC shifts changed, absorbed by separate shift table |
| 2 | full | all | True | 228 | 106 | 106 | 5 | 8 | 0-1-2-3-4-5-6-7-8-9-10-11-12-13-14-15-16-17-18-19-20-21-22-23-24-25-26-27-28-29-30-31-32-33-34-35-36-37-38-39-40-41 | QC shifts changed, absorbed by separate shift table |

## Field Maxima

| Field | Max Observed | Bits Required | Proposed Bits | Status |
|---|---:|---:|---:|---|
| layer_id | 45 | 6 | 6 | OK |
| local_edge_id | 18 | 5 | 5 | OK |
| qslot | 9 | 4 | 4 | OK |
| forward_slot | 7 | 3 | 3 | OK |
| APP column | 67 | 7 | 7 | OK |
| program_length | 288 | 9 | 9 | OK |

The 36-bit ACC/REC words use `layer_id`, two local edge IDs, `qbuf`, `qslot`, two 4-bit forward selector fields, a 2-bit lane mask, valid bit, two REC final-touch flag bits, and two reserved bits. APP columns are recovered from the base-graph table by `(BG, layer, local_edge)`; if APP column were stored directly, BG1 column 67 requires 7 bits.

## Storage

Schedule ROM once per `(BG, active-layer profile)` at 72 bits/cycle: 43056 bits (5382.0 bytes, 5.26 KiB).
Schedule ROM duplicated for every supported Z: 2195856 bits (274482.0 bytes, 268.05 KiB).
Storage reduction from hybrid schedule sharing: 51.0x fewer schedule bits.
Separate 9-bit QC-shift table for every BG/Z/layer/edge: 26163 entries, 235467 bits (29433.4 bytes, 28.74 KiB).
Distinct optimized APP bank maps across the analyzed profiles: 4.

## Packed Example

Packed BG1 Z=384 first4 example: `results\schedule_encoding_bg1_z384_first4.txt`.
Round-trip decoding of every packed ACC and REC instruction reproduced the structured schedule records exactly.

## Conclusion

For the tested real BG1/BG2 files and active-layer profiles, changing Z changed QC shifts but did not change base-column connectivity, optimized bank map, selected layer order, B=2 pairing, ACC order, REC order, forwarding-slot assignment, or cycle count. One optimized schedule can therefore serve the tested lifting sizes for the same BG/profile when paired with the separate shift table.
