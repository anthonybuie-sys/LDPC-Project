`timescale 1ns/1ps

module app_lut8_model #(
  parameter integer LANES = 384,
  parameter integer APP_W = 8,
  parameter integer BANKS = 8,
  parameter integer DEPTH = 64,
  parameter integer BANK_W = 3,
  parameter integer ADDR_W = 6
) (
  input  wire clk,
  input  wire read_valid_i,
  input  wire [BANK_W-1:0] read_bank_a_i,
  input  wire [BANK_W-1:0] read_bank_b_i,
  input  wire [ADDR_W-1:0] read_addr_a_i,
  input  wire [ADDR_W-1:0] read_addr_b_i,
  input  wire write_valid_a_i,
  input  wire write_valid_b_i,
  input  wire [BANK_W-1:0] write_bank_a_i,
  input  wire [BANK_W-1:0] write_bank_b_i,
  input  wire [ADDR_W-1:0] write_addr_a_i,
  input  wire [ADDR_W-1:0] write_addr_b_i,
  input  wire [LANES*APP_W-1:0] write_data_a_i,
  input  wire [LANES*APP_W-1:0] write_data_b_i,
  output reg  [LANES*APP_W-1:0] read_data_a_o,
  output reg  [LANES*APP_W-1:0] read_data_b_o
);
  (* ram_style = "distributed" *) reg [LANES*APP_W-1:0] mem [0:BANKS-1][0:DEPTH-1];

  always @(posedge clk) begin
    if (write_valid_a_i) begin
      mem[write_bank_a_i][write_addr_a_i] <= write_data_a_i;
    end
    if (write_valid_b_i) begin
      mem[write_bank_b_i][write_addr_b_i] <= write_data_b_i;
    end
    if (read_valid_i) begin
      read_data_a_o <= mem[read_bank_a_i][read_addr_a_i];
      read_data_b_o <= mem[read_bank_b_i][read_addr_b_i];
    end
  end
endmodule
