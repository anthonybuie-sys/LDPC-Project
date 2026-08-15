`timescale 1ns/1ps

module qc_permute #(
  parameter integer LANES = 384,
  parameter integer DATA_W = 8,
  parameter integer SHIFT_W = 9,
  parameter integer INVERSE = 0
) (
  input  wire [LANES*DATA_W-1:0] data_i,
  input  wire [SHIFT_W-1:0] shift_i,
  output reg  [LANES*DATA_W-1:0] data_o
);
  integer lane;
  integer src_lane;
  integer shift_int;

  always @* begin
    shift_int = shift_i % LANES;
    for (lane = 0; lane < LANES; lane = lane + 1) begin
      if (INVERSE != 0) begin
        src_lane = lane + shift_int;
        if (src_lane >= LANES) begin
          src_lane = src_lane - LANES;
        end
      end else begin
        src_lane = lane - shift_int;
        if (src_lane < 0) begin
          src_lane = src_lane + LANES;
        end
      end
      data_o[lane*DATA_W +: DATA_W] = data_i[src_lane*DATA_W +: DATA_W];
    end
  end
endmodule
