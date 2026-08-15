`timescale 1ns/1ps

module app_lut8_wrapper #(
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
  output wire [LANES*APP_W-1:0] read_data_a_o,
  output wire [LANES*APP_W-1:0] read_data_b_o
);
  app_lut8_model #(
    .LANES(LANES), .APP_W(APP_W), .BANKS(BANKS), .DEPTH(DEPTH),
    .BANK_W(BANK_W), .ADDR_W(ADDR_W)
  ) u_app (
    .clk(clk), .read_valid_i(read_valid_i), .read_bank_a_i(read_bank_a_i),
    .read_bank_b_i(read_bank_b_i), .read_addr_a_i(read_addr_a_i),
    .read_addr_b_i(read_addr_b_i), .write_valid_a_i(write_valid_a_i),
    .write_valid_b_i(write_valid_b_i), .write_bank_a_i(write_bank_a_i),
    .write_bank_b_i(write_bank_b_i), .write_addr_a_i(write_addr_a_i),
    .write_addr_b_i(write_addr_b_i), .write_data_a_i(write_data_a_i),
    .write_data_b_i(write_data_b_i), .read_data_a_o(read_data_a_o),
    .read_data_b_o(read_data_b_o)
  );
endmodule
