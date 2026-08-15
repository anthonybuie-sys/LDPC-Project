`timescale 1ns/1ps

module tb_accumulation;
  localparam integer LANES = 32;
  localparam integer APP_W = 8;
  localparam integer Q_W = 8;
  localparam integer MSG_W = 6;
  localparam integer EDGE_ID_W = 5;
  localparam integer SHIFT_W = 9;
  localparam integer NUM_CASES = 512;

  reg clk = 1'b0;
  reg rst = 1'b1;
  reg valid_i = 1'b0;
  reg signed [LANES*APP_W-1:0] app_a_i;
  reg signed [LANES*APP_W-1:0] app_b_i;
  reg [LANES*MSG_W-1:0] old_min1_i;
  reg [LANES*MSG_W-1:0] old_min2_i;
  reg [LANES*EDGE_ID_W-1:0] old_imin_i;
  reg [LANES-1:0] old_total_sign_i;
  reg [LANES-1:0] old_q_sign_a_i;
  reg [LANES-1:0] old_q_sign_b_i;
  reg [EDGE_ID_W-1:0] edge_id_a_i;
  reg [EDGE_ID_W-1:0] edge_id_b_i;
  reg [SHIFT_W-1:0] shift_a_i;
  reg [SHIFT_W-1:0] shift_b_i;

  wire valid_da3;
  wire valid_da4;
  wire signed [LANES*Q_W-1:0] q_a_da3;
  wire signed [LANES*Q_W-1:0] q_b_da3;
  wire signed [LANES*Q_W-1:0] q_a_da4;
  wire signed [LANES*Q_W-1:0] q_b_da4;
  wire [LANES*MSG_W-1:0] min1_da3;
  wire [LANES*MSG_W-1:0] min2_da3;
  wire [LANES*MSG_W-1:0] min1_da4;
  wire [LANES*MSG_W-1:0] min2_da4;
  wire [LANES*EDGE_ID_W-1:0] imin_da3;
  wire [LANES*EDGE_ID_W-1:0] imin_da4;
  wire [LANES-1:0] sign_da3;
  wire [LANES-1:0] sign_da4;

  reg valid_da3_d1;
  reg signed [LANES*Q_W-1:0] q_a_da3_d1;
  reg signed [LANES*Q_W-1:0] q_b_da3_d1;
  reg [LANES*MSG_W-1:0] min1_da3_d1;
  reg [LANES*MSG_W-1:0] min2_da3_d1;
  reg [LANES*EDGE_ID_W-1:0] imin_da3_d1;
  reg [LANES-1:0] sign_da3_d1;
  integer cycle;
  integer case_idx;
  integer lane;
  integer tmp;
  integer checked;

  always #5 clk = ~clk;

  accumulation_da3 #(
    .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
    .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
  ) u_da3 (
    .clk(clk), .rst(rst), .valid_i(valid_i), .app_a_i(app_a_i), .app_b_i(app_b_i),
    .old_min1_i(old_min1_i), .old_min2_i(old_min2_i), .old_imin_i(old_imin_i),
    .old_total_sign_i(old_total_sign_i), .old_q_sign_a_i(old_q_sign_a_i),
    .old_q_sign_b_i(old_q_sign_b_i), .edge_id_a_i(edge_id_a_i),
    .edge_id_b_i(edge_id_b_i), .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
    .valid_o(valid_da3), .q_a_o(q_a_da3), .q_b_o(q_b_da3),
    .new_min1_o(min1_da3), .new_min2_o(min2_da3),
    .new_imin_o(imin_da3), .new_total_sign_o(sign_da3)
  );

  accumulation_da4 #(
    .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
    .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
  ) u_da4 (
    .clk(clk), .rst(rst), .valid_i(valid_i), .app_a_i(app_a_i), .app_b_i(app_b_i),
    .old_min1_i(old_min1_i), .old_min2_i(old_min2_i), .old_imin_i(old_imin_i),
    .old_total_sign_i(old_total_sign_i), .old_q_sign_a_i(old_q_sign_a_i),
    .old_q_sign_b_i(old_q_sign_b_i), .edge_id_a_i(edge_id_a_i),
    .edge_id_b_i(edge_id_b_i), .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
    .valid_o(valid_da4), .q_a_o(q_a_da4), .q_b_o(q_b_da4),
    .new_min1_o(min1_da4), .new_min2_o(min2_da4),
    .new_imin_o(imin_da4), .new_total_sign_o(sign_da4)
  );

  task apply_case;
    input integer idx;
    begin
      edge_id_a_i = idx % 19;
      edge_id_b_i = (idx * 5 + 4) % 19;
      shift_a_i = (idx * 3 + 2) % LANES;
      shift_b_i = (idx * 13 + 1) % LANES;
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        tmp = ((idx * 23 + lane * 17) % 255) - 127;
        app_a_i[lane*APP_W +: APP_W] = tmp[APP_W-1:0];
        tmp = ((idx * 29 + lane * 5 + 11) % 255) - 127;
        app_b_i[lane*APP_W +: APP_W] = tmp[APP_W-1:0];
        old_min1_i[lane*MSG_W +: MSG_W] = ((idx + lane * 2) % 31) + 1;
        old_min2_i[lane*MSG_W +: MSG_W] = ((idx + lane * 2) % 31) + 32;
        old_imin_i[lane*EDGE_ID_W +: EDGE_ID_W] = (idx + lane * 7) % 19;
        old_total_sign_i[lane] = (idx + lane) & 1;
        old_q_sign_a_i[lane] = (idx + lane * 3) & 1;
        old_q_sign_b_i[lane] = (idx + lane * 11) & 1;
      end
    end
  endtask

  always @(posedge clk) begin
    if (rst) begin
      cycle <= 0;
      valid_da3_d1 <= 1'b0;
      q_a_da3_d1 <= {LANES*Q_W{1'b0}};
      q_b_da3_d1 <= {LANES*Q_W{1'b0}};
      min1_da3_d1 <= {LANES*MSG_W{1'b0}};
      min2_da3_d1 <= {LANES*MSG_W{1'b0}};
      imin_da3_d1 <= {LANES*EDGE_ID_W{1'b0}};
      sign_da3_d1 <= {LANES{1'b0}};
      checked <= 0;
    end else begin
      cycle <= cycle + 1;
      valid_da3_d1 <= valid_da3;
      q_a_da3_d1 <= q_a_da3;
      q_b_da3_d1 <= q_b_da3;
      min1_da3_d1 <= min1_da3;
      min2_da3_d1 <= min2_da3;
      imin_da3_d1 <= imin_da3;
      sign_da3_d1 <= sign_da3;
      if (valid_da4) begin
        if (!valid_da3_d1) begin
          $display("FAIL accumulation latency alignment at cycle %0d", cycle);
          $finish;
        end
        if ((^q_a_da4 === 1'bx) || (^q_b_da4 === 1'bx)) begin
          $display("FAIL accumulation X/Z output at cycle %0d", cycle);
          $finish;
        end
        if ((q_a_da4 !== q_a_da3_d1) || (q_b_da4 !== q_b_da3_d1) ||
            (min1_da4 !== min1_da3_d1) || (min2_da4 !== min2_da3_d1) ||
            (imin_da4 !== imin_da3_d1) || (sign_da4 !== sign_da3_d1)) begin
          $display("FAIL accumulation DA3/DA4 mismatch at cycle %0d", cycle);
          $finish;
        end
        checked <= checked + 1;
      end
    end
  end

  initial begin
    app_a_i = 0;
    app_b_i = 0;
    old_min1_i = 0;
    old_min2_i = 0;
    old_imin_i = 0;
    old_total_sign_i = 0;
    old_q_sign_a_i = 0;
    old_q_sign_b_i = 0;
    edge_id_a_i = 0;
    edge_id_b_i = 1;
    shift_a_i = 0;
    shift_b_i = 0;
    repeat (4) @(posedge clk);
    rst = 1'b0;
    for (case_idx = 0; case_idx < NUM_CASES; case_idx = case_idx + 1) begin
      @(negedge clk);
      valid_i = 1'b1;
      apply_case(case_idx);
    end
    @(negedge clk);
    valid_i = 1'b0;
    repeat (14) @(posedge clk);
    if (checked != NUM_CASES) begin
      $display("FAIL accumulation checked %0d expected %0d", checked, NUM_CASES);
      $finish;
    end
    $display("PASS accumulation DA3/DA4 equivalence cases=%0d", checked);
    $finish;
  end
endmodule

