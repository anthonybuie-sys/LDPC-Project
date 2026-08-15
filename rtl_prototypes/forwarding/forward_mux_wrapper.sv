`timescale 1ns/1ps

module forward_mux_wrapper #(
  parameter integer LANES = 384,
  parameter integer APP_W = 8,
  parameter integer NF = 8,
  parameter integer SLOT_W = 4
) (
  input  wire clk,
  input  wire rst,
  input  wire write_valid_i,
  input  wire [SLOT_W-1:0] write_slot_i,
  input  wire [LANES*APP_W-1:0] write_vector_i,
  input  wire use_forward_a_i,
  input  wire use_forward_b_i,
  input  wire [SLOT_W-1:0] slot_select_a_i,
  input  wire [SLOT_W-1:0] slot_select_b_i,
  input  wire [LANES*APP_W-1:0] app_mem_a_i,
  input  wire [LANES*APP_W-1:0] app_mem_b_i,
  output wire [LANES*APP_W-1:0] operand_a_o,
  output wire [LANES*APP_W-1:0] operand_b_o
);
  forward_cache_8 #(
    .LANES(LANES),
    .APP_W(APP_W),
    .NF(NF),
    .SLOT_W(SLOT_W)
  ) u_cache (
    .clk(clk), .rst(rst), .write_valid_i(write_valid_i), .write_slot_i(write_slot_i),
    .write_vector_i(write_vector_i), .use_forward_a_i(use_forward_a_i),
    .use_forward_b_i(use_forward_b_i), .slot_select_a_i(slot_select_a_i),
    .slot_select_b_i(slot_select_b_i), .app_mem_a_i(app_mem_a_i),
    .app_mem_b_i(app_mem_b_i), .operand_a_o(operand_a_o), .operand_b_o(operand_b_o)
  );
endmodule
