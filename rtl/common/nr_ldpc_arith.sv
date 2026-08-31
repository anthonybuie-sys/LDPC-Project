`ifndef NR_LDPC_ARITH_SV
`define NR_LDPC_ARITH_SV

module nr_ldpc_sat_signed #(
  parameter int IN_W = nr_ldpc_pkg::W_ARITH,
  parameter int OUT_W = nr_ldpc_pkg::W_APP
) (
  input  logic signed [IN_W-1:0]  in_i,
  output logic signed [OUT_W-1:0] out_o
);
  function automatic logic signed [IN_W-1:0] ext_const(input logic signed [31:0] value);
    ext_const = value[IN_W-1:0];
  endfunction

  localparam logic signed [IN_W-1:0] OUT_MIN_EXT = ext_const(-(1 << (OUT_W - 1)));
  localparam logic signed [IN_W-1:0] OUT_MAX_EXT = ext_const((1 << (OUT_W - 1)) - 1);

  always_comb begin
    if (in_i < OUT_MIN_EXT) begin
      out_o = OUT_W'(OUT_MIN_EXT);
    end else if (in_i > OUT_MAX_EXT) begin
      out_o = OUT_W'(OUT_MAX_EXT);
    end else begin
      out_o = OUT_W'(in_i);
    end
  end
endmodule

module nr_ldpc_q_sub (
  input  logic signed [7:0] app_i,
  input  logic signed [6:0] old_c2v_i,
  output logic signed [7:0] q_o,
  output logic signed [8:0] raw_o
);
  import nr_ldpc_pkg::*;

  arith_t app_ext;
  arith_t old_c2v_ext;

  assign app_ext = {{(W_ARITH-W_APP){app_i[W_APP-1]}}, app_i};
  assign old_c2v_ext = {{(W_ARITH-W_C2V){old_c2v_i[W_C2V-1]}}, old_c2v_i};
  assign raw_o = app_ext - old_c2v_ext;

  nr_ldpc_sat_signed #(
    .IN_W(W_ARITH),
    .OUT_W(W_Q)
  ) u_sat_q (
    .in_i(raw_o),
    .out_o(q_o)
  );
endmodule

module nr_ldpc_q_magnitude (
  input  logic signed [7:0] q_i,
  output logic              sign_o,
  output logic [8:0]        magnitude_raw_o,
  output logic [5:0]        magnitude_m6_o
);
  import nr_ldpc_pkg::*;

  arith_t q_ext;
  arith_t q_abs_signed;

  assign sign_o = q_i[W_Q-1];
  assign q_ext = {{(W_ARITH-W_Q){q_i[W_Q-1]}}, q_i};
  assign q_abs_signed = sign_o ? -q_ext : q_ext;
  assign magnitude_raw_o = q_abs_signed[W_ARITH-1:0];
  assign magnitude_m6_o = (magnitude_raw_o > arith_mag_t'(9'd63))
      ? mag_t'(6'd63)
      : magnitude_raw_o[W_M-1:0];
endmodule

module nr_ldpc_beta_sub (
  input  logic [5:0] raw_mag_i,
  output logic [5:0] offset_mag_o
);
  import nr_ldpc_pkg::*;

  localparam mag_t BETA_MAG = mag_t'(BETA_INT);

  assign offset_mag_o = (raw_mag_i > BETA_MAG)
      ? mag_t'(raw_mag_i - BETA_MAG)
      : mag_t'(6'd0);
endmodule

module nr_ldpc_c2v_reconstruct (
  input  logic [5:0]        magnitude_i,
  input  logic              negative_i,
  output logic signed [6:0] c2v_o
);
  import nr_ldpc_pkg::*;

  c2v_t positive_value;
  c2v_t negative_value;

  assign positive_value = {1'b0, magnitude_i};
  assign negative_value = -positive_value;

  always_comb begin
    if (magnitude_i == mag_t'(6'd0)) begin
      c2v_o = c2v_t'(7'sd0);
    end else if (negative_i) begin
      c2v_o = negative_value;
    end else begin
      c2v_o = positive_value;
    end
  end
endmodule

module nr_ldpc_app_add (
  input  logic signed [7:0] q_i,
  input  logic signed [6:0] new_c2v_i,
  output logic signed [7:0] app_o,
  output logic signed [8:0] raw_o
);
  import nr_ldpc_pkg::*;

  arith_t q_ext;
  arith_t new_c2v_ext;

  assign q_ext = {{(W_ARITH-W_Q){q_i[W_Q-1]}}, q_i};
  assign new_c2v_ext = {{(W_ARITH-W_C2V){new_c2v_i[W_C2V-1]}}, new_c2v_i};
  assign raw_o = q_ext + new_c2v_ext;

  nr_ldpc_sat_signed #(
    .IN_W(W_ARITH),
    .OUT_W(W_APP)
  ) u_sat_app (
    .in_i(raw_o),
    .out_o(app_o)
  );
endmodule

module nr_ldpc_ch_to_app_init (
  input  logic signed [5:0] ch_i,
  output logic signed [7:0] app_o,
  output logic signed [8:0] raw_o
);
  import nr_ldpc_pkg::*;

  arith_t ch_ext;

  assign ch_ext = {{(W_ARITH-W_CH){ch_i[W_CH-1]}}, ch_i};
  assign raw_o = ch_ext <<< CH_TO_APP_SHIFT;

  nr_ldpc_sat_signed #(
    .IN_W(W_ARITH),
    .OUT_W(W_APP)
  ) u_sat_init (
    .in_i(raw_o),
    .out_o(app_o)
  );
endmodule

`endif
