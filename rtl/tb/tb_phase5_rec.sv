`timescale 1ns/1ps

module tb_phase5_rec;
  import nr_ldpc_pkg::*;

`ifdef PHASE5_REDUCED_P
  localparam int P_VAL = `PHASE5_REDUCED_P;
  localparam bit REDUCED_P_SIM = 1'b1;
`else
  localparam int P_VAL = REFERENCE_Z;
  localparam bit REDUCED_P_SIM = 1'b0;
`endif
  localparam int SHIFT_W = $clog2(P_VAL + 1);

  logic clk;
  logic rst;

  logic issue_valid;
  logic issue_ready;
  logic [1:0] issue_lane_mask;
  logic [5:0] issue_layer_id;
  logic [4:0] issue_edge0_id;
  logic [4:0] issue_edge1_id;
  logic [0:0] issue_qbuf;
  logic [3:0] issue_qslot;
  logic issue_target_generation;
  logic [3:0] issue_iteration_epoch;
  logic [SHIFT_W-1:0] issue_shift0;
  logic [SHIFT_W-1:0] issue_shift1;
  logic [6:0] issue_base_column0;
  logic [6:0] issue_base_column1;
  logic [3:0] issue_aux0;
  logic [3:0] issue_aux1;
  logic issue_final_touch0;
  logic issue_final_touch1;

  logic new_state_resp_valid;
  logic new_state_valid;
  logic new_state_closed;
  logic [5:0] new_state_layer_id;
  logic new_state_generation;
  logic [3:0] new_state_iteration_epoch;
  logic [P_VAL*W_M-1:0] new_m1;
  logic [P_VAL*W_M-1:0] new_m2;
  logic [P_VAL*5-1:0] new_imin;
  logic [P_VAL-1:0] new_aggregate_sign;
  logic [P_VAL-1:0] new_qsign0;
  logic [P_VAL-1:0] new_qsign1;

  logic q_req_valid;
  logic [0:0] q_req_qbuf;
  logic [3:0] q_req_qslot;
  logic [1:0] q_req_lane_mask;
  logic [5:0] q_req_layer_id;
  logic [3:0] q_req_iteration_epoch;

  logic q_resp_valid;
  logic [0:0] q_resp_qbuf;
  logic [3:0] q_resp_qslot;
  logic [1:0] q_resp_lane_mask;
  logic [5:0] q_resp_layer_id;
  logic [3:0] q_resp_iteration_epoch;
  logic [P_VAL*W_Q-1:0] q_resp_lane0;
  logic [P_VAL*W_Q-1:0] q_resp_lane1;

  logic [1:0] app_write_valid;
  logic [P_VAL*W_APP-1:0] app_write_lane0;
  logic [P_VAL*W_APP-1:0] app_write_lane1;
  logic [6:0] app_write_base_column0;
  logic [6:0] app_write_base_column1;
  logic [1:0] app_write_lane_mask;
  logic [5:0] app_write_layer_id;
  logic [4:0] app_write_edge0_id;
  logic [4:0] app_write_edge1_id;
  logic [3:0] app_write_iteration_epoch;
  logic [0:0] app_write_qbuf;
  logic [3:0] app_write_qslot;
  logic [3:0] app_write_aux0;
  logic [3:0] app_write_aux1;
  logic app_write_final_touch0;
  logic app_write_final_touch1;

  logic [1:0] forward_valid;
  logic [2:0] forward_slot0;
  logic [2:0] forward_slot1;
  logic [6:0] forward_base_column0;
  logic [6:0] forward_base_column1;
  logic [3:0] forward_iteration_epoch;
  logic [P_VAL*W_APP-1:0] forward_app0;
  logic [P_VAL*W_APP-1:0] forward_app1;

  logic [1:0] final_touch_valid;
  logic [6:0] final_touch_base_column0;
  logic [6:0] final_touch_base_column1;
  logic [5:0] final_touch_layer_id;
  logic [4:0] final_touch_edge0_id;
  logic [4:0] final_touch_edge1_id;
  logic [3:0] final_touch_iteration_epoch;
  logic [P_VAL*W_APP-1:0] final_touch_app0;
  logic [P_VAL*W_APP-1:0] final_touch_app1;
  logic [P_VAL-1:0] final_touch_hard0;
  logic [P_VAL-1:0] final_touch_hard1;
  logic error_valid;

  int errors;
  int directed_cases;
  int alignment_cases;
  int high_rate_issue_count;
  int high_rate_edge_count;
  int high_rate_publication_count;

  nr_ldpc_rec_pipeline #(
    .P(P_VAL)
  ) u_rec (
    .clk_i(clk),
    .rst_i(rst),
    .issue_valid_i(issue_valid),
    .issue_ready_o(issue_ready),
    .issue_lane_mask_i(issue_lane_mask),
    .issue_layer_id_i(issue_layer_id),
    .issue_edge0_id_i(issue_edge0_id),
    .issue_edge1_id_i(issue_edge1_id),
    .issue_qbuf_i(issue_qbuf),
    .issue_qslot_i(issue_qslot),
    .issue_target_generation_i(issue_target_generation),
    .issue_iteration_epoch_i(issue_iteration_epoch),
    .issue_shift0_i(issue_shift0),
    .issue_shift1_i(issue_shift1),
    .issue_base_column0_i(issue_base_column0),
    .issue_base_column1_i(issue_base_column1),
    .issue_aux0_i(issue_aux0),
    .issue_aux1_i(issue_aux1),
    .issue_final_touch0_i(issue_final_touch0),
    .issue_final_touch1_i(issue_final_touch1),
    .new_state_resp_valid_i(new_state_resp_valid),
    .new_state_valid_i(new_state_valid),
    .new_state_closed_i(new_state_closed),
    .new_state_layer_id_i(new_state_layer_id),
    .new_state_generation_i(new_state_generation),
    .new_state_iteration_epoch_i(new_state_iteration_epoch),
    .new_m1_i(new_m1),
    .new_m2_i(new_m2),
    .new_imin_i(new_imin),
    .new_aggregate_sign_i(new_aggregate_sign),
    .new_qsign0_i(new_qsign0),
    .new_qsign1_i(new_qsign1),
    .q_req_valid_o(q_req_valid),
    .q_req_qbuf_o(q_req_qbuf),
    .q_req_qslot_o(q_req_qslot),
    .q_req_lane_mask_o(q_req_lane_mask),
    .q_req_layer_id_o(q_req_layer_id),
    .q_req_iteration_epoch_o(q_req_iteration_epoch),
    .q_resp_valid_i(q_resp_valid),
    .q_resp_qbuf_i(q_resp_qbuf),
    .q_resp_qslot_i(q_resp_qslot),
    .q_resp_lane_mask_i(q_resp_lane_mask),
    .q_resp_layer_id_i(q_resp_layer_id),
    .q_resp_iteration_epoch_i(q_resp_iteration_epoch),
    .q_resp_lane0_i(q_resp_lane0),
    .q_resp_lane1_i(q_resp_lane1),
    .app_write_valid_o(app_write_valid),
    .app_write_lane0_o(app_write_lane0),
    .app_write_lane1_o(app_write_lane1),
    .app_write_base_column0_o(app_write_base_column0),
    .app_write_base_column1_o(app_write_base_column1),
    .app_write_lane_mask_o(app_write_lane_mask),
    .app_write_layer_id_o(app_write_layer_id),
    .app_write_edge0_id_o(app_write_edge0_id),
    .app_write_edge1_id_o(app_write_edge1_id),
    .app_write_iteration_epoch_o(app_write_iteration_epoch),
    .app_write_qbuf_o(app_write_qbuf),
    .app_write_qslot_o(app_write_qslot),
    .app_write_aux0_o(app_write_aux0),
    .app_write_aux1_o(app_write_aux1),
    .app_write_final_touch0_o(app_write_final_touch0),
    .app_write_final_touch1_o(app_write_final_touch1),
    .forward_valid_o(forward_valid),
    .forward_slot0_o(forward_slot0),
    .forward_slot1_o(forward_slot1),
    .forward_base_column0_o(forward_base_column0),
    .forward_base_column1_o(forward_base_column1),
    .forward_iteration_epoch_o(forward_iteration_epoch),
    .forward_app0_o(forward_app0),
    .forward_app1_o(forward_app1),
    .final_touch_valid_o(final_touch_valid),
    .final_touch_base_column0_o(final_touch_base_column0),
    .final_touch_base_column1_o(final_touch_base_column1),
    .final_touch_layer_id_o(final_touch_layer_id),
    .final_touch_edge0_id_o(final_touch_edge0_id),
    .final_touch_edge1_id_o(final_touch_edge1_id),
    .final_touch_iteration_epoch_o(final_touch_iteration_epoch),
    .final_touch_app0_o(final_touch_app0),
    .final_touch_app1_o(final_touch_app1),
    .final_touch_hard0_o(final_touch_hard0),
    .final_touch_hard1_o(final_touch_hard1),
    .error_valid_o(error_valid)
  );

  task automatic tick;
    begin
      #5;
      clk = 1'b1;
      #1;
      clk = 1'b0;
      #4;
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

  task automatic check_bit(input string name, input logic actual, input logic expected);
    begin
      if (actual !== expected) begin
        $display("FAIL %s actual=%0b expected=%0b", name, actual, expected);
        errors++;
      end
    end
  endtask

  function automatic int signed app0(input int lane);
    logic signed [W_APP-1:0] value;
    begin
      value = app_write_lane0[lane*W_APP +: W_APP];
      app0 = value;
    end
  endfunction

  function automatic int signed app1(input int lane);
    logic signed [W_APP-1:0] value;
    begin
      value = app_write_lane1[lane*W_APP +: W_APP];
      app1 = value;
    end
  endfunction

  task automatic clear_inputs;
    begin
      issue_valid = 1'b0;
      issue_lane_mask = 2'b00;
      issue_layer_id = 6'd0;
      issue_edge0_id = 5'd0;
      issue_edge1_id = 5'd0;
      issue_qbuf = 1'b0;
      issue_qslot = 4'd0;
      issue_target_generation = 1'b1;
      issue_iteration_epoch = 4'd0;
      issue_shift0 = '0;
      issue_shift1 = '0;
      issue_base_column0 = 7'd0;
      issue_base_column1 = 7'd0;
      issue_aux0 = 4'd0;
      issue_aux1 = 4'd0;
      issue_final_touch0 = 1'b0;
      issue_final_touch1 = 1'b0;
      new_state_resp_valid = 1'b0;
      new_state_valid = 1'b0;
      new_state_closed = 1'b0;
      new_state_layer_id = 6'd0;
      new_state_generation = 1'b1;
      new_state_iteration_epoch = 4'd0;
      new_m1 = '0;
      new_m2 = '0;
      new_imin = '0;
      new_aggregate_sign = '0;
      new_qsign0 = '0;
      new_qsign1 = '0;
      q_resp_valid = 1'b0;
      q_resp_qbuf = 1'b0;
      q_resp_qslot = 4'd0;
      q_resp_lane_mask = 2'b00;
      q_resp_layer_id = 6'd0;
      q_resp_iteration_epoch = 4'd0;
      q_resp_lane0 = '0;
      q_resp_lane1 = '0;
    end
  endtask

  task automatic reset_pipeline;
    begin
      clear_inputs();
      rst = 1'b1;
      tick();
      tick();
      rst = 1'b0;
      tick();
    end
  endtask

  task automatic fill_state_all(
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
        new_m1[lane*W_M +: W_M] = m1[W_M-1:0];
        new_m2[lane*W_M +: W_M] = m2[W_M-1:0];
        new_imin[lane*5 +: 5] = imin[4:0];
        new_aggregate_sign[lane] = aggregate[0];
        new_qsign0[lane] = qsign0[0];
        new_qsign1[lane] = qsign1[0];
      end
    end
  endtask

  task automatic fill_q_all(input int lane0_value, input int lane1_value);
    int lane;
    logic signed [W_Q-1:0] q0;
    logic signed [W_Q-1:0] q1;
    begin
      q0 = lane0_value;
      q1 = lane1_value;
      for (lane = 0; lane < P_VAL; lane++) begin
        q_resp_lane0[lane*W_Q +: W_Q] = q0;
        q_resp_lane1[lane*W_Q +: W_Q] = q1;
      end
    end
  endtask

  task automatic set_q0_lane(input int lane, input int value);
    logic signed [W_Q-1:0] q;
    begin
      q = value;
      q_resp_lane0[lane*W_Q +: W_Q] = q;
    end
  endtask

  task automatic set_q1_lane(input int lane, input int value);
    logic signed [W_Q-1:0] q;
    begin
      q = value;
      q_resp_lane1[lane*W_Q +: W_Q] = q;
    end
  endtask

  task automatic drive_issue(
    input int lane_mask,
    input int layer,
    input int edge0,
    input int edge1,
    input int qbuf,
    input int qslot,
    input int epoch,
    input int shift0,
    input int shift1,
    input int column0,
    input int column1,
    input int aux0,
    input int aux1,
    input int final0,
    input int final1
  );
    begin
      issue_valid = 1'b1;
      issue_lane_mask = lane_mask[1:0];
      issue_layer_id = layer[5:0];
      issue_edge0_id = edge0[4:0];
      issue_edge1_id = edge1[4:0];
      issue_qbuf = qbuf[0];
      issue_qslot = qslot[3:0];
      issue_target_generation = 1'b1;
      issue_iteration_epoch = epoch[3:0];
      issue_shift0 = shift0[SHIFT_W-1:0];
      issue_shift1 = shift1[SHIFT_W-1:0];
      issue_base_column0 = column0[6:0];
      issue_base_column1 = column1[6:0];
      issue_aux0 = aux0[3:0];
      issue_aux1 = aux1[3:0];
      issue_final_touch0 = final0[0];
      issue_final_touch1 = final1[0];
    end
  endtask

  task automatic drive_state_for_issue(
    input int layer,
    input int epoch,
    input int valid,
    input int closed
  );
    begin
      new_state_resp_valid = 1'b1;
      new_state_valid = valid[0];
      new_state_closed = closed[0];
      new_state_layer_id = layer[5:0];
      new_state_generation = 1'b1;
      new_state_iteration_epoch = epoch[3:0];
    end
  endtask

  task automatic drive_q_for_issue(
    input int lane_mask,
    input int layer,
    input int qbuf,
    input int qslot,
    input int epoch,
    input int valid
  );
    begin
      q_resp_valid = valid[0];
      q_resp_lane_mask = lane_mask[1:0];
      q_resp_layer_id = layer[5:0];
      q_resp_qbuf = qbuf[0];
      q_resp_qslot = qslot[3:0];
      q_resp_iteration_epoch = epoch[3:0];
    end
  endtask

  task automatic check_q_req(
    input string name,
    input int lane_mask,
    input int layer,
    input int qbuf,
    input int qslot,
    input int epoch
  );
    begin
      check_bit({name, ".q_req_valid"}, q_req_valid, 1'b1);
      check_int({name, ".q_req_mask"}, q_req_lane_mask, lane_mask);
      check_int({name, ".q_req_layer"}, q_req_layer_id, layer);
      check_int({name, ".q_req_qbuf"}, q_req_qbuf, qbuf);
      check_int({name, ".q_req_qslot"}, q_req_qslot, qslot);
      check_int({name, ".q_req_epoch"}, q_req_iteration_epoch, epoch);
    end
  endtask

  task automatic check_common_pub(
    input string name,
    input int lane_mask,
    input int layer,
    input int edge0,
    input int edge1,
    input int qbuf,
    input int qslot,
    input int epoch,
    input int column0,
    input int column1
  );
    begin
      check_int({name, ".valid_mask"}, app_write_valid, lane_mask);
      check_int({name, ".lane_mask"}, app_write_lane_mask, lane_mask);
      check_int({name, ".layer"}, app_write_layer_id, layer);
      check_int({name, ".edge0"}, app_write_edge0_id, edge0);
      check_int({name, ".edge1"}, app_write_edge1_id, edge1);
      check_int({name, ".qbuf"}, app_write_qbuf, qbuf);
      check_int({name, ".qslot"}, app_write_qslot, qslot);
      check_int({name, ".epoch"}, app_write_iteration_epoch, epoch);
      check_int({name, ".column0"}, app_write_base_column0, column0);
      check_int({name, ".column1"}, app_write_base_column1, column1);
      check_bit({name, ".no_error"}, error_valid, 1'b0);
    end
  endtask

  task automatic check_no_publication(input string name);
    begin
      check_int({name, ".no_app"}, app_write_valid, 0);
      check_int({name, ".no_forward"}, forward_valid, 0);
      check_int({name, ".no_final"}, final_touch_valid, 0);
    end
  endtask

  task automatic run_const_case(
    input string name,
    input int lane_mask,
    input int layer,
    input int edge0,
    input int edge1,
    input int qbuf,
    input int qslot,
    input int shift0,
    input int shift1,
    input int column0,
    input int column1,
    input int aux0,
    input int aux1,
    input int final0,
    input int final1,
    input int m1,
    input int m2,
    input int imin,
    input int aggregate,
    input int qsign0,
    input int qsign1,
    input int q0,
    input int q1,
    input int expected0,
    input int expected1
  );
    begin
      reset_pipeline();
      fill_state_all(m1, m2, imin, aggregate, qsign0, qsign1);
      fill_q_all(q0, q1);
      drive_issue(lane_mask, layer, edge0, edge1, qbuf, qslot, 4, shift0, shift1, column0, column1, aux0, aux1, final0, final1);
      tick();
      check_q_req(name, lane_mask, layer, qbuf, qslot, 4);
      issue_valid = 1'b0;
      drive_state_for_issue(layer, 4, 1, 1);
      tick();
      drive_q_for_issue(lane_mask, layer, qbuf, qslot, 4, 1);
      tick();
      q_resp_valid = 1'b0;
      tick();
      check_common_pub(name, lane_mask, layer, edge0, edge1, qbuf, qslot, 4, column0, column1);
      if (lane_mask[0]) begin
        check_int({name, ".app0_lane0"}, app0(0), expected0);
      end
      if (lane_mask[1]) begin
        check_int({name, ".app1_lane0"}, app1(0), expected1);
      end
      directed_cases++;
    end
  endtask

  task automatic run_shift_case(input string name, input int shift, input int expected_lane, input int value);
    begin
      reset_pipeline();
      fill_state_all(0, 0, 7, 0, 0, 0);
      fill_q_all(0, 0);
      set_q0_lane(0, value);
      drive_issue(2'b01, 5, 2, 0, 0, 2, 4, shift, 0, 9, 0, 0, 0, 0, 0);
      tick();
      check_q_req(name, 1, 5, 0, 2, 4);
      issue_valid = 1'b0;
      drive_state_for_issue(5, 4, 1, 1);
      tick();
      drive_q_for_issue(1, 5, 0, 2, 4, 1);
      tick();
      q_resp_valid = 1'b0;
      tick();
      check_common_pub(name, 1, 5, 2, 0, 0, 2, 4, 9, 0);
      check_int({name, ".expected_lane"}, app0(expected_lane), value);
      directed_cases++;
    end
  endtask

  task automatic run_error_case(input string name, input int error_kind);
    begin
      reset_pipeline();
      fill_state_all(3, 0, 7, 0, 0, 0);
      fill_q_all(4, 0);
      drive_issue(2'b01, 6, 1, 0, 0, 3, 4, (error_kind == 4) ? P_VAL : 0, 0, 7, 0, 0, 0, 0, 0);
      tick();
      check_q_req(name, 1, 6, 0, 3, 4);
      issue_valid = 1'b0;
      if (error_kind == 3) begin
        drive_state_for_issue(7, 4, 1, 1);
      end else begin
        drive_state_for_issue(6, 4, (error_kind == 3) ? 0 : 1, 1);
      end
      tick();
      if (error_kind == 1) begin
        drive_q_for_issue(1, 6, 0, 3, 4, 0);
      end else if (error_kind == 2) begin
        drive_q_for_issue(1, 6, 0, 4, 4, 1);
      end else begin
        drive_q_for_issue(1, 6, 0, 3, 4, 1);
      end
      tick();
      q_resp_valid = 1'b0;
      tick();
      check_bit({name, ".error"}, error_valid, 1'b1);
      check_no_publication(name);
      directed_cases++;
    end
  endtask

  task automatic run_zero_lane_error;
    begin
      reset_pipeline();
      fill_state_all(5, 0, 7, 0, 0, 0);
      fill_q_all(6, 0);
      drive_issue(2'b00, 6, 1, 0, 0, 3, 4, 0, 0, 7, 0, 0, 0, 0, 0);
      tick();
      check_q_req("zero_lane", 0, 6, 0, 3, 4);
      issue_valid = 1'b0;
      drive_state_for_issue(6, 4, 1, 1);
      tick();
      drive_q_for_issue(0, 6, 0, 3, 4, 1);
      tick();
      q_resp_valid = 1'b0;
      tick();
      check_bit("zero_lane.error", error_valid, 1'b1);
      check_no_publication("zero_lane");
      directed_cases++;
    end
  endtask

  task automatic run_missing_state_response_error;
    begin
      reset_pipeline();
      fill_state_all(5, 0, 7, 0, 0, 0);
      fill_q_all(6, 0);
      drive_issue(2'b01, 6, 1, 0, 0, 3, 4, 0, 0, 7, 0, 0, 0, 0, 0);
      tick();
      check_q_req("missing_state_resp", 1, 6, 0, 3, 4);
      issue_valid = 1'b0;
      new_state_resp_valid = 1'b0;
      tick();
      drive_q_for_issue(1, 6, 0, 3, 4, 1);
      tick();
      q_resp_valid = 1'b0;
      tick();
      check_bit("missing_state_resp.error", error_valid, 1'b1);
      check_no_publication("missing_state_resp");
      directed_cases++;
    end
  endtask

  task automatic run_directed_tests;
    begin
      run_const_case("ordinary_non_imin", 1, 2, 3, 0, 0, 1, 0, 0, 5, 0, 0, 0, 0, 0, 22, 31, 7, 0, 0, 0, 0, 0, 22, 0);
      run_const_case("imin_selects_m2", 1, 2, 3, 0, 0, 1, 0, 0, 5, 0, 0, 0, 0, 0, 22, 31, 3, 0, 0, 0, 0, 0, 31, 0);
      run_const_case("aggregate_xor_negative", 1, 2, 3, 0, 0, 1, 0, 0, 5, 0, 0, 0, 0, 0, 12, 0, 7, 1, 0, 0, 0, 0, -12, 0);
      run_const_case("zero_negative_suppression", 1, 2, 3, 0, 0, 1, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 7, 1, 0, 0, 0, 0, 0, 0);
      run_const_case("plus_minus_63", 3, 2, 3, 4, 0, 1, 0, 0, 5, 6, 0, 0, 0, 0, 63, 0, 7, 0, 0, 1, 0, 0, 63, -63);
      run_const_case("positive_saturation", 1, 2, 3, 0, 0, 1, 0, 0, 5, 0, 0, 0, 0, 0, 63, 0, 7, 0, 0, 0, 100, 0, 127, 0);
      run_const_case("negative_saturation", 1, 2, 3, 0, 0, 1, 0, 0, 5, 0, 0, 0, 0, 0, 63, 0, 7, 1, 0, 0, -100, 0, -128, 0);
      run_shift_case("inverse_shift0", 0, 0, 55);
      run_shift_case("inverse_shift1", 1, 1, 56);
      run_shift_case("inverse_shift383", P_VAL - 1, P_VAL - 1, 57);

      reset_pipeline();
      fill_state_all(0, 0, 7, 0, 0, 0);
      fill_q_all(0, 0);
      set_q0_lane(0, 10);
      set_q1_lane(0, 20);
      drive_issue(3, 5, 2, 3, 0, 2, 4, 1, P_VAL - 1, 9, 10, 0, 0, 0, 0);
      tick();
      check_q_req("b2_different_shifts", 3, 5, 0, 2, 4);
      issue_valid = 1'b0;
      drive_state_for_issue(5, 4, 1, 1);
      tick();
      drive_q_for_issue(3, 5, 0, 2, 4, 1);
      tick();
      q_resp_valid = 1'b0;
      tick();
      check_common_pub("b2_different_shifts", 3, 5, 2, 3, 0, 2, 4, 9, 10);
      check_int("b2_different_shifts.app0_lane1", app0(1), 10);
      check_int("b2_different_shifts.app1_last_lane", app1(P_VAL - 1), 20);
      directed_cases++;

      run_const_case("singleton_lane0", 1, 2, 3, 0, 0, 1, 0, 0, 5, 0, 0, 0, 0, 0, 9, 0, 7, 0, 0, 0, 1, 0, 10, 0);
      run_const_case("aux0_no_forward", 1, 2, 3, 0, 0, 1, 0, 0, 5, 0, 0, 0, 0, 0, 9, 0, 7, 0, 0, 0, 1, 0, 10, 0);
      check_int("aux0_no_forward.forward", forward_valid, 0);
      run_const_case("aux_slot_map", 3, 2, 3, 4, 0, 1, 0, 0, 5, 6, 1, 8, 0, 0, 9, 0, 7, 0, 0, 0, 1, 2, 10, 11);
      check_int("aux_slot_map.forward_valid", forward_valid, 3);
      check_int("aux_slot_map.slot0", forward_slot0, 0);
      check_int("aux_slot_map.slot1", forward_slot1, 7);

      reset_pipeline();
      fill_state_all(0, 0, 7, 0, 0, 0);
      fill_q_all(0, 0);
      set_q0_lane(0, 10);
      set_q0_lane(1, -2);
      set_q0_lane(2, 0);
      drive_issue(1, 2, 3, 0, 0, 1, 4, 0, 0, 5, 0, 0, 0, 1, 0);
      tick();
      check_q_req("final_touch_hard", 1, 2, 0, 1, 4);
      issue_valid = 1'b0;
      drive_state_for_issue(2, 4, 1, 1);
      tick();
      drive_q_for_issue(1, 2, 0, 1, 4, 1);
      tick();
      q_resp_valid = 1'b0;
      tick();
      check_common_pub("final_touch_hard", 1, 2, 3, 0, 0, 1, 4, 5, 0);
      check_int("final_touch_hard.valid", final_touch_valid, 1);
      check_bit("final_touch_hard.positive", final_touch_hard0[0], 1'b0);
      check_bit("final_touch_hard.negative", final_touch_hard0[1], 1'b1);
      check_bit("final_touch_hard.zero", final_touch_hard0[2], 1'b0);
      directed_cases++;

      run_error_case("missing_q_response", 1);
      run_error_case("q_metadata_mismatch", 2);
      run_error_case("state_metadata_mismatch", 3);
      run_error_case("illegal_shift", 4);
      run_zero_lane_error();
      run_missing_state_response_error();
    end
  endtask

  function automatic logic [35:0] trace_word_for_cycle(input int cycle);
    logic [35:0] trace_word;
    begin
      trace_word = 36'd0;
      case (cycle)
        15: trace_word = 36'h02110c40f;
        16: trace_word = 36'h04342500f;
        17: trace_word = 36'h06563580f;
        18: trace_word = 36'h08700400f;
        19: trace_word = 36'h01221480f;
        20: trace_word = 36'h04331cc0f;
        21: trace_word = 36'h06552d40f;
        22: trace_word = 36'h07873dc0f;
        23: trace_word = 36'h02184600f;
        24: trace_word = 36'h00390240b;
        29: trace_word = 36'h0210bdc1f;
        30: trace_word = 36'h04319021f;
        31: trace_word = 36'h0652a8e1f;
        32: trace_word = 36'h087498a1f;
        33: trace_word = 36'h0218b401f;
        34: trace_word = 36'h03438c41f;
        35: trace_word = 36'h0656b161f;
        36: trace_word = 36'h00798241b;
        37: trace_word = 36'h0215a501f;
        38: trace_word = 36'h0437c601f;
        46: trace_word = 36'h021010417;
        47: trace_word = 36'h043231017;
        48: trace_word = 36'h065304017;
        49: trace_word = 36'h087529217;
        50: trace_word = 36'h201145e17;
        51: trace_word = 36'h202418a17;
        52: trace_word = 36'h130639a17;
        53: trace_word = 36'h20474a017;
        54: trace_word = 36'h30081c617;
        55: trace_word = 36'h100901613;
        59: trace_word = 36'h3000a5007;
        60: trace_word = 36'h3001c6007;
        61: trace_word = 36'h3002c9807;
        62: trace_word = 36'h300384007;
        63: trace_word = 36'h300494807;
        64: trace_word = 36'h30059cc07;
        65: trace_word = 36'h3006ad407;
        66: trace_word = 36'h3007b9a07;
        67: trace_word = 36'h3008bc407;
        68: trace_word = 36'h100980603;
        default: trace_word = 36'd0;
      endcase
      trace_word_for_cycle = trace_word;
    end
  endfunction

  task automatic lookup_column_shift(input int layer_arg, input int edge_arg, output int column, output int shift_value);
    begin
      column = 0;
      shift_value = 0;
      case ({layer_arg[5:0], edge_arg[4:0]})
        {6'd0, 5'd0}: begin column = 7'd0; shift_value = 307; end
        {6'd0, 5'd1}: begin column = 7'd1; shift_value = 19; end
        {6'd0, 5'd2}: begin column = 7'd2; shift_value = 50; end
        {6'd0, 5'd3}: begin column = 7'd3; shift_value = 369; end
        {6'd0, 5'd4}: begin column = 7'd5; shift_value = 181; end
        {6'd0, 5'd5}: begin column = 7'd6; shift_value = 216; end
        {6'd0, 5'd6}: begin column = 7'd9; shift_value = 317; end
        {6'd0, 5'd7}: begin column = 7'd10; shift_value = 288; end
        {6'd0, 5'd8}: begin column = 7'd11; shift_value = 109; end
        {6'd0, 5'd9}: begin column = 7'd12; shift_value = 17; end
        {6'd0, 5'd10}: begin column = 7'd13; shift_value = 357; end
        {6'd0, 5'd11}: begin column = 7'd15; shift_value = 215; end
        {6'd0, 5'd12}: begin column = 7'd16; shift_value = 106; end
        {6'd0, 5'd13}: begin column = 7'd18; shift_value = 242; end
        {6'd0, 5'd14}: begin column = 7'd19; shift_value = 180; end
        {6'd0, 5'd15}: begin column = 7'd20; shift_value = 330; end
        {6'd0, 5'd16}: begin column = 7'd21; shift_value = 346; end
        {6'd0, 5'd17}: begin column = 7'd22; shift_value = 1; end
        {6'd0, 5'd18}: begin column = 7'd23; shift_value = 0; end
        {6'd1, 5'd0}: begin column = 7'd0; shift_value = 76; end
        {6'd1, 5'd1}: begin column = 7'd2; shift_value = 76; end
        {6'd1, 5'd2}: begin column = 7'd3; shift_value = 73; end
        {6'd1, 5'd3}: begin column = 7'd4; shift_value = 288; end
        {6'd1, 5'd4}: begin column = 7'd5; shift_value = 144; end
        {6'd1, 5'd5}: begin column = 7'd7; shift_value = 331; end
        {6'd1, 5'd6}: begin column = 7'd8; shift_value = 331; end
        {6'd1, 5'd7}: begin column = 7'd9; shift_value = 178; end
        {6'd1, 5'd8}: begin column = 7'd11; shift_value = 295; end
        {6'd1, 5'd9}: begin column = 7'd12; shift_value = 342; end
        {6'd1, 5'd10}: begin column = 7'd14; shift_value = 217; end
        {6'd1, 5'd11}: begin column = 7'd15; shift_value = 99; end
        {6'd1, 5'd12}: begin column = 7'd16; shift_value = 354; end
        {6'd1, 5'd13}: begin column = 7'd17; shift_value = 114; end
        {6'd1, 5'd14}: begin column = 7'd19; shift_value = 331; end
        {6'd1, 5'd15}: begin column = 7'd21; shift_value = 112; end
        {6'd1, 5'd16}: begin column = 7'd22; shift_value = 0; end
        {6'd1, 5'd17}: begin column = 7'd23; shift_value = 0; end
        {6'd1, 5'd18}: begin column = 7'd24; shift_value = 0; end
        {6'd2, 5'd0}: begin column = 7'd0; shift_value = 205; end
        {6'd2, 5'd1}: begin column = 7'd1; shift_value = 250; end
        {6'd2, 5'd2}: begin column = 7'd2; shift_value = 328; end
        {6'd2, 5'd3}: begin column = 7'd4; shift_value = 332; end
        {6'd2, 5'd4}: begin column = 7'd5; shift_value = 256; end
        {6'd2, 5'd5}: begin column = 7'd6; shift_value = 161; end
        {6'd2, 5'd6}: begin column = 7'd7; shift_value = 267; end
        {6'd2, 5'd7}: begin column = 7'd8; shift_value = 160; end
        {6'd2, 5'd8}: begin column = 7'd9; shift_value = 63; end
        {6'd2, 5'd9}: begin column = 7'd10; shift_value = 129; end
        {6'd2, 5'd10}: begin column = 7'd13; shift_value = 200; end
        {6'd2, 5'd11}: begin column = 7'd14; shift_value = 88; end
        {6'd2, 5'd12}: begin column = 7'd15; shift_value = 53; end
        {6'd2, 5'd13}: begin column = 7'd17; shift_value = 131; end
        {6'd2, 5'd14}: begin column = 7'd18; shift_value = 240; end
        {6'd2, 5'd15}: begin column = 7'd19; shift_value = 205; end
        {6'd2, 5'd16}: begin column = 7'd20; shift_value = 13; end
        {6'd2, 5'd17}: begin column = 7'd24; shift_value = 0; end
        {6'd2, 5'd18}: begin column = 7'd25; shift_value = 0; end
        {6'd3, 5'd0}: begin column = 7'd0; shift_value = 276; end
        {6'd3, 5'd1}: begin column = 7'd1; shift_value = 87; end
        {6'd3, 5'd2}: begin column = 7'd3; shift_value = 0; end
        {6'd3, 5'd3}: begin column = 7'd4; shift_value = 275; end
        {6'd3, 5'd4}: begin column = 7'd6; shift_value = 199; end
        {6'd3, 5'd5}: begin column = 7'd7; shift_value = 153; end
        {6'd3, 5'd6}: begin column = 7'd8; shift_value = 56; end
        {6'd3, 5'd7}: begin column = 7'd10; shift_value = 132; end
        {6'd3, 5'd8}: begin column = 7'd11; shift_value = 305; end
        {6'd3, 5'd9}: begin column = 7'd12; shift_value = 231; end
        {6'd3, 5'd10}: begin column = 7'd13; shift_value = 341; end
        {6'd3, 5'd11}: begin column = 7'd14; shift_value = 212; end
        {6'd3, 5'd12}: begin column = 7'd16; shift_value = 304; end
        {6'd3, 5'd13}: begin column = 7'd17; shift_value = 300; end
        {6'd3, 5'd14}: begin column = 7'd18; shift_value = 271; end
        {6'd3, 5'd15}: begin column = 7'd20; shift_value = 39; end
        {6'd3, 5'd16}: begin column = 7'd21; shift_value = 357; end
        {6'd3, 5'd17}: begin column = 7'd22; shift_value = 1; end
        {6'd3, 5'd18}: begin column = 7'd25; shift_value = 0; end
        default: begin
          $display("FAIL lookup missing layer=%0d edge=%0d", layer_arg, edge_arg);
          errors++;
        end
      endcase
    end
  endtask

  function automatic int field_valid(input logic [35:0] word);
    field_valid = word[0];
  endfunction

  function automatic int field_mask(input logic [35:0] word);
    field_mask = word[2:1];
  endfunction

  function automatic int field_layer(input logic [35:0] word);
    field_layer = word[8:3];
  endfunction

  function automatic int field_edge0(input logic [35:0] word);
    field_edge0 = word[13:9];
  endfunction

  function automatic int field_edge1(input logic [35:0] word);
    field_edge1 = word[18:14];
  endfunction

  function automatic int field_qbuf(input logic [35:0] word);
    field_qbuf = word[19];
  endfunction

  function automatic int field_qslot(input logic [35:0] word);
    field_qslot = word[23:20];
  endfunction

  function automatic int field_aux0(input logic [35:0] word);
    field_aux0 = word[27:24];
  endfunction

  function automatic int field_aux1(input logic [35:0] word);
    field_aux1 = word[31:28];
  endfunction

  function automatic int field_final0(input logic [35:0] word);
    field_final0 = word[32];
  endfunction

  function automatic int field_final1(input logic [35:0] word);
    field_final1 = word[33];
  endfunction

  task automatic drive_issue_from_word(input logic [35:0] word);
    int col0;
    int col1;
    int sh0;
    int sh1;
    begin
      lookup_column_shift(field_layer(word), field_edge0(word), col0, sh0);
      if (field_mask(word) & 2) begin
        lookup_column_shift(field_layer(word), field_edge1(word), col1, sh1);
      end else begin
        col1 = 0;
        sh1 = 0;
      end
      drive_issue(
        field_mask(word),
        field_layer(word),
        field_edge0(word),
        field_edge1(word),
        field_qbuf(word),
        field_qslot(word),
        6,
        sh0,
        sh1,
        col0,
        col1,
        field_aux0(word),
        field_aux1(word),
        field_final0(word),
        field_final1(word)
      );
    end
  endtask

  task automatic drive_state_from_word(input logic [35:0] word);
    begin
      if (field_valid(word)) begin
        drive_state_for_issue(field_layer(word), 6, 1, 1);
      end else begin
        new_state_resp_valid = 1'b0;
      end
    end
  endtask

  task automatic drive_q_from_word(input logic [35:0] word);
    begin
      if (field_valid(word)) begin
        fill_q_all(1, 2);
        drive_q_for_issue(field_mask(word), field_layer(word), field_qbuf(word), field_qslot(word), 6, 1);
      end else begin
        q_resp_valid = 1'b0;
      end
    end
  endtask

  task automatic check_pub_from_word(input int cycle, input logic [35:0] word);
    int col0;
    int col1;
    int sh0_unused;
    int sh1_unused;
    int expected_edges;
    begin
      if (field_valid(word)) begin
        lookup_column_shift(field_layer(word), field_edge0(word), col0, sh0_unused);
        if (field_mask(word) & 2) begin
          lookup_column_shift(field_layer(word), field_edge1(word), col1, sh1_unused);
        end else begin
          col1 = 0;
        end
        check_common_pub("trace", field_mask(word), field_layer(word), field_edge0(word), field_edge1(word), field_qbuf(word), field_qslot(word), 6, col0, col1);
        expected_edges = (field_mask(word) & 1) + ((field_mask(word) >> 1) & 1);
        high_rate_publication_count++;
        high_rate_edge_count += expected_edges;
      end else begin
        if (app_write_valid != 2'b00) begin
          $display("FAIL trace extra publication cycle=%0d valid=%0d", cycle, app_write_valid);
          errors++;
        end
        if (error_valid) begin
          $display("FAIL trace unexpected error cycle=%0d", cycle);
          errors++;
        end
      end
    end
  endtask

  task automatic run_high_rate_trace;
    int cycle;
    logic [35:0] issue_word;
    logic [35:0] state_word;
    logic [35:0] q_word;
    logic [35:0] pub_word;
    begin
      reset_pipeline();
      high_rate_issue_count = 0;
      high_rate_edge_count = 0;
      high_rate_publication_count = 0;
      fill_state_all(0, 0, 7, 0, 0, 0);
      for (cycle = 0; cycle <= 72; cycle++) begin
        issue_word = trace_word_for_cycle(cycle);
        state_word = trace_word_for_cycle(cycle - 1);
        q_word = trace_word_for_cycle(cycle - 2);
        pub_word = trace_word_for_cycle(cycle - 3);

        if (field_valid(issue_word)) begin
          high_rate_issue_count++;
          drive_issue_from_word(issue_word);
        end else begin
          issue_valid = 1'b0;
        end
        drive_state_from_word(state_word);
        drive_q_from_word(q_word);
        tick();
        if (field_valid(issue_word)) begin
          check_q_req("trace", field_mask(issue_word), field_layer(issue_word), field_qbuf(issue_word), field_qslot(issue_word), 6);
        end
        check_pub_from_word(cycle, pub_word);
      end
      check_int("trace.issue_cycles", high_rate_issue_count, 40);
      check_int("trace.active_edges", high_rate_edge_count, 76);
      check_int("trace.publications", high_rate_publication_count, 40);
    end
  endtask

  task automatic run_alignment_test;
    int col_a0;
    int col_b0;
    int col_b1;
    int col_c0;
    int col_c1;
    int shift_a0;
    int shift_b0;
    int shift_b1;
    int shift_c0;
    int shift_c1;
    begin
      reset_pipeline();
      lookup_column_shift(1, 2, col_a0, shift_a0);
      lookup_column_shift(3, 5, col_b0, shift_b0);
      lookup_column_shift(3, 6, col_b1, shift_b1);
      lookup_column_shift(2, 10, col_c0, shift_c0);
      lookup_column_shift(2, 11, col_c1, shift_c1);

      drive_issue(2'b01, 1, 2, 0, 0, 1, 6, shift_a0, 0, col_a0, 0, 0, 0, 0, 0);
      new_state_resp_valid = 1'b0;
      q_resp_valid = 1'b0;
      tick();
      check_q_req("align.A", 1, 1, 0, 1, 6);

      drive_issue(2'b11, 3, 5, 6, 1, 4, 6, shift_b0, shift_b1, col_b0, col_b1, 1, 0, 1, 0);
      fill_state_all(11, 41, 7, 0, 0, 0);
      drive_state_for_issue(1, 6, 1, 1);
      q_resp_valid = 1'b0;
      tick();
      check_q_req("align.B", 3, 3, 1, 4, 6);

      drive_issue(2'b11, 2, 10, 11, 0, 8, 6, shift_c0, shift_c1, col_c0, col_c1, 8, 4, 0, 1);
      fill_state_all(9, 28, 5, 0, 0, 1);
      drive_state_for_issue(3, 6, 1, 1);
      fill_q_all(3, 0);
      drive_q_for_issue(1, 1, 0, 1, 6, 1);
      tick();
      check_q_req("align.C", 3, 2, 0, 8, 6);

      issue_valid = 1'b0;
      fill_state_all(17, 33, 11, 1, 1, 0);
      drive_state_for_issue(2, 6, 1, 1);
      fill_q_all(-5, 7);
      drive_q_for_issue(3, 3, 1, 4, 6, 1);
      tick();
      check_common_pub("align.A", 1, 1, 2, 0, 0, 1, 6, col_a0, 0);
      check_int("align.A.aux0", app_write_aux0, 0);
      check_int("align.A.final0", app_write_final_touch0, 0);
      check_int("align.A.app0", app0(0), 14);
      check_int("align.A.forward", forward_valid, 0);
      check_int("align.A.final", final_touch_valid, 0);

      new_state_resp_valid = 1'b0;
      fill_q_all(-40, 20);
      drive_q_for_issue(3, 2, 0, 8, 6, 1);
      tick();
      check_common_pub("align.B", 3, 3, 5, 6, 1, 4, 6, col_b0, col_b1);
      check_int("align.B.aux0", app_write_aux0, 1);
      check_int("align.B.aux1", app_write_aux1, 0);
      check_int("align.B.final0", app_write_final_touch0, 1);
      check_int("align.B.final1", app_write_final_touch1, 0);
      check_int("align.B.app0", app0(0), 23);
      check_int("align.B.app1", app1(0), -2);
      check_int("align.B.forward_valid", forward_valid, 1);
      check_int("align.B.forward_slot0", forward_slot0, 0);
      check_int("align.B.final_valid", final_touch_valid, 1);
      check_int("align.B.final_layer", final_touch_layer_id, 3);
      check_int("align.B.final_edge0", final_touch_edge0_id, 5);
      check_bit("align.B.hard0", final_touch_hard0[0], 1'b0);

      q_resp_valid = 1'b0;
      tick();
      check_common_pub("align.C", 3, 2, 10, 11, 0, 8, 6, col_c0, col_c1);
      check_int("align.C.aux0", app_write_aux0, 8);
      check_int("align.C.aux1", app_write_aux1, 4);
      check_int("align.C.final0", app_write_final_touch0, 0);
      check_int("align.C.final1", app_write_final_touch1, 1);
      check_int("align.C.app0", app0(0), -23);
      check_int("align.C.app1", app1(0), -13);
      check_int("align.C.forward_valid", forward_valid, 3);
      check_int("align.C.forward_slot0", forward_slot0, 7);
      check_int("align.C.forward_slot1", forward_slot1, 3);
      check_int("align.C.final_valid", final_touch_valid, 2);
      check_int("align.C.final_layer", final_touch_layer_id, 2);
      check_int("align.C.final_edge1", final_touch_edge1_id, 11);
      check_bit("align.C.hard1", final_touch_hard1[0], 1'b1);
      alignment_cases++;
    end
  endtask

  initial begin
    int selected_case;
    clk = 1'b0;
    rst = 1'b0;
    errors = 0;
    directed_cases = 0;
    alignment_cases = 0;
    high_rate_issue_count = 0;
    high_rate_edge_count = 0;
    high_rate_publication_count = 0;
    if (!$value$plusargs("phase5_case=%d", selected_case)) begin
      selected_case = 0;
    end

    if (!REDUCED_P_SIM && (P != 384 || B != 2 || D_R != 3)) begin
      $display("FAIL frozen Phase-5 constants");
      errors++;
    end

    case (selected_case)
      0: begin
        run_directed_tests();
        if (!REDUCED_P_SIM) begin
          run_alignment_test();
          run_high_rate_trace();
        end
      end
      1: run_directed_tests();
      2: run_alignment_test();
      3: run_high_rate_trace();
      default: begin
        $display("FAIL unknown phase5_case=%0d", selected_case);
        errors++;
      end
    endcase

    if (errors == 0) begin
      $display("PASS phase5 rec pipeline");
      $display("phase5_case=%0d", selected_case);
      $display("p_lanes=%0d reduced_p_sim=%0d", P_VAL, REDUCED_P_SIM);
      $display(
        "directed_cases=%0d alignment_cases=%0d high_rate_rec_issue_cycles=%0d high_rate_active_edges=%0d",
        directed_cases,
        alignment_cases,
        high_rate_issue_count,
        high_rate_edge_count
      );
      $finish;
    end

    $display("FAIL phase5 rec pipeline errors=%0d", errors);
    $finish(1);
  end
endmodule
