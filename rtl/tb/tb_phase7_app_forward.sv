`timescale 1ns/1ps

module tb_phase7_app_forward;
  import nr_ldpc_pkg::*;

  localparam int P_VAL = REFERENCE_Z;
  localparam int SHIFT_W = $clog2(P_VAL + 1);

  logic clk_i;
  logic rst_i;
  logic start_block_i;
  logic advance_iteration_i;

  logic app_load_valid_i;
  logic [6:0] app_load_column_i;
  logic [3:0] app_load_iteration_epoch_i;
  logic [P_VAL*W_APP-1:0] app_load_i;

  logic acc_issue_valid_i;
  logic [1:0] acc_issue_lane_mask_i;
  logic [5:0] acc_issue_layer_id_i;
  logic [5:0] acc_issue_layer_position_i;
  logic [5:0] acc_issue_layer_degree_i;
  logic acc_issue_start_layer_i;
  logic [4:0] acc_issue_edge0_id_i;
  logic [4:0] acc_issue_edge1_id_i;
  logic [0:0] acc_issue_qbuf_i;
  logic [3:0] acc_issue_qslot_i;
  logic [3:0] acc_issue_iteration_epoch_i;
  logic [6:0] acc_issue_base_column0_i;
  logic [6:0] acc_issue_base_column1_i;
  logic [3:0] acc_issue_aux0_i;
  logic [3:0] acc_issue_aux1_i;
  logic [SHIFT_W-1:0] acc_issue_shift0_i;
  logic [SHIFT_W-1:0] acc_issue_shift1_i;

  logic rec_issue_valid_i;
  logic [1:0] rec_issue_lane_mask_i;
  logic [5:0] rec_issue_layer_id_i;
  logic [4:0] rec_issue_edge0_id_i;
  logic [4:0] rec_issue_edge1_id_i;
  logic [0:0] rec_issue_qbuf_i;
  logic [3:0] rec_issue_qslot_i;
  logic [3:0] rec_issue_iteration_epoch_i;
  logic [SHIFT_W-1:0] rec_issue_shift0_i;
  logic [SHIFT_W-1:0] rec_issue_shift1_i;
  logic [6:0] rec_issue_base_column0_i;
  logic [6:0] rec_issue_base_column1_i;
  logic [3:0] rec_issue_aux0_i;
  logic [3:0] rec_issue_aux1_i;
  logic rec_issue_final_touch0_i;
  logic rec_issue_final_touch1_i;

  logic acc_issue_ready_o;
  logic rec_issue_ready_o;
  logic [1:0] rec_app_write_valid_o;
  logic [P_VAL*W_APP-1:0] rec_app_write_lane0_o;
  logic [P_VAL*W_APP-1:0] rec_app_write_lane1_o;
  logic [6:0] rec_app_write_base_column0_o;
  logic [6:0] rec_app_write_base_column1_o;
  logic [1:0] rec_app_write_lane_mask_o;
  logic [5:0] rec_app_write_layer_id_o;
  logic [4:0] rec_app_write_edge0_id_o;
  logic [4:0] rec_app_write_edge1_id_o;
  logic [3:0] rec_app_write_iteration_epoch_o;
  logic [0:0] rec_app_write_qbuf_o;
  logic [3:0] rec_app_write_qslot_o;
  logic [3:0] rec_app_write_aux0_o;
  logic [3:0] rec_app_write_aux1_o;
  logic rec_app_write_final_touch0_o;
  logic rec_app_write_final_touch1_o;

  logic [1:0] rec_forward_valid_o;
  logic [2:0] rec_forward_slot0_o;
  logic [2:0] rec_forward_slot1_o;
  logic [6:0] rec_forward_base_column0_o;
  logic [6:0] rec_forward_base_column1_o;
  logic [3:0] rec_forward_iteration_epoch_o;
  logic [P_VAL*W_APP-1:0] rec_forward_app0_o;
  logic [P_VAL*W_APP-1:0] rec_forward_app1_o;

  logic [1:0] rec_final_touch_valid_o;
  logic [6:0] rec_final_touch_base_column0_o;
  logic [6:0] rec_final_touch_base_column1_o;
  logic [5:0] rec_final_touch_layer_id_o;
  logic [4:0] rec_final_touch_edge0_id_o;
  logic [4:0] rec_final_touch_edge1_id_o;
  logic [3:0] rec_final_touch_iteration_epoch_o;
  logic [P_VAL*W_APP-1:0] rec_final_touch_app0_o;
  logic [P_VAL*W_APP-1:0] rec_final_touch_app1_o;
  logic [P_VAL-1:0] rec_final_touch_hard0_o;
  logic [P_VAL-1:0] rec_final_touch_hard1_o;

  logic acc_error_valid_o;
  logic rec_error_valid_o;
  logic q_scratch_error_valid_o;
  logic [7:0] q_scratch_error_code_o;
  logic check_state_error_valid_o;
  logic [7:0] check_state_error_code_o;
  logic old_state_alignment_error_o;
  logic unsafe_advance_error_o;
  logic phase6_storage_error_valid_o;
  logic app_memory_error_valid_o;
  logic [7:0] app_memory_error_code_o;
  logic forward_error_valid_o;
  logic [7:0] forward_error_code_o;
  logic app_forward_error_valid_o;
  logic storage_error_valid_o;

  logic [1:0] debug_acc_source_valid_o;
  logic [1:0] debug_acc_source_forwarded_o;
  logic [P_VAL*W_APP-1:0] debug_acc_source0_app_o;
  logic [P_VAL*W_APP-1:0] debug_acc_source1_app_o;
  logic [2:0] debug_app_read_bank0_o;
  logic [2:0] debug_app_read_bank1_o;
  logic [2:0] debug_app_write_bank0_o;
  logic [2:0] debug_app_write_bank1_o;
  logic debug_app_same_bank_collision_o;
  logic [1:0] debug_app_write_accept_o;
  logic debug_app_write_commit_o;
  logic [1:0] debug_forward_alloc_valid_o;
  logic [1:0] debug_forward_alloc_accept_o;
  logic [1:0] debug_forward_read_valid_o;
  logic [1:0] debug_forward_read_accept_o;
  logic [5:0] debug_forward_live_count_o;
  logic [1:0] debug_forward_candidate_valid_o;
  logic [2:0] debug_forward_candidate_slot0_o;
  logic [2:0] debug_forward_candidate_slot1_o;
  logic [6:0] debug_forward_candidate_base_column0_o;
  logic [6:0] debug_forward_candidate_base_column1_o;
  logic [3:0] debug_forward_candidate_iteration_epoch_o;
  logic [P_VAL*W_APP-1:0] debug_forward_candidate_app0_o;
  logic [P_VAL*W_APP-1:0] debug_forward_candidate_app1_o;
  logic [1:0] debug_rec_publication_valid_o;
  logic debug_acc_q_write_valid_o;
  logic [0:0] debug_acc_q_write_qbuf_o;
  logic [3:0] debug_acc_q_write_qslot_o;
  logic [1:0] debug_acc_q_write_lane_mask_o;
  logic [P_VAL*W_Q-1:0] debug_acc_q_write_lane0_o;
  logic [P_VAL*W_Q-1:0] debug_acc_q_write_lane1_o;
  logic [5:0] debug_acc_q_write_layer_id_o;
  logic [3:0] debug_acc_q_write_iteration_epoch_o;
  logic [1:0] debug_acc_qsign_write_valid_o;
  logic [4:0] debug_acc_qsign_write_edge0_id_o;
  logic [4:0] debug_acc_qsign_write_edge1_id_o;
  logic [P_VAL-1:0] debug_acc_qsign_write_lane0_o;
  logic [P_VAL-1:0] debug_acc_qsign_write_lane1_o;
  logic debug_layer_close_valid_o;
  logic [5:0] debug_layer_close_layer_id_o;
  logic [P_VAL*W_M-1:0] debug_layer_close_m1_o;
  logic [P_VAL*W_M-1:0] debug_layer_close_m2_o;
  logic [P_VAL*5-1:0] debug_layer_close_imin_o;
  logic [P_VAL-1:0] debug_layer_close_aggregate_sign_o;
  logic debug_q_write_accept_o;
  logic debug_advance_accept_o;
  logic debug_acc_old_resp_valid_o;
  logic debug_acc_old_generation_valid_o;
  logic debug_rec_new_resp_valid_o;
  logic debug_rec_new_state_closed_o;
  logic [P_VAL*W_M-1:0] debug_rec_new_m1_o;
  logic [P_VAL*W_M-1:0] debug_rec_new_m2_o;
  logic [P_VAL*5-1:0] debug_rec_new_imin_o;
  logic [P_VAL-1:0] debug_rec_new_aggregate_sign_o;
  logic [P_VAL*W_Q-1:0] debug_q_read_resp_lane0_o;
  logic [P_VAL*W_Q-1:0] debug_q_read_resp_lane1_o;
  logic [5:0] debug_q_read_resp_layer_id_o;
  logic [3:0] debug_q_read_resp_qslot_o;
  logic [5:0] debug_q_live_count_o;
  logic current_old_generation_o;
  logic current_new_generation_o;

  logic mem_start_block;
  logic mem_load_valid;
  logic [6:0] mem_load_column;
  logic [3:0] mem_load_epoch;
  logic [P_VAL*W_APP-1:0] mem_load_app;
  logic [1:0] mem_read_valid;
  logic [6:0] mem_read_column0;
  logic [6:0] mem_read_column1;
  logic [1:0] mem_read_accept;
  logic [P_VAL*W_APP-1:0] mem_read_app0;
  logic [P_VAL*W_APP-1:0] mem_read_app1;
  logic [2:0] mem_read_bank0;
  logic [2:0] mem_read_bank1;
  logic [1:0] mem_write_valid;
  logic mem_write_commit;
  logic [6:0] mem_write_column0;
  logic [6:0] mem_write_column1;
  logic [3:0] mem_write_epoch;
  logic [P_VAL*W_APP-1:0] mem_write_app0;
  logic [P_VAL*W_APP-1:0] mem_write_app1;
  logic [1:0] mem_write_accept;
  logic [2:0] mem_write_bank0;
  logic [2:0] mem_write_bank1;
  logic mem_collision;
  logic mem_error;
  logic [7:0] mem_error_code;

  logic fc_start_block;
  logic fc_advance_iteration;
  logic [1:0] fc_reserve_valid;
  logic [2:0] fc_reserve_slot0;
  logic [2:0] fc_reserve_slot1;
  logic [6:0] fc_reserve_column0;
  logic [6:0] fc_reserve_column1;
  logic [3:0] fc_reserve_epoch;
  logic [1:0] fc_publish_valid;
  logic fc_publish_commit;
  logic [2:0] fc_publish_slot0;
  logic [2:0] fc_publish_slot1;
  logic [6:0] fc_publish_column0;
  logic [6:0] fc_publish_column1;
  logic [3:0] fc_publish_epoch;
  logic [P_VAL*W_APP-1:0] fc_publish_app0;
  logic [P_VAL*W_APP-1:0] fc_publish_app1;
  logic [1:0] fc_reserve_accept;
  logic [1:0] fc_alloc_accept;
  logic [1:0] fc_read_valid;
  logic [2:0] fc_read_slot0;
  logic [2:0] fc_read_slot1;
  logic [6:0] fc_read_column0;
  logic [6:0] fc_read_column1;
  logic [3:0] fc_read_epoch;
  logic [1:0] fc_read_accept;
  logic [P_VAL*W_APP-1:0] fc_read_app0;
  logic [P_VAL*W_APP-1:0] fc_read_app1;
  logic [5:0] fc_live_count;
  logic fc_error;
  logic [7:0] fc_error_code;

  int errors;
  int directed_cases;
  int numerical_dependency_checks;
  int acc_issue_count;
  int rec_issue_count;
  int acc_edge_count;
  int rec_edge_count;
  int forward_allocations;
  int forwarded_reads;
  int normal_reads;
  int max_live_forward_entries;
  int same_bank_collisions;
  int high_rate_cycles;
  int source_oo_count;
  int source_of_count;
  int source_fo_count;
  int source_ff_count;
  int source_singleton_ordinary_count;

  nr_ldpc_app_memory #(
    .P(P_VAL)
  ) u_mem_direct (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_block_i(mem_start_block),
    .load_valid_i(mem_load_valid),
    .load_column_i(mem_load_column),
    .load_iteration_epoch_i(mem_load_epoch),
    .load_app_i(mem_load_app),
    .read_valid_i(mem_read_valid),
    .read_column0_i(mem_read_column0),
    .read_column1_i(mem_read_column1),
    .read_accept_o(mem_read_accept),
    .read_app0_o(mem_read_app0),
    .read_app1_o(mem_read_app1),
    .read_bank0_o(mem_read_bank0),
    .read_bank1_o(mem_read_bank1),
    .write_valid_i(mem_write_valid),
    .write_commit_i(mem_write_commit),
    .write_column0_i(mem_write_column0),
    .write_column1_i(mem_write_column1),
    .write_iteration_epoch_i(mem_write_epoch),
    .write_app0_i(mem_write_app0),
    .write_app1_i(mem_write_app1),
    .write_accept_o(mem_write_accept),
    .write_bank0_o(mem_write_bank0),
    .write_bank1_o(mem_write_bank1),
    .same_bank_read_write_collision_o(mem_collision),
    .error_valid_o(mem_error),
    .error_code_o(mem_error_code)
  );

  nr_ldpc_forward_cache #(
    .P(P_VAL),
    .DEPTH(FORWARD_DEPTH)
  ) u_fc_direct (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_block_i(fc_start_block),
    .advance_iteration_i(fc_advance_iteration),
    .reserve_valid_i(fc_reserve_valid),
    .reserve_slot0_i(fc_reserve_slot0),
    .reserve_slot1_i(fc_reserve_slot1),
    .reserve_column0_i(fc_reserve_column0),
    .reserve_column1_i(fc_reserve_column1),
    .reserve_iteration_epoch_i(fc_reserve_epoch),
    .publish_valid_i(fc_publish_valid),
    .publish_commit_i(fc_publish_commit),
    .publish_slot0_i(fc_publish_slot0),
    .publish_slot1_i(fc_publish_slot1),
    .publish_column0_i(fc_publish_column0),
    .publish_column1_i(fc_publish_column1),
    .publish_iteration_epoch_i(fc_publish_epoch),
    .publish_app0_i(fc_publish_app0),
    .publish_app1_i(fc_publish_app1),
    .reserve_accept_o(fc_reserve_accept),
    .alloc_accept_o(fc_alloc_accept),
    .read_valid_i(fc_read_valid),
    .read_slot0_i(fc_read_slot0),
    .read_slot1_i(fc_read_slot1),
    .read_column0_i(fc_read_column0),
    .read_column1_i(fc_read_column1),
    .read_iteration_epoch_i(fc_read_epoch),
    .read_accept_o(fc_read_accept),
    .read_app0_o(fc_read_app0),
    .read_app1_o(fc_read_app1),
    .live_count_o(fc_live_count),
    .error_valid_o(fc_error),
    .error_code_o(fc_error_code)
  );

`ifndef PHASE7_METADATA_ONLY
  nr_ldpc_app_forward_datapath #(
    .P(P_VAL)
  ) dut (.*);
