#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT/results/rtl_prototypes/sim"
mkdir -p "$OUT_DIR"

iverilog -g2012 -Wall -o "$OUT_DIR/reconstruction_tb.vvp" \
  "$ROOT/rtl_prototypes/reconstruction/reconstruction_dr3.sv" \
  "$ROOT/rtl_prototypes/reconstruction/reconstruction_dr4.sv" \
  "$ROOT/rtl_prototypes/tb/tb_reconstruction.sv"
vvp "$OUT_DIR/reconstruction_tb.vvp"

iverilog -g2012 -Wall -o "$OUT_DIR/accumulation_tb.vvp" \
  "$ROOT/rtl_prototypes/accumulation/accumulation_da3.sv" \
  "$ROOT/rtl_prototypes/accumulation/accumulation_da4.sv" \
  "$ROOT/rtl_prototypes/tb/tb_accumulation.sv"
vvp "$OUT_DIR/accumulation_tb.vvp"

iverilog -g2012 -Wall -o "$OUT_DIR/forwarding_app_tb.vvp" \
  "$ROOT/rtl_prototypes/forwarding/forward_cache_8.sv" \
  "$ROOT/rtl_prototypes/forwarding/forward_mux_wrapper.sv" \
  "$ROOT/rtl_prototypes/app_memory/app_lut8_model.sv" \
  "$ROOT/rtl_prototypes/tb/tb_forwarding_app.sv"
vvp "$OUT_DIR/forwarding_app_tb.vvp"

echo "All RTL prototype simulations passed."

