`timescale 1ns/1ps

module reconstruction_wrapper #(
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
  output wire valid_o,
  output wire signed [LANES*APP_W-1:0] app_a_o,
  output wire signed [LANES*APP_W-1:0] app_b_o
);
  generate
    if (PIPELINE_DEPTH == 3) begin : gen_dr3
      reconstruction_dr3 #(
        .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
        .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
      ) u_dr3 (
        .clk(clk), .rst(rst), .valid_i(valid_i),
        .q_a_i(q_a_i), .q_b_i(q_b_i), .min1_i(min1_i), .min2_i(min2_i),
        .imin_i(imin_i), .total_sign_i(total_sign_i),
        .q_sign_a_i(q_sign_a_i), .q_sign_b_i(q_sign_b_i),
        .edge_id_a_i(edge_id_a_i), .edge_id_b_i(edge_id_b_i),
        .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
        .valid_o(valid_o), .app_a_o(app_a_o), .app_b_o(app_b_o)
      );
    end else begin : gen_dr4
      reconstruction_dr4 #(
        .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
        .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
      ) u_dr4 (
        .clk(clk), .rst(rst), .valid_i(valid_i),
        .q_a_i(q_a_i), .q_b_i(q_b_i), .min1_i(min1_i), .min2_i(min2_i),
        .imin_i(imin_i), .total_sign_i(total_sign_i),
        .q_sign_a_i(q_sign_a_i), .q_sign_b_i(q_sign_b_i),
        .edge_id_a_i(edge_id_a_i), .edge_id_b_i(edge_id_b_i),
        .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
        .valid_o(valid_o), .app_a_o(app_a_o), .app_b_o(app_b_o)
      );
    end
  endgenerate
endmodule