`endif

  task automatic tick;
    begin
      #5;
      clk_i = 1'b1;
      #1;
      clk_i = 1'b0;
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

  function automatic int signed lane_app(input logic [P_VAL*W_APP-1:0] vec, input int lane);
    logic signed [W_APP-1:0] value;
    begin
      value = vec[lane*W_APP +: W_APP];
      lane_app = value;
    end
  endfunction

  function automatic int signed lane_q(input logic [P_VAL*W_Q-1:0] vec, input int lane);
    logic signed [W_Q-1:0] value;
    begin
      value = vec[lane*W_Q +: W_Q];
      lane_q = value;
    end
  endfunction

  task automatic fill_app_vec(output logic [P_VAL*W_APP-1:0] vec, input int value);
    int lane;
    logic signed [W_APP-1:0] packed_value;
    begin
      packed_value = value;
      for (lane = 0; lane < P_VAL; lane++) begin
        vec[lane*W_APP +: W_APP] = packed_value;
      end
    end
  endtask

  task automatic set_app_lane(inout logic [P_VAL*W_APP-1:0] vec, input int lane, input int value);
    logic signed [W_APP-1:0] packed_value;
    begin
      packed_value = value;
      vec[lane*W_APP +: W_APP] = packed_value;
    end
  endtask

  task automatic clear_inputs;
    begin
      start_block_i = 1'b0;
      advance_iteration_i = 1'b0;
      app_load_valid_i = 1'b0;
      app_load_column_i = 7'd0;
      app_load_iteration_epoch_i = 4'd0;
      app_load_i = '0;

      acc_issue_valid_i = 1'b0;
      acc_issue_lane_mask_i = 2'b00;
      acc_issue_layer_id_i = 6'd0;
      acc_issue_layer_position_i = 6'd0;
      acc_issue_layer_degree_i = 6'd0;
      acc_issue_start_layer_i = 1'b0;
      acc_issue_edge0_id_i = 5'd0;
      acc_issue_edge1_id_i = 5'd0;
      acc_issue_qbuf_i = 1'b0;
      acc_issue_qslot_i = 4'd0;
      acc_issue_iteration_epoch_i = 4'd0;
      acc_issue_base_column0_i = 7'd0;
      acc_issue_base_column1_i = 7'd0;
      acc_issue_aux0_i = 4'd0;
      acc_issue_aux1_i = 4'd0;
      acc_issue_shift0_i = '0;
      acc_issue_shift1_i = '0;

      rec_issue_valid_i = 1'b0;
      rec_issue_lane_mask_i = 2'b00;
      rec_issue_layer_id_i = 6'd0;
      rec_issue_edge0_id_i = 5'd0;
      rec_issue_edge1_id_i = 5'd0;
      rec_issue_qbuf_i = 1'b0;
      rec_issue_qslot_i = 4'd0;
      rec_issue_iteration_epoch_i = 4'd0;
      rec_issue_shift0_i = '0;
      rec_issue_shift1_i = '0;
      rec_issue_base_column0_i = 7'd0;
      rec_issue_base_column1_i = 7'd0;
      rec_issue_aux0_i = 4'd0;
      rec_issue_aux1_i = 4'd0;
      rec_issue_final_touch0_i = 1'b0;
      rec_issue_final_touch1_i = 1'b0;

      mem_start_block = 1'b0;
      mem_load_valid = 1'b0;
      mem_load_column = 7'd0;
      mem_load_epoch = 4'd0;
      mem_load_app = '0;
      mem_read_valid = 2'b00;
      mem_read_column0 = 7'd0;
      mem_read_column1 = 7'd0;
      mem_write_valid = 2'b00;
      mem_write_commit = 1'b0;
      mem_write_column0 = 7'd0;
      mem_write_column1 = 7'd0;
      mem_write_epoch = 4'd0;
      mem_write_app0 = '0;
      mem_write_app1 = '0;

      fc_start_block = 1'b0;
      fc_advance_iteration = 1'b0;
      fc_reserve_valid = 2'b00;
      fc_reserve_slot0 = 3'd0;
      fc_reserve_slot1 = 3'd0;
      fc_reserve_column0 = 7'd0;
      fc_reserve_column1 = 7'd0;
      fc_reserve_epoch = 4'd0;
      fc_publish_valid = 2'b00;
      fc_publish_commit = 1'b0;
      fc_publish_slot0 = 3'd0;
      fc_publish_slot1 = 3'd0;
      fc_publish_column0 = 7'd0;
      fc_publish_column1 = 7'd0;
      fc_publish_epoch = 4'd0;
      fc_publish_app0 = '0;
      fc_publish_app1 = '0;
      fc_read_valid = 2'b00;
      fc_read_slot0 = 3'd0;
      fc_read_slot1 = 3'd0;
      fc_read_column0 = 7'd0;
      fc_read_column1 = 7'd0;
      fc_read_epoch = 4'd0;
    end
  endtask

  task automatic reset_all;
    begin
      clear_inputs();
      rst_i = 1'b1;
      tick();
      tick();
      rst_i = 1'b0;
      start_block_i = 1'b1;
      mem_start_block = 1'b1;
      fc_start_block = 1'b1;
      tick();
      start_block_i = 1'b0;
      mem_start_block = 1'b0;
      fc_start_block = 1'b0;
      tick();
    end
  endtask

  task automatic load_dut_column(input int column, input logic [P_VAL*W_APP-1:0] vec);
    begin
      app_load_valid_i = 1'b1;
      app_load_column_i = column[6:0];
      app_load_iteration_epoch_i = 4'd6;
      app_load_i = vec;
      tick();
      app_load_valid_i = 1'b0;
    end
  endtask

  task automatic drive_acc_issue(
    input int lane_mask,
    input int layer_id,
    input int layer_position,
    input int layer_degree,
    input int start_layer,
    input int edge0,
    input int edge1,
    input int qbuf,
    input int qslot,
    input int epoch,
    input int column0,
    input int column1,
    input int aux0,
    input int aux1,
    input int shift0,
    input int shift1
  );
    begin
      acc_issue_valid_i = 1'b1;
      acc_issue_lane_mask_i = lane_mask[1:0];
      acc_issue_layer_id_i = layer_id[5:0];
      acc_issue_layer_position_i = layer_position[5:0];
      acc_issue_layer_degree_i = layer_degree[5:0];
      acc_issue_start_layer_i = start_layer[0];
      acc_issue_edge0_id_i = edge0[4:0];
      acc_issue_edge1_id_i = edge1[4:0];
      acc_issue_qbuf_i = qbuf[0];
      acc_issue_qslot_i = qslot[3:0];
      acc_issue_iteration_epoch_i = epoch[3:0];
      acc_issue_base_column0_i = column0[6:0];
      acc_issue_base_column1_i = column1[6:0];
      acc_issue_aux0_i = aux0[3:0];
      acc_issue_aux1_i = aux1[3:0];
      acc_issue_shift0_i = shift0[SHIFT_W-1:0];
      acc_issue_shift1_i = shift1[SHIFT_W-1:0];
    end
  endtask

  task automatic drive_rec_issue(
    input int lane_mask,
    input int layer_id,
    input int edge0,
    input int edge1,
    input int qbuf,
    input int qslot,
    input int epoch,
    input int column0,
    input int column1,
    input int aux0,
    input int aux1,
    input int final0,
    input int final1,
    input int shift0,
    input int shift1
  );
    begin
      rec_issue_valid_i = 1'b1;
      rec_issue_lane_mask_i = lane_mask[1:0];
      rec_issue_layer_id_i = layer_id[5:0];
      rec_issue_edge0_id_i = edge0[4:0];
      rec_issue_edge1_id_i = edge1[4:0];
      rec_issue_qbuf_i = qbuf[0];
      rec_issue_qslot_i = qslot[3:0];
      rec_issue_iteration_epoch_i = epoch[3:0];
      rec_issue_base_column0_i = column0[6:0];
      rec_issue_base_column1_i = column1[6:0];
      rec_issue_aux0_i = aux0[3:0];
      rec_issue_aux1_i = aux1[3:0];
      rec_issue_final_touch0_i = final0[0];
      rec_issue_final_touch1_i = final1[0];
      rec_issue_shift0_i = shift0[SHIFT_W-1:0];
      rec_issue_shift1_i = shift1[SHIFT_W-1:0];
    end
  endtask

  task automatic idle_dut;
    begin
      acc_issue_valid_i = 1'b0;
      acc_issue_lane_mask_i = 2'b00;
      rec_issue_valid_i = 1'b0;
      rec_issue_lane_mask_i = 2'b00;
    end
  endtask

  task automatic reset_high_rate_counters;
    begin
      acc_issue_count = 0;
      rec_issue_count = 0;
      acc_edge_count = 0;
      rec_edge_count = 0;
      forward_allocations = 0;
      forwarded_reads = 0;
      normal_reads = 0;
      max_live_forward_entries = 0;
      same_bank_collisions = 0;
      high_rate_cycles = 71;
      source_oo_count = 0;
      source_of_count = 0;
      source_fo_count = 0;
      source_ff_count = 0;
      source_singleton_ordinary_count = 0;
    end
  endtask

  task automatic count_packed_source_mode(input logic [35:0] word);
    begin
      if (field_mask(word) == 2'b11) begin
        if ((field_aux0(word) == 0) && (field_aux1(word) == 0)) begin
          source_oo_count++;
        end else if ((field_aux0(word) == 0) && (field_aux1(word) != 0)) begin
          source_of_count++;
        end else if ((field_aux0(word) != 0) && (field_aux1(word) == 0)) begin
          source_fo_count++;
        end else begin
          source_ff_count++;
        end
      end else if ((field_mask(word) == 2'b01) && (field_aux0(word) == 0)) begin
        source_singleton_ordinary_count++;
      end else begin
        $display(
          "FAIL high_rate unexpected source mode mask=%0d aux0=%0d aux1=%0d",
          field_mask(word),
          field_aux0(word),
          field_aux1(word)
        );
        errors++;
      end
    end
  endtask

  function automatic int layer_position(input int layer);
    begin
      case (layer)
        1: layer_position = 0;
        3: layer_position = 1;
        2: layer_position = 2;
        0: layer_position = 3;
        default: layer_position = layer;
      endcase
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

  function automatic logic [35:0] acc_word_for_cycle(input int cycle);
    begin
      acc_word_for_cycle = 36'd0;
      case (cycle)
        0: acc_word_for_cycle = 36'h00000400f;
        1: acc_word_for_cycle = 36'h0000bdc1f;
        2: acc_word_for_cycle = 36'h00010c40f;
        3: acc_word_for_cycle = 36'h00019021f;
        4: acc_word_for_cycle = 36'h00021480f;
        5: acc_word_for_cycle = 36'h0002a8e1f;
        6: acc_word_for_cycle = 36'h00031cc0f;
        7: acc_word_for_cycle = 36'h00042500f;
        8: acc_word_for_cycle = 36'h00052d40f;
        9: acc_word_for_cycle = 36'h00063580f;
        10: acc_word_for_cycle = 36'h00073dc0f;
        11: acc_word_for_cycle = 36'h00084600f;
        12: acc_word_for_cycle = 36'h00090240b;
        13: acc_word_for_cycle = 36'h00098241b;
        18: acc_word_for_cycle = 36'h02138c41f;
        19: acc_word_for_cycle = 36'h0435a501f;
        21: acc_word_for_cycle = 36'h0078b401f;
        22: acc_word_for_cycle = 36'h020010417;
        23: acc_word_for_cycle = 36'h030498a1f;
        24: acc_word_for_cycle = 36'h060231017;
        25: acc_word_for_cycle = 36'h0006b161f;
        26: acc_word_for_cycle = 36'h0107c601f;
        27: acc_word_for_cycle = 36'h030145e17;
        34: acc_word_for_cycle = 36'h065529217;
        35: acc_word_for_cycle = 36'h070418a17;
        36: acc_word_for_cycle = 36'h001304017;
        37: acc_word_for_cycle = 36'h00381c617;
        38: acc_word_for_cycle = 36'h0062c9807;
        39: acc_word_for_cycle = 36'h07074a017;
        40: acc_word_for_cycle = 36'h0210a5007;
        41: acc_word_for_cycle = 36'h0431c6007;
        42: acc_word_for_cycle = 36'h000639a17;
        43: acc_word_for_cycle = 36'h000901613;
        44: acc_word_for_cycle = 36'h000980603;
        51: acc_word_for_cycle = 36'h065384007;
        52: acc_word_for_cycle = 36'h07059cc07;
        53: acc_word_for_cycle = 36'h0006ad407;
        54: acc_word_for_cycle = 36'h020494807;
        55: acc_word_for_cycle = 36'h0037b9a07;
        56: acc_word_for_cycle = 36'h0408bc407;
        default: acc_word_for_cycle = 36'd0;
      endcase
    end
  endfunction

  function automatic logic [35:0] rec_word_for_cycle(input int cycle);
    begin
      rec_word_for_cycle = 36'd0;
      case (cycle)
        15: rec_word_for_cycle = 36'h02110c40f;
        16: rec_word_for_cycle = 36'h04342500f;
        17: rec_word_for_cycle = 36'h06563580f;
        18: rec_word_for_cycle = 36'h08700400f;
        19: rec_word_for_cycle = 36'h01221480f;
        20: rec_word_for_cycle = 36'h04331cc0f;
        21: rec_word_for_cycle = 36'h06552d40f;
        22: rec_word_for_cycle = 36'h07873dc0f;
        23: rec_word_for_cycle = 36'h02184600f;
        24: rec_word_for_cycle = 36'h00390240b;
        29: rec_word_for_cycle = 36'h0210bdc1f;
        30: rec_word_for_cycle = 36'h04319021f;
        31: rec_word_for_cycle = 36'h0652a8e1f;
        32: rec_word_for_cycle = 36'h087498a1f;
        33: rec_word_for_cycle = 36'h0218b401f;
        34: rec_word_for_cycle = 36'h03438c41f;
        35: rec_word_for_cycle = 36'h0656b161f;
        36: rec_word_for_cycle = 36'h00798241b;
        37: rec_word_for_cycle = 36'h0215a501f;
        38: rec_word_for_cycle = 36'h0437c601f;
        46: rec_word_for_cycle = 36'h021010417;
        47: rec_word_for_cycle = 36'h043231017;
        48: rec_word_for_cycle = 36'h065304017;
        49: rec_word_for_cycle = 36'h087529217;
        50: rec_word_for_cycle = 36'h201145e17;
        51: rec_word_for_cycle = 36'h202418a17;
        52: rec_word_for_cycle = 36'h130639a17;
        53: rec_word_for_cycle = 36'h20474a017;
        54: rec_word_for_cycle = 36'h30081c617;
        55: rec_word_for_cycle = 36'h100901613;
        59: rec_word_for_cycle = 36'h3000a5007;
        60: rec_word_for_cycle = 36'h3001c6007;
        61: rec_word_for_cycle = 36'h3002c9807;
        62: rec_word_for_cycle = 36'h300384007;
        63: rec_word_for_cycle = 36'h300494807;
        64: rec_word_for_cycle = 36'h30059cc07;
        65: rec_word_for_cycle = 36'h3006ad407;
        66: rec_word_for_cycle = 36'h3007b9a07;
        67: rec_word_for_cycle = 36'h3008bc407;
        68: rec_word_for_cycle = 36'h100980603;
        default: rec_word_for_cycle = 36'd0;
      endcase
    end
  endfunction

  function automatic int high_rate_acc_start_layer(input int cycle, input logic [35:0] word);
    begin
      high_rate_acc_start_layer = field_valid(word)
          && ((cycle == 0) || (cycle == 1) || (cycle == 22) || (cycle == 38));
    end
  endfunction

  task automatic drive_acc_from_word(input int cycle, input logic [35:0] word);
    int col0;
    int col1;
    int sh0;
    int sh1;
    begin
      if (field_valid(word)) begin
        lookup_column_shift(field_layer(word), field_edge0(word), col0, sh0);
        if (field_mask(word) & 2) begin
          lookup_column_shift(field_layer(word), field_edge1(word), col1, sh1);
        end else begin
          col1 = 0;
          sh1 = 0;
        end
        drive_acc_issue(
          field_mask(word),
          field_layer(word),
          layer_position(field_layer(word)),
          19,
          high_rate_acc_start_layer(cycle, word),
          field_edge0(word),
          field_edge1(word),
          field_qbuf(word),
          field_qslot(word),
          6,
          col0,
          col1,
          field_aux0(word),
          field_aux1(word),
          sh0,
          sh1
        );
      end else begin
        acc_issue_valid_i = 1'b0;
        acc_issue_lane_mask_i = 2'b00;
      end
    end
  endtask

  task automatic drive_rec_from_word(input logic [35:0] word);
    int col0;
    int col1;
    int sh0;
    int sh1;
    begin
      if (field_valid(word)) begin
        lookup_column_shift(field_layer(word), field_edge0(word), col0, sh0);
        if (field_mask(word) & 2) begin
          lookup_column_shift(field_layer(word), field_edge1(word), col1, sh1);
        end else begin
          col1 = 0;
          sh1 = 0;
        end
        drive_rec_issue(
          field_mask(word),
          field_layer(word),
          field_edge0(word),
          field_edge1(word),
          field_qbuf(word),
          field_qslot(word),
          6,
          col0,
          col1,
          field_aux0(word),
          field_aux1(word),
          field_final0(word),
          field_final1(word),
          sh0,
          sh1
        );
      end else begin
        rec_issue_valid_i = 1'b0;
        rec_issue_lane_mask_i = 2'b00;
      end
    end
  endtask

  task automatic run_app_memory_directed;
    logic [P_VAL*W_APP-1:0] vec;
    logic [P_VAL*W_APP-1:0] vec2;
    begin
      reset_all();
      fill_app_vec(vec, 11);
      set_app_lane(vec, 7, -12);
      mem_load_valid = 1'b1;
      mem_load_column = 7'd5;
      mem_load_epoch = 4'd6;
      mem_load_app = vec;
      tick();
      mem_load_valid = 1'b0;
      mem_read_valid = 2'b01;
      mem_read_column0 = 7'd5;
      #1;
      check_int("app.load.read_accept", mem_read_accept[0], 1);
      check_int("app.load.lane0", lane_app(mem_read_app0, 0), 11);
      check_int("app.load.lane7", lane_app(mem_read_app0, 7), -12);
      check_int("app.load.bank", mem_read_bank0, 3);
      tick();
      directed_cases++;

      reset_all();
      fill_app_vec(vec, 21);
      fill_app_vec(vec2, -31);
      mem_load_valid = 1'b1;
      mem_load_column = 7'd1;
      mem_load_epoch = 4'd6;
      mem_load_app = vec;
      tick();
      mem_load_column = 7'd5;
      mem_load_app = vec2;
      tick();
      mem_load_valid = 1'b0;
      mem_read_valid = 2'b01;
      mem_read_column0 = 7'd1;
      mem_write_valid = 2'b01;
      mem_write_commit = 1'b1;
      mem_write_column0 = 7'd5;
      mem_write_epoch = 4'd6;
      mem_write_app0 = vec2;
      #1;
      check_int("app.same_bank.read_accept", mem_read_accept[0], 1);
      check_int("app.same_bank.collision", mem_collision, 1);
      check_int("app.same_bank.bank", mem_write_bank0, 3);
      tick();
      mem_write_valid = 2'b00;
      mem_write_commit = 1'b0;
      mem_read_column0 = 7'd5;
      #1;
      check_int("app.c4.pending_read", lane_app(mem_read_app0, 0), -31);
      tick();
      directed_cases++;

      reset_all();
      mem_read_valid = 2'b01;
      mem_read_column0 = 7'd4;
      #1;
      check_int("app.invalid_read.accept", mem_read_accept[0], 0);
      tick();
      check_bit("app.invalid_read.error", mem_error, 1'b1);
      directed_cases++;

      reset_all();
      fill_app_vec(vec, 127);
      set_app_lane(vec, 9, -128);
      mem_write_valid = 2'b01;
      mem_write_commit = 1'b1;
      mem_write_column0 = 7'd2;
      mem_write_epoch = 4'd6;
      mem_write_app0 = vec;
      #1;
      check_int("app.write.accept", mem_write_accept[0], 1);
      tick();
      mem_write_valid = 2'b00;
      mem_write_commit = 1'b0;
      mem_read_valid = 2'b01;
      mem_read_column0 = 7'd2;
      #1;
      check_int("app.saturation.positive", lane_app(mem_read_app0, 0), 127);
      check_int("app.saturation.negative", lane_app(mem_read_app0, 9), -128);
      tick();
      directed_cases++;

      reset_all();
      fill_app_vec(vec, 44);
      mem_load_valid = 1'b1;
      mem_load_column = 7'd7;
      mem_load_epoch = 4'd6;
      mem_load_app = vec;
      tick();
      mem_load_valid = 1'b0;
      mem_start_block = 1'b1;
      tick();
      mem_start_block = 1'b0;
      mem_read_valid = 2'b01;
      mem_read_column0 = 7'd7;
      #1;
      check_int("app.block_start.inaccessible", mem_read_accept[0], 0);
      tick();
      directed_cases++;
    end
  endtask

  task automatic fc_reserve_one(input int slot, input int column, input int epoch);
    begin
      fc_reserve_valid = 2'b01;
      fc_reserve_slot0 = slot[2:0];
      fc_reserve_column0 = column[6:0];
      fc_reserve_epoch = epoch[3:0];
    end
  endtask

  task automatic fc_publish_one(input int slot, input int column, input int epoch, input logic [P_VAL*W_APP-1:0] vec);
    begin
      fc_publish_valid = 2'b01;
      fc_publish_commit = 1'b1;
      fc_publish_slot0 = slot[2:0];
      fc_publish_column0 = column[6:0];
      fc_publish_epoch = epoch[3:0];
      fc_publish_app0 = vec;
    end
  endtask

  task automatic fc_read_one(input int slot, input int column, input int epoch);
    begin
      fc_read_valid = 2'b01;
      fc_read_slot0 = slot[2:0];
      fc_read_column0 = column[6:0];
      fc_read_epoch = epoch[3:0];
    end
  endtask

  task automatic run_forward_cache_directed;
    logic [P_VAL*W_APP-1:0] vec0;
    logic [P_VAL*W_APP-1:0] vec1;
    begin
      reset_all();
      fill_app_vec(vec0, 31);
      fc_reserve_one(0, 5, 6);
      #1;
      check_int("fwd.aux1_slot0.reserve", fc_reserve_accept[0], 1);
      check_int("fwd.reserve.live_count", fc_live_count, 1);
      tick();
      fc_reserve_valid = 2'b00;
      repeat (2) tick();
      fc_publish_one(0, 5, 6, vec0);
      fc_read_one(0, 5, 6);
      #1;
      check_int("fwd.c3.publish_accept", fc_alloc_accept[0], 1);
      check_int("fwd.c3.read_accept", fc_read_accept[0], 1);
      check_int("fwd.c3.payload", lane_app(fc_read_app0, 0), 31);
      tick();
      fc_publish_valid = 2'b00;
      fc_publish_commit = 1'b0;
      fc_read_one(0, 5, 6);
      #1;
      check_int("fwd.c4.stored_payload", lane_app(fc_read_app0, 0), 31);
      tick();
      fc_read_one(0, 5, 6);
      #1;
      check_int("fwd.retired", fc_read_accept[0], 0);
      tick();
      directed_cases++;

      reset_all();
      fill_app_vec(vec0, 71);
      fill_app_vec(vec1, -72);
      fc_reserve_valid = 2'b11;
      fc_reserve_slot0 = 3'd0;
      fc_reserve_slot1 = 3'd7;
      fc_reserve_column0 = 7'd0;
      fc_reserve_column1 = 7'd24;
      fc_reserve_epoch = 4'd6;
      #1;
      check_int("fwd.aux8_slot7.reserve", fc_reserve_accept, 3);
      tick();
      fc_reserve_valid = 2'b00;
      repeat (2) tick();
      fc_publish_valid = 2'b11;
      fc_publish_commit = 1'b1;
      fc_publish_slot0 = 3'd0;
      fc_publish_slot1 = 3'd7;
      fc_publish_column0 = 7'd0;
      fc_publish_column1 = 7'd24;
      fc_publish_epoch = 4'd6;
      fc_publish_app0 = vec0;
      fc_publish_app1 = vec1;
      fc_read_valid = 2'b11;
      fc_read_slot0 = 3'd0;
      fc_read_slot1 = 3'd7;
      fc_read_column0 = 7'd0;
      fc_read_column1 = 7'd24;
      fc_read_epoch = 4'd6;
      #1;
      check_int("fwd.both_lanes_accept", fc_read_accept, 3);
      check_int("fwd.both_lanes0", lane_app(fc_read_app0, 0), 71);
      check_int("fwd.both_lanes1", lane_app(fc_read_app1, 0), -72);
      tick();
      directed_cases++;

      reset_all();
      fill_app_vec(vec0, 40);
      fc_reserve_one(2, 8, 6);
      tick();
      fc_reserve_valid = 2'b00;
      repeat (2) tick();
      fc_publish_one(2, 8, 6, vec0);
      fc_read_one(2, 9, 6);
      #1;
      check_int("fwd.tag_mismatch.no_fallback", fc_read_accept[0], 0);
      tick();
      check_bit("fwd.tag_mismatch.error", fc_error, 1'b1);
      check_int("fwd.tag_mismatch.code", fc_error_code, 4);
      directed_cases++;

      reset_all();
      fill_app_vec(vec0, 41);
      fc_reserve_one(3, 8, 6);
      tick();
      fc_reserve_valid = 2'b00;
      repeat (2) tick();
      fc_publish_one(3, 8, 6, vec0);
      fc_read_one(3, 8, 7);
      #1;
      check_int("fwd.epoch_mismatch.reject", fc_read_accept[0], 0);
      tick();
      check_bit("fwd.epoch_mismatch.error", fc_error, 1'b1);
      check_int("fwd.epoch_mismatch.code", fc_error_code, 5);
      directed_cases++;

      reset_all();
      fc_read_one(4, 8, 6);
      #1;
      check_int("fwd.invalid_slot.reject", fc_read_accept[0], 0);
      tick();
      check_bit("fwd.invalid_slot.error", fc_error, 1'b1);
      check_int("fwd.invalid_slot.code", fc_error_code, 3);
      directed_cases++;

      reset_all();
      fc_reserve_one(5, 10, 6);
      tick();
      fc_reserve_one(5, 10, 6);
      #1;
      check_int("fwd.live_overwrite.reject", fc_reserve_accept[0], 0);
      tick();
      check_bit("fwd.live_overwrite.error", fc_error, 1'b1);
      check_int("fwd.live_overwrite.code", fc_error_code, 2);
      directed_cases++;

      reset_all();
      fill_app_vec(vec0, 52);
      fc_reserve_one(6, 11, 6);
      tick();
      fc_reserve_valid = 2'b00;
      repeat (2) tick();
      fc_publish_one(6, 11, 6, vec0);
      tick();
      fc_publish_valid = 2'b00;
      fc_publish_commit = 1'b0;
      fc_start_block = 1'b1;
      tick();
      fc_start_block = 1'b0;
      fc_read_one(6, 11, 6);
      #1;
      check_int("fwd.block_start_invalidates", fc_read_accept[0], 0);
      tick();
      directed_cases++;

      reset_all();
      fill_app_vec(vec0, 53);
      fc_reserve_one(6, 11, 6);
      tick();
      fc_reserve_valid = 2'b00;
      repeat (2) tick();
      fc_publish_one(6, 11, 6, vec0);
      tick();
      fc_publish_valid = 2'b00;
      fc_publish_commit = 1'b0;
      fc_advance_iteration = 1'b1;
      tick();
      fc_advance_iteration = 1'b0;
      fc_read_one(6, 11, 6);
      #1;
      check_int("fwd.advance_invalidates", fc_read_accept[0], 0);
      tick();
      directed_cases++;
    end
  endtask

  task automatic run_integrated_lane_modes;
    logic [P_VAL*W_APP-1:0] vec0;
    logic [P_VAL*W_APP-1:0] vec1;
    int wait_idx;
    int saw_singleton_qwrite;
    begin
      reset_all();
      fill_app_vec(vec0, 10);
      fill_app_vec(vec1, -20);
      load_dut_column(0, vec0);
      load_dut_column(1, vec1);
      drive_acc_issue(2'b11, 30, 0, 2, 1, 0, 1, 0, 0, 6, 0, 1, 0, 0, 0, 0);
      #1;
      check_int("dut.both_ordinary.source_valid", debug_acc_source_valid_o, 3);
      check_int("dut.both_ordinary.forwarded", debug_acc_source_forwarded_o, 0);
      tick();
      idle_dut();
      repeat (3) tick();
      check_bit("dut.both_ordinary.qwrite", debug_acc_q_write_valid_o, 1'b1);
      check_int("dut.both_ordinary.q0", lane_q(debug_acc_q_write_lane0_o, 0), 10);
      check_int("dut.both_ordinary.q1", lane_q(debug_acc_q_write_lane1_o, 0), -20);
      check_bit("dut.both_ordinary.no_error", storage_error_valid_o, 1'b0);
      directed_cases++;

      reset_all();
      fill_app_vec(vec0, 12);
      load_dut_column(0, vec0);
      drive_acc_issue(2'b01, 31, 1, 19, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0);
      #1;
      check_int("dut.singleton.source_valid", debug_acc_source_valid_o, 1);
      tick();
      idle_dut();
      saw_singleton_qwrite = 0;
      for (wait_idx = 0; wait_idx < 5; wait_idx++) begin
        tick();
        if (debug_acc_q_write_valid_o) begin
          saw_singleton_qwrite = 1;
          check_int("dut.singleton.q0", lane_q(debug_acc_q_write_lane0_o, 0), 12);
        end
      end
      check_int("dut.singleton.qwrite", saw_singleton_qwrite, 1);
      directed_cases++;
    end
  endtask

  task automatic run_numerical_dependency_test;
    logic [P_VAL*W_APP-1:0] v0;
    logic [P_VAL*W_APP-1:0] v1;
    logic [P_VAL*W_APP-1:0] v2;
    logic [P_VAL*W_APP-1:0] v3;
    int expected_lane0;
    int expected_lane5;
    int saw_dependent_qwrite;
    begin
      reset_all();
      fill_app_vec(v0, 10);
      set_app_lane(v0, 5, 99);
      fill_app_vec(v1, -20);
      fill_app_vec(v2, 3);
      fill_app_vec(v3, 40);
      load_dut_column(0, v0);
      load_dut_column(1, v1);
      load_dut_column(2, v2);
      load_dut_column(3, v3);

      drive_acc_issue(2'b11, 18, 0, 4, 1, 0, 1, 0, 0, 6, 0, 1, 0, 0, 0, 0);
      tick();
      drive_acc_issue(2'b11, 18, 0, 4, 0, 2, 3, 0, 1, 6, 2, 3, 0, 0, 0, 0);
      tick();
      idle_dut();
      tick();
      tick();

      drive_rec_issue(2'b11, 18, 0, 1, 0, 0, 6, 0, 1, 1, 0, 0, 0, 0, 0);
      #1;
      check_int("num.c0.no_publication", debug_rec_publication_valid_o[0], 0);
      check_int("num.c0.no_candidate", debug_forward_candidate_valid_o[0], 0);
      tick();
      idle_dut();
      tick();
      idle_dut();
      tick();
      drive_acc_issue(2'b11, 19, 1, 19, 1, 0, 1, 0, 2, 6, 0, 0, 1, 0, 5, 0);
      #1;
      check_int("num.c2.candidate_valid", debug_forward_candidate_valid_o[0], 1);
      check_int("num.c2.candidate_column", debug_forward_candidate_base_column0_o, 0);
      check_int("num.c2.candidate_epoch", debug_forward_candidate_iteration_epoch_o, 6);
      check_int("num.c2.candidate_slot", debug_forward_candidate_slot0_o, 0);
      check_int("num.c2.no_publication", debug_rec_publication_valid_o[0], 0);
      check_int("num.c2.forward_read_valid", debug_forward_read_valid_o[0], 1);
      check_int("num.c2.forward_read_accept", debug_forward_read_accept_o[0], 1);
      check_int("num.c2.source_forwarded", debug_acc_source_forwarded_o[0], 1);
      check_int("num.c2.source_valid", debug_acc_source_valid_o[0], 1);
      check_int("num.c2.same_cycle_ordinary_valid", debug_acc_source_valid_o[1], 1);
      check_int("num.c2.same_cycle_ordinary_not_forwarded", debug_acc_source_forwarded_o[1], 0);
      check_int("num.c2.same_cycle_ordinary_old_lane0", lane_app(debug_acc_source1_app_o, 0), 10);
      expected_lane0 = lane_app(debug_acc_source0_app_o, 0);
      expected_lane5 = lane_app(debug_acc_source0_app_o, 5);
      check_int("num.c2.candidate_app_matches_source", lane_app(debug_forward_candidate_app0_o, 0), expected_lane0);
      if (expected_lane0 == 10) begin
        $display("FAIL num.forward_payload_matches_old_lane0");
        errors++;
      end
      if (expected_lane5 == 99) begin
        $display("FAIL num.forward_payload_not_distinct");
        errors++;
      end
      tick();
      idle_dut();
      #1;
      check_int("num.c3.publication_valid", debug_rec_publication_valid_o[0], 1);
      check_int("num.c3.publication_forward_valid", rec_forward_valid_o[0], 1);
      check_int("num.c3.publication_column", rec_app_write_base_column0_o, 0);
      check_int("num.c3.publication_epoch", rec_app_write_iteration_epoch_o, 6);
      check_int("num.c3.publication_slot", rec_forward_slot0_o, 0);
      check_int("num.c3.publication_layer", rec_app_write_layer_id_o, 18);
      check_int("num.c3.publication_edge", rec_app_write_edge0_id_o, 0);
      check_int("num.c3.publication_app_matches_candidate", lane_app(rec_forward_app0_o, 0), expected_lane0);
      drive_acc_issue(2'b01, 19, 1, 19, 1, 0, 0, 0, 3, 6, 0, 0, 0, 0, 0, 0);
      #1;
      check_int("num.c3.ordinary_read_old", lane_app(debug_acc_source0_app_o, 0), 10);
      check_int("num.c3.ordinary_not_forwarded", debug_acc_source_forwarded_o[0], 0);
      idle_dut();
      tick();
      drive_acc_issue(2'b01, 19, 1, 19, 1, 0, 0, 0, 3, 6, 0, 0, 0, 0, 0, 0);
      #1;
      check_int("num.c4.ordinary_read_new", lane_app(debug_acc_source0_app_o, 0), expected_lane0);
      check_int("num.c4.ordinary_not_forwarded", debug_acc_source_forwarded_o[0], 0);
      idle_dut();
      saw_dependent_qwrite = 0;
      repeat (4) begin
        tick();
        if (debug_acc_q_write_valid_o && (debug_acc_q_write_qslot_o == 4'd2)) begin
          saw_dependent_qwrite = 1;
          check_int("num.forward_q_shift5", lane_q(debug_acc_q_write_lane0_o, 0), expected_lane5);
        end
      end
      check_int("num.dependent_q_write", saw_dependent_qwrite, 1);
      check_bit("num.no_acc_error", acc_error_valid_o, 1'b0);
      check_bit("num.no_storage_error", storage_error_valid_o, 1'b0);
      numerical_dependency_checks += 32;
      directed_cases++;
    end
  endtask

  task automatic load_direct_high_rate_columns;
    int column;
    logic [P_VAL*W_APP-1:0] vec;
    begin
      for (column = 0; column < 26; column++) begin
        fill_app_vec(vec, 20 + (column % 5));
        app_load_valid_i = 1'b0;
        mem_load_valid = 1'b1;
        mem_load_column = column[6:0];
        mem_load_epoch = 4'd6;
        mem_load_app = vec;
        tick();
      end
      mem_load_valid = 1'b0;
    end
  endtask

  task automatic load_dut_high_rate_columns;
    int column;
    logic [P_VAL*W_APP-1:0] vec;
    begin
      for (column = 0; column < 26; column++) begin
        fill_app_vec(vec, 20 + (column % 5));
        load_dut_column(column, vec);
      end
    end
  endtask

  task automatic run_standalone_high_rate_schedule;
    int cycle;
    int lane_edges;
    int col0;
    int col1;
    int sh_unused0;
    int sh_unused1;
    logic [35:0] acc_word;
    logic [35:0] rec_word;
    logic [35:0] publication_word;
    logic [P_VAL*W_APP-1:0] publish_vec0;
    logic [P_VAL*W_APP-1:0] publish_vec1;
    begin
      reset_all();
      load_direct_high_rate_columns();
      reset_high_rate_counters();

      for (cycle = 0; cycle <= 74; cycle++) begin
        acc_word = acc_word_for_cycle(cycle);
        rec_word = rec_word_for_cycle(cycle);
        publication_word = rec_word_for_cycle(cycle - 3);
        idle_dut();
        mem_read_valid = 2'b00;
        mem_write_valid = 2'b00;
        mem_write_commit = 1'b0;
        fc_reserve_valid = 2'b00;
        fc_publish_valid = 2'b00;
        fc_publish_commit = 1'b0;
        fc_read_valid = 2'b00;

        if (field_valid(acc_word)) begin
          lookup_column_shift(field_layer(acc_word), field_edge0(acc_word), col0, sh_unused0);
          if (field_aux0(acc_word) == 0) begin
            mem_read_valid[0] = 1'b1;
            mem_read_column0 = col0[6:0];
          end else begin
            fc_read_valid[0] = 1'b1;
            fc_read_slot0 = field_aux0(acc_word) - 1;
            fc_read_column0 = col0[6:0];
            fc_read_epoch = 4'd6;
          end

          if (field_mask(acc_word) & 2) begin
            lookup_column_shift(field_layer(acc_word), field_edge1(acc_word), col1, sh_unused1);
            if (field_aux1(acc_word) == 0) begin
              mem_read_valid[1] = 1'b1;
              mem_read_column1 = col1[6:0];
            end else begin
              fc_read_valid[1] = 1'b1;
              fc_read_slot1 = field_aux1(acc_word) - 1;
              fc_read_column1 = col1[6:0];
              fc_read_epoch = 4'd6;
            end
          end
        end

        if (field_valid(publication_word)) begin
          fill_app_vec(publish_vec0, 30 + (cycle % 17));
          fill_app_vec(publish_vec1, -30 - (cycle % 17));
          lookup_column_shift(field_layer(publication_word), field_edge0(publication_word), col0, sh_unused0);
          mem_write_valid[0] = field_mask(publication_word) & 1;
          mem_write_column0 = col0[6:0];
          mem_write_epoch = 4'd6;
          mem_write_app0 = publish_vec0;
          if (field_aux0(publication_word) != 0) begin
            fc_publish_valid[0] = 1'b1;
            fc_publish_slot0 = field_aux0(publication_word) - 1;
            fc_publish_column0 = col0[6:0];
            fc_publish_epoch = 4'd6;
            fc_publish_app0 = publish_vec0;
          end

          if (field_mask(publication_word) & 2) begin
            lookup_column_shift(field_layer(publication_word), field_edge1(publication_word), col1, sh_unused1);
            mem_write_valid[1] = 1'b1;
            mem_write_column1 = col1[6:0];
            mem_write_app1 = publish_vec1;
            if (field_aux1(publication_word) != 0) begin
              fc_publish_valid[1] = 1'b1;
              fc_publish_slot1 = field_aux1(publication_word) - 1;
              fc_publish_column1 = col1[6:0];
              fc_publish_epoch = 4'd6;
              fc_publish_app1 = publish_vec1;
            end
          end
          mem_write_commit = |mem_write_valid;
          fc_publish_commit = |fc_publish_valid;
        end

        if (field_valid(rec_word)) begin
          lookup_column_shift(field_layer(rec_word), field_edge0(rec_word), col0, sh_unused0);
          if (field_aux0(rec_word) != 0) begin
            fc_reserve_valid[0] = 1'b1;
            fc_reserve_slot0 = field_aux0(rec_word) - 1;
            fc_reserve_column0 = col0[6:0];
            fc_reserve_epoch = 4'd6;
          end
          if (field_mask(rec_word) & 2) begin
            lookup_column_shift(field_layer(rec_word), field_edge1(rec_word), col1, sh_unused1);
            if (field_aux1(rec_word) != 0) begin
              fc_reserve_valid[1] = 1'b1;
              fc_reserve_slot1 = field_aux1(rec_word) - 1;
              fc_reserve_column1 = col1[6:0];
              fc_reserve_epoch = 4'd6;
            end
          end
        end
        #1;

        if (field_valid(acc_word)) begin
          count_packed_source_mode(acc_word);
          acc_issue_count++;
          lane_edges = (field_mask(acc_word) & 1) + ((field_mask(acc_word) >> 1) & 1);
          acc_edge_count += lane_edges;
          if (field_aux0(acc_word) == 0) begin
            normal_reads++;
            check_int("high_rate.mem0_accept", mem_read_accept[0], 1);
          end else begin
            forwarded_reads++;
            check_int("high_rate.forward0_accept", fc_read_accept[0], 1);
          end
          if (field_mask(acc_word) & 2) begin
            if (field_aux1(acc_word) == 0) begin
              normal_reads++;
              check_int("high_rate.mem1_accept", mem_read_accept[1], 1);
            end else begin
              forwarded_reads++;
              check_int("high_rate.forward1_accept", fc_read_accept[1], 1);
            end
          end
        end

        if (field_valid(rec_word)) begin
          rec_issue_count++;
          lane_edges = (field_mask(rec_word) & 1) + ((field_mask(rec_word) >> 1) & 1);
          rec_edge_count += lane_edges;
        end

        forward_allocations += fc_publish_valid[0] + fc_publish_valid[1];
        if (fc_live_count > max_live_forward_entries) begin
          max_live_forward_entries = fc_live_count;
        end
        if (mem_collision) begin
          same_bank_collisions++;
          if (!((cycle == 21) || (cycle == 37) || (cycle == 53) || (cycle == 56))) begin
            $display("FAIL high_rate unexpected same-bank collision cycle=%0d", cycle);
            errors++;
          end
        end

        tick();
        if (mem_error || fc_error) begin
          $display(
            "FAIL high_rate storage error cycle=%0d mem=%0b/%0d fwd=%0b/%0d",
            cycle,
            mem_error,
            mem_error_code,
            fc_error,
            fc_error_code
          );
          errors++;
        end
      end

      check_int("high_rate.decoder_cycles", high_rate_cycles, 71);
      check_int("high_rate.acc_issue_cycles", acc_issue_count, 40);
      check_int("high_rate.rec_issue_cycles", rec_issue_count, 40);
      check_int("high_rate.acc_edges", acc_edge_count, 76);
      check_int("high_rate.rec_edges", rec_edge_count, 76);
      check_int("high_rate.forward_allocations", forward_allocations, 50);
      check_int("high_rate.forwarded_reads", forwarded_reads, 27);
      check_int("high_rate.normal_reads", normal_reads, 49);
      check_int("high_rate.max_live", max_live_forward_entries, 8);
      check_int("high_rate.same_bank_collisions", same_bank_collisions, 4);
      check_int("high_rate.source_oo", source_oo_count, 15);
      check_int("high_rate.source_of", source_of_count, 10);
      check_int("high_rate.source_fo", source_fo_count, 5);
      check_int("high_rate.source_ff", source_ff_count, 6);
      check_int("high_rate.source_singleton_ordinary", source_singleton_ordinary_count, 4);
      directed_cases++;
    end
  endtask

  task automatic check_no_dut_errors(input string name, input int cycle);
    begin
      if (acc_error_valid_o || rec_error_valid_o || q_scratch_error_valid_o
          || check_state_error_valid_o || old_state_alignment_error_o
          || unsafe_advance_error_o || phase6_storage_error_valid_o
          || app_memory_error_valid_o || forward_error_valid_o
          || app_forward_error_valid_o || storage_error_valid_o) begin
        $display(
          "FAIL %s cycle=%0d acc=%0b rec=%0b q=%0b/%0d check=%0b/%0d old_align=%0b unsafe=%0b phase6=%0b app=%0b/%0d fwd=%0b/%0d app_fwd=%0b storage=%0b",
          name,
          cycle,
          acc_error_valid_o,
          rec_error_valid_o,
          q_scratch_error_valid_o,
          q_scratch_error_code_o,
          check_state_error_valid_o,
          check_state_error_code_o,
          old_state_alignment_error_o,
          unsafe_advance_error_o,
          phase6_storage_error_valid_o,
          app_memory_error_valid_o,
          app_memory_error_code_o,
          forward_error_valid_o,
          forward_error_code_o,
          app_forward_error_valid_o,
          storage_error_valid_o
        );
        errors++;
      end
    end
  endtask

  task automatic run_integrated_high_rate_schedule;
    int cycle;
    int lane_edges;
    int expected_forwarded0;
    int expected_forwarded1;
    int source_valid_expected;
    logic [35:0] acc_word;
    logic [35:0] rec_word;
    begin
      reset_all();
      load_dut_high_rate_columns();
      reset_high_rate_counters();

      for (cycle = 0; cycle <= 74; cycle++) begin
        acc_word = acc_word_for_cycle(cycle);
        rec_word = rec_word_for_cycle(cycle);
        idle_dut();
        app_load_valid_i = 1'b0;
        drive_acc_from_word(cycle, acc_word);
        drive_rec_from_word(rec_word);
        #1;

        if (field_valid(acc_word)) begin
          acc_issue_count++;
          lane_edges = (field_mask(acc_word) & 1) + ((field_mask(acc_word) >> 1) & 1);
          acc_edge_count += lane_edges;
          count_packed_source_mode(acc_word);
          source_valid_expected = field_mask(acc_word);
          expected_forwarded0 = (field_aux0(acc_word) != 0);
          expected_forwarded1 = ((field_mask(acc_word) & 2) != 0) && (field_aux1(acc_word) != 0);
          check_int("integrated.acc_ready", acc_issue_ready_o, 1);
          check_int("integrated.source_valid", debug_acc_source_valid_o, source_valid_expected);
          check_int("integrated.source_forwarded0", debug_acc_source_forwarded_o[0], expected_forwarded0);
          check_int("integrated.source_forwarded1", debug_acc_source_forwarded_o[1], expected_forwarded1);
          forwarded_reads += expected_forwarded0 + expected_forwarded1;
          normal_reads += lane_edges - expected_forwarded0 - expected_forwarded1;
        end

        if (field_valid(rec_word)) begin
          rec_issue_count++;
          lane_edges = (field_mask(rec_word) & 1) + ((field_mask(rec_word) >> 1) & 1);
          rec_edge_count += lane_edges;
          check_int("integrated.rec_ready", rec_issue_ready_o, 1);
        end

        forward_allocations += debug_forward_alloc_valid_o[0] + debug_forward_alloc_valid_o[1];
        check_int("integrated.forward_alloc_accept", debug_forward_alloc_accept_o, debug_forward_alloc_valid_o);

        if (debug_forward_live_count_o > max_live_forward_entries) begin
          max_live_forward_entries = debug_forward_live_count_o;
        end

        if (debug_app_same_bank_collision_o) begin
          same_bank_collisions++;
          if (!((cycle == 21) || (cycle == 37) || (cycle == 53) || (cycle == 56))) begin
            $display("FAIL integrated unexpected same-bank collision cycle=%0d", cycle);
            errors++;
          end
        end

        check_no_dut_errors("integrated.pre_tick", cycle);
        tick();
        idle_dut();
        #1;
        check_no_dut_errors("integrated.post_tick", cycle);
      end

      idle_dut();
      check_int("integrated.decoder_cycles", high_rate_cycles, 71);
      check_int("integrated.acc_issue_cycles", acc_issue_count, 40);
      check_int("integrated.rec_issue_cycles", rec_issue_count, 40);
      check_int("integrated.acc_edges", acc_edge_count, 76);
      check_int("integrated.rec_edges", rec_edge_count, 76);
      check_int("integrated.forward_allocations", forward_allocations, 50);
      check_int("integrated.forwarded_reads", forwarded_reads, 27);
      check_int("integrated.normal_reads", normal_reads, 49);
      check_int("integrated.max_live", max_live_forward_entries, 8);
      check_int("integrated.same_bank_collisions", same_bank_collisions, 4);
      check_int("integrated.source_oo", source_oo_count, 15);
      check_int("integrated.source_of", source_of_count, 10);
      check_int("integrated.source_fo", source_fo_count, 5);
      check_int("integrated.source_ff", source_ff_count, 6);
      check_int("integrated.source_singleton_ordinary", source_singleton_ordinary_count, 4);
      directed_cases++;
    end
  endtask

  initial begin
    int selected_case;
    clk_i = 1'b0;
    rst_i = 1'b0;
    errors = 0;
    directed_cases = 0;
    numerical_dependency_checks = 0;
    acc_issue_count = 0;
    rec_issue_count = 0;
    acc_edge_count = 0;
    rec_edge_count = 0;
    forward_allocations = 0;
    forwarded_reads = 0;
    normal_reads = 0;
    max_live_forward_entries = 0;
    same_bank_collisions = 0;
    high_rate_cycles = 0;
    source_oo_count = 0;
    source_of_count = 0;
    source_fo_count = 0;
    source_ff_count = 0;
    source_singleton_ordinary_count = 0;
    if (!$value$plusargs("phase7_case=%d", selected_case)) begin
      selected_case = 0;
    end

    if (P != 384 || B != 2 || D_A != 3 || D_R != 3 || NUM_APP_BANKS != 8 || FORWARD_DEPTH != 8) begin
      $display("FAIL frozen Phase-7 constants");
      errors++;
    end

    reset_all();
    case (selected_case)
      0: begin
        run_app_memory_directed();
        run_forward_cache_directed();
        run_integrated_lane_modes();
        run_numerical_dependency_test();
        run_standalone_high_rate_schedule();
        run_integrated_high_rate_schedule();
      end
      1: run_app_memory_directed();
      2: run_forward_cache_directed();
      3: run_integrated_lane_modes();
      4: run_numerical_dependency_test();
      5: run_standalone_high_rate_schedule();
      6: run_integrated_high_rate_schedule();
      default: begin
        $display("FAIL unknown phase7_case=%0d", selected_case);
        errors++;
      end
    endcase

    if (errors == 0) begin
      $display("PASS phase7 app forward integration");
      $display("phase7_case=%0d", selected_case);
      $display("directed_cases=%0d numerical_dependency_checks=%0d", directed_cases, numerical_dependency_checks);
      $display("high_rate_acc_issue_cycles=%0d high_rate_rec_issue_cycles=%0d", acc_issue_count, rec_issue_count);
      $display("high_rate_acc_active_edges=%0d high_rate_rec_active_edges=%0d", acc_edge_count, rec_edge_count);
      $display("forward_allocations=%0d forwarded_reads=%0d normal_reads=%0d max_live_forward_entries=%0d", forward_allocations, forwarded_reads, normal_reads, max_live_forward_entries);
      $display("same_bank_collisions=%0d decoder_cycles=%0d", same_bank_collisions, high_rate_cycles);
      $display("source_modes OO=%0d OF=%0d FO=%0d FF=%0d singleton_ordinary_lane0=%0d", source_oo_count, source_of_count, source_fo_count, source_ff_count, source_singleton_ordinary_count);
      $finish;
    end

    $display("FAIL phase7 app forward integration errors=%0d", errors);
    $finish(1);
  end
endmodule
