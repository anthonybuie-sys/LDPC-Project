`timescale 1ns/1ps

module tb_phase4_acc;
  import nr_ldpc_pkg::*;

`ifdef PHASE4_REDUCED_P
  localparam int P_VAL = `PHASE4_REDUCED_P;
  localparam bit REDUCED_P_SIM = 1'b1;
`else
  localparam int P_VAL = REFERENCE_Z;
  localparam bit REDUCED_P_SIM = 1'b0;
`endif
  localparam int SHIFT_W = $clog2(P_VAL+1);
  localparam int RANDOM_LAYER_SWEEP_CASES = 0;

  logic clk;
  logic rst;

  logic mu_cand0_valid;
  logic mu_cand1_valid;
  logic [5:0] mu_edge_count_i;
  logic [5:0] mu_edge_count_o;
  mag_t mu_min1_i;
  mag_t mu_min2_i;
  mag_t mu_min1_o;
  mag_t mu_min2_o;
  logic [4:0] mu_imin_i;
  logic [4:0] mu_imin_o;
  logic mu_aggregate_i;
  logic mu_aggregate_o;
  mag_t mu_cand0_mag;
  mag_t mu_cand1_mag;
  logic [4:0] mu_cand0_edge;
  logic [4:0] mu_cand1_edge;
  logic mu_cand0_sign;
  logic mu_cand1_sign;

  logic issue_valid;
  logic issue_ready;
  logic [1:0] issue_lane_mask;
  logic [5:0] issue_layer_id;
  logic [5:0] issue_layer_position;
  logic [5:0] issue_layer_degree;
  logic issue_start_layer;
  logic [4:0] issue_edge0_id;
  logic [4:0] issue_edge1_id;
  logic [0:0] issue_qbuf;
  logic [3:0] issue_qslot;
  logic issue_target_generation;
  logic [3:0] issue_iteration_epoch;
  logic [P_VAL*W_APP-1:0] issue_app0_canonical;
  logic [P_VAL*W_APP-1:0] issue_app1_canonical;
  logic issue_source0_valid;
  logic issue_source1_valid;
  logic [SHIFT_W-1:0] issue_shift0;
  logic [SHIFT_W-1:0] issue_shift1;

  logic old_state_req_valid;
  logic [1:0] old_state_req_lane_mask;
  logic [5:0] old_state_req_layer_id;
  logic [4:0] old_state_req_edge0_id;
  logic [4:0] old_state_req_edge1_id;
  logic [3:0] old_state_req_iteration_epoch;
  logic old_state_resp_valid;
  logic old_generation_valid;
  logic [P_VAL*W_M-1:0] old_m1;
  logic [P_VAL*W_M-1:0] old_m2;
  logic [P_VAL*5-1:0] old_imin;
  logic [P_VAL-1:0] old_aggregate_sign;
  logic [P_VAL-1:0] old_qsign0;
  logic [P_VAL-1:0] old_qsign1;

  logic q_write_valid;
  logic [0:0] q_write_qbuf;
  logic [3:0] q_write_qslot;
  logic [1:0] q_write_lane_mask;
  logic [P_VAL*W_Q-1:0] q_write_lane0;
  logic [P_VAL*W_Q-1:0] q_write_lane1;
  logic [5:0] q_write_layer_id;
  logic [3:0] q_write_iteration_epoch;
  logic [1:0] qsign_write_valid;
  logic [4:0] qsign_write_edge0_id;
  logic [4:0] qsign_write_edge1_id;
  logic [P_VAL-1:0] qsign_write_lane0;
  logic [P_VAL-1:0] qsign_write_lane1;
  logic [5:0] qsign_write_layer_id;
  logic qsign_write_target_generation;
  logic [3:0] qsign_write_iteration_epoch;
  logic layer_close_valid;
  logic [5:0] layer_close_layer_id;
  logic layer_close_target_generation;
  logic [3:0] layer_close_iteration_epoch;
  logic [P_VAL*W_M-1:0] layer_close_m1_offset;
  logic [P_VAL*W_M-1:0] layer_close_m2_offset;
  logic [P_VAL*5-1:0] layer_close_imin;
  logic [P_VAL-1:0] layer_close_aggregate_sign;
  logic error_valid;

  int errors;
  int directed_cases;
  int order_independence_cases;
  int random_layer_cases;
  int pipeline_checks;
  int high_rate_issue_count;
  int high_rate_edge_count;
  int high_rate_qslot_max;

  int ref_min1 [0:P_VAL-1];
  int ref_min2 [0:P_VAL-1];
  int ref_imin [0:P_VAL-1];
  int ref_sign [0:P_VAL-1];
  int ref_count;

  nr_ldpc_acc_min_update u_min_update (
    .edge_count_i(mu_edge_count_i),
    .min1_i(mu_min1_i),
    .min2_i(mu_min2_i),
    .imin_i(mu_imin_i),
    .aggregate_sign_i(mu_aggregate_i),
    .cand0_valid_i(mu_cand0_valid),
    .cand0_mag_i(mu_cand0_mag),
    .cand0_edge_id_i(mu_cand0_edge),
    .cand0_sign_i(mu_cand0_sign),
    .cand1_valid_i(mu_cand1_valid),
    .cand1_mag_i(mu_cand1_mag),
    .cand1_edge_id_i(mu_cand1_edge),
    .cand1_sign_i(mu_cand1_sign),
    .edge_count_o(mu_edge_count_o),
    .min1_o(mu_min1_o),
    .min2_o(mu_min2_o),
    .imin_o(mu_imin_o),
    .aggregate_sign_o(mu_aggregate_o)
  );

  nr_ldpc_acc_pipeline #(
    .P(P_VAL)
  ) u_acc_pipeline (
    .clk_i(clk),
    .rst_i(rst),
    .issue_valid_i(issue_valid),
    .issue_ready_o(issue_ready),
    .issue_lane_mask_i(issue_lane_mask),
    .issue_layer_id_i(issue_layer_id),
    .issue_layer_position_i(issue_layer_position),
    .issue_layer_degree_i(issue_layer_degree),
    .issue_start_layer_i(issue_start_layer),
    .issue_edge0_id_i(issue_edge0_id),
    .issue_edge1_id_i(issue_edge1_id),
    .issue_qbuf_i(issue_qbuf),
    .issue_qslot_i(issue_qslot),
    .issue_target_generation_i(issue_target_generation),
    .issue_iteration_epoch_i(issue_iteration_epoch),
    .issue_app0_canonical_i(issue_app0_canonical),
    .issue_app1_canonical_i(issue_app1_canonical),
    .issue_source0_valid_i(issue_source0_valid),
    .issue_source1_valid_i(issue_source1_valid),
    .issue_shift0_i(issue_shift0),
    .issue_shift1_i(issue_shift1),
    .old_state_req_valid_o(old_state_req_valid),
    .old_state_req_lane_mask_o(old_state_req_lane_mask),
    .old_state_req_layer_id_o(old_state_req_layer_id),
    .old_state_req_edge0_id_o(old_state_req_edge0_id),
    .old_state_req_edge1_id_o(old_state_req_edge1_id),
    .old_state_req_iteration_epoch_o(old_state_req_iteration_epoch),
    .old_state_resp_valid_i(old_state_resp_valid),
    .old_generation_valid_i(old_generation_valid),
    .old_m1_i(old_m1),
    .old_m2_i(old_m2),
    .old_imin_i(old_imin),
    .old_aggregate_sign_i(old_aggregate_sign),
    .old_qsign0_i(old_qsign0),
    .old_qsign1_i(old_qsign1),
    .q_write_valid_o(q_write_valid),
    .q_write_qbuf_o(q_write_qbuf),
    .q_write_qslot_o(q_write_qslot),
    .q_write_lane_mask_o(q_write_lane_mask),
    .q_write_lane0_o(q_write_lane0),
    .q_write_lane1_o(q_write_lane1),
    .q_write_layer_id_o(q_write_layer_id),
    .q_write_iteration_epoch_o(q_write_iteration_epoch),
    .qsign_write_valid_o(qsign_write_valid),
    .qsign_write_edge0_id_o(qsign_write_edge0_id),
    .qsign_write_edge1_id_o(qsign_write_edge1_id),
    .qsign_write_lane0_o(qsign_write_lane0),
    .qsign_write_lane1_o(qsign_write_lane1),
    .qsign_write_layer_id_o(qsign_write_layer_id),
    .qsign_write_target_generation_o(qsign_write_target_generation),
    .qsign_write_iteration_epoch_o(qsign_write_iteration_epoch),
    .layer_close_valid_o(layer_close_valid),
    .layer_close_layer_id_o(layer_close_layer_id),
    .layer_close_target_generation_o(layer_close_target_generation),
    .layer_close_iteration_epoch_o(layer_close_iteration_epoch),
    .layer_close_m1_offset_o(layer_close_m1_offset),
    .layer_close_m2_offset_o(layer_close_m2_offset),
    .layer_close_imin_o(layer_close_imin),
    .layer_close_aggregate_sign_o(layer_close_aggregate_sign),
    .error_valid_o(error_valid)
  );

  function automatic int sat8(input int value);
    begin
      if (value < -128) begin
        sat8 = -128;
      end else if (value > 127) begin
        sat8 = 127;
      end else begin
        sat8 = value;
      end
    end
  endfunction

  function automatic int abs_int(input int value);
    begin
      abs_int = (value < 0) ? -value : value;
    end
  endfunction

  function automatic int beta_offset(input int raw_mag);
    begin
      beta_offset = (raw_mag > BETA_INT) ? (raw_mag - BETA_INT) : 0;
    end
  endfunction

  function automatic int signed q_lane0(input int lane);
    logic signed [W_Q-1:0] value;
    begin
      value = q_write_lane0[lane*W_Q +: W_Q];
      q_lane0 = value;
    end
  endfunction

  function automatic int signed q_lane1(input int lane);
    logic signed [W_Q-1:0] value;
    begin
      value = q_write_lane1[lane*W_Q +: W_Q];
      q_lane1 = value;
    end
  endfunction

  function automatic int close_m1(input int lane);
    begin
      close_m1 = layer_close_m1_offset[lane*W_M +: W_M];
    end
  endfunction

  function automatic int close_m2(input int lane);
    begin
      close_m2 = layer_close_m2_offset[lane*W_M +: W_M];
    end
  endfunction

  function automatic int close_imin(input int lane);
    begin
      close_imin = layer_close_imin[lane*5 +: 5];
    end
  endfunction

  task automatic check_int(input string name, input int actual, input int expected);
    begin
      if (actual != expected) begin
        $display("FAIL %s actual=%0d expected=%0d", name, actual, expected);
        errors++;
      end
    end
  endtask

  task automatic check_bit(input string name, input logic actual, input logic expected);
    begin
      if (actual !== expected) begin
        $display("FAIL %s actual=%0b expected=%0b", name, actual, expected);
        errors++;
      end
    end
  endtask

  task automatic set_min_update_inputs(
    input int edge_count,
    input int min1,
    input int min2,
    input int imin,
    input int aggregate_sign,
    input int c0_valid,
    input int c0_mag,
    input int c0_edge,
    input int c0_sign,
    input int c1_valid,
    input int c1_mag,
    input int c1_edge,
    input int c1_sign
  );
    begin
      mu_edge_count_i = edge_count[5:0];
      mu_min1_i = min1[W_M-1:0];
      mu_min2_i = min2[W_M-1:0];
      mu_imin_i = imin[4:0];
      mu_aggregate_i = aggregate_sign[0];
      mu_cand0_valid = c0_valid[0];
      mu_cand0_mag = c0_mag[W_M-1:0];
      mu_cand0_edge = c0_edge[4:0];
      mu_cand0_sign = c0_sign[0];
      mu_cand1_valid = c1_valid[0];
      mu_cand1_mag = c1_mag[W_M-1:0];
      mu_cand1_edge = c1_edge[4:0];
      mu_cand1_sign = c1_sign[0];
      #1;
    end
  endtask

  task automatic expect_min_update(
    input string name,
    input int edge_count,
    input int min1,
    input int min2,
    input int imin,
    input int aggregate_sign
  );
    begin
      check_int({name, ".edge_count"}, mu_edge_count_o, edge_count);
      check_int({name, ".min1"}, mu_min1_o, min1);
      check_int({name, ".min2"}, mu_min2_o, min2);
      check_int({name, ".imin"}, mu_imin_o, imin);
      check_int({name, ".aggregate_sign"}, mu_aggregate_o, aggregate_sign);
      directed_cases++;
    end
  endtask

  task automatic reset_pipeline;
    begin
      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      issue_layer_id = 6'd0;
      issue_layer_position = 6'd0;
      issue_layer_degree = 6'd0;
      issue_start_layer = 1'b0;
      issue_edge0_id = 5'd0;
      issue_edge1_id = 5'd0;
      issue_qbuf = 1'b0;
      issue_qslot = 4'd0;
      issue_target_generation = 1'b0;
      issue_iteration_epoch = 4'd0;
      issue_app0_canonical = '0;
      issue_app1_canonical = '0;
      issue_source0_valid = 1'b1;
      issue_source1_valid = 1'b1;
      issue_shift0 = '0;
      issue_shift1 = '0;
      old_state_resp_valid = 1'b1;
      old_generation_valid = 1'b0;
      old_m1 = '0;
      old_m2 = '0;
      old_imin = '0;
      old_aggregate_sign = '0;
      old_qsign0 = '0;
      old_qsign1 = '0;
      rst = 1'b1;
      tick();
      tick();
      rst = 1'b0;
      tick();
    end
  endtask

  task automatic tick;
    begin
      #5;
      clk = 1'b1;
      #1;
      clk = 1'b0;
      #4;
    end
  endtask

  task automatic idle_tick;
    begin
      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      tick();
    end
  endtask

  task automatic fill_app0_all(input int value);
    int lane;
    logic signed [W_APP-1:0] packed_value;
    begin
      packed_value = value;
      for (lane = 0; lane < P_VAL; lane++) begin
        issue_app0_canonical[lane*W_APP +: W_APP] = packed_value;
      end
    end
  endtask

  task automatic fill_app1_all(input int value);
    int lane;
    logic signed [W_APP-1:0] packed_value;
    begin
      packed_value = value;
      for (lane = 0; lane < P_VAL; lane++) begin
        issue_app1_canonical[lane*W_APP +: W_APP] = packed_value;
      end
    end
  endtask

  task automatic fill_old_state(
    input int m1,
    input int m2,
    input int imin,
    input int aggregate,
    input int qsign0,
    input int qsign1
  );
    int lane;
    begin
      for (lane = 0; lane < P_VAL; lane++) begin
        old_m1[lane*W_M +: W_M] = m1[W_M-1:0];
        old_m2[lane*W_M +: W_M] = m2[W_M-1:0];
        old_imin[lane*5 +: 5] = imin[4:0];
        old_aggregate_sign[lane] = aggregate[0];
        old_qsign0[lane] = qsign0[0];
        old_qsign1[lane] = qsign1[0];
      end
    end
  endtask

  task automatic drive_issue(
    input int lane_mask,
    input int layer_id,
    input int layer_position,
    input int layer_degree,
    input int start_layer,
    input int edge0,
    input int edge1,
    input int qbuf,
    input int qslot,
    input int target_generation,
    input int epoch,
    input int shift0,
    input int shift1
  );
    begin
      issue_valid = 1'b1;
      issue_lane_mask = lane_mask[1:0];
      issue_layer_id = layer_id[5:0];
      issue_layer_position = layer_position[5:0];
      issue_layer_degree = layer_degree[5:0];
      issue_start_layer = start_layer[0];
      issue_edge0_id = edge0[4:0];
      issue_edge1_id = edge1[4:0];
      issue_qbuf = qbuf[0];
      issue_qslot = qslot[3:0];
      issue_target_generation = target_generation[0];
      issue_iteration_epoch = epoch[3:0];
      issue_shift0 = shift0[SHIFT_W-1:0];
      issue_shift1 = shift1[SHIFT_W-1:0];
      issue_source0_valid = 1'b1;
      issue_source1_valid = 1'b1;
    end
  endtask

  task automatic clear_ref_layer;
    int lane;
    begin
      ref_count = 0;
      for (lane = 0; lane < P_VAL; lane++) begin
        ref_min1[lane] = 0;
        ref_min2[lane] = 0;
        ref_imin[lane] = 0;
        ref_sign[lane] = 0;
      end
    end
  endtask

  task automatic ref_insert_lane(input int lane, input int mag, input int edge_id, input int sign);
    begin
      if (ref_count == 0) begin
        ref_min1[lane] = mag;
        ref_imin[lane] = edge_id;
      end else if (ref_count == 1) begin
        if (mag < ref_min1[lane]) begin
          ref_min2[lane] = ref_min1[lane];
          ref_min1[lane] = mag;
          ref_imin[lane] = edge_id;
        end else if (mag == ref_min1[lane]) begin
          ref_min2[lane] = ref_min1[lane];
          if (edge_id < ref_imin[lane]) begin
            ref_imin[lane] = edge_id;
          end
        end else begin
          ref_min2[lane] = mag;
        end
      end else begin
        if (mag < ref_min1[lane]) begin
          ref_min2[lane] = ref_min1[lane];
          ref_min1[lane] = mag;
          ref_imin[lane] = edge_id;
        end else if (mag == ref_min1[lane]) begin
          ref_min2[lane] = ref_min1[lane];
          if (edge_id < ref_imin[lane]) begin
            ref_imin[lane] = edge_id;
          end
        end else if (mag < ref_min2[lane]) begin
          ref_min2[lane] = mag;
        end
      end
      ref_sign[lane] = ref_sign[lane] ^ sign;
    end
  endtask

  task automatic ref_insert_constant_edge(input int mag, input int edge_id, input int sign);
    int lane;
    begin
      for (lane = 0; lane < P_VAL; lane++) begin
        ref_insert_lane(lane, mag, edge_id, sign);
      end
      ref_count = ref_count + 1;
    end
  endtask

  task automatic ref_insert_vector_from_app(
    input int edge_id,
    input int use_lane1,
    input int seed,
    input int issue_index
  );
    int lane;
    int mag;
    int sign;
    int value;
    logic signed [W_APP-1:0] packed_value;
    begin
      for (lane = 0; lane < P_VAL; lane++) begin
        mag = (seed + issue_index * 17 + edge_id * 11 + lane * 5) & 6'h3f;
        if ((lane == 5) && ((issue_index & 3) == 0)) begin
          mag = 63;
        end
        if ((lane == 9) && ((issue_index & 2) == 0)) begin
          mag = 0;
        end
        sign = ((seed >> 3) ^ issue_index ^ edge_id ^ (lane >> 1)) & 1;
        if (mag == 0) begin
          sign = 0;
        end
        value = sign ? -mag : mag;
        packed_value = value;
        if (use_lane1) begin
          issue_app1_canonical[lane*W_APP +: W_APP] = packed_value;
        end else begin
          issue_app0_canonical[lane*W_APP +: W_APP] = packed_value;
        end
        ref_insert_lane(lane, mag, edge_id, sign);
      end
    end
  endtask

  task automatic compare_close_to_ref(input string name, input int layer_id, input int epoch);
    int lane;
    begin
      check_bit({name, ".close_valid"}, layer_close_valid, 1'b1);
      check_int({name, ".layer_id"}, layer_close_layer_id, layer_id);
      check_int({name, ".epoch"}, layer_close_iteration_epoch, epoch);
      for (lane = 0; lane < P_VAL; lane++) begin
        check_int({name, ".m1"}, close_m1(lane), beta_offset(ref_min1[lane]));
        check_int({name, ".m2"}, close_m2(lane), beta_offset(ref_min2[lane]));
        check_int({name, ".imin"}, close_imin(lane), ref_imin[lane]);
        check_bit({name, ".sign"}, layer_close_aggregate_sign[lane], ref_sign[lane][0]);
      end
      pipeline_checks++;
    end
  endtask

  task automatic run_min_update_directed;
    begin
      set_min_update_inputs(0, 0, 0, 0, 0, 1, 63, 17, 0, 0, 0, 0, 0);
      expect_min_update("first singleton 63", 1, 63, 0, 17, 0);

      set_min_update_inputs(0, 0, 0, 0, 0, 1, 63, 7, 1, 1, 63, 3, 0);
      expect_min_update("first pair 63 63", 2, 63, 63, 3, 1);

      set_min_update_inputs(2, 63, 63, 5, 1, 1, 63, 4, 0, 1, 63, 2, 1);
      expect_min_update("complete all 63 continuation", 4, 63, 63, 2, 0);

      set_min_update_inputs(0, 0, 0, 0, 0, 1, 12, 7, 0, 1, 12, 3, 0);
      expect_min_update("equal minima normal", 2, 12, 12, 3, 0);
      set_min_update_inputs(0, 0, 0, 0, 0, 1, 12, 3, 0, 1, 12, 7, 0);
      expect_min_update("equal minima reversed", 2, 12, 12, 3, 0);

      set_min_update_inputs(2, 12, 20, 7, 0, 1, 12, 3, 0, 0, 0, 0, 0);
      expect_min_update("later equal lower edge", 3, 12, 12, 3, 0);

      set_min_update_inputs(2, 5, 9, 4, 0, 1, 5, 8, 0, 0, 0, 0, 0);
      expect_min_update("duplicate min makes min2", 3, 5, 5, 4, 0);

      set_min_update_inputs(2, 10, 30, 4, 0, 1, 5, 8, 0, 0, 0, 0, 0);
      expect_min_update("unique new min", 3, 5, 10, 8, 0);
      set_min_update_inputs(2, 10, 30, 4, 0, 1, 20, 8, 0, 0, 0, 0, 0);
      expect_min_update("unique new second min", 3, 10, 20, 4, 0);

      set_min_update_inputs(1, 9, 0, 6, 0, 0, 4, 3, 1, 1, 11, 7, 1);
      expect_min_update("masked lane0", 2, 9, 11, 6, 1);
      set_min_update_inputs(1, 9, 0, 6, 0, 1, 4, 3, 1, 0, 11, 7, 1);
      expect_min_update("masked lane1", 2, 4, 9, 3, 1);

      set_min_update_inputs(0, 0, 0, 0, 0, 1, 4, 1, 1, 1, 7, 2, 1);
      expect_min_update("sign parity even", 2, 4, 7, 1, 0);
      set_min_update_inputs(0, 0, 0, 0, 0, 1, 4, 1, 1, 1, 7, 2, 0);
      expect_min_update("sign parity odd", 2, 4, 7, 1, 1);
    end
  endtask

  task automatic run_order_independence;
    int m0;
    int m1;
    int pair_index;
    int e0 [0:3];
    int e1 [0:3];
    int sign0;
    int sign1;
    int exp_min1;
    int exp_min2;
    int exp_imin;
    int out_min1_a;
    int out_min2_a;
    int out_imin_a;
    int out_sign_a;
    begin
      e0[0] = 0;  e1[0] = 1;
      e0[1] = 7;  e1[1] = 3;
      e0[2] = 31; e1[2] = 2;
      e0[3] = 12; e1[3] = 29;
      for (m0 = 0; m0 < 64; m0++) begin
        for (m1 = 0; m1 < 64; m1++) begin
          for (pair_index = 0; pair_index < 4; pair_index++) begin
            sign0 = (m0 ^ e0[pair_index]) & 1;
            sign1 = (m1 ^ e1[pair_index] ^ 1) & 1;
            set_min_update_inputs(0, 0, 0, 0, 0, 1, m0, e0[pair_index], sign0, 1, m1, e1[pair_index], sign1);
            out_min1_a = mu_min1_o;
            out_min2_a = mu_min2_o;
            out_imin_a = mu_imin_o;
            out_sign_a = mu_aggregate_o;

            set_min_update_inputs(0, 0, 0, 0, 0, 1, m1, e1[pair_index], sign1, 1, m0, e0[pair_index], sign0);
            check_int("order.min1", mu_min1_o, out_min1_a);
            check_int("order.min2", mu_min2_o, out_min2_a);
            check_int("order.imin", mu_imin_o, out_imin_a);
            check_int("order.sign", mu_aggregate_o, out_sign_a);
            check_int("order.count", mu_edge_count_o, 2);

            if (m0 < m1) begin
              exp_min1 = m0;
              exp_min2 = m1;
              exp_imin = e0[pair_index];
            end else if (m1 < m0) begin
              exp_min1 = m1;
              exp_min2 = m0;
              exp_imin = e1[pair_index];
            end else begin
              exp_min1 = m0;
              exp_min2 = m0;
              exp_imin = (e0[pair_index] < e1[pair_index]) ? e0[pair_index] : e1[pair_index];
            end
            check_int("order.expected_min1", mu_min1_o, exp_min1);
            check_int("order.expected_min2", mu_min2_o, exp_min2);
            check_int("order.expected_imin", mu_imin_o, exp_imin);
            order_independence_cases++;
          end
        end
      end
    end
  endtask

  task automatic run_single_close_case(input string name, input int mag0, input int mag1);
    int lane;
    begin
      reset_pipeline();
      clear_ref_layer();
      fill_app0_all(mag0);
      fill_app1_all(mag1);
      ref_insert_constant_edge(mag0, 4, 0);
      ref_insert_constant_edge(mag1, 9, 0);
      drive_issue(2'b11, 6, 0, 2, 1, 4, 9, 0, 3, 1, 2, 0, 0);
      tick();
      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      check_bit({name, ".no_pub_c0"}, q_write_valid, 1'b0);
      tick();
      check_bit({name, ".no_pub_c1"}, q_write_valid, 1'b0);
      tick();
      check_bit({name, ".no_pub_c2"}, q_write_valid, 1'b0);
      tick();
      check_bit({name, ".q_write"}, q_write_valid, 1'b1);
      check_int({name, ".q0"}, q_lane0(0), mag0);
      check_int({name, ".q1"}, q_lane1(0), mag1);
      check_int({name, ".qslot"}, q_write_qslot, 3);
      check_int({name, ".qsign_valid"}, qsign_write_valid, 2'b11);
      compare_close_to_ref(name, 6, 2);
      directed_cases++;
    end
  endtask

  task automatic run_beta_close_cases;
    begin
      run_single_close_case("beta 0 0", 0, 0);
      run_single_close_case("beta 0 1", 0, 1);
      run_single_close_case("beta 1 1", 1, 1);
      run_single_close_case("beta 1 2", 1, 2);
      run_single_close_case("beta 62 63", 62, 63);
      run_single_close_case("beta 63 63", 63, 63);
    end
  endtask

  task automatic run_end_to_end_arithmetic;
    int lane;
    int expected0_lane0;
    int expected1_lane0;
    logic signed [W_APP-1:0] packed_value;
    begin
      reset_pipeline();
      old_generation_valid = 1'b1;
      fill_old_state(5, 11, 3, 0, 0, 1);
      for (lane = 0; lane < P_VAL; lane++) begin
        packed_value = 20 + (lane % 10);
        issue_app0_canonical[lane*W_APP +: W_APP] = packed_value;
        packed_value = -20 + (lane % 6);
        issue_app1_canonical[lane*W_APP +: W_APP] = packed_value;
      end
      drive_issue(2'b11, 8, 0, 2, 1, 3, 7, 1, 4, 1, 3, 5, 5);
      tick();
      issue_valid = 1'b0;
      tick();
      tick();
      tick();
      expected0_lane0 = sat8((20 + 5) - 11);
      expected1_lane0 = sat8((-20 + 5) - (-5));
      check_bit("e2e.q_write", q_write_valid, 1'b1);
      check_int("e2e.q0 lane0", q_lane0(0), expected0_lane0);
      check_int("e2e.q1 lane0", q_lane1(0), expected1_lane0);
      check_bit("e2e.qsign0 lane0", qsign_write_lane0[0], (expected0_lane0 < 0));
      check_bit("e2e.qsign1 lane0", qsign_write_lane1[0], (expected1_lane0 < 0));
      check_bit("e2e.close", layer_close_valid, 1'b1);
      pipeline_checks++;

      reset_pipeline();
      old_generation_valid = 1'b0;
      fill_old_state(63, 63, 0, 1, 1, 1);
      fill_app0_all(-128);
      fill_app1_all(0);
      drive_issue(2'b11, 9, 0, 2, 1, 1, 2, 0, 5, 0, 4, 0, 0);
      tick();
      issue_valid = 1'b0;
      tick();
      tick();
      tick();
      check_int("e2e.invalid_old_zero q0", q_lane0(0), -128);
      check_int("e2e.invalid_old_zero q1", q_lane1(0), 0);
      check_bit("e2e.minus128 sign", qsign_write_lane0[0], 1'b1);
      check_int("e2e.minus128 m1", close_m1(0), 0);
      check_int("e2e.minus128 m2", close_m2(0), 62);
      pipeline_checks++;
    end
  endtask

  task automatic run_edge_count_tests;
    begin
      reset_pipeline();
      fill_app0_all(4);
      fill_app1_all(9);
      drive_issue(2'b11, 12, 0, 3, 1, 0, 1, 0, 0, 1, 1, 0, 0);
      tick();
      fill_app0_all(5);
      fill_app1_all(0);
      drive_issue(2'b01, 12, 0, 3, 0, 2, 0, 0, 1, 1, 1, 0, 0);
      tick();
      issue_valid = 1'b0;
      tick();
      check_bit("edge_count.no_close_after_two", layer_close_valid, 1'b0);
      tick();
      tick();
      check_bit("edge_count.close_exact", layer_close_valid, 1'b1);
      check_bit("edge_count.no_error", error_valid, 1'b0);
      directed_cases++;

      reset_pipeline();
      fill_app0_all(4);
      fill_app1_all(9);
      drive_issue(2'b11, 13, 0, 3, 1, 0, 1, 0, 0, 1, 1, 0, 0);
      tick();
      fill_app0_all(5);
      fill_app1_all(6);
      drive_issue(2'b11, 13, 0, 3, 0, 2, 3, 0, 1, 1, 1, 0, 0);
      tick();
      issue_valid = 1'b0;
      tick();
      tick();
      tick();
      check_bit("edge_count.exceed_error", error_valid, 1'b1);
      check_bit("edge_count.exceed_no_close", layer_close_valid, 1'b0);
      directed_cases++;
    end
  endtask

  task automatic run_context_overlap_reuse;
    begin
      reset_pipeline();
      fill_app0_all(3);
      fill_app1_all(4);
      drive_issue(2'b11, 20, 0, 4, 1, 0, 1, 0, 0, 1, 1, 0, 0);
      tick();
      fill_app0_all(5);
      fill_app1_all(6);
      drive_issue(2'b11, 21, 1, 4, 1, 0, 1, 1, 0, 1, 1, 0, 0);
      tick();
      fill_app0_all(7);
      fill_app1_all(8);
      drive_issue(2'b11, 20, 0, 4, 0, 2, 3, 0, 1, 1, 1, 0, 0);
      tick();
      fill_app0_all(9);
      fill_app1_all(10);
      drive_issue(2'b11, 21, 1, 4, 0, 2, 3, 1, 1, 1, 1, 0, 0);
      tick();
      issue_valid = 1'b0;
      tick();
      tick();
      check_bit("overlap.close0", layer_close_valid, 1'b1);
      check_int("overlap.layer0", layer_close_layer_id, 20);
      tick();
      check_bit("overlap.close1", layer_close_valid, 1'b1);
      check_int("overlap.layer1", layer_close_layer_id, 21);
      check_bit("overlap.no_error", error_valid, 1'b0);
      directed_cases++;

      reset_pipeline();
      fill_app0_all(2);
      fill_app1_all(3);
      drive_issue(2'b11, 22, 0, 2, 1, 0, 1, 0, 0, 1, 1, 0, 0);
      tick();
      issue_valid = 1'b0;
      tick();
      tick();
      tick();
      check_bit("reuse.first_close", layer_close_valid, 1'b1);
      fill_app0_all(4);
      fill_app1_all(5);
      drive_issue(2'b11, 23, 0, 2, 1, 0, 1, 0, 1, 1, 1, 0, 0);
      tick();
      issue_valid = 1'b0;
      tick();
      tick();
      tick();
      check_bit("reuse.second_close", layer_close_valid, 1'b1);
      check_int("reuse.second_layer", layer_close_layer_id, 23);
      check_bit("reuse.no_error", error_valid, 1'b0);
      directed_cases++;
    end
  endtask

  task automatic run_stateful_all63_context;
    begin
      reset_pipeline();
      old_generation_valid = 1'b0;
      clear_ref_layer();

      fill_app0_all(63);
      fill_app1_all(63);
      ref_insert_constant_edge(63, 6, 0);
      ref_insert_constant_edge(63, 3, 0);
      drive_issue(2'b11, 24, 0, 7, 1, 6, 3, 0, 0, 1, 8, 0, 0);
      tick();

      fill_app0_all(63);
      fill_app1_all(63);
      ref_insert_constant_edge(63, 5, 0);
      ref_insert_constant_edge(63, 1, 0);
      drive_issue(2'b11, 24, 0, 7, 0, 5, 1, 0, 1, 1, 8, 0, 0);
      tick();

      fill_app0_all(63);
      fill_app1_all(63);
      ref_insert_constant_edge(63, 4, 0);
      ref_insert_constant_edge(63, 2, 0);
      drive_issue(2'b11, 24, 0, 7, 0, 4, 2, 0, 2, 1, 8, 0, 0);
      tick();

      fill_app0_all(63);
      fill_app1_all(0);
      ref_insert_constant_edge(63, 0, 0);
      drive_issue(2'b01, 24, 0, 7, 0, 0, 0, 0, 3, 1, 8, 0, 0);
      tick();

      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      tick();
      tick();
      tick();
      compare_close_to_ref("all63_context_degree7", 24, 8);
      check_int("all63_context.m1_offset", close_m1(0), 62);
      check_int("all63_context.m2_offset", close_m2(0), 62);
      check_int("all63_context.imin", close_imin(0), 0);
      check_bit("all63_context.no_error", error_valid, 1'b0);
      directed_cases++;
    end
  endtask

  task automatic run_old_state_response_alignment;
    begin
      reset_pipeline();
      old_generation_valid = 1'b1;

      fill_app0_all(20);
      fill_app1_all(21);
      drive_issue(2'b11, 40, 0, 2, 1, 2, 3, 0, 1, 1, 7, 0, 0);
      tick();
      check_bit("align.reqA.valid", old_state_req_valid, 1'b1);
      check_int("align.reqA.mask", old_state_req_lane_mask, 2'b11);
      check_int("align.reqA.layer", old_state_req_layer_id, 40);
      check_int("align.reqA.edge0", old_state_req_edge0_id, 2);
      check_int("align.reqA.edge1", old_state_req_edge1_id, 3);
      check_int("align.reqA.epoch", old_state_req_iteration_epoch, 7);

      fill_old_state(5, 5, 0, 0, 0, 0);
      fill_app0_all(30);
      fill_app1_all(31);
      drive_issue(2'b11, 41, 1, 2, 1, 4, 5, 1, 2, 1, 7, 0, 0);
      tick();
      check_bit("align.reqB.valid", old_state_req_valid, 1'b1);
      check_int("align.reqB.mask", old_state_req_lane_mask, 2'b11);
      check_int("align.reqB.layer", old_state_req_layer_id, 41);
      check_int("align.reqB.edge0", old_state_req_edge0_id, 4);
      check_int("align.reqB.edge1", old_state_req_edge1_id, 5);
      check_int("align.reqB.epoch", old_state_req_iteration_epoch, 7);

      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      tick();
      fill_old_state(12, 12, 0, 0, 0, 0);
      tick();
      check_bit("align.pubA.q_write", q_write_valid, 1'b1);
      check_int("align.pubA.layer", q_write_layer_id, 40);
      check_int("align.pubA.qslot", q_write_qslot, 1);
      check_int("align.pubA.q0", q_lane0(0), 15);
      check_int("align.pubA.q1", q_lane1(0), 16);

      tick();
      check_bit("align.pubB.q_write", q_write_valid, 1'b1);
      check_int("align.pubB.layer", q_write_layer_id, 41);
      check_int("align.pubB.qslot", q_write_qslot, 2);
      check_int("align.pubB.q0", q_lane0(0), 18);
      check_int("align.pubB.q1", q_lane1(0), 19);
      check_bit("align.no_error", error_valid, 1'b0);
      pipeline_checks++;
      directed_cases++;
    end
  endtask

  task automatic run_missing_old_state_response;
    begin
      reset_pipeline();
      old_generation_valid = 1'b0;
      old_state_resp_valid = 1'b1;
      fill_app0_all(10);
      fill_app1_all(11);
      drive_issue(2'b11, 50, 0, 2, 1, 0, 1, 0, 0, 1, 9, 0, 0);
      tick();
      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      old_state_resp_valid = 1'b0;
      tick();
      tick();
      old_state_resp_valid = 1'b1;
      tick();
      check_bit("missing_resp.error", error_valid, 1'b1);
      check_bit("missing_resp.no_q_write", q_write_valid, 1'b0);
      check_int("missing_resp.no_qsign", qsign_write_valid, 0);
      check_bit("missing_resp.no_close", layer_close_valid, 1'b0);

      fill_app0_all(7);
      fill_app1_all(8);
      drive_issue(2'b11, 51, 0, 2, 1, 0, 1, 0, 1, 1, 9, 0, 0);
      tick();
      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      tick();
      tick();
      tick();
      check_bit("missing_resp.reuse_close", layer_close_valid, 1'b1);
      check_int("missing_resp.reuse_layer", layer_close_layer_id, 51);
      check_bit("missing_resp.reuse_no_error", error_valid, 1'b0);
      pipeline_checks++;
      directed_cases++;
    end
  endtask

  task automatic run_random_layer(input int layer_id, input int position, input int degree, input int seed);
    int edge_idx;
    int issue_index;
    begin
      reset_pipeline();
      old_generation_valid = 1'b0;
      clear_ref_layer();
      issue_index = 0;
      for (edge_idx = 0; edge_idx < degree; edge_idx = edge_idx + 2) begin
        issue_app0_canonical = '0;
        issue_app1_canonical = '0;
        ref_insert_vector_from_app(edge_idx, 0, seed, issue_index);
        ref_count = ref_count + 1;
        if ((edge_idx + 1) < degree) begin
          ref_insert_vector_from_app(edge_idx + 1, 1, seed + 31, issue_index);
          ref_count = ref_count + 1;
          drive_issue(2'b11, layer_id, position, degree, (edge_idx == 0), edge_idx, edge_idx + 1, issue_index[0], issue_index, 1, 5, 0, 0);
        end else begin
          drive_issue(2'b01, layer_id, position, degree, (edge_idx == 0), edge_idx, 0, issue_index[0], issue_index, 1, 5, 0, 0);
        end
        tick();
        issue_index++;
      end
      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      tick();
      tick();
      tick();
      compare_close_to_ref("random_layer", layer_id, 5);
      check_bit("random_layer.no_error", error_valid, 1'b0);
      random_layer_cases++;
    end
  endtask

  task automatic drive_trace_issue(input int cycle);
    begin
      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      fill_app0_all(0);
      fill_app1_all(0);
      case (cycle)
        0:  drive_issue(2'b11, 1, 0, 19, 1, 0, 1, 0, 0, 1, 6, 0, 0);
        1:  drive_issue(2'b11, 3, 1, 19, 1, 14, 15, 1, 0, 1, 6, 0, 0);
        2:  drive_issue(2'b11, 1, 0, 19, 0, 2, 3, 0, 1, 1, 6, 0, 0);
        3:  drive_issue(2'b11, 3, 1, 19, 0, 1, 4, 1, 1, 1, 6, 0, 0);
        4:  drive_issue(2'b11, 1, 0, 19, 0, 4, 5, 0, 2, 1, 6, 0, 0);
        5:  drive_issue(2'b11, 3, 1, 19, 0, 7, 10, 1, 2, 1, 6, 0, 0);
        6:  drive_issue(2'b11, 1, 0, 19, 0, 6, 7, 0, 3, 1, 6, 0, 0);
        7:  drive_issue(2'b11, 1, 0, 19, 0, 8, 9, 0, 4, 1, 6, 0, 0);
        8:  drive_issue(2'b11, 1, 0, 19, 0, 10, 11, 0, 5, 1, 6, 0, 0);
        9:  drive_issue(2'b11, 1, 0, 19, 0, 12, 13, 0, 6, 1, 6, 0, 0);
        10: drive_issue(2'b11, 1, 0, 19, 0, 14, 15, 0, 7, 1, 6, 0, 0);
        11: drive_issue(2'b11, 1, 0, 19, 0, 16, 17, 0, 8, 1, 6, 0, 0);
        12: drive_issue(2'b01, 1, 0, 19, 0, 18, 0, 0, 9, 1, 6, 0, 0);
        13: drive_issue(2'b01, 3, 1, 19, 0, 18, 0, 1, 9, 1, 6, 0, 0);
        18: drive_issue(2'b11, 3, 1, 19, 0, 2, 3, 1, 3, 1, 6, 0, 0);
        19: drive_issue(2'b11, 3, 1, 19, 0, 8, 9, 1, 5, 1, 6, 0, 0);
        21: drive_issue(2'b11, 3, 1, 19, 0, 0, 13, 1, 8, 1, 6, 0, 0);
        22: drive_issue(2'b11, 2, 2, 19, 1, 2, 4, 0, 0, 1, 6, 0, 0);
        23: drive_issue(2'b11, 3, 1, 19, 0, 5, 6, 1, 4, 1, 6, 0, 0);
        24: drive_issue(2'b11, 2, 2, 19, 0, 8, 12, 0, 2, 1, 6, 0, 0);
        25: drive_issue(2'b11, 3, 1, 19, 0, 11, 12, 1, 6, 1, 6, 0, 0);
        26: drive_issue(2'b11, 3, 1, 19, 0, 16, 17, 1, 7, 1, 6, 0, 0);
        27: drive_issue(2'b11, 2, 2, 19, 0, 15, 17, 0, 1, 1, 6, 0, 0);
        34: drive_issue(2'b11, 2, 2, 19, 0, 9, 10, 0, 5, 1, 6, 0, 0);
        35: drive_issue(2'b11, 2, 2, 19, 0, 5, 6, 0, 4, 1, 6, 0, 0);
        36: drive_issue(2'b11, 2, 2, 19, 0, 0, 1, 0, 3, 1, 6, 0, 0);
        37: drive_issue(2'b11, 2, 2, 19, 0, 3, 7, 0, 8, 1, 6, 0, 0);
        38: drive_issue(2'b11, 0, 3, 19, 1, 12, 18, 1, 2, 1, 6, 0, 0);
        39: drive_issue(2'b11, 2, 2, 19, 0, 16, 18, 0, 7, 1, 6, 0, 0);
        40: drive_issue(2'b11, 0, 3, 19, 0, 8, 9, 1, 0, 1, 6, 0, 0);
        41: drive_issue(2'b11, 0, 3, 19, 0, 16, 17, 1, 1, 1, 6, 0, 0);
        42: drive_issue(2'b11, 2, 2, 19, 0, 13, 14, 0, 6, 1, 6, 0, 0);
        43: drive_issue(2'b01, 2, 2, 19, 0, 11, 0, 0, 9, 1, 6, 0, 0);
        44: drive_issue(2'b01, 0, 3, 19, 0, 3, 0, 1, 9, 1, 6, 0, 0);
        51: drive_issue(2'b11, 0, 3, 19, 0, 0, 1, 1, 3, 1, 6, 0, 0);
        52: drive_issue(2'b11, 0, 3, 19, 0, 6, 7, 1, 5, 1, 6, 0, 0);
        53: drive_issue(2'b11, 0, 3, 19, 0, 10, 11, 1, 6, 1, 6, 0, 0);
        54: drive_issue(2'b11, 0, 3, 19, 0, 4, 5, 1, 4, 1, 6, 0, 0);
        55: drive_issue(2'b11, 0, 3, 19, 0, 13, 14, 1, 7, 1, 6, 0, 0);
        56: drive_issue(2'b11, 0, 3, 19, 0, 2, 15, 1, 8, 1, 6, 0, 0);
        default: begin
          issue_valid = 1'b0;
          issue_lane_mask = 2'b00;
        end
      endcase

      if (issue_valid) begin
        high_rate_issue_count++;
        high_rate_edge_count += issue_lane_mask[0] + issue_lane_mask[1];
        if (issue_layer_position[0] != issue_layer_position % NUM_ACC_CONTEXTS) begin
          $display("FAIL trace context identity");
          errors++;
        end
        if (issue_qslot > high_rate_qslot_max) begin
          high_rate_qslot_max = issue_qslot;
        end
      end
    end
  endtask

  task automatic run_high_rate_trace;
    int cycle;
    int close_count;
    begin
      reset_pipeline();
      high_rate_issue_count = 0;
      high_rate_edge_count = 0;
      high_rate_qslot_max = 0;
      close_count = 0;
      old_generation_valid = 1'b0;
      for (cycle = 0; cycle <= 62; cycle++) begin
        drive_trace_issue(cycle);
        tick();
        if (q_write_valid) begin
          pipeline_checks++;
        end
        if (layer_close_valid) begin
          close_count++;
          if (cycle == 15) begin
            check_int("trace.close15.layer", layer_close_layer_id, 1);
          end else if (cycle == 29) begin
            check_int("trace.close29.layer", layer_close_layer_id, 3);
          end else if (cycle == 46) begin
            check_int("trace.close46.layer", layer_close_layer_id, 2);
          end else if (cycle == 59) begin
            check_int("trace.close59.layer", layer_close_layer_id, 0);
          end else begin
            $display("FAIL trace unexpected close cycle=%0d layer=%0d", cycle, layer_close_layer_id);
            errors++;
          end
        end
        if (error_valid) begin
          $display("FAIL trace unexpected context error cycle=%0d", cycle);
          errors++;
        end
      end
      check_int("trace.issue_cycles", high_rate_issue_count, 40);
      check_int("trace.active_edges", high_rate_edge_count, 76);
      check_int("trace.close_count", close_count, 4);
      check_int("trace.qslot_max", high_rate_qslot_max, 9);
      pipeline_checks++;
    end
  endtask

  initial begin
    int random_case;
    int selected_case;
    clk = 1'b0;
    rst = 1'b0;
    errors = 0;
    directed_cases = 0;
    order_independence_cases = 0;
    random_layer_cases = 0;
    pipeline_checks = 0;
    high_rate_issue_count = 0;
    high_rate_edge_count = 0;
    high_rate_qslot_max = 0;
    if (!$value$plusargs("phase4_case=%d", selected_case)) begin
      selected_case = 0;
    end

    if (!REDUCED_P_SIM && (P != 384 || B != 2 || D_A != 3 || NUM_ACC_CONTEXTS != 2)) begin
      $display("FAIL frozen Phase-4 constants");
      errors++;
    end

    case (selected_case)
      0: begin
        run_min_update_directed();
        run_beta_close_cases();
        run_end_to_end_arithmetic();
        run_edge_count_tests();
        run_context_overlap_reuse();
        run_stateful_all63_context();
        run_old_state_response_alignment();
        run_missing_old_state_response();
        for (random_case = 0; random_case < RANDOM_LAYER_SWEEP_CASES; random_case++) begin
          run_random_layer(
            30 + random_case,
            random_case & 1,
            (random_case % 3 == 0) ? 7 : ((random_case % 3 == 1) ? 13 : 19),
            97 + random_case * 29
          );
        end
        run_high_rate_trace();
      end
      1: run_min_update_directed();
      2: run_beta_close_cases();
      3: run_end_to_end_arithmetic();
      4: run_edge_count_tests();
      5: run_context_overlap_reuse();
      6: run_stateful_all63_context();
      7: run_old_state_response_alignment();
      8: run_missing_old_state_response();
      9: run_high_rate_trace();
      default: begin
        $display("FAIL unknown phase4_case=%0d", selected_case);
        errors++;
      end
    endcase;

    if (errors == 0) begin
      $display("PASS phase4 acc pipeline");
      $display("phase4_case=%0d", selected_case);
      $display("p_lanes=%0d reduced_p_sim=%0d", P_VAL, REDUCED_P_SIM);
      $display(
        "directed_cases=%0d order_independence_cases=%0d random_layers=%0d pipeline_checks=%0d high_rate_acc_issue_cycles=%0d high_rate_active_edges=%0d",
        directed_cases,
        order_independence_cases,
        random_layer_cases,
        pipeline_checks,
        high_rate_issue_count,
        high_rate_edge_count
      );
      $finish;
    end else begin
      $display("FAIL phase4 acc pipeline errors=%0d", errors);
      $finish(1);
    end
  end
endmodule
