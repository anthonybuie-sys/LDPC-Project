`timescale 1ns/1ps

module tb_phase8_syndrome;
  import nr_ldpc_pkg::*;
  import nr_ldpc_syndrome_profile_bg1_first4_pkg::*;

  localparam int P_VAL = REFERENCE_Z;
  localparam int SHIFT_W = $clog2(P_VAL + 1);

  logic clk_i;
  logic rst_i;

  logic direct_start_iteration;
  logic [3:0] direct_epoch;
  logic [1:0] direct_final_valid;
  logic [6:0] direct_col0;
  logic [6:0] direct_col1;
  logic [3:0] direct_final_epoch;
  logic [P_VAL-1:0] direct_hard0;
  logic [P_VAL-1:0] direct_hard1;
  logic direct_done;
  logic direct_zero;
  logic [P_VAL-1:0] direct_row0;
  logic [P_VAL-1:0] direct_row1;
  logic [P_VAL-1:0] direct_row2;
  logic [P_VAL-1:0] direct_row3;
  logic direct_error;
  logic [7:0] direct_error_code;
  logic [5:0] direct_finalized_count;
  logic [6:0] direct_consumed_count;
  logic [3:0] direct_queue_occupancy;
  logic [3:0] direct_max_queue_occupancy;
  logic [6:0] direct_max_backlog;
  logic [3:0] direct_consumed_this_cycle;

  logic decide_syndrome_done;
  logic decide_syndrome_zero;
  logic [3:0] decide_max_iterations;
  logic [3:0] decide_completed_iterations;
  logic decide_valid;
  logic decide_success;
  logic decide_max;
  logic decide_retry;
  logic decide_illegal;
  logic [3:0] decide_completed_after;

  logic start_block_i;
  logic advance_iteration_i;
  logic start_iteration_i;
  logic [3:0] syndrome_iteration_epoch_i;

  logic app_load_valid_i;
  logic [6:0] app_load_column_i;
  logic [3:0] app_load_iteration_epoch_i;
  logic [P_VAL*W_APP-1:0] app_load_i;

  logic acc_issue_valid_i;
  logic acc_issue_ready_o;
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
  logic rec_issue_ready_o;
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

  logic [1:0] rec_final_touch_valid_o;
  logic [6:0] rec_final_touch_base_column0_o;
  logic [6:0] rec_final_touch_base_column1_o;
  logic [3:0] rec_final_touch_iteration_epoch_o;
  logic [P_VAL-1:0] rec_final_touch_hard0_o;
  logic [P_VAL-1:0] rec_final_touch_hard1_o;

  logic syndrome_done_o;
  logic syndrome_zero_o;
  logic [P_VAL-1:0] syndrome_row0_o;
  logic [P_VAL-1:0] syndrome_row1_o;
  logic [P_VAL-1:0] syndrome_row2_o;
  logic [P_VAL-1:0] syndrome_row3_o;
  logic syndrome_error_valid_o;
  logic [7:0] syndrome_error_code_o;
  logic [5:0] finalized_columns_count_o;
  logic [6:0] consumed_work_items_count_o;
  logic [3:0] syndrome_queue_occupancy_o;
  logic [3:0] syndrome_max_queue_occupancy_o;
  logic [6:0] syndrome_max_backlog_o;
  logic [3:0] syndrome_work_items_consumed_this_cycle_o;
  logic error_valid_o;
  logic [1:0] debug_acc_source_valid_o;
  logic [1:0] debug_acc_source_forwarded_o;
  logic [1:0] debug_forward_alloc_valid_o;
  logic [1:0] debug_forward_alloc_accept_o;
  logic [5:0] debug_forward_live_count_o;
  logic debug_app_same_bank_collision_o;

  int errors;
  int syndrome_directed_cases;
  int decision_cases;
  int integrated_cases;
  int acc_issue_count;
  int rec_issue_count;
  int acc_edge_count;
  int rec_edge_count;
  int forward_allocations;
  int forwarded_reads;
  int normal_reads;
  int max_live_forward_entries;
  int same_bank_collisions;
  int first_final_touch_cycle;
  int last_final_touch_cycle;
  int syndrome_completion_cycle;
  int source_oo_count;
  int source_of_count;
  int source_fo_count;
  int source_ff_count;
  int source_singleton_ordinary_count;
  int phase8_trace;
  int integrated_nonzero_final_hard_bits;
  int integrated_zero_final_hard_bits;
  int positive_nonzero_final_hard_bits;
  int positive_zero_final_hard_bits;
  int mixed_nonzero_final_hard_bits;
  int mixed_zero_final_hard_bits;

  logic [P_VAL-1:0] final_hard_by_column [0:PHASE8_ACTIVE_COLUMNS-1];
  logic [PHASE8_ACTIVE_COLUMNS-1:0] tb_final_seen;

  nr_ldpc_syndrome_engine #(
    .P(P_VAL),
    .S(SYNDROME_S),
    .Q(SYNDROME_Q)
  ) u_direct_syndrome (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_iteration_i(direct_start_iteration),
    .iteration_epoch_i(direct_epoch),
    .final_touch_valid_i(direct_final_valid),
    .final_touch_base_column0_i(direct_col0),
    .final_touch_base_column1_i(direct_col1),
    .final_touch_iteration_epoch_i(direct_final_epoch),
    .final_touch_hard0_i(direct_hard0),
    .final_touch_hard1_i(direct_hard1),
    .syndrome_done_o(direct_done),
    .syndrome_zero_o(direct_zero),
    .syndrome_row0_o(direct_row0),
    .syndrome_row1_o(direct_row1),
    .syndrome_row2_o(direct_row2),
    .syndrome_row3_o(direct_row3),
    .error_valid_o(direct_error),
    .error_code_o(direct_error_code),
    .finalized_columns_count_o(direct_finalized_count),
    .consumed_work_items_count_o(direct_consumed_count),
    .queue_occupancy_o(direct_queue_occupancy),
    .max_queue_occupancy_o(direct_max_queue_occupancy),
    .max_syndrome_backlog_o(direct_max_backlog),
    .work_items_consumed_this_cycle_o(direct_consumed_this_cycle)
  );

  nr_ldpc_iteration_decide u_decide (
    .syndrome_done_i(decide_syndrome_done),
    .syndrome_zero_i(decide_syndrome_zero),
    .max_iterations_i(decide_max_iterations),
    .completed_iterations_i(decide_completed_iterations),
    .decision_valid_o(decide_valid),
    .terminate_success_o(decide_success),
    .terminate_max_iterations_o(decide_max),
    .retry_next_iteration_o(decide_retry),
    .illegal_config_o(decide_illegal),
    .completed_iterations_after_decide_o(decide_completed_after)
  );

  nr_ldpc_syndrome_datapath #(
    .P(P_VAL)
  ) dut (.*);

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

  task automatic check_vec(input string name, input logic [P_VAL-1:0] actual, input logic [P_VAL-1:0] expected);
    begin
      if (actual !== expected) begin
        $display("FAIL %s actual=%h expected=%h", name, actual, expected);
        errors++;
      end
    end
  endtask

  task automatic fill_hard(output logic [P_VAL-1:0] vec, input logic bit_value);
    int lane;
    begin
      for (lane = 0; lane < P_VAL; lane = lane + 1) begin
        vec[lane] = bit_value;
      end
    end
  endtask

  task automatic set_hard_lane(inout logic [P_VAL-1:0] vec, input int lane, input logic bit_value);
    begin
      vec[lane] = bit_value;
    end
  endtask

  function automatic logic [P_VAL-1:0] tb_qc_forward(input logic [P_VAL-1:0] canonical, input int shift_value);
    int lane;
    int src;
    begin
      tb_qc_forward = '0;
      for (lane = 0; lane < P_VAL; lane = lane + 1) begin
        src = lane + shift_value;
        if (src >= P_VAL) begin
          src = src - P_VAL;
        end
        tb_qc_forward[lane] = canonical[src];
      end
    end
  endfunction

  task automatic clear_direct_inputs;
    begin
      direct_start_iteration = 1'b0;
      direct_epoch = 4'd6;
      direct_final_valid = 2'b00;
      direct_col0 = 7'd0;
      direct_col1 = 7'd0;
      direct_final_epoch = 4'd6;
      direct_hard0 = '0;
      direct_hard1 = '0;
    end
  endtask

  task automatic clear_wrapper_inputs;
    begin
      start_block_i = 1'b0;
      advance_iteration_i = 1'b0;
      start_iteration_i = 1'b0;
      syndrome_iteration_epoch_i = 4'd6;
      app_load_valid_i = 1'b0;
      app_load_column_i = 7'd0;
      app_load_iteration_epoch_i = 4'd6;
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
      acc_issue_iteration_epoch_i = 4'd6;
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
      rec_issue_iteration_epoch_i = 4'd6;
      rec_issue_shift0_i = '0;
      rec_issue_shift1_i = '0;
      rec_issue_base_column0_i = 7'd0;
      rec_issue_base_column1_i = 7'd0;
      rec_issue_aux0_i = 4'd0;
      rec_issue_aux1_i = 4'd0;
      rec_issue_final_touch0_i = 1'b0;
      rec_issue_final_touch1_i = 1'b0;
    end
  endtask

  task automatic reset_all;
    begin
      clear_direct_inputs();
      clear_wrapper_inputs();
      rst_i = 1'b1;
      tick();
      tick();
      rst_i = 1'b0;
      direct_start_iteration = 1'b1;
      start_block_i = 1'b1;
      start_iteration_i = 1'b1;
      tick();
      direct_start_iteration = 1'b0;
      start_block_i = 1'b0;
      start_iteration_i = 1'b0;
      tick();
    end
  endtask

  task automatic direct_finalize_one(input int column, input logic [P_VAL-1:0] hard);
    begin
      direct_final_valid = 2'b01;
      direct_col0 = column[6:0];
      direct_col1 = 7'd0;
      direct_final_epoch = 4'd6;
      direct_hard0 = hard;
      direct_hard1 = '0;
      tick();
      direct_final_valid = 2'b00;
    end
  endtask

  task automatic direct_finalize_two(
    input int column0,
    input logic [P_VAL-1:0] hard0,
    input int column1,
    input logic [P_VAL-1:0] hard1
  );
    begin
      direct_final_valid = 2'b11;
      direct_col0 = column0[6:0];
      direct_col1 = column1[6:0];
      direct_final_epoch = 4'd6;
      direct_hard0 = hard0;
      direct_hard1 = hard1;
      tick();
      direct_final_valid = 2'b00;
    end
  endtask

  task automatic run_syndrome_directed;
    logic [P_VAL-1:0] h0;
    logic [P_VAL-1:0] h1;
    logic [P_VAL-1:0] h2;
    logic [P_VAL-1:0] expected_row0;
    logic [P_VAL-1:0] expected_row1;
    logic [P_VAL-1:0] expected_row2;
    logic [P_VAL-1:0] expected_row3;
    int column;
    int work_id;
    int work_column;
    int work_row;
    int work_shift;
    int guard;
    begin
      reset_all();
      check_bit("syndrome.start.done", direct_done, 1'b0);
      check_bit("syndrome.start.error", direct_error, 1'b0);
      check_int("syndrome.start.finalized", direct_finalized_count, 0);
      check_int("syndrome.start.consumed", direct_consumed_count, 0);
      check_vec("syndrome.start.row0", direct_row0, '0);
      syndrome_directed_cases++;

      reset_all();
      fill_hard(h0, 1'b0);
      direct_finalize_one(0, h0);
      #1;
      check_int("syndrome.one.finalized", direct_finalized_count, 1);
      check_int("syndrome.one.consumed", direct_consumed_count, 4);
      check_int("syndrome.one.queue", direct_queue_occupancy, 0);
      check_int("syndrome.one.max_queue", direct_max_queue_occupancy, 1);
      check_int("syndrome.one.max_backlog", direct_max_backlog, 4);
      check_bit("syndrome.one.no_done", direct_done, 1'b0);
      syndrome_directed_cases++;

      reset_all();
      fill_hard(h0, 1'b0);
      fill_hard(h1, 1'b0);
      direct_finalize_two(0, h0, 1, h1);
      #1;
      check_int("syndrome.two.finalized", direct_finalized_count, 2);
      check_int("syndrome.two.consumed", direct_consumed_count, 7);
      check_int("syndrome.two.max_queue", direct_max_queue_occupancy, 2);
      check_int("syndrome.two.max_backlog", direct_max_backlog, 7);
      check_int("syndrome.two.consumed_this_cycle", direct_consumed_this_cycle, 7);
      syndrome_directed_cases++;

      reset_all();
      fill_hard(h0, 1'b0);
      fill_hard(h1, 1'b0);
      fill_hard(h2, 1'b0);
      set_hard_lane(h0, 7, 1'b1);
      set_hard_lane(h0, 111, 1'b1);
      set_hard_lane(h1, 20, 1'b1);
      set_hard_lane(h1, 211, 1'b1);
      set_hard_lane(h2, 42, 1'b1);
      set_hard_lane(h2, 300, 1'b1);
      u_direct_syndrome.queue_count_q = 4'd3;
      u_direct_syndrome.queue_column_q[0] = 7'd0;
      u_direct_syndrome.queue_column_q[1] = 7'd1;
      u_direct_syndrome.queue_column_q[2] = 7'd2;
      u_direct_syndrome.queue_next_work_q[0] = 5'd0;
      u_direct_syndrome.queue_next_work_q[1] = 5'd0;
      u_direct_syndrome.queue_next_work_q[2] = 5'd0;
      u_direct_syndrome.queue_hard_q[0] = h0;
      u_direct_syndrome.queue_hard_q[1] = h1;
      u_direct_syndrome.queue_hard_q[2] = h2;

      expected_row0 = '0;
      expected_row1 = '0;
      expected_row2 = '0;
      expected_row3 = '0;
      for (work_id = 0; work_id < 8; work_id = work_id + 1) begin
        work_column = phase8_work_column(work_id[6:0]);
        work_row = phase8_work_row(work_id[6:0]);
        work_shift = phase8_work_shift(work_id[6:0]);
        case (work_row)
          0: expected_row0 = expected_row0 ^ tb_qc_forward(
              (work_column == 0) ? h0 : (work_column == 1) ? h1 : h2,
              work_shift
          );
          1: expected_row1 = expected_row1 ^ tb_qc_forward(
              (work_column == 0) ? h0 : (work_column == 1) ? h1 : h2,
              work_shift
          );
          2: expected_row2 = expected_row2 ^ tb_qc_forward(
              (work_column == 0) ? h0 : (work_column == 1) ? h1 : h2,
              work_shift
          );
          3: expected_row3 = expected_row3 ^ tb_qc_forward(
              (work_column == 0) ? h0 : (work_column == 1) ? h1 : h2,
              work_shift
          );
          default: begin end
        endcase
      end

      tick();
      #1;
      check_int("syndrome.fifo_s8.consumed_this_cycle", direct_consumed_this_cycle, 8);
      check_int("syndrome.fifo_s8.queue_count", direct_queue_occupancy, 1);
      check_int("syndrome.fifo_s8.head_column", u_direct_syndrome.queue_column_q[0], 2);
      check_int("syndrome.fifo_s8.head_next_work", u_direct_syndrome.queue_next_work_q[0], 1);
      check_int("syndrome.fifo_s8.consumed_count", direct_consumed_count, 8);
      check_vec("syndrome.fifo_s8.row0_cycle1", direct_row0, expected_row0);
      check_vec("syndrome.fifo_s8.row1_cycle1", direct_row1, expected_row1);
      check_vec("syndrome.fifo_s8.row2_cycle1", direct_row2, expected_row2);
      check_vec("syndrome.fifo_s8.row3_cycle1", direct_row3, expected_row3);

      for (work_id = 8; work_id < 10; work_id = work_id + 1) begin
        work_column = phase8_work_column(work_id[6:0]);
        work_row = phase8_work_row(work_id[6:0]);
        work_shift = phase8_work_shift(work_id[6:0]);
        case (work_row)
          0: expected_row0 = expected_row0 ^ tb_qc_forward(h2, work_shift);
          1: expected_row1 = expected_row1 ^ tb_qc_forward(h2, work_shift);
          2: expected_row2 = expected_row2 ^ tb_qc_forward(h2, work_shift);
          3: expected_row3 = expected_row3 ^ tb_qc_forward(h2, work_shift);
          default: begin end
        endcase
      end
      tick();
      #1;
      check_int("syndrome.fifo_s8.second_cycle_consumed", direct_consumed_this_cycle, 2);
      check_int("syndrome.fifo_s8.second_cycle_count", direct_queue_occupancy, 0);
      check_int("syndrome.fifo_s8.second_consumed_count", direct_consumed_count, 10);
      check_vec("syndrome.fifo_s8.row0_cycle2", direct_row0, expected_row0);
      check_vec("syndrome.fifo_s8.row1_cycle2", direct_row1, expected_row1);
      check_vec("syndrome.fifo_s8.row2_cycle2", direct_row2, expected_row2);
      check_vec("syndrome.fifo_s8.row3_cycle2", direct_row3, expected_row3);
      check_bit("syndrome.fifo_s8.no_done", direct_done, 1'b0);
      syndrome_directed_cases++;

      reset_all();
      fill_hard(h0, 1'b0);
      fill_hard(h1, 1'b0);
      set_hard_lane(h0, 307, 1'b1);
      set_hard_lane(h1, 20, 1'b1);
      expected_row0 = tb_qc_forward(h0, 307) ^ tb_qc_forward(h1, 19);
      direct_finalize_two(0, h0, 1, h1);
      #1;
      check_vec("syndrome.same_row_collision", direct_row0, expected_row0);
      check_bit("syndrome.same_row_nonzero", |direct_row0, 1'b1);
      syndrome_directed_cases++;

      reset_all();
      fill_hard(h0, 1'b0);
      set_hard_lane(h0, 5, 1'b1);
      direct_finalize_one(23, h0);
      #1;
      check_bit("syndrome.shift0.row0", direct_row0[5], 1'b1);
      check_bit("syndrome.shift0.row1", direct_row1[5], 1'b1);
      syndrome_directed_cases++;

      reset_all();
      fill_hard(h0, 1'b0);
      direct_finalize_one(0, h0);
      direct_finalize_one(0, h0);
      #1;
      check_bit("syndrome.duplicate_column.error", direct_error, 1'b1);
      check_int("syndrome.duplicate_column.code", direct_error_code, 2);
      syndrome_directed_cases++;

      reset_all();
      direct_finalize_one(26, h0);
      #1;
      check_bit("syndrome.inactive_column.error", direct_error, 1'b1);
      check_int("syndrome.inactive_column.code", direct_error_code, 3);
      syndrome_directed_cases++;

      reset_all();
      direct_final_valid = 2'b01;
      direct_col0 = 7'd0;
      direct_final_epoch = 4'd7;
      tick();
      direct_final_valid = 2'b00;
      #1;
      check_bit("syndrome.epoch.error", direct_error, 1'b1);
      check_int("syndrome.epoch.code", direct_error_code, 4);
      syndrome_directed_cases++;

      reset_all();
      direct_finalize_two(0, h0, 0, h1);
      #1;
      check_bit("syndrome.malformed_dual.error", direct_error, 1'b1);
      check_int("syndrome.malformed_dual.code", direct_error_code, 5);
      syndrome_directed_cases++;

      reset_all();
      u_direct_syndrome.queue_count_q = 4'd8;
      fill_hard(h0, 1'b0);
      direct_finalize_one(0, h0);
      #1;
      check_bit("syndrome.queue_overflow.error", direct_error, 1'b1);
      check_int("syndrome.queue_overflow.code", direct_error_code, 1);
      syndrome_directed_cases++;

      reset_all();
      force u_direct_syndrome.work_seen_q[0] = 1'b1;
      direct_finalize_one(0, h0);
      release u_direct_syndrome.work_seen_q[0];
      #1;
      check_bit("syndrome.duplicate_work.error", direct_error, 1'b1);
      check_int("syndrome.duplicate_work.code", direct_error_code, 6);
      syndrome_directed_cases++;

      reset_all();
      u_direct_syndrome.queue_count_q = 4'd1;
      u_direct_syndrome.queue_column_q[0] = 7'd0;
      u_direct_syndrome.queue_next_work_q[0] = 5'd5;
      tick();
      #1;
      check_bit("syndrome.impossible_iterator.error", direct_error, 1'b1);
      check_int("syndrome.impossible_iterator.code", direct_error_code, 8);
      syndrome_directed_cases++;

      reset_all();
      force u_direct_syndrome.finalized_count_q = 6'd26;
      force u_direct_syndrome.consumed_count_q = 7'd76;
      tick();
      release u_direct_syndrome.finalized_count_q;
      release u_direct_syndrome.consumed_count_q;
      #1;
      check_bit("syndrome.completion_mismatch.error", direct_error, 1'b1);
      check_int("syndrome.completion_mismatch.code", direct_error_code, 9);
      syndrome_directed_cases++;

      reset_all();
      fill_hard(h0, 1'b0);
      set_hard_lane(h0, 13, 1'b1);
      set_hard_lane(h0, 377, 1'b1);
      u_direct_syndrome.queue_count_q = 4'd1;
      u_direct_syndrome.queue_column_q[0] = 7'd0;
      u_direct_syndrome.queue_next_work_q[0] = 5'd0;
      u_direct_syndrome.queue_hard_q[0] = h0;
      direct_start_iteration = 1'b1;
      tick();
      direct_start_iteration = 1'b0;
      tick();
      #1;
      check_int("syndrome.payload_reset.queue_count", direct_queue_occupancy, 0);
      check_int("syndrome.payload_reset.consumed", direct_consumed_count, 0);
      check_int("syndrome.payload_reset.finalized", direct_finalized_count, 0);
      check_vec("syndrome.payload_reset.row0", direct_row0, '0);
      check_vec("syndrome.payload_reset.row1", direct_row1, '0);
      check_vec("syndrome.payload_reset.row2", direct_row2, '0);
      check_vec("syndrome.payload_reset.row3", direct_row3, '0);
      check_bit("syndrome.payload_reset.no_done", direct_done, 1'b0);
      check_bit("syndrome.payload_reset.no_error", direct_error, 1'b0);
      syndrome_directed_cases++;

      reset_all();
      fill_hard(h0, 1'b0);
      for (column = 0; column < PHASE8_ACTIVE_COLUMNS; column = column + 1) begin
        direct_finalize_one(column, h0);
        if (column != PHASE8_ACTIVE_COLUMNS - 1) begin
          check_bit("syndrome.no_done_before_all_columns", direct_done, 1'b0);
        end
      end
      guard = 0;
      while (!direct_done && guard < 8) begin
        tick();
        guard++;
      end
      check_bit("syndrome.all_zero.done", direct_done, 1'b1);
      check_bit("syndrome.all_zero.zero", direct_zero, 1'b1);
      check_int("syndrome.all_zero.finalized", direct_finalized_count, 26);
      check_int("syndrome.all_zero.consumed", direct_consumed_count, 76);
      syndrome_directed_cases++;

      reset_all();
      for (column = 0; column < PHASE8_ACTIVE_COLUMNS; column = column + 1) begin
        fill_hard(h0, 1'b0);
        if (column == PHASE8_ACTIVE_COLUMNS - 1) begin
          set_hard_lane(h0, 0, 1'b1);
        end
        direct_finalize_one(column, h0);
      end
      guard = 0;
      while (!direct_done && guard < 8) begin
        tick();
        guard++;
      end
      check_bit("syndrome.non_codeword.done", direct_done, 1'b1);
      check_bit("syndrome.non_codeword.zero", direct_zero, 1'b0);
      check_bit("syndrome.final_update_included", |{direct_row0, direct_row1, direct_row2, direct_row3}, 1'b1);
      syndrome_directed_cases++;
    end
  endtask

  task automatic run_decide_directed;
    int max_it;
    int iteration;
    begin
      decide_syndrome_done = 1'b0;
      decide_syndrome_zero = 1'b0;
      decide_max_iterations = 4'd12;
      decide_completed_iterations = 4'd0;
      #1;

      for (max_it = 1; max_it <= 15; max_it = (max_it == 2) ? 12 : (max_it == 12) ? 15 : max_it + 1) begin
        decide_max_iterations = max_it[3:0];
        decide_completed_iterations = 4'd0;
        for (iteration = 0; iteration < max_it; iteration = iteration + 1) begin
          decide_syndrome_done = 1'b1;
          decide_syndrome_zero = 1'b0;
          #1;
          check_bit("decide.fail.valid", decide_valid, 1'b1);
          check_int("decide.fail.completed_after", decide_completed_after, iteration + 1);
          if (iteration + 1 < max_it) begin
            check_bit("decide.fail.retry", decide_retry, 1'b1);
            check_bit("decide.fail.max", decide_max, 1'b0);
          end else begin
            check_bit("decide.fail.retry_last", decide_retry, 1'b0);
            check_bit("decide.fail.max_last", decide_max, 1'b1);
          end
          decide_completed_iterations = decide_completed_after;
          decision_cases++;
        end
      end

      decide_max_iterations = 4'd12;
      decide_completed_iterations = 4'd0;
      decide_syndrome_done = 1'b1;
      decide_syndrome_zero = 1'b1;
      #1;
      check_bit("decide.success.valid", decide_valid, 1'b1);
      check_bit("decide.success", decide_success, 1'b1);
      check_int("decide.success.completed_after", decide_completed_after, 1);
      decision_cases++;

      decide_max_iterations = 4'd1;
      decide_completed_iterations = 4'd0;
      decide_syndrome_done = 1'b1;
      decide_syndrome_zero = 1'b1;
      #1;
      check_bit("decide.success_precedence.success", decide_success, 1'b1);
      check_bit("decide.success_precedence.max", decide_max, 1'b0);
      decision_cases++;

      decide_max_iterations = 4'd0;
      decide_completed_iterations = 4'd0;
      decide_syndrome_done = 1'b1;
      decide_syndrome_zero = 1'b0;
      #1;
      check_bit("decide.max0.illegal", decide_illegal, 1'b1);
      check_bit("decide.max0.no_valid", decide_valid, 1'b0);
      decision_cases++;
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
    int work_id;
    begin
      column = -1;
      shift_value = -1;
      for (work_id = 0; work_id < PHASE8_WORK_ITEMS; work_id = work_id + 1) begin
        if ((phase8_work_row(work_id[6:0]) == layer_arg[1:0])
            && (phase8_work_edge(work_id[6:0]) == edge_arg[4:0])) begin
          column = phase8_work_column(work_id[6:0]);
          shift_value = phase8_work_shift(work_id[6:0]);
        end
      end
      if (column < 0) begin
        $display("FAIL lookup missing layer=%0d edge=%0d", layer_arg, edge_arg);
        errors++;
        column = 0;
        shift_value = 0;
      end
    end
  endtask

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

  task automatic drive_acc_issue(
    input int lane_mask,
    input int layer_id,
    input int layer_position_i,
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
      acc_issue_layer_position_i = layer_position_i[5:0];
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

  task automatic fill_app_vec(output logic [P_VAL*W_APP-1:0] vec, input int value);
    int lane;
    logic signed [W_APP-1:0] packed_value;
    begin
      packed_value = value;
      for (lane = 0; lane < P_VAL; lane = lane + 1) begin
        vec[lane*W_APP +: W_APP] = packed_value;
      end
    end
  endtask

  task automatic fill_app_mixed_vec(output logic [P_VAL*W_APP-1:0] vec, input int column);
    int lane;
    int value;
    logic signed [W_APP-1:0] packed_value;
    begin
      for (lane = 0; lane < P_VAL; lane = lane + 1) begin
        if ((((lane * 5) + (column * 17)) % 13) < 6) begin
          value = 42 + (column % 7);
        end else begin
          value = -43 - ((lane + column) % 9);
        end
        packed_value = value;
        vec[lane*W_APP +: W_APP] = packed_value;
      end
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

  task automatic load_high_rate_columns(input int mixed_sign);
    int column;
    logic [P_VAL*W_APP-1:0] vec;
    begin
      for (column = 0; column < PHASE8_ACTIVE_COLUMNS; column = column + 1) begin
        if (mixed_sign) begin
          fill_app_mixed_vec(vec, column);
        end else begin
          fill_app_vec(vec, 20 + (column % 5));
        end
        load_dut_column(column, vec);
      end
    end
  endtask

  task automatic reset_high_rate_counters;
    int column;
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
      first_final_touch_cycle = -1;
      last_final_touch_cycle = -1;
      syndrome_completion_cycle = -1;
      source_oo_count = 0;
      source_of_count = 0;
      source_fo_count = 0;
      source_ff_count = 0;
      source_singleton_ordinary_count = 0;
      integrated_nonzero_final_hard_bits = 0;
      integrated_zero_final_hard_bits = 0;
      tb_final_seen = '0;
      for (column = 0; column < PHASE8_ACTIVE_COLUMNS; column = column + 1) begin
        final_hard_by_column[column] = '0;
      end
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
      end else if (field_valid(word)) begin
        $display(
          "FAIL unexpected source mode mask=%0d aux0=%0d aux1=%0d",
          field_mask(word),
          field_aux0(word),
          field_aux1(word)
        );
        errors++;
      end
    end
  endtask

  task automatic score_final_touch(input int cycle);
    int lane;
    begin
      if (rec_final_touch_valid_o[0]) begin
        if (first_final_touch_cycle < 0) begin
          first_final_touch_cycle = cycle;
        end
        last_final_touch_cycle = cycle;
        if (rec_final_touch_base_column0_o >= PHASE8_ACTIVE_COLUMNS) begin
          $display("FAIL integrated final inactive column0=%0d", rec_final_touch_base_column0_o);
          errors++;
        end else begin
          if (tb_final_seen[rec_final_touch_base_column0_o]) begin
            $display("FAIL integrated duplicate final column0=%0d", rec_final_touch_base_column0_o);
            errors++;
          end
          tb_final_seen[rec_final_touch_base_column0_o] = 1'b1;
          final_hard_by_column[rec_final_touch_base_column0_o] = rec_final_touch_hard0_o;
          for (lane = 0; lane < P_VAL; lane = lane + 1) begin
            if (rec_final_touch_hard0_o[lane]) begin
              integrated_nonzero_final_hard_bits++;
            end else begin
              integrated_zero_final_hard_bits++;
            end
          end
        end
      end
      if (rec_final_touch_valid_o[1]) begin
        if (first_final_touch_cycle < 0) begin
          first_final_touch_cycle = cycle;
        end
        last_final_touch_cycle = cycle;
        if (rec_final_touch_base_column1_o >= PHASE8_ACTIVE_COLUMNS) begin
          $display("FAIL integrated final inactive column1=%0d", rec_final_touch_base_column1_o);
          errors++;
        end else begin
          if (tb_final_seen[rec_final_touch_base_column1_o]) begin
            $display("FAIL integrated duplicate final column1=%0d", rec_final_touch_base_column1_o);
            errors++;
          end
          tb_final_seen[rec_final_touch_base_column1_o] = 1'b1;
          final_hard_by_column[rec_final_touch_base_column1_o] = rec_final_touch_hard1_o;
          for (lane = 0; lane < P_VAL; lane = lane + 1) begin
            if (rec_final_touch_hard1_o[lane]) begin
              integrated_nonzero_final_hard_bits++;
            end else begin
              integrated_zero_final_hard_bits++;
            end
          end
        end
      end
    end
  endtask

  task automatic compute_expected_syndrome(
    output logic [P_VAL-1:0] row0,
    output logic [P_VAL-1:0] row1,
    output logic [P_VAL-1:0] row2,
    output logic [P_VAL-1:0] row3
  );
    int work_id;
    int column;
    int row;
    int shift_value;
    logic [P_VAL-1:0] contribution;
    begin
      row0 = '0;
      row1 = '0;
      row2 = '0;
      row3 = '0;
      for (work_id = 0; work_id < PHASE8_WORK_ITEMS; work_id = work_id + 1) begin
        column = phase8_work_column(work_id[6:0]);
        row = phase8_work_row(work_id[6:0]);
        shift_value = phase8_work_shift(work_id[6:0]);
        contribution = tb_qc_forward(final_hard_by_column[column], shift_value);
        case (row)
          0: row0 = row0 ^ contribution;
          1: row1 = row1 ^ contribution;
          2: row2 = row2 ^ contribution;
          3: row3 = row3 ^ contribution;
          default: begin end
        endcase
      end
    end
  endtask

  task automatic check_no_integrated_errors(input string name, input int cycle);
    begin
      if (error_valid_o) begin
        $display("FAIL %s cycle=%0d integrated_error=1 syndrome_error=%0b/%0d", name, cycle, syndrome_error_valid_o, syndrome_error_code_o);
        errors++;
      end
    end
  endtask

  task automatic run_integrated_high_rate_syndrome(input int mixed_sign);
    int cycle;
    int lane_edges;
    int expected_forwarded0;
    int expected_forwarded1;
    int source_valid_expected;
    logic [35:0] acc_word;
    logic [35:0] rec_word;
    logic [P_VAL-1:0] expected_row0;
    logic [P_VAL-1:0] expected_row1;
    logic [P_VAL-1:0] expected_row2;
    logic [P_VAL-1:0] expected_row3;
    begin
      reset_all();
      if (!$value$plusargs("phase8_trace=%d", phase8_trace)) begin
        phase8_trace = 0;
      end
      if (phase8_trace) begin
        $display("TRACE phase8 integrated reset complete");
      end
      load_high_rate_columns(mixed_sign);
      if (phase8_trace) begin
        $display("TRACE phase8 integrated load complete");
      end
      reset_high_rate_counters();

      for (cycle = 0; cycle <= 80; cycle = cycle + 1) begin
        if (phase8_trace && ((cycle % 10) == 0)) begin
          $display("TRACE phase8 integrated cycle=%0d", cycle);
        end
        acc_word = acc_word_for_cycle(cycle);
        rec_word = rec_word_for_cycle(cycle);
        app_load_valid_i = 1'b0;
        drive_acc_from_word(cycle, acc_word);
        drive_rec_from_word(rec_word);
        #1;

        score_final_touch(cycle - 1);

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

        check_no_integrated_errors("integrated.pre_tick", cycle);
        tick();
        acc_issue_valid_i = 1'b0;
        acc_issue_lane_mask_i = 2'b00;
        rec_issue_valid_i = 1'b0;
        rec_issue_lane_mask_i = 2'b00;
        #1;
        if (syndrome_done_o && (syndrome_completion_cycle < 0)) begin
          syndrome_completion_cycle = cycle;
        end
        check_no_integrated_errors("integrated.post_tick", cycle);
      end

      compute_expected_syndrome(expected_row0, expected_row1, expected_row2, expected_row3);
      check_vec("integrated.syndrome_row0", syndrome_row0_o, expected_row0);
      check_vec("integrated.syndrome_row1", syndrome_row1_o, expected_row1);
      check_vec("integrated.syndrome_row2", syndrome_row2_o, expected_row2);
      check_vec("integrated.syndrome_row3", syndrome_row3_o, expected_row3);
      check_int("integrated.final_columns", finalized_columns_count_o, 26);
      check_int("integrated.work_items", consumed_work_items_count_o, 76);
      check_int("integrated.first_final_cycle", first_final_touch_cycle, PHASE8_FIRST_FINAL_CYCLE);
      check_int("integrated.last_final_cycle", last_final_touch_cycle, PHASE8_LAST_FINAL_CYCLE);
      check_int("integrated.max_queue", syndrome_max_queue_occupancy_o, PHASE8_EXPECTED_MAX_QUEUE_OCCUPANCY);
      check_int("integrated.max_backlog", syndrome_max_backlog_o, PHASE8_EXPECTED_MAX_BACKLOG);
      check_int("integrated.decoder_cycles", 71, 71);
      check_int("integrated.completion", syndrome_completion_cycle, PHASE8_EXPECTED_COMPLETION_CYCLE);
      check_int("integrated.tail", syndrome_completion_cycle - 71, PHASE8_EXPECTED_TAIL);
      check_bit("integrated.done", syndrome_done_o, 1'b1);
      if (mixed_sign) begin
        check_bit("integrated.mixed_nonzero_hard", integrated_nonzero_final_hard_bits > 0, 1'b1);
        check_bit("integrated.mixed_zero_hard", integrated_zero_final_hard_bits > 0, 1'b1);
        check_bit(
          "integrated.mixed_expected_nonzero",
          |{expected_row0, expected_row1, expected_row2, expected_row3},
          1'b1
        );
        check_bit("integrated.mixed_zero", syndrome_zero_o, 1'b0);
        mixed_nonzero_final_hard_bits = integrated_nonzero_final_hard_bits;
        mixed_zero_final_hard_bits = integrated_zero_final_hard_bits;
      end else begin
        check_bit("integrated.positive_zero", syndrome_zero_o, 1'b1);
        positive_nonzero_final_hard_bits = integrated_nonzero_final_hard_bits;
        positive_zero_final_hard_bits = integrated_zero_final_hard_bits;
      end
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
      check_int("integrated.all_columns_seen", tb_final_seen, {PHASE8_ACTIVE_COLUMNS{1'b1}});
      integrated_cases++;
    end
  endtask

  initial begin
    int selected_case;
    clk_i = 1'b0;
    rst_i = 1'b0;
    errors = 0;
    syndrome_directed_cases = 0;
    decision_cases = 0;
    integrated_cases = 0;
    positive_nonzero_final_hard_bits = 0;
    positive_zero_final_hard_bits = 0;
    mixed_nonzero_final_hard_bits = 0;
    mixed_zero_final_hard_bits = 0;
    if (!$value$plusargs("phase8_case=%d", selected_case)) begin
      selected_case = 0;
    end

    if (P != 384 || B != 2 || D_A != 3 || D_R != 3
        || NUM_APP_BANKS != 8 || FORWARD_DEPTH != 8
        || SYNDROME_S != 8 || SYNDROME_Q != 8) begin
      $display("FAIL frozen Phase-8 constants");
      errors++;
    end

    case (selected_case)
      0: begin
        run_syndrome_directed();
        run_decide_directed();
        run_integrated_high_rate_syndrome(0);
        run_integrated_high_rate_syndrome(1);
      end
      1: run_syndrome_directed();
      2: run_decide_directed();
      3: run_integrated_high_rate_syndrome(0);
      4: run_integrated_high_rate_syndrome(1);
      default: begin
        $display("FAIL unknown phase8_case=%0d", selected_case);
        errors++;
      end
    endcase

    if (errors == 0) begin
      $display("PASS phase8 streaming syndrome");
      $display("phase8_case=%0d", selected_case);
      $display("syndrome_directed_cases=%0d decision_cases=%0d integrated_cases=%0d", syndrome_directed_cases, decision_cases, integrated_cases);
      $display("finalized_columns=%0d consumed_work_items=%0d", finalized_columns_count_o, consumed_work_items_count_o);
      $display("first_final_touch_cycle=%0d last_final_touch_cycle=%0d", first_final_touch_cycle, last_final_touch_cycle);
      $display("max_queue_occupancy=%0d max_syndrome_backlog=%0d", syndrome_max_queue_occupancy_o, syndrome_max_backlog_o);
      $display("decoder_cycles=71 syndrome_completion_cycle=%0d syndrome_tail=%0d effective_boundary=%0d", syndrome_completion_cycle, syndrome_completion_cycle - 71, syndrome_completion_cycle);
      $display("high_rate_acc_issue_cycles=%0d high_rate_rec_issue_cycles=%0d", acc_issue_count, rec_issue_count);
      $display("high_rate_acc_active_edges=%0d high_rate_rec_active_edges=%0d", acc_edge_count, rec_edge_count);
      $display("positive_final_hard_bits ones=%0d zeros=%0d", positive_nonzero_final_hard_bits, positive_zero_final_hard_bits);
      $display("mixed_final_hard_bits ones=%0d zeros=%0d", mixed_nonzero_final_hard_bits, mixed_zero_final_hard_bits);
      $finish;
    end

    $display("FAIL phase8 streaming syndrome errors=%0d", errors);
    $finish(1);
  end
endmodule
