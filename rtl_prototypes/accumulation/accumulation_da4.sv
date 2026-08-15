`timescale 1ns/1ps

module accumulation_da4 #(
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
  input  wire signed [LANES*APP_W-1:0] app_a_i,
  input  wire signed [LANES*APP_W-1:0] app_b_i,
  input  wire [LANES*MSG_W-1:0] old_min1_i,
  input  wire [LANES*MSG_W-1:0] old_min2_i,
  input  wire [LANES*EDGE_ID_W-1:0] old_imin_i,
  input  wire [LANES-1:0] old_total_sign_i,
  input  wire [LANES-1:0] old_q_sign_a_i,
  input  wire [LANES-1:0] old_q_sign_b_i,
  input  wire [EDGE_ID_W-1:0] edge_id_a_i,
  input  wire [EDGE_ID_W-1:0] edge_id_b_i,
  input  wire [SHIFT_W-1:0] shift_a_i,
  input  wire [SHIFT_W-1:0] shift_b_i,
  output reg  valid_o,
  output reg  signed [LANES*Q_W-1:0] q_a_o,
  output reg  signed [LANES*Q_W-1:0] q_b_o,
  output reg  [LANES*MSG_W-1:0] new_min1_o,
  output reg  [LANES*MSG_W-1:0] new_min2_o,
  output reg  [LANES*EDGE_ID_W-1:0] new_imin_o,
  output reg  [LANES-1:0] new_total_sign_o
);
  localparam signed [Q_W:0] Q_MAX = (1 <<< (Q_W - 1)) - 1;
  localparam signed [Q_W:0] Q_MIN = -(1 <<< (Q_W - 1));

  reg valid_s0;
  reg valid_s1;
  reg valid_s2;
  reg signed [LANES*APP_W-1:0] app_a_perm_s0;
  reg signed [LANES*APP_W-1:0] app_b_perm_s0;
  reg [LANES*MSG_W-1:0] old_min1_s0;
  reg [LANES*MSG_W-1:0] old_min2_s0;
  reg [LANES*EDGE_ID_W-1:0] old_imin_s0;
  reg [LANES-1:0] old_total_sign_s0;
  reg [LANES-1:0] old_q_sign_a_s0;
  reg [LANES-1:0] old_q_sign_b_s0;
  reg [EDGE_ID_W-1:0] edge_id_a_s0;
  reg [EDGE_ID_W-1:0] edge_id_b_s0;
  reg signed [LANES*(MSG_W+1)-1:0] c2v_a_s1;
  reg signed [LANES*(MSG_W+1)-1:0] c2v_b_s1;
  reg signed [LANES*APP_W-1:0] app_a_s1;
  reg signed [LANES*APP_W-1:0] app_b_s1;
  reg [LANES*MSG_W-1:0] old_min1_s1;
  reg [LANES*MSG_W-1:0] old_min2_s1;
  reg [LANES*EDGE_ID_W-1:0] old_imin_s1;
  reg [LANES-1:0] old_total_sign_s1;
  reg [EDGE_ID_W-1:0] edge_id_a_s1;
  reg [EDGE_ID_W-1:0] edge_id_b_s1;
  reg signed [LANES*Q_W-1:0] q_a_s2;
  reg signed [LANES*Q_W-1:0] q_b_s2;

  integer lane;
  integer src_lane;
  integer shift_int;
  reg [MSG_W-1:0] mag_a;
  reg [MSG_W-1:0] mag_b;
  reg signed [Q_W:0] q_tmp;
  reg [MSG_W-1:0] min1_tmp;
  reg [MSG_W-1:0] min2_tmp;
  reg [EDGE_ID_W-1:0] imin_tmp;
  reg [MSG_W-1:0] abs_a;
  reg [MSG_W-1:0] abs_b;

  function signed [Q_W-1:0] sat_q;
    input signed [Q_W:0] value;
    begin
      if (value > Q_MAX) begin
        sat_q = Q_MAX[Q_W-1:0];
      end else if (value < Q_MIN) begin
        sat_q = Q_MIN[Q_W-1:0];
      end else begin
        sat_q = value[Q_W-1:0];
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

  function [MSG_W-1:0] abs_q;
    input signed [Q_W-1:0] value;
    reg signed [Q_W-1:0] neg_value;
    begin
      neg_value = -value;
      abs_q = value[Q_W-1] ? neg_value[MSG_W-1:0] : value[MSG_W-1:0];
    end
  endfunction

  function [LANES*APP_W-1:0] forward_permute;
    input [LANES*APP_W-1:0] data;
    input [SHIFT_W-1:0] shift;
    begin
      shift_int = shift % LANES;
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        src_lane = lane - shift_int;
        if (src_lane < 0) begin
          src_lane = src_lane + LANES;
        end
        forward_permute[lane*APP_W +: APP_W] = data[src_lane*APP_W +: APP_W];
      end
    end
  endfunction

  always @(posedge clk) begin
    if (rst) begin
      valid_s0 <= 1'b0;
      valid_s1 <= 1'b0;
      valid_s2 <= 1'b0;
      valid_o <= 1'b0;
      q_a_o <= {LANES*Q_W{1'b0}};
      q_b_o <= {LANES*Q_W{1'b0}};
      new_min1_o <= {LANES*MSG_W{1'b0}};
      new_min2_o <= {LANES*MSG_W{1'b0}};
      new_imin_o <= {LANES*EDGE_ID_W{1'b0}};
      new_total_sign_o <= {LANES{1'b0}};
    end else begin
      valid_s0 <= valid_i;
      valid_s1 <= valid_s0;
      valid_s2 <= valid_s1;
      valid_o <= valid_s2;

      app_a_perm_s0 <= forward_permute(app_a_i, shift_a_i);
      app_b_perm_s0 <= forward_permute(app_b_i, shift_b_i);
      old_min1_s0 <= old_min1_i;
      old_min2_s0 <= old_min2_i;
      old_imin_s0 <= old_imin_i;
      old_total_sign_s0 <= old_total_sign_i;
      old_q_sign_a_s0 <= old_q_sign_a_i;
      old_q_sign_b_s0 <= old_q_sign_b_i;
      edge_id_a_s0 <= edge_id_a_i;
      edge_id_b_s0 <= edge_id_b_i;

      app_a_s1 <= app_a_perm_s0;
      app_b_s1 <= app_b_perm_s0;
      old_min1_s1 <= old_min1_s0;
      old_min2_s1 <= old_min2_s0;
      old_imin_s1 <= old_imin_s0;
      old_total_sign_s1 <= old_total_sign_s0;
      edge_id_a_s1 <= edge_id_a_s0;
      edge_id_b_s1 <= edge_id_b_s0;

      for (lane = 0; lane < LANES; lane = lane + 1) begin
        mag_a = (edge_id_a_s0 == old_imin_s0[lane*EDGE_ID_W +: EDGE_ID_W]) ?
          old_min2_s0[lane*MSG_W +: MSG_W] : old_min1_s0[lane*MSG_W +: MSG_W];
        mag_b = (edge_id_b_s0 == old_imin_s0[lane*EDGE_ID_W +: EDGE_ID_W]) ?
          old_min2_s0[lane*MSG_W +: MSG_W] : old_min1_s0[lane*MSG_W +: MSG_W];
        c2v_a_s1[lane*(MSG_W+1) +: (MSG_W+1)] <=
          signed_c2v(mag_a, old_total_sign_s0[lane] ^ old_q_sign_a_s0[lane]);
        c2v_b_s1[lane*(MSG_W+1) +: (MSG_W+1)] <=
          signed_c2v(mag_b, old_total_sign_s0[lane] ^ old_q_sign_b_s0[lane]);

        q_tmp = $signed(app_a_s1[lane*APP_W +: APP_W]) -
          $signed(c2v_a_s1[lane*(MSG_W+1) +: (MSG_W+1)]);
        q_a_s2[lane*Q_W +: Q_W] <= sat_q(q_tmp);
        q_tmp = $signed(app_b_s1[lane*APP_W +: APP_W]) -
          $signed(c2v_b_s1[lane*(MSG_W+1) +: (MSG_W+1)]);
        q_b_s2[lane*Q_W +: Q_W] <= sat_q(q_tmp);

        min1_tmp = old_min1_s1[lane*MSG_W +: MSG_W];
        min2_tmp = old_min2_s1[lane*MSG_W +: MSG_W];
        imin_tmp = old_imin_s1[lane*EDGE_ID_W +: EDGE_ID_W];
        abs_a = abs_q(q_a_s2[lane*Q_W +: Q_W]);
        abs_b = abs_q(q_b_s2[lane*Q_W +: Q_W]);
        if ((abs_a < min1_tmp) || ((abs_a == min1_tmp) && (edge_id_a_s1 < imin_tmp))) begin
          min2_tmp = min1_tmp;
          min1_tmp = abs_a;
          imin_tmp = edge_id_a_s1;
        end else if (abs_a < min2_tmp) begin
          min2_tmp = abs_a;
        end
        if ((abs_b < min1_tmp) || ((abs_b == min1_tmp) && (edge_id_b_s1 < imin_tmp))) begin
          min2_tmp = min1_tmp;
          min1_tmp = abs_b;
          imin_tmp = edge_id_b_s1;
        end else if (abs_b < min2_tmp) begin
          min2_tmp = abs_b;
        end
        q_a_o[lane*Q_W +: Q_W] <= q_a_s2[lane*Q_W +: Q_W];
        q_b_o[lane*Q_W +: Q_W] <= q_b_s2[lane*Q_W +: Q_W];
        new_min1_o[lane*MSG_W +: MSG_W] <= min1_tmp;
        new_min2_o[lane*MSG_W +: MSG_W] <= min2_tmp;
        new_imin_o[lane*EDGE_ID_W +: EDGE_ID_W] <= imin_tmp;
        new_total_sign_o[lane] <= old_total_sign_s1[lane] ^
          q_a_s2[lane*Q_W + Q_W - 1] ^ q_b_s2[lane*Q_W + Q_W - 1];
      end
    end
  end
endmodule
