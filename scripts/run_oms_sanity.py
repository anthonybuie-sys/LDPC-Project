from __future__ import annotations

from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ldpc_sim.base_graphs import load_3gpp_base_graph
from ldpc_sim.fixed_point import FixedPointFormat
from ldpc_sim.numerical_decoder import (
    assert_full_compressed_fixed_equivalent,
    assert_full_compressed_float_equivalent,
    decode_fixed,
    decode_float,
)


def main() -> int:
    graph = load_3gpp_base_graph(1, 384, i_ls=1, active_layer_ids=(0, 1, 2, 3))
    layer_order = (0, 2, 1, 3)
    llr = np.full((26, graph.Z), 8.0, dtype=np.float64)
    llr[:2, :] = 0.0
    assert_full_compressed_float_equivalent(
        graph,
        llr,
        beta=0.5,
        max_iterations=2,
        layer_order=layer_order,
    )
    fmt = FixedPointFormat("D", 5, 8, 8, 6, channel_gain=1.0, beta_int=1)
    q = np.rint(llr).astype(np.int64)
    assert_full_compressed_fixed_equivalent(
        graph,
        q,
        fmt=fmt,
        max_iterations=2,
        layer_order=layer_order,
    )
    float_result = decode_float(
        graph,
        llr,
        beta=0.5,
        max_iterations=12,
        layer_order=layer_order,
    )
    fixed_result = decode_fixed(
        graph,
        q,
        fmt=fmt,
        max_iterations=12,
        layer_order=layer_order,
    )
    print(f"float: iterations={float_result.iterations} syndrome={float_result.syndrome_passed}")
    print(f"fixed: iterations={fixed_result.iterations} syndrome={fixed_result.syndrome_passed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
