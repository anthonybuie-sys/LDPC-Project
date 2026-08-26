`timescale 1ns/1ps

module tb_phase4_acc_min_update;
  import nr_ldpc_pkg::*;

  logic [5:0] edge_count_i;
  logic [5:0] edge_count_o;
  logic [5:0] min1_i;
  logic [5:0] min2_i;
  logic [5:0] min1_o;
  logic [5:0] min2_o;
  logic [4:0] imin_i;
  logic [4:0] imin_o;
  logic aggregate_i;
  logic aggregate_o;
  logic cand0_valid;
  logic cand1_valid;
  logic [5:0] cand0_mag;
  logic [5:0] cand1_mag;
  logic [4:0] cand0_edge;
  logic [4:0] cand1_edge;
  logic cand0_sign;
  logic cand1_sign;

  int errors;
  int order_independence_cases;

  nr_ldpc_acc_min_update u_update (
    .edge_count_i(edge_count_i),
    .min1_i(min1_i),
    .min2_i(min2_i),
    .imin_i(imin_i),
    .aggregate_sign_i(aggregate_i),
    .cand0_valid_i(cand0_valid),
    .cand0_mag_i(cand0_mag),
    .cand0_edge_id_i(cand0_edge),
    .cand0_sign_i(cand0_sign),
    .cand1_valid_i(cand1_valid),
    .cand1_mag_i(cand1_mag),
    .cand1_edge_id_i(cand1_edge),
    .cand1_sign_i(cand1_sign),
    .edge_count_o(edge_count_o),
    .min1_o(min1_o),
    .min2_o(min2_o),
    .imin_o(imin_o),
    .aggregate_sign_o(aggregate_o)
  );

  task automatic drive_pair(
    input int m0,
    input int m1,
    input int e0,
    input int e1,
    input int s0,
    input int s1
  );
    begin
      edge_count_i = 6'd0;
      min1_i = 6'd0;
      min2_i = 6'd0;
      imin_i = 5'd0;
      aggregate_i = 1'b0;
      cand0_valid = 1'b1;
      cand1_valid = 1'b1;
      cand0_mag = m0[5:0];
      cand1_mag = m1[5:0];
      cand0_edge = e0[4:0];
      cand1_edge = e1[4:0];
      cand0_sign = s0[0];
      cand1_sign = s1[0];
      #1;
    end
  endtask

  task automatic require_equal(input string name, input int actual, input int expected);
    begin
      if (actual != expected) begin
        if (errors < 20) begin
          $display("FAIL %s actual=%0d expected=%0d", name, actual, expected);
        end
        errors++;
      end
    end
  endtask

  initial begin
    int m0;
    int m1;
    int pair_index;
    int e0 [0:3];
    int e1 [0:3];
    int sign0;
    int sign1;
    int ref_min1;
    int ref_min2;
    int ref_imin;
    int out_min1;
    int out_min2;
    int out_imin;
    int out_sign;

    errors = 0;
    order_independence_cases = 0;
    e0[0] = 0;  e1[0] = 1;
    e0[1] = 7;  e1[1] = 3;
    e0[2] = 31; e1[2] = 2;
    e0[3] = 12; e1[3] = 29;

    for (m0 = 0; m0 < 64; m0++) begin
      for (m1 = 0; m1 < 64; m1++) begin
        for (pair_index = 0; pair_index < 4; pair_index++) begin
          sign0 = (m0 ^ e0[pair_index]) & 1;
          sign1 = (m1 ^ e1[pair_index] ^ 1) & 1;

          drive_pair(m0, m1, e0[pair_index], e1[pair_index], sign0, sign1);
          out_min1 = min1_o;
          out_min2 = min2_o;
          out_imin = imin_o;
          out_sign = aggregate_o;

          drive_pair(m1, m0, e1[pair_index], e0[pair_index], sign1, sign0);
          require_equal("swapped.min1", min1_o, out_min1);
          require_equal("swapped.min2", min2_o, out_min2);
          require_equal("swapped.imin", imin_o, out_imin);
          require_equal("swapped.sign", aggregate_o, out_sign);
          require_equal("swapped.edge_count", edge_count_o, 2);

          if (m0 < m1) begin
            ref_min1 = m0;
            ref_min2 = m1;
            ref_imin = e0[pair_index];
          end else if (m1 < m0) begin
            ref_min1 = m1;
            ref_min2 = m0;
            ref_imin = e1[pair_index];
          end else begin
            ref_min1 = m0;
            ref_min2 = m0;
            ref_imin = (e0[pair_index] < e1[pair_index]) ? e0[pair_index] : e1[pair_index];
          end
          require_equal("expected.min1", min1_o, ref_min1);
          require_equal("expected.min2", min2_o, ref_min2);
          require_equal("expected.imin", imin_o, ref_imin);
          require_equal("expected.sign", aggregate_o, sign0 ^ sign1);
          order_independence_cases++;
        end
      end
    end

    if (errors == 0) begin
      $display("PASS phase4 acc min-update exhaustive");
      $display("order_independence_cases=%0d", order_independence_cases);
      $finish;
    end else begin
      $display("FAIL phase4 acc min-update exhaustive errors=%0d", errors);
      $finish(1);
    end
  end
endmodule
