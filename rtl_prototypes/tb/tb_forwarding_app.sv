`timescale 1ns/1ps

module tb_forwarding_app;
  localparam integer LANES = 16;
  localparam integer APP_W = 8;
  localparam integer NF = 8;
  localparam integer SLOT_W = 4;
  localparam integer BANKS = 8;
  localparam integer DEPTH = 16;
  localparam integer BANK_W = 3;
  localparam integer ADDR_W = 4;

  reg clk = 1'b0;
  reg rst = 1'b1;
  reg [LANES*APP_W-1:0] vec0;
  reg [LANES*APP_W-1:0] vec1;
  reg [LANES*APP_W-1:0] app_a;
  reg [LANES*APP_W-1:0] app_b;
  wire [LANES*APP_W-1:0] operand_a;
  wire [LANES*APP_W-1:0] operand_b;
  wire [LANES*APP_W-1:0] read_a;
  wire [LANES*APP_W-1:0] read_b;
  integer lane;

  always #5 clk = ~clk;

  forward_mux_wrapper #(
    .LANES(LANES), .APP_W(APP_W), .NF(NF), .SLOT_W(SLOT_W)
  ) u_fwd (
    .clk(clk), .rst(rst), .write_valid_i(1'b1), .write_slot_i(4'd2),
    .write_vector_i(vec0), .use_forward_a_i(1'b1), .use_forward_b_i(1'b0),
    .slot_select_a_i(4'd2), .slot_select_b_i(4'd0), .app_mem_a_i(app_a),
    .app_mem_b_i(app_b), .operand_a_o(operand_a), .operand_b_o(operand_b)
  );

  app_lut8_model #(
    .LANES(LANES), .APP_W(APP_W), .BANKS(BANKS), .DEPTH(DEPTH),
    .BANK_W(BANK_W), .ADDR_W(ADDR_W)
  ) u_app (
    .clk(clk), .read_valid_i(1'b1), .read_bank_a_i(3'd1), .read_bank_b_i(3'd2),
    .read_addr_a_i(4'd3), .read_addr_b_i(4'd4), .write_valid_a_i(1'b1),
    .write_valid_b_i(1'b1), .write_bank_a_i(3'd1), .write_bank_b_i(3'd2),
    .write_addr_a_i(4'd3), .write_addr_b_i(4'd4), .write_data_a_i(vec0),
    .write_data_b_i(vec1), .read_data_a_o(read_a), .read_data_b_o(read_b)
  );

  initial begin
    for (lane = 0; lane < LANES; lane = lane + 1) begin
      vec0[lane*APP_W +: APP_W] = lane + 8'd1;
      vec1[lane*APP_W +: APP_W] = lane + 8'd33;
      app_a[lane*APP_W +: APP_W] = lane + 8'd65;
      app_b[lane*APP_W +: APP_W] = lane + 8'd97;
    end
    repeat (2) @(posedge clk);
    rst = 1'b0;
    repeat (3) @(posedge clk);
    if (operand_a !== vec0) begin
      $display("FAIL forwarding operand A");
      $finish;
    end
    if (operand_b !== app_b) begin
      $display("FAIL forwarding operand B");
      $finish;
    end
    if (read_a !== vec0 || read_b !== vec1) begin
      $display("FAIL APP LUT8 readback");
      $finish;
    end
    $display("PASS forwarding/app prototypes");
    $finish;
  end
endmodule

