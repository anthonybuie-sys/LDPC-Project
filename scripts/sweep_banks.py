from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.benchmark_bg1_z384 import DEFAULT_CONFIG, DEFAULT_GRAPH
from ldpc_sim.simulator import bank_sweep


def main() -> None:
    print(DEFAULT_GRAPH.source_note)
    print("APP bank sweep")
    print(f"{'banks':>6} {'strategy':>10} {'cycles':>8} {'bank stalls':>12}")
    for row in bank_sweep(DEFAULT_GRAPH, DEFAULT_CONFIG):
        if row["cycles_per_iteration"] is None:
            print(
                f"{row['num_app_banks']:6d} {row['strategy']:>10} "
                f"{'NA':>8} {'NA':>12}  {row['status']}"
            )
        else:
            print(
                f"{row['num_app_banks']:6d} {row['strategy']:>10} "
                f"{row['cycles_per_iteration']:8d} {row['bank_stalls']:12d}"
            )


if __name__ == "__main__":
    main()
