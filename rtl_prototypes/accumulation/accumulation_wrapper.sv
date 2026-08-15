`timescale 1ns/1ps

module accumulation_wrapper #(
  parameter integer PIPELINE_DEPTH = 3,
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
  output wire valid_o,
  output wire signed [LANES*Q_W-1:0] q_a_o,
  output wire signed [LANES*Q_W-1:0] q_b_o,
  output wire [LANES*MSG_W-1:0] new_min1_o,
  output wire [LANES*MSG_W-1:0] new_min2_o,
  output wire [LANES*EDGE_ID_W-1:0] new_imin_o,
  output wire [LANES-1:0] new_total_sign_o
);
  generate
    if (PIPELINE_DEPTH == 3) begin : gen_da3
      accumulation_da3 #(
        .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
        .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
      ) u_da3 (
        .clk(clk), .rst(rst), .valid_i(valid_i), .app_a_i(app_a_i), .app_b_i(app_b_i),
        .old_min1_i(old_min1_i), .old_min2_i(old_min2_i), .old_imin_i(old_imin_i),
        .old_total_sign_i(old_total_sign_i), .old_q_sign_a_i(old_q_sign_a_i),
        .old_q_sign_b_i(old_q_sign_b_i), .edge_id_a_i(edge_id_a_i),
        .edge_id_b_i(edge_id_b_i), .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
        .valid_o(valid_o), .q_a_o(q_a_o), .q_b_o(q_b_o),
        .new_min1_o(new_min1_o), .new_min2_o(new_min2_o),
        .new_imin_o(new_imin_o), .new_total_sign_o(new_total_sign_o)
      );
    end else begin : gen_da4
      accumulation_da4 #(
        .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
        .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
      ) u_da4 (
        .clk(clk), .rst(rst), .valid_i(valid_i), .app_a_i(app_a_i), .app_b_i(app_b_i),
        .old_min1_i(old_min1_i), .old_min2_i(old_min2_i), .old_imin_i(old_imin_i),
        .old_total_sign_i(old_total_sign_i), .old_q_sign_a_i(old_q_sign_a_i),
        .old_q_sign_b_i(old_q_sign_b_i), .edge_id_a_i(edge_id_a_i),
        .edge_id_b_i(edge_id_b_i), .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
        .valid_o(valid_o), .q_a_o(q_a_o), .q_b_o(q_b_o),
        .new_min1_o(new_min1_o), .new_min2_o(new_min2_o),
        .new_imin_o(new_imin_o), .new_total_sign_o(new_total_sign_o)
      );
    end
  endgenerate
endmodule
