`timescale 1ns/1ps

module tb_reconstruction;
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
  reg signed [LANES*Q_W-1:0] q_a_i;
  reg signed [LANES*Q_W-1:0] q_b_i;
  reg [LANES*MSG_W-1:0] min1_i;
  reg [LANES*MSG_W-1:0] min2_i;
  reg [LANES*EDGE_ID_W-1:0] imin_i;
  reg [LANES-1:0] total_sign_i;
  reg [LANES-1:0] q_sign_a_i;
  reg [LANES-1:0] q_sign_b_i;
  reg [EDGE_ID_W-1:0] edge_id_a_i;
  reg [EDGE_ID_W-1:0] edge_id_b_i;
  reg [SHIFT_W-1:0] shift_a_i;
  reg [SHIFT_W-1:0] shift_b_i;

  wire valid_dr3;
  wire valid_dr4;
  wire signed [LANES*APP_W-1:0] app_a_dr3;
  wire signed [LANES*APP_W-1:0] app_b_dr3;
  wire signed [LANES*APP_W-1:0] app_a_dr4;
  wire signed [LANES*APP_W-1:0] app_b_dr4;

  reg valid_dr3_d1;
  reg signed [LANES*APP_W-1:0] app_a_dr3_d1;
  reg signed [LANES*APP_W-1:0] app_b_dr3_d1;
  integer cycle;
  integer case_idx;
  integer lane;
  integer tmp;
  integer checked;

  always #5 clk = ~clk;

  reconstruction_dr3 #(
    .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
    .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
  ) u_dr3 (
    .clk(clk), .rst(rst), .valid_i(valid_i), .q_a_i(q_a_i), .q_b_i(q_b_i),
    .min1_i(min1_i), .min2_i(min2_i), .imin_i(imin_i),
    .total_sign_i(total_sign_i), .q_sign_a_i(q_sign_a_i),
    .q_sign_b_i(q_sign_b_i), .edge_id_a_i(edge_id_a_i),
    .edge_id_b_i(edge_id_b_i), .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
    .valid_o(valid_dr3), .app_a_o(app_a_dr3), .app_b_o(app_b_dr3)
  );

  reconstruction_dr4 #(
    .LANES(LANES), .APP_W(APP_W), .Q_W(Q_W), .MSG_W(MSG_W),
    .EDGE_ID_W(EDGE_ID_W), .SHIFT_W(SHIFT_W)
  ) u_dr4 (
    .clk(clk), .rst(rst), .valid_i(valid_i), .q_a_i(q_a_i), .q_b_i(q_b_i),
    .min1_i(min1_i), .min2_i(min2_i), .imin_i(imin_i),
    .total_sign_i(total_sign_i), .q_sign_a_i(q_sign_a_i),
    .q_sign_b_i(q_sign_b_i), .edge_id_a_i(edge_id_a_i),
    .edge_id_b_i(edge_id_b_i), .shift_a_i(shift_a_i), .shift_b_i(shift_b_i),
    .valid_o(valid_dr4), .app_a_o(app_a_dr4), .app_b_o(app_b_dr4)
  );

  task apply_case;
    input integer idx;
    begin
      edge_id_a_i = idx % 19;
      edge_id_b_i = (idx * 7 + 3) % 19;
      shift_a_i = (idx * 5 + 1) % LANES;
      shift_b_i = (idx * 11 + 2) % LANES;
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        tmp = ((idx * 17 + lane * 13) % 255) - 127;
        q_a_i[lane*Q_W +: Q_W] = tmp[Q_W-1:0];
        tmp = ((idx * 19 + lane * 7 + 31) % 255) - 127;
        q_b_i[lane*Q_W +: Q_W] = tmp[Q_W-1:0];
        min1_i[lane*MSG_W +: MSG_W] = ((idx + lane) % 31) + 1;
        min2_i[lane*MSG_W +: MSG_W] = ((idx + lane) % 31) + 32;
        imin_i[lane*EDGE_ID_W +: EDGE_ID_W] = (idx + lane * 3) % 19;
        total_sign_i[lane] = (idx + lane) & 1;
        q_sign_a_i[lane] = (idx + lane * 2) & 1;
        q_sign_b_i[lane] = (idx + lane * 5) & 1;
      end
      if (idx == 3) begin
        q_a_i[0 +: Q_W] = 8'sh7f;
        q_b_i[0 +: Q_W] = 8'sh80;
        min1_i[0 +: MSG_W] = 6'd63;
        min2_i[0 +: MSG_W] = 6'd63;
      end
    end
  endtask

  always @(posedge clk) begin
    if (rst) begin
      cycle <= 0;
      valid_dr3_d1 <= 1'b0;
      app_a_dr3_d1 <= {LANES*APP_W{1'b0}};
      app_b_dr3_d1 <= {LANES*APP_W{1'b0}};
      checked <= 0;
    end else begin
      cycle <= cycle + 1;
      valid_dr3_d1 <= valid_dr3;
      app_a_dr3_d1 <= app_a_dr3;
      app_b_dr3_d1 <= app_b_dr3;
      if (valid_dr4) begin
        if (!valid_dr3_d1) begin
          $display("FAIL reconstruction latency alignment at cycle %0d", cycle);
          $finish;
        end
        if ((^app_a_dr4 === 1'bx) || (^app_b_dr4 === 1'bx)) begin
          $display("FAIL reconstruction X/Z output at cycle %0d", cycle);
          $finish;
        end
        if ((app_a_dr4 !== app_a_dr3_d1) || (app_b_dr4 !== app_b_dr3_d1)) begin
          $display("FAIL reconstruction DR3/DR4 mismatch at cycle %0d", cycle);
          $finish;
        end
        checked <= checked + 1;
      end
    end
  end

  initial begin
    q_a_i = 0;
    q_b_i = 0;
    min1_i = 0;
    min2_i = 0;
    imin_i = 0;
    total_sign_i = 0;
    q_sign_a_i = 0;
    q_sign_b_i = 0;
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
    repeat (12) @(posedge clk);
    if (checked != NUM_CASES) begin
      $display("FAIL reconstruction checked %0d expected %0d", checked, NUM_CASES);
      $finish;
    end
    $display("PASS reconstruction DR3/DR4 equivalence cases=%0d", checked);
    $finish;
  end
endmodule

