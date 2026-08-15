`timescale 1ns/1ps

module min2_merge #(
  parameter integer MSG_W = 6,
  parameter integer EDGE_ID_W = 5
) (
  input  wire [MSG_W-1:0] old_min1_i,
  input  wire [MSG_W-1:0] old_min2_i,
  input  wire [EDGE_ID_W-1:0] old_imin_i,
  input  wire old_total_sign_i,
  input  wire signed [MSG_W:0] q_a_i,
  input  wire signed [MSG_W:0] q_b_i,
  input  wire [EDGE_ID_W-1:0] edge_id_a_i,
  input  wire [EDGE_ID_W-1:0] edge_id_b_i,
  output reg  [MSG_W-1:0] new_min1_o,
  output reg  [MSG_W-1:0] new_min2_o,
  output reg  [EDGE_ID_W-1:0] new_imin_o,
  output reg  new_total_sign_o
);
  reg [MSG_W-1:0] mag_a;
  reg [MSG_W-1:0] mag_b;
  reg [MSG_W-1:0] min1_tmp;
  reg [MSG_W-1:0] min2_tmp;
  reg [EDGE_ID_W-1:0] imin_tmp;

  function [MSG_W-1:0] abs_msg;
    input signed [MSG_W:0] value;
    reg signed [MSG_W:0] neg_value;
    begin
      neg_value = -value;
      abs_msg = value[MSG_W] ? neg_value[MSG_W-1:0] : value[MSG_W-1:0];
    end
  endfunction

  task automatic update_min;
    input [MSG_W-1:0] mag;
    input [EDGE_ID_W-1:0] edge_id;
    begin
      if ((mag < min1_tmp) || ((mag == min1_tmp) && (edge_id < imin_tmp))) begin
        min2_tmp = min1_tmp;
        min1_tmp = mag;
        imin_tmp = edge_id;
      end else if (mag < min2_tmp) begin
        min2_tmp = mag;
      end
    end
  endtask

  always @* begin
    mag_a = abs_msg(q_a_i);
    mag_b = abs_msg(q_b_i);
    min1_tmp = old_min1_i;
    min2_tmp = old_min2_i;
    imin_tmp = old_imin_i;
    update_min(mag_a, edge_id_a_i);
    update_min(mag_b, edge_id_b_i);
    new_min1_o = min1_tmp;
    new_min2_o = min2_tmp;
    new_imin_o = imin_tmp;
    new_total_sign_o = old_total_sign_i ^ q_a_i[MSG_W] ^ q_b_i[MSG_W];
  end
endmodule
