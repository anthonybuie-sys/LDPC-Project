`timescale 1ns/1ps

module da3_dr3_datapath #(
  parameter integer LANES = 384,
  parameter integer APP_W = 8,
  parameter integer Q_W = 8,
  parameter integer MSG_W = 6,
  parameter integer EDGE_ID_W = 5,
  parameter integer SHIFT_W = 9,
  parameter integer NF = 8,
  parameter integer SLOT_W = 4
) (
  input  wire clk,
  input  wire rst,
  input  wire acc_valid_i,
  input  wire rec_valid_i,
  input  wire signed [LANES*APP_W-1:0] app_mem_a_i,
  input  wire signed [LANES*APP_W-1:0] app_mem_b_i,
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
  input  wire use_forward_a_i,
  input  wire use_forward_b_i,
  input  wire [SLOT_W-1:0] slot_select_a_i,
  input  wire [SLOT_W-1:0] slot_select_b_i,
  input  wire [SLOT_W-1:0] write_slot_i,
  output wire acc_valid_o,
  output wire rec_valid_o,
  output wire signed [LANES*Q_W-1:0] q_a_o,
  output wire signed [LANES*Q_W-1:0] q_b_o,
  output wire signed [LANES*APP_W-1:0] app_a_o,
  output wire signed [LANES*APP_W-1:0] app_b_o
);
  wire [LANES*APP_W-1:0] fwd_a;
  wire [LANES*APP_W-1:0] fwd_b;
  wire [LANES*MSG_W-1:0] acc_min1_unused;
  wire [LANES*MSG_W-1:0] acc_min2_unused;
  wire [LANES*EDGE_ID_W-1:0] acc_imin_unused;
  wire [LANES-1:0] acc_sign_unused;

  forward_mux_wrapper #(
    .LANES(LANES), .APP_W(APP_W), .NF(NF), .SLOT_W(SLOT_W)
  ) u_forward (
    .clk(clk), .rst(rst), .write_valid_i(rec_valid_o), .write_slot_i(write_slot_i),
    .write_vector_i(app_a_o), .use_forward_a_i(use_forward_a_i),
    .use_forward_b_i(use_forward_b_i), .slot_select_a_i(slot_select_a_i),
    .slot_select_b_i(slot_select_b_i), .app_mem_a_i(app_mem_a_i),
    .app_mem_b_i(app_mem_b_i), .operand_a_o(fwd_a), .operand_b_o(fwd_b)
  );

  accumulation_da3 #(
    .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
    .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
  ) u_acc (
    .clk(clk), .rst(rst), .valid_i(acc_valid_i), .app_a_i(fwd_a), .app_b_i(fwd_b),
    .old_min1_i(min1_i), .old_min2_i(min2_i), .old_imin_i(imin_i),
    .old_total_sign_i(total_sign_i), .old_q_sign_a_i(q_sign_a_i),
    .old_q_sign_b_i(q_sign_b_i), .edge_id_a_i(edge_id_a_i),
    .edge_id_b_i(edge_id_b_i), .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
    .valid_o(acc_valid_o), .q_a_o(q_a_o), .q_b_o(q_b_o),
    .new_min1_o(acc_min1_unused), .new_min2_o(acc_min2_unused),
    .new_imin_o(acc_imin_unused), .new_total_sign_o(acc_sign_unused)
  );

  reconstruction_dr3 #(
    .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
    .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
  ) u_rec (
    .clk(clk), .rst(rst), .valid_i(rec_valid_i), .q_a_i(q_a_i), .q_b_i(q_b_i),
    .min1_i(min1_i), .min2_i(min2_i), .imin_i(imin_i),
    .total_sign_i(total_sign_i), .q_sign_a_i(q_sign_a_i),
    .q_sign_b_i(q_sign_b_i), .edge_id_a_i(edge_id_a_i),
    .edge_id_b_i(edge_id_b_i), .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
    .valid_o(rec_valid_o), .app_a_o(app_a_o), .app_b_o(app_b_o)
  );
endmodule
