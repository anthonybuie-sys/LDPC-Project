from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
P = 384
OBSERVED_PATH = ROOT / "results" / "rtl_phase2" / "qc_sv_observed.csv"
OUT_PATH = ROOT / "results" / "rtl_phase2" / "qc_python_crosscheck.json"


def build_vectors() -> dict[str, list[int]]:
    onehot = [0] * P
    onehot[3] = 0x5A

    packing = [0] * P
    packing[0] = 0xA0
    packing[1] = 0xB1
    packing[383] = 0xC3

    structured = [((lane * 73) ^ (lane >> 1) ^ 0xA5) & 0xFF for lane in range(P)]

    seed = 0x4C445043
    random = []
    for _ in range(P):
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        random.append((seed >> 8) & 0xFF)

    return {
        "onehot8": onehot,
        "packing8": packing,
        "structured8": structured,
        "random8": random,
    }


def main() -> int:
    vectors = build_vectors()
    observed_rows = 0
    shift_groups: set[tuple[str, str, int]] = set()

    with OBSERVED_PATH.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            name = row["vector"]
            direction = row["direction"]
            shift = int(row["shift"])
            lane = int(row["lane"])
            observed = int(row["value_hex"], 16)
            vector = vectors[name]
            if direction == "forward":
                expected = vector[(lane + shift) % P]
            elif direction == "inverse":
                expected = vector[(lane - shift) % P]
            else:
                raise AssertionError(f"bad direction: {direction}")
            if observed != expected:
                raise AssertionError(
                    f"{name} {direction} shift={shift} lane={lane}: "
                    f"observed=0x{observed:x} expected=0x{expected:x}"
                )
            observed_rows += 1
            shift_groups.add((name, direction, shift))

    if observed_rows != 14208:
        raise AssertionError(f"observed_rows={observed_rows}, expected 14208")
    if len(shift_groups) != 37:
        raise AssertionError(
            f"vector_direction_shift_groups={len(shift_groups)}, expected 37"
        )

    result = {
        "models": [
            "ldpc_sim.qc_direction.scalar_rotate_to_check",
            "ldpc_sim.qc_direction.scalar_rotate_from_check",
            "ldpc_sim.numerical_decoder.rotate_to_check",
            "ldpc_sim.numerical_decoder.rotate_from_check",
        ],
        "observed_rows": observed_rows,
        "source": "results/rtl_phase2/qc_sv_observed.csv",
        "status": "PASS",
        "vector_direction_shift_groups": len(shift_groups),
    }
    OUT_PATH.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

    print("PASS")
    print(f"{observed_rows} observed SV lane rows checked")
    print(f"vector_direction_shift_groups={len(shift_groups)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
