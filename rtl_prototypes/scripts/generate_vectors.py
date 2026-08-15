from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

LANES = 384
APP_W = 8
Q_W = 8
MSG_W = 6
EDGE_ID_W = 5


def sat_signed(value: int, width: int) -> int:
    lo = -(1 << (width - 1))
    hi = (1 << (width - 1)) - 1
    return max(lo, min(hi, value))


def signed_c2v(mag: int, sign: int) -> int:
    return -mag if sign else mag


def inv_permute(values: list[int], shift: int) -> list[int]:
    lanes = len(values)
    return [values[(lane + shift) % lanes] for lane in range(lanes)]


def fwd_permute(values: list[int], shift: int) -> list[int]:
    lanes = len(values)
    return [values[(lane - shift) % lanes] for lane in range(lanes)]


def reconstruction_ref(case: dict[str, object]) -> dict[str, list[int]]:
    app_a_local: list[int] = []
    app_b_local: list[int] = []
    edge_a = int(case["edge_id_a"])
    edge_b = int(case["edge_id_b"])
    for lane in range(LANES):
        min1 = case["min1"][lane]
        min2 = case["min2"][lane]
        imin = case["imin"][lane]
        mag_a = min2 if edge_a == imin else min1
        mag_b = min2 if edge_b == imin else min1
        c2v_a = signed_c2v(mag_a, case["total_sign"][lane] ^ case["q_sign_a"][lane])
        c2v_b = signed_c2v(mag_b, case["total_sign"][lane] ^ case["q_sign_b"][lane])
        app_a_local.append(sat_signed(case["q_a"][lane] + c2v_a, APP_W))
        app_b_local.append(sat_signed(case["q_b"][lane] + c2v_b, APP_W))
    return {
        "app_a": inv_permute(app_a_local, int(case["shift_a"])),
        "app_b": inv_permute(app_b_local, int(case["shift_b"])),
    }


def accumulation_ref(case: dict[str, object]) -> dict[str, list[int]]:
    app_a_perm = fwd_permute(case["app_a"], int(case["shift_a"]))
    app_b_perm = fwd_permute(case["app_b"], int(case["shift_b"]))
    edge_a = int(case["edge_id_a"])
    edge_b = int(case["edge_id_b"])
    q_a: list[int] = []
    q_b: list[int] = []
    new_min1: list[int] = []
    new_min2: list[int] = []
    new_imin: list[int] = []
    new_sign: list[int] = []
    for lane in range(LANES):
        min1 = case["old_min1"][lane]
        min2 = case["old_min2"][lane]
        imin = case["old_imin"][lane]
        mag_a = min2 if edge_a == imin else min1
        mag_b = min2 if edge_b == imin else min1
        c2v_a = signed_c2v(mag_a, case["old_total_sign"][lane] ^ case["old_q_sign_a"][lane])
        c2v_b = signed_c2v(mag_b, case["old_total_sign"][lane] ^ case["old_q_sign_b"][lane])
        qa = sat_signed(app_a_perm[lane] - c2v_a, Q_W)
        qb = sat_signed(app_b_perm[lane] - c2v_b, Q_W)
        q_a.append(qa)
        q_b.append(qb)
        min1_tmp = min1
        min2_tmp = min2
        imin_tmp = imin
        for mag, edge in ((abs(qa), edge_a), (abs(qb), edge_b)):
            if mag < min1_tmp or (mag == min1_tmp and edge < imin_tmp):
                min2_tmp = min1_tmp
                min1_tmp = mag
                imin_tmp = edge
            elif mag < min2_tmp:
                min2_tmp = mag
        new_min1.append(min1_tmp)
        new_min2.append(min2_tmp)
        new_imin.append(imin_tmp)
        new_sign.append(case["old_total_sign"][lane] ^ (qa < 0) ^ (qb < 0))
    return {
        "q_a": q_a,
        "q_b": q_b,
        "min1": new_min1,
        "min2": new_min2,
        "imin": new_imin,
        "total_sign": [int(item) for item in new_sign],
    }


def random_signs(rng: random.Random) -> list[int]:
    return [rng.randrange(2) for _ in range(LANES)]


def random_case(rng: random.Random, kind: str) -> dict[str, object]:
    common = {
        "edge_id_a": rng.randrange(19),
        "edge_id_b": rng.randrange(19),
        "shift_a": rng.randrange(LANES),
        "shift_b": rng.randrange(LANES),
    }
    if kind == "reconstruction":
        case = {
            **common,
            "q_a": [rng.randint(-128, 127) for _ in range(LANES)],
            "q_b": [rng.randint(-128, 127) for _ in range(LANES)],
            "min1": [rng.randint(0, 31) for _ in range(LANES)],
            "min2": [rng.randint(32, 63) for _ in range(LANES)],
            "imin": [rng.randrange(19) for _ in range(LANES)],
            "total_sign": random_signs(rng),
            "q_sign_a": random_signs(rng),
            "q_sign_b": random_signs(rng),
        }
        case["expected"] = reconstruction_ref(case)
        return case
    case = {
        **common,
        "app_a": [rng.randint(-128, 127) for _ in range(LANES)],
        "app_b": [rng.randint(-128, 127) for _ in range(LANES)],
        "old_min1": [rng.randint(0, 31) for _ in range(LANES)],
        "old_min2": [rng.randint(32, 63) for _ in range(LANES)],
        "old_imin": [rng.randrange(19) for _ in range(LANES)],
        "old_total_sign": random_signs(rng),
        "old_q_sign_a": random_signs(rng),
        "old_q_sign_b": random_signs(rng),
    }
    case["expected"] = accumulation_ref(case)
    return case


def write_jsonl(path: Path, records: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, separators=(",", ":")) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate deterministic RTL prototype vectors.")
    parser.add_argument("--cases", type=int, default=4096)
    parser.add_argument("--seed", type=int, default=20260811)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("results/rtl_prototypes/vectors"),
    )
    args = parser.parse_args()

    rng = random.Random(args.seed)
    reconstruction = [random_case(rng, "reconstruction") for _ in range(args.cases)]
    accumulation = [random_case(rng, "accumulation") for _ in range(args.cases)]

    write_jsonl(args.output_dir / "reconstruction_vectors.jsonl", reconstruction)
    write_jsonl(args.output_dir / "accumulation_vectors.jsonl", accumulation)
    print(f"Generated {args.cases} reconstruction vectors")
    print(f"Generated {args.cases} accumulation vectors")
    print(args.output_dir.resolve())


if __name__ == "__main__":
    main()

