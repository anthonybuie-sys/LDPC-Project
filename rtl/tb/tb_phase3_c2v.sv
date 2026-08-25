`timescale 1ns/1ps

module tb_phase3_c2v;
  import nr_ldpc_pkg::*;

  localparam int P_VAL = REFERENCE_Z;
  localparam int EDGE_ID_W = 5;

  logic [5:0] lane_m1;
  logic [5:0] lane_m2;
  logic [4:0] lane_imin;
  logic lane_aggregate_sign;
  logic lane_q_sign;
  logic [4:0] lane_edge_id;
  logic signed [6:0] lane_c2v;

  logic [P_VAL*W_M-1:0] vector_m1;
  logic [P_VAL*W_M-1:0] vector_m2;
  logic [P_VAL*EDGE_ID_W-1:0] vector_imin;
  logic [P_VAL-1:0] vector_aggregate_sign;
  logic [P_VAL-1:0] vector_q_sign;
  logic [EDGE_ID_W-1:0] vector_edge_id;
  logic [P_VAL*W_C2V-1:0] vector_c2v;

  int errors;
  int scalar_cases;
  int vector_cases;
  int explicit_edges_checked;

  nr_ldpc_compressed_c2v_reconstruct_lane u_lane (
    .m1_i(lane_m1),
    .m2_i(lane_m2),
    .imin_i(lane_imin),
    .aggregate_sign_i(lane_aggregate_sign),
    .q_sign_i(lane_q_sign),
    .local_edge_id_i(lane_edge_id),
    .c2v_o(lane_c2v)
  );

  nr_ldpc_compressed_c2v_reconstruct_vector #(
    .P(P_VAL)
  ) u_vector (
    .m1_i(vector_m1),
    .m2_i(vector_m2),
    .imin_i(vector_imin),
    .aggregate_sign_i(vector_aggregate_sign),
    .q_sign_i(vector_q_sign),
    .local_edge_id_i(vector_edge_id),
    .c2v_o(vector_c2v)
  );

  function automatic int expected_c2v(
    input int m1,
    input int m2,
    input int imin,
    input int edge_id,
    input int aggregate_sign,
    input int q_sign
  );
    int magnitude;
    int negative;
    begin
      magnitude = (edge_id == imin) ? m2 : m1;
      negative = aggregate_sign ^ q_sign;
      if (magnitude == 0) begin
        expected_c2v = 0;
      end else if (negative) begin
        expected_c2v = -magnitude;
      end else begin
        expected_c2v = magnitude;
      end
    end
  endfunction

  function automatic int lane_c2v_value(
    input logic [P_VAL*W_C2V-1:0] vec,
    input int lane
  );
    logic signed [W_C2V-1:0] value;
    begin
      value = vec[lane*W_C2V +: W_C2V];
      lane_c2v_value = value;
    end
  endfunction

  task automatic fail_case(
    input string name,
    input int lane,
    input int actual,
    input int expected
  );
    begin
      $display("FAIL %s lane=%0d actual=%0d expected=%0d", name, lane, actual, expected);
      errors++;
    end
  endtask

  task automatic check_int(input string name, input int actual, input int expected);
    begin
      if (actual != expected) begin
        $display("FAIL %s actual=%0d expected=%0d", name, actual, expected);
        errors++;
      end
    end
  endtask

  task automatic check_lane_case(
    input string name,
    input int m1,
    input int m2,
    input int imin,
    input int edge_id,
    input int aggregate_sign,
    input int q_sign
  );
    int expected;
    begin
      lane_m1 = m1;
      lane_m2 = m2;
      lane_imin = imin;
      lane_edge_id = edge_id;
      lane_aggregate_sign = aggregate_sign[0];
      lane_q_sign = q_sign[0];
      #1;
      expected = expected_c2v(m1, m2, imin, edge_id, aggregate_sign, q_sign);
      if ($signed(lane_c2v) != expected) begin
        fail_case(name, -1, $signed(lane_c2v), expected);
      end
    end
  endtask

  task automatic set_vector_lane(
    input int lane,
    input int m1,
    input int m2,
    input int imin,
    input int aggregate_sign,
    input int q_sign
  );
    begin
      vector_m1[lane*W_M +: W_M] = m1 & 6'h3f;
      vector_m2[lane*W_M +: W_M] = m2 & 6'h3f;
      vector_imin[lane*EDGE_ID_W +: EDGE_ID_W] = imin & 5'h1f;
      vector_aggregate_sign[lane] = aggregate_sign[0];
      vector_q_sign[lane] = q_sign[0];
    end
  endtask

  task automatic check_vector_case(input string name, input int edge_id);
    int lane;
    int m1;
    int m2;
    int imin;
    int aggregate_sign;
    int q_sign;
    int expected;
    int actual;
    begin
      vector_edge_id = edge_id;
      #1;
      for (lane = 0; lane < P_VAL; lane++) begin
        m1 = vector_m1[lane*W_M +: W_M];
        m2 = vector_m2[lane*W_M +: W_M];
        imin = vector_imin[lane*EDGE_ID_W +: EDGE_ID_W];
        aggregate_sign = vector_aggregate_sign[lane];
        q_sign = vector_q_sign[lane];
        expected = expected_c2v(m1, m2, imin, edge_id, aggregate_sign, q_sign);
        actual = lane_c2v_value(vector_c2v, lane);
        if (actual != expected) begin
          fail_case(name, lane, actual, expected);
        end
      end
      vector_cases++;
    end
  endtask

  task automatic fill_lane_distinct_vector(input int case_id);
    int lane;
    int m1;
    int m2;
    int imin;
    int aggregate_sign;
    int q_sign;
    begin
      vector_m1 = '0;
      vector_m2 = '0;
      vector_imin = '0;
      vector_aggregate_sign = '0;
      vector_q_sign = '0;
      for (lane = 0; lane < P_VAL; lane++) begin
        m1 = (lane * 3 + case_id * 11) & 6'h3f;
        m2 = (lane * 7 + case_id * 5 + 9) & 6'h3f;
        imin = (lane + case_id * 13) & 5'h1f;
        aggregate_sign = ((lane >> 1) ^ case_id) & 1;
        q_sign = ((lane >> 3) ^ (case_id >> 1)) & 1;
        set_vector_lane(lane, m1, m2, imin, aggregate_sign, q_sign);
      end
    end
  endtask

  task automatic fill_randomized_valid_state(input int seed_in);
    int lane;
    int seed;
    int m1;
    int m2;
    int imin;
    int aggregate_sign;
    int q_sign;
    begin
      vector_m1 = '0;
      vector_m2 = '0;
      vector_imin = '0;
      vector_aggregate_sign = '0;
      vector_q_sign = '0;
      seed = seed_in;
      for (lane = 0; lane < P_VAL; lane++) begin
        seed = (seed * 1103515245 + 12345) & 32'h7fffffff;
        m1 = (seed >> 3) & 6'h3f;
        seed = (seed * 1103515245 + 12345) & 32'h7fffffff;
        m2 = (seed >> 5) & 6'h3f;
        seed = (seed * 1103515245 + 12345) & 32'h7fffffff;
        imin = (seed >> 7) & 5'h1f;
        seed = (seed * 1103515245 + 12345) & 32'h7fffffff;
        aggregate_sign = (seed >> 9) & 1;
        seed = (seed * 1103515245 + 12345) & 32'h7fffffff;
        q_sign = (seed >> 11) & 1;
        set_vector_lane(lane, m1, m2, imin, aggregate_sign, q_sign);
      end
    end
  endtask

  initial begin
    int m1;
    int m2;
    int match;
    int aggregate_sign;
    int q_sign;
    int edge_id;
    int case_id;
    int explicit_case;

    errors = 0;
    scalar_cases = 0;
    vector_cases = 0;
    explicit_edges_checked = 0;

    check_lane_case("non-Imin edge positive", 5, 9, 3, 7, 0, 0);
    check_lane_case("Imin edge positive", 5, 9, 3, 3, 0, 0);
    check_lane_case("non-Imin edge negative", 5, 9, 3, 7, 1, 0);
    check_lane_case("Imin edge negative", 5, 9, 3, 3, 1, 0);
    check_lane_case("zero negative suppression non-Imin", 0, 9, 3, 7, 1, 0);
    check_lane_case("zero negative suppression Imin", 5, 0, 3, 3, 1, 0);
    check_lane_case("maximum positive", 63, 12, 3, 7, 0, 0);
    check_lane_case("maximum negative", 63, 12, 3, 7, 1, 0);
    check_lane_case("duplicate minima non-Imin", 12, 12, 3, 7, 0, 0);
    check_lane_case("duplicate minima Imin", 12, 12, 3, 3, 0, 0);
    check_lane_case("all-zero non-Imin positive", 0, 0, 3, 7, 0, 0);
    check_lane_case("all-zero non-Imin negative", 0, 0, 3, 7, 1, 0);
    check_lane_case("all-zero Imin positive", 0, 0, 3, 3, 0, 0);
    check_lane_case("all-zero Imin negative", 0, 0, 3, 3, 1, 0);

    for (m1 = 0; m1 <= 63; m1++) begin
      for (m2 = 0; m2 <= 63; m2++) begin
        for (match = 0; match <= 1; match++) begin
          for (aggregate_sign = 0; aggregate_sign <= 1; aggregate_sign++) begin
            for (q_sign = 0; q_sign <= 1; q_sign++) begin
              if (match) begin
                check_lane_case("scalar exhaustive Imin", m1, m2, 17, 17, aggregate_sign, q_sign);
              end else begin
                check_lane_case("scalar exhaustive non-Imin", m1, m2, 3, 7, aggregate_sign, q_sign);
              end
              scalar_cases++;
            end
          end
        end
      end
    end

    fill_lane_distinct_vector(0);
    begin
      vector_edge_id = 0;
      #1;
      check_int("lane 0 vector packing", lane_c2v_value(vector_c2v, 0),
          expected_c2v(
            vector_m1[0*W_M +: W_M],
            vector_m2[0*W_M +: W_M],
            vector_imin[0*EDGE_ID_W +: EDGE_ID_W],
            0,
            vector_aggregate_sign[0],
            vector_q_sign[0]
          ));
      check_int("lane 1 vector packing", lane_c2v_value(vector_c2v, 1),
          expected_c2v(
            vector_m1[1*W_M +: W_M],
            vector_m2[1*W_M +: W_M],
            vector_imin[1*EDGE_ID_W +: EDGE_ID_W],
            0,
            vector_aggregate_sign[1],
            vector_q_sign[1]
          ));
      check_int("lane 383 vector packing", lane_c2v_value(vector_c2v, 383),
          expected_c2v(
            vector_m1[383*W_M +: W_M],
            vector_m2[383*W_M +: W_M],
            vector_imin[383*EDGE_ID_W +: EDGE_ID_W],
            0,
            vector_aggregate_sign[383],
            vector_q_sign[383]
          ));
    end

    for (case_id = 0; case_id < 4; case_id++) begin
      fill_lane_distinct_vector(case_id);
      check_vector_case("lane-distinct edge 0", 0);
      check_vector_case("lane-distinct edge 1", 1);
      check_vector_case("lane-distinct edge 3", 3);
      check_vector_case("lane-distinct edge 18", 18);
      check_vector_case("lane-distinct edge 31", 31);
    end

    for (explicit_case = 0; explicit_case < 3; explicit_case++) begin
      fill_randomized_valid_state(32'h1d0c0001 + explicit_case * 32'h101);
      for (edge_id = 0; edge_id < 32; edge_id++) begin
        check_vector_case("explicit-C2V equivalence", edge_id);
        explicit_edges_checked++;
      end
    end

    $display("phase3 scalar_cases=%0d", scalar_cases);
    $display("phase3 vector_cases=%0d", vector_cases);
    $display("phase3 explicit_edges_checked=%0d", explicit_edges_checked);

    if (errors == 0) begin
      $display("PASS phase3 compressed c2v reconstruction");
      $finish;
    end

    $display("FAIL phase3 compressed c2v reconstruction errors=%0d", errors);
    $finish(1);
  end
endmodule
