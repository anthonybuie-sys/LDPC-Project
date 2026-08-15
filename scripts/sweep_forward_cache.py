from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.benchmark_bg1_z384 import DEFAULT_CONFIG, DEFAULT_GRAPH
from ldpc_sim.simulator import forward_cache_sweep


def main() -> None:
    print(DEFAULT_GRAPH.source_note)
    print("Forward-cache depth sweep")
    print(f"{'depth':>6} {'cycles':>8} {'overflows':>10} {'max live':>10}")
    for row in forward_cache_sweep(DEFAULT_GRAPH, DEFAULT_CONFIG):
        print(
            f"{row['forward_cache_depth']:6d} {row['cycles_per_iteration']:8d} "
            f"{row['overflow_events']:10d} {row['max_live_entries']:10d}"
        )


if __name__ == "__main__":
    main()
