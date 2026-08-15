`timescale 1ns/1ps

module reconstruction_dr3 #(
  parameter integer LANES = 384,
  parameter integer APP_W = 8,
  parameter integer Q_W = 8,
  parameter integer MSG_W = 6,
  parameter integer EDGE_ID_W = 5,
  parameter integer SHIFT_W = 9
) (
  input  wire clk,
  input  wire rst,
  input  wire valid_i,
  input  wire signed [LANES*Q_W-1:0] q_a_i,
  input  wire signed [LANES*Q_W-1:0] q_b_i,
  input  wire [LANES*MSG_W-1:0] min1_i,
  input  wire [LANES*MSG_W-1:0] min2_i,
  input  wire [LANES*EDGE_ID_W-1:0] imin_i,
  input  wire [LANES-1:0] total_sign_i,
  input  wire [LANES-1:0] q_sign_a_i,
  input  wire [LANES-1:0] q_sign_b_i,
  input  wire [EDGE_ID_W-1:0] edge_id_a_i,
  input  wire [EDGE_ID_W-1:0] edge_id_b_i,
  input  wire [SHIFT_W-1:0] shift_a_i,
  input  wire [SHIFT_W-1:0] shift_b_i,
  output reg  valid_o,
  output reg  signed [LANES*APP_W-1:0] app_a_o,
  output reg  signed [LANES*APP_W-1:0] app_b_o
);
  localparam signed [APP_W:0] APP_MAX = (1 <<< (APP_W - 1)) - 1;
  localparam signed [APP_W:0] APP_MIN = -(1 <<< (APP_W - 1));

  reg valid_s0;
  reg valid_s1;
  reg [SHIFT_W-1:0] shift_a_s0;
  reg [SHIFT_W-1:0] shift_b_s0;
  reg [SHIFT_W-1:0] shift_a_s1;
  reg [SHIFT_W-1:0] shift_b_s1;
  reg signed [LANES*(MSG_W+1)-1:0] c2v_a_s0;
  reg signed [LANES*(MSG_W+1)-1:0] c2v_b_s0;
  reg signed [LANES*Q_W-1:0] q_a_s0;
  reg signed [LANES*Q_W-1:0] q_b_s0;
  reg signed [LANES*APP_W-1:0] app_a_s1;
  reg signed [LANES*APP_W-1:0] app_b_s1;

  integer lane;
  integer src_lane;
  integer shift_int;
  reg [MSG_W-1:0] mag_a;
  reg [MSG_W-1:0] mag_b;
  reg signed [MSG_W:0] c2v_a_tmp;
  reg signed [MSG_W:0] c2v_b_tmp;
  reg signed [APP_W:0] add_tmp;

  function signed [APP_W-1:0] sat_app;
    input signed [APP_W:0] value;
    begin
      if (value > APP_MAX) begin
        sat_app = APP_MAX[APP_W-1:0];
      end else if (value < APP_MIN) begin
        sat_app = APP_MIN[APP_W-1:0];
      end else begin
        sat_app = value[APP_W-1:0];
      end
    end
  endfunction

  function signed [MSG_W:0] signed_c2v;
    input [MSG_W-1:0] mag;
    input sign_bit;
    reg signed [MSG_W:0] mag_ext;
    begin
      mag_ext = $signed({1'b0, mag});
      signed_c2v = sign_bit ? -mag_ext : mag_ext;
    end
  endfunction

  function [LANES*APP_W-1:0] inverse_permute;
    input [LANES*APP_W-1:0] data;
    input [SHIFT_W-1:0] shift;
    begin
      shift_int = shift % LANES;
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        src_lane = lane + shift_int;
        if (src_lane >= LANES) begin
          src_lane = src_lane - LANES;
        end
        inverse_permute[lane*APP_W +: APP_W] = data[src_lane*APP_W +: APP_W];
      end
    end
  endfunction

  always @(posedge clk) begin
    if (rst) begin
      valid_s0 <= 1'b0;
      valid_s1 <= 1'b0;
      valid_o <= 1'b0;
      app_a_o <= {LANES*APP_W{1'b0}};
      app_b_o <= {LANES*APP_W{1'b0}};
    end else begin
      valid_s0 <= valid_i;
      valid_s1 <= valid_s0;
      valid_o <= valid_s1;

      shift_a_s0 <= shift_a_i;
      shift_b_s0 <= shift_b_i;
      shift_a_s1 <= shift_a_s0;
      shift_b_s1 <= shift_b_s0;
      q_a_s0 <= q_a_i;
      q_b_s0 <= q_b_i;

      for (lane = 0; lane < LANES; lane = lane + 1) begin
        mag_a = (edge_id_a_i == imin_i[lane*EDGE_ID_W +: EDGE_ID_W]) ?
          min2_i[lane*MSG_W +: MSG_W] : min1_i[lane*MSG_W +: MSG_W];
        mag_b = (edge_id_b_i == imin_i[lane*EDGE_ID_W +: EDGE_ID_W]) ?
          min2_i[lane*MSG_W +: MSG_W] : min1_i[lane*MSG_W +: MSG_W];
        c2v_a_tmp = signed_c2v(mag_a, total_sign_i[lane] ^ q_sign_a_i[lane]);
        c2v_b_tmp = signed_c2v(mag_b, total_sign_i[lane] ^ q_sign_b_i[lane]);
        c2v_a_s0[lane*(MSG_W+1) +: (MSG_W+1)] <= c2v_a_tmp;
        c2v_b_s0[lane*(MSG_W+1) +: (MSG_W+1)] <= c2v_b_tmp;

        add_tmp = $signed(q_a_s0[lane*Q_W +: Q_W]) +
          $signed(c2v_a_s0[lane*(MSG_W+1) +: (MSG_W+1)]);
        app_a_s1[lane*APP_W +: APP_W] <= sat_app(add_tmp);
        add_tmp = $signed(q_b_s0[lane*Q_W +: Q_W]) +
          $signed(c2v_b_s0[lane*(MSG_W+1) +: (MSG_W+1)]);
        app_b_s1[lane*APP_W +: APP_W] <= sat_app(add_tmp);
      end

      app_a_o <= inverse_permute(app_a_s1, shift_a_s1);
      app_b_o <= inverse_permute(app_b_s1, shift_b_s1);
    end
  end
endmodule
