`timescale 1ns/1ps

module sat_sub #(
  parameter integer A_W = 8,
  parameter integer B_W = 7,
  parameter integer OUT_W = 8
) (
  input  wire signed [A_W-1:0] a_i,
  input  wire signed [B_W-1:0] b_i,
  output reg  signed [OUT_W-1:0] y_o
);
  localparam signed [OUT_W:0] SAT_MAX = (1 <<< (OUT_W - 1)) - 1;
  localparam signed [OUT_W:0] SAT_MIN = -(1 <<< (OUT_W - 1));
  reg signed [OUT_W:0] diff_ext;

  always @* begin
    diff_ext = $signed(a_i) - $signed(b_i);
    if (diff_ext > SAT_MAX) begin
      y_o = SAT_MAX[OUT_W-1:0];
    end else if (diff_ext < SAT_MIN) begin
      y_o = SAT_MIN[OUT_W-1:0];
    end else begin
      y_o = diff_ext[OUT_W-1:0];
    end
  end
endmodule
