`timescale 1ns/1ps

module forward_cache_8 #(
  parameter integer LANES = 384,
  parameter integer APP_W = 8,
  parameter integer NF = 8,
  parameter integer SLOT_W = 3
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
  output reg  [LANES*APP_W-1:0] operand_a_o,
  output reg  [LANES*APP_W-1:0] operand_b_o
);
  reg [LANES*APP_W-1:0] slots [0:NF-1];
  integer idx;

  always @(posedge clk) begin
    if (rst) begin
      for (idx = 0; idx < NF; idx = idx + 1) begin
        slots[idx] <= {LANES*APP_W{1'b0}};
      end
    end else if (write_valid_i && write_slot_i < NF) begin
      slots[write_slot_i] <= write_vector_i;
    end
  end

  always @* begin
    operand_a_o = app_mem_a_i;
    operand_b_o = app_mem_b_i;
    if (use_forward_a_i && slot_select_a_i < NF) begin
      operand_a_o = slots[slot_select_a_i];
    end
    if (use_forward_b_i && slot_select_b_i < NF) begin
      operand_b_o = slots[slot_select_b_i];
    end
  end
endmodule
