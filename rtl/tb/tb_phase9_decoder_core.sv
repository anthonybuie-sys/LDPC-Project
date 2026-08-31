`timescale 1ns/1ps

module tb_phase9_decoder_core;
  import nr_ldpc_pkg::*;
  import nr_ldpc_controller_profile_bg1_first4_pkg::*;
  import nr_ldpc_syndrome_profile_bg1_first4_pkg::*;

  localparam int P_VAL = REFERENCE_Z;
  localparam int SHIFT_W = $clog2(P_VAL + 1);

  logic clk_i;
  logic rst_i;
  logic start_i;
  logic abort_i;
  logic [3:0] max_iterations_i;

  logic app_load_valid_i;
  logic [6:0] app_load_column_i;
  logic [P_VAL*W_APP-1:0] app_load_i;
  logic app_load_ready_o;

  logic start_ready_o;
  logic busy_o;
  logic done_o;
  logic decode_success_o;
  logic max_iterations_reached_o;
  logic aborted_o;
  logic error_valid_o;
  logic [7:0] error_code_o;
  logic [3:0] completed_iterations_o;
  logic [3:0] current_iteration_epoch_o;
  logic [8:0] program_counter_o;

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

  logic [1:0] rec_final_touch_valid_o;
  logic [6:0] rec_final_touch_base_column0_o;
  logic [6:0] rec_final_touch_base_column1_o;
  logic [3:0] rec_final_touch_iteration_epoch_o;
  logic [P_VAL-1:0] rec_final_touch_hard0_o;
  logic [P_VAL-1:0] rec_final_touch_hard1_o;

  logic [3:0] debug_state_o;
  logic debug_program_issue_valid_o;
  logic [71:0] debug_schedule_word_o;
  logic [35:0] debug_acc_word_o;
  logic [35:0] debug_rec_word_o;
  logic debug_start_block_o;
  logic debug_start_iteration_o;
  logic debug_advance_iteration_o;
  logic debug_advance_accept_o;
  logic debug_decision_valid_o;
  logic debug_retry_decision_o;
  logic debug_app_load_accept_o;
  logic [25:0] debug_app_load_seen_o;
  logic [3:0] debug_acc_seen_layers_o;

  logic debug_acc_issue_valid_o;
  logic debug_acc_issue_ready_o;
  logic [1:0] debug_acc_issue_lane_mask_o;
  logic [5:0] debug_acc_issue_layer_id_o;
  logic [5:0] debug_acc_issue_layer_position_o;
  logic [5:0] debug_acc_issue_layer_degree_o;
  logic debug_acc_issue_start_layer_o;
  logic [4:0] debug_acc_issue_edge0_id_o;
  logic [4:0] debug_acc_issue_edge1_id_o;
  logic [0:0] debug_acc_issue_qbuf_o;
  logic [3:0] debug_acc_issue_qslot_o;
  logic [3:0] debug_acc_issue_iteration_epoch_o;
  logic [6:0] debug_acc_issue_base_column0_o;
  logic [6:0] debug_acc_issue_base_column1_o;
  logic [3:0] debug_acc_issue_aux0_o;
  logic [3:0] debug_acc_issue_aux1_o;
  logic [SHIFT_W-1:0] debug_acc_issue_shift0_o;
  logic [SHIFT_W-1:0] debug_acc_issue_shift1_o;

  logic debug_rec_issue_valid_o;
  logic debug_rec_issue_ready_o;
  logic [1:0] debug_rec_issue_lane_mask_o;
  logic [5:0] debug_rec_issue_layer_id_o;
  logic [4:0] debug_rec_issue_edge0_id_o;
  logic [4:0] debug_rec_issue_edge1_id_o;
  logic [0:0] debug_rec_issue_qbuf_o;
  logic [3:0] debug_rec_issue_qslot_o;
  logic [3:0] debug_rec_issue_iteration_epoch_o;
  logic [SHIFT_W-1:0] debug_rec_issue_shift0_o;
  logic [SHIFT_W-1:0] debug_rec_issue_shift1_o;
  logic [6:0] debug_rec_issue_base_column0_o;
  logic [6:0] debug_rec_issue_base_column1_o;
  logic [3:0] debug_rec_issue_aux0_o;
  logic [3:0] debug_rec_issue_aux1_o;
  logic debug_rec_issue_final_touch0_o;
  logic debug_rec_issue_final_touch1_o;

  logic [1:0] debug_acc_source_valid_o;
  logic [1:0] debug_acc_source_forwarded_o;
  logic [1:0] debug_forward_alloc_valid_o;
  logic [1:0] debug_forward_alloc_accept_o;
  logic [5:0] debug_forward_live_count_o;
  logic debug_app_same_bank_collision_o;

  int errors;
  int directed_cases;
  int integrated_cases;
  int abs_cycle;

  int acc_issue_count;
  int rec_issue_count;
  int acc_edge_count;
  int rec_edge_count;
  int schedule_cycles_seen;
  int pc0_count;
  int first_iteration_pc0_capture;
  int second_iteration_pc0_capture;
  int third_iteration_pc0_capture;
  int first_iteration_pc70_capture;
  int first_syndrome_decision;
  int generation_advance_capture;
  int first_generation_advance_capture;
  int second_generation_advance_capture;
  int terminal_done_capture;
  int accepted_generation_advances;
  int first_final_touch_cycle;
  int last_final_touch_cycle;
  int syndrome_completion_cycle;
  int max_queue_occupancy_seen;
  int max_backlog_seen;
  int current_pc0_abs;
  int current_iteration_index;
  int final_hard_ones;
  int final_hard_zeros;
  int positive_final_ones;
  int positive_final_zeros;
  int mixed_final_ones;
  int mixed_final_zeros;
  int measured_retry_interval;
  int measured_retry_interval_12;
  int positive_terminal_done;
  int mixed_retry_terminal_done;
  int mixed_three_terminal_done;
  int mixed_three_retry_interval_01;
  int mixed_three_retry_interval_12;
  int mixed_three_generation_advances;
  int mixed_three_epoch0;
  int mixed_three_epoch1;
  int mixed_three_epoch2;
  int selected_case;
  bit run_all_cases;

  logic [3:0] tb_acc_seen_layers;
  logic [8:0] expected_pc;
  logic [P_VAL-1:0] final_hard_by_column [0:PHASE9_ACTIVE_COLUMNS-1];
  logic [PHASE9_ACTIVE_COLUMNS-1:0] tb_final_seen;
  int pc0_capture [0:2];
  int pc0_epoch [0:2];

  nr_ldpc_decoder_core #(
    .P(P_VAL)
  ) dut (.*);

  task automatic tick;
    begin
      #5;
      clk_i = 1'b1;
      #1;
      clk_i = 1'b0;
      #4;
      abs_cycle++;
    end
  endtask

  task automatic fail(input string name);
    begin
      $display("FAIL %s", name);
      errors++;
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

  task automatic check_int(input string name, input int actual, input int expected);
    begin
      if (actual != expected) begin
        $display("FAIL %s actual=%0d expected=%0d", name, actual, expected);
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

  task automatic check_word72(input string name, input logic [71:0] actual, input logic [71:0] expected);
    begin
      if (actual !== expected) begin
        $display("FAIL %s actual=0x%018h expected=0x%018h", name, actual, expected);
        errors++;
      end
    end
  endtask

  task automatic check_word36(input string name, input logic [35:0] actual, input logic [35:0] expected);
    begin
      if (actual !== expected) begin
        $display("FAIL %s actual=0x%09h expected=0x%09h", name, actual, expected);
        errors++;
      end
    end
  endtask

  task automatic check_no_datapath_errors(input string label);
    begin
      check_bit({label, ".controller_error"}, error_valid_o, 1'b0);
      check_bit({label, ".acc_error"}, dut.u_datapath.acc_error_valid_o, 1'b0);
      check_bit({label, ".rec_error"}, dut.u_datapath.rec_error_valid_o, 1'b0);
      check_bit({label, ".q_scratch_error"}, dut.u_datapath.q_scratch_error_valid_o, 1'b0);
      check_bit({label, ".check_state_error"}, dut.u_datapath.check_state_error_valid_o, 1'b0);
      check_bit({label, ".old_state_alignment_error"}, dut.u_datapath.old_state_alignment_error_o, 1'b0);
      check_bit({label, ".unsafe_advance_error"}, dut.u_datapath.unsafe_advance_error_o, 1'b0);
      check_bit({label, ".phase6_storage_error"}, dut.u_datapath.phase6_storage_error_valid_o, 1'b0);
      check_bit({label, ".app_memory_error"}, dut.u_datapath.app_memory_error_valid_o, 1'b0);
      check_bit({label, ".forward_error"}, dut.u_datapath.forward_error_valid_o, 1'b0);
      check_bit({label, ".app_forward_error"}, dut.u_datapath.app_forward_error_valid_o, 1'b0);
      check_bit({label, ".storage_error"}, dut.u_datapath.storage_error_valid_o, 1'b0);
      check_bit({label, ".syndrome_error"}, syndrome_error_valid_o, 1'b0);
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

  function automatic int field_reserved(input logic [35:0] word);
    field_reserved = word[35:34];
  endfunction

  function automatic int lane_count(input logic [1:0] mask);
    lane_count = mask[0] + mask[1];
  endfunction

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

  task automatic default_inputs;
    begin
      start_i = 1'b0;
      abort_i = 1'b0;
      max_iterations_i = 4'd12;
      app_load_valid_i = 1'b0;
      app_load_column_i = 7'd0;
      app_load_i = '0;
    end
  endtask

  task automatic reset_core;
    begin
      default_inputs();
      rst_i = 1'b1;
      tick();
      tick();
      rst_i = 1'b0;
      #1;
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

  task automatic reset_run_metrics;
    int column;
    int pc_idx;
    begin
      acc_issue_count = 0;
      rec_issue_count = 0;
      acc_edge_count = 0;
      rec_edge_count = 0;
      schedule_cycles_seen = 0;
      pc0_count = 0;
      first_iteration_pc0_capture = -1;
      second_iteration_pc0_capture = -1;
      third_iteration_pc0_capture = -1;
      first_iteration_pc70_capture = -1;
      first_syndrome_decision = -1;
      generation_advance_capture = -1;
      first_generation_advance_capture = -1;
      second_generation_advance_capture = -1;
      terminal_done_capture = -1;
      accepted_generation_advances = 0;
      first_final_touch_cycle = -1;
      last_final_touch_cycle = -1;
      syndrome_completion_cycle = -1;
      max_queue_occupancy_seen = 0;
      max_backlog_seen = 0;
      current_pc0_abs = -1;
      current_iteration_index = -1;
      final_hard_ones = 0;
      final_hard_zeros = 0;
      measured_retry_interval = -1;
      measured_retry_interval_12 = -1;
      tb_acc_seen_layers = 4'd0;
      expected_pc = 9'd0;
      tb_final_seen = '0;
      for (pc_idx = 0; pc_idx < 3; pc_idx = pc_idx + 1) begin
        pc0_capture[pc_idx] = -1;
        pc0_epoch[pc_idx] = -1;
      end
      for (column = 0; column < PHASE9_ACTIVE_COLUMNS; column = column + 1) begin
        final_hard_by_column[column] = '0;
      end
    end
  endtask

  task automatic begin_block(input int max_iter);
    begin
      max_iterations_i = max_iter[3:0];
      start_i = 1'b1;
      #1;
      check_bit("start.ready", start_ready_o, 1'b1);
      check_bit("start.block_pulse", debug_start_block_o, 1'b1);
      tick();
      start_i = 1'b0;
      #1;
      check_bit("block_load.busy", busy_o, 1'b1);
      check_bit("block_load.ready", app_load_ready_o, 1'b1);
    end
  endtask

  task automatic drive_load_column(input int column, input int mixed);
    logic [P_VAL*W_APP-1:0] vec;
    begin
      if (mixed) begin
        fill_app_mixed_vec(vec, column);
      end else begin
        fill_app_vec(vec, 20 + (column % 5));
      end
      app_load_valid_i = 1'b1;
      app_load_column_i = column[6:0];
      app_load_i = vec;
      #1;
      check_bit("app_load.ready", app_load_ready_o, 1'b1);
      check_bit("app_load.accept", debug_app_load_accept_o, 1'b1);
      tick();
    end
  endtask

  task automatic load_all_columns(input int mixed);
    int column;
    begin
      for (column = 0; column < PHASE9_ACTIVE_COLUMNS; column = column + 1) begin
        drive_load_column(column, mixed);
      end
      app_load_valid_i = 1'b0;
      #1;
      check_int("after_load.state", debug_state_o, 2);
    end
  endtask

  task automatic clear_iteration_scoreboard;
    int column;
    begin
      tb_acc_seen_layers = 4'd0;
      expected_pc = 9'd0;
      tb_final_seen = '0;
      final_hard_ones = 0;
      final_hard_zeros = 0;
      for (column = 0; column < PHASE9_ACTIVE_COLUMNS; column = column + 1) begin
        final_hard_by_column[column] = '0;
      end
    end
  endtask

  task automatic check_acc_output(input logic [35:0] word);
    logic [5:0] layer;
    logic [1:0] mask;
    logic [4:0] edge0;
    logic [4:0] edge1;
    int start_expected;
    begin
      layer = field_layer(word);
      mask = field_mask(word);
      edge0 = field_edge0(word);
      edge1 = field_edge1(word);
      start_expected = !tb_acc_seen_layers[layer[1:0]];
      check_bit("acc.valid", debug_acc_issue_valid_o, 1'b1);
      check_int("acc.mask", debug_acc_issue_lane_mask_o, mask);
      check_int("acc.layer", debug_acc_issue_layer_id_o, layer);
      check_int("acc.layer_position", debug_acc_issue_layer_position_o, phase9_layer_position(layer));
      check_int("acc.layer_degree", debug_acc_issue_layer_degree_o, phase9_layer_degree(layer));
      check_int("acc.start_layer", debug_acc_issue_start_layer_o, start_expected);
      check_int("acc.edge0", debug_acc_issue_edge0_id_o, edge0);
      check_int("acc.edge1", debug_acc_issue_edge1_id_o, edge1);
      check_int("acc.qbuf", debug_acc_issue_qbuf_o, field_qbuf(word));
      check_int("acc.qslot", debug_acc_issue_qslot_o, field_qslot(word));
      check_int("acc.epoch", debug_acc_issue_iteration_epoch_o, current_iteration_epoch_o);
      check_int("acc.aux0", debug_acc_issue_aux0_o, field_aux0(word));
      check_int("acc.aux1", debug_acc_issue_aux1_o, field_aux1(word));
      if (mask & 1) begin
        check_int("acc.column0", debug_acc_issue_base_column0_o,
            phase9_edge_base_column(layer, edge0));
        check_int("acc.shift0", debug_acc_issue_shift0_o,
            phase9_edge_shift(layer, edge0));
      end
      if (mask & 2) begin
        check_int("acc.column1", debug_acc_issue_base_column1_o,
            phase9_edge_base_column(layer, edge1));
        check_int("acc.shift1", debug_acc_issue_shift1_o,
            phase9_edge_shift(layer, edge1));
      end
      acc_issue_count++;
      acc_edge_count += lane_count(mask);
      tb_acc_seen_layers[layer[1:0]] = 1'b1;
    end
  endtask

  task automatic check_rec_output(input logic [35:0] word);
    logic [5:0] layer;
    logic [1:0] mask;
    logic [4:0] edge0;
    logic [4:0] edge1;
    begin
      layer = field_layer(word);
      mask = field_mask(word);
      edge0 = field_edge0(word);
      edge1 = field_edge1(word);
      check_bit("rec.valid", debug_rec_issue_valid_o, 1'b1);
      check_int("rec.mask", debug_rec_issue_lane_mask_o, mask);
      check_int("rec.layer", debug_rec_issue_layer_id_o, layer);
      check_int("rec.edge0", debug_rec_issue_edge0_id_o, edge0);
      check_int("rec.edge1", debug_rec_issue_edge1_id_o, edge1);
      check_int("rec.qbuf", debug_rec_issue_qbuf_o, field_qbuf(word));
      check_int("rec.qslot", debug_rec_issue_qslot_o, field_qslot(word));
      check_int("rec.epoch", debug_rec_issue_iteration_epoch_o, current_iteration_epoch_o);
      check_int("rec.aux0", debug_rec_issue_aux0_o, field_aux0(word));
      check_int("rec.aux1", debug_rec_issue_aux1_o, field_aux1(word));
      check_int("rec.final0", debug_rec_issue_final_touch0_o, field_final0(word));
      check_int("rec.final1", debug_rec_issue_final_touch1_o, field_final1(word));
      if (mask & 1) begin
        check_int("rec.column0", debug_rec_issue_base_column0_o,
            phase9_edge_base_column(layer, edge0));
        check_int("rec.shift0", debug_rec_issue_shift0_o,
            phase9_edge_shift(layer, edge0));
      end
      if (mask & 2) begin
        check_int("rec.column1", debug_rec_issue_base_column1_o,
            phase9_edge_base_column(layer, edge1));
        check_int("rec.shift1", debug_rec_issue_shift1_o,
            phase9_edge_shift(layer, edge1));
      end
      rec_issue_count++;
      rec_edge_count += lane_count(mask);
    end
  endtask

  task automatic observe_pre_tick(input string label, input int allow_error);
    logic [71:0] expected_word;
    logic [35:0] acc_word;
    logic [35:0] rec_word;
    int rel_cycle;
    begin
      if (debug_start_iteration_o) begin
        clear_iteration_scoreboard();
      end

      if (debug_decision_valid_o) begin
        rel_cycle = abs_cycle - first_iteration_pc0_capture;
        if (first_syndrome_decision < 0) begin
          first_syndrome_decision = rel_cycle;
        end
        if (debug_retry_decision_o) begin
          if (accepted_generation_advances == 0) begin
            first_generation_advance_capture = rel_cycle;
          end else if (accepted_generation_advances == 1) begin
            second_generation_advance_capture = rel_cycle;
          end
          generation_advance_capture = rel_cycle;
          accepted_generation_advances++;
          check_bit("retry.advance_accept", debug_advance_accept_o, 1'b1);
        end
      end

      if (debug_program_issue_valid_o) begin
        expected_word = phase9_program_word(program_counter_o);
        acc_word = expected_word[35:0];
        rec_word = expected_word[71:36];
        check_word72("schedule.word", debug_schedule_word_o, expected_word);
        check_int("schedule.pc", program_counter_o, expected_pc);
        check_word36("schedule.acc_word", debug_acc_word_o, acc_word);
        check_word36("schedule.rec_word", debug_rec_word_o, rec_word);
        if (program_counter_o == 9'd0) begin
          if (pc0_count < 3) begin
            pc0_capture[pc0_count] = abs_cycle;
            pc0_epoch[pc0_count] = current_iteration_epoch_o;
          end
          pc0_count++;
          current_iteration_index++;
          current_pc0_abs = abs_cycle;
          if (pc0_count == 1) begin
            first_iteration_pc0_capture = abs_cycle;
          end else if (pc0_count == 2) begin
            second_iteration_pc0_capture = abs_cycle;
            measured_retry_interval = second_iteration_pc0_capture - first_iteration_pc0_capture;
          end else if (pc0_count == 3) begin
            third_iteration_pc0_capture = abs_cycle;
            measured_retry_interval_12 = third_iteration_pc0_capture - second_iteration_pc0_capture;
          end
        end
        if (program_counter_o == 9'd70 && first_iteration_pc70_capture < 0) begin
          first_iteration_pc70_capture = abs_cycle - first_iteration_pc0_capture;
        end
        if (field_valid(acc_word)) begin
          check_acc_output(acc_word);
        end else begin
          check_bit("acc.invalid", debug_acc_issue_valid_o, 1'b0);
        end
        if (field_valid(rec_word)) begin
          check_rec_output(rec_word);
        end else begin
          check_bit("rec.invalid", debug_rec_issue_valid_o, 1'b0);
        end
        schedule_cycles_seen++;
        expected_pc++;
      end

      if (syndrome_queue_occupancy_o > max_queue_occupancy_seen) begin
        max_queue_occupancy_seen = syndrome_queue_occupancy_o;
      end
      if (syndrome_max_backlog_o > max_backlog_seen) begin
        max_backlog_seen = syndrome_max_backlog_o;
      end
      if (!allow_error && error_valid_o) begin
        $display("FAIL %s unexpected_error code=%0d syndrome=%0b/%0d", label, error_code_o, syndrome_error_valid_o, syndrome_error_code_o);
        $display("    suberrors acc=%0b rec=%0b q=%0b qcode=%0d check=%0b checkcode=%0d old_align=%0b unsafe=%0b phase6=%0b appmem=%0b appcode=%0d fwd=%0b fwdcode=%0d appfwd=%0b storage=%0b pc=%0d state=%0d epoch=%0d abs_cycle=%0d",
            dut.u_datapath.acc_error_valid_o,
            dut.u_datapath.rec_error_valid_o,
            dut.u_datapath.q_scratch_error_valid_o,
            dut.u_datapath.q_scratch_error_code_o,
            dut.u_datapath.check_state_error_valid_o,
            dut.u_datapath.check_state_error_code_o,
            dut.u_datapath.old_state_alignment_error_o,
            dut.u_datapath.unsafe_advance_error_o,
            dut.u_datapath.phase6_storage_error_valid_o,
            dut.u_datapath.app_memory_error_valid_o,
            dut.u_datapath.app_memory_error_code_o,
            dut.u_datapath.forward_error_valid_o,
            dut.u_datapath.forward_error_code_o,
            dut.u_datapath.app_forward_error_valid_o,
            dut.u_datapath.storage_error_valid_o,
            program_counter_o,
            debug_state_o,
            current_iteration_epoch_o,
            abs_cycle);
        errors++;
      end
    end
  endtask

  task automatic record_final_touch_column(input int column, input logic [P_VAL-1:0] hard_vec);
    int lane;
    begin
      if (column < 0 || column >= PHASE9_ACTIVE_COLUMNS) begin
        $display("FAIL final_touch inactive column=%0d", column);
        errors++;
      end else begin
        if (tb_final_seen[column]) begin
          $display("FAIL final_touch duplicate column=%0d", column);
          errors++;
        end
        tb_final_seen[column] = 1'b1;
        final_hard_by_column[column] = hard_vec;
        for (lane = 0; lane < P_VAL; lane = lane + 1) begin
          if (hard_vec[lane]) begin
            final_hard_ones++;
          end else begin
            final_hard_zeros++;
          end
        end
      end
    end
  endtask

  task automatic observe_after_tick;
    int rel_cycle;
    begin
      if (current_pc0_abs >= 0) begin
        rel_cycle = (abs_cycle - 1) - current_pc0_abs;
        if (rec_final_touch_valid_o[0]) begin
          if (first_final_touch_cycle < 0) begin
            first_final_touch_cycle = rel_cycle;
          end
          last_final_touch_cycle = rel_cycle;
          record_final_touch_column(rec_final_touch_base_column0_o, rec_final_touch_hard0_o);
        end
        if (rec_final_touch_valid_o[1]) begin
          if (first_final_touch_cycle < 0) begin
            first_final_touch_cycle = rel_cycle;
          end
          last_final_touch_cycle = rel_cycle;
          record_final_touch_column(rec_final_touch_base_column1_o, rec_final_touch_hard1_o);
        end
        if (syndrome_done_o && (syndrome_completion_cycle < 0)) begin
          syndrome_completion_cycle = rel_cycle;
        end
      end
      if (done_o && (terminal_done_capture < 0) && (first_iteration_pc0_capture >= 0)) begin
        terminal_done_capture = (abs_cycle - 1) - first_iteration_pc0_capture;
      end
    end
  endtask

  task automatic tick_observed(input string label, input int allow_error);
    begin
      #1;
      observe_pre_tick(label, allow_error);
      tick();
      #1;
      observe_after_tick();
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

  task automatic check_final_rows(input string label, input int require_nonzero);
    logic [P_VAL-1:0] exp0;
    logic [P_VAL-1:0] exp1;
    logic [P_VAL-1:0] exp2;
    logic [P_VAL-1:0] exp3;
    begin
      compute_expected_syndrome(exp0, exp1, exp2, exp3);
      check_vec({label, ".row0"}, syndrome_row0_o, exp0);
      check_vec({label, ".row1"}, syndrome_row1_o, exp1);
      check_vec({label, ".row2"}, syndrome_row2_o, exp2);
      check_vec({label, ".row3"}, syndrome_row3_o, exp3);
      if (require_nonzero) begin
        check_bit({label, ".expected_nonzero"}, |{exp0, exp1, exp2, exp3}, 1'b1);
      end
    end
  endtask

  task automatic run_until_terminal(input string label, input int max_cycles);
    int loops;
    begin
      loops = 0;
      while (!done_o && !error_valid_o && !aborted_o && loops < max_cycles) begin
        tick_observed(label, 0);
        loops++;
      end
      if (loops >= max_cycles) begin
        $display("FAIL %s timeout", label);
        errors++;
      end
    end
  endtask

  task automatic run_integrated_block(
    input string label,
    input int mixed,
    input int max_iter,
    input int expected_iterations,
    input int expected_success,
    input int expected_max,
    input int expect_retry
  );
    int expected_terminal_done;
    begin
      reset_core();
      reset_run_metrics();
      begin_block(max_iter);
      load_all_columns(mixed);
      run_until_terminal(label, 360);
      check_bit({label, ".done"}, done_o, 1'b1);
      if (expected_success >= 0) begin
        check_bit({label, ".success"}, decode_success_o, expected_success[0]);
      end
      if (expected_max >= 0) begin
        check_bit({label, ".max"}, max_iterations_reached_o, expected_max[0]);
      end
      if ((expected_success < 0) || (expected_max < 0)) begin
        check_bit({label, ".terminal_cause_valid"},
            decode_success_o || max_iterations_reached_o, 1'b1);
        check_bit({label, ".terminal_cause_exclusive"},
            decode_success_o && max_iterations_reached_o, 1'b0);
      end
      check_int({label, ".completed"}, completed_iterations_o, expected_iterations);
      check_int({label, ".acc_issues"}, acc_issue_count, 40 * expected_iterations);
      check_int({label, ".rec_issues"}, rec_issue_count, 40 * expected_iterations);
      check_int({label, ".acc_edges"}, acc_edge_count, 76 * expected_iterations);
      check_int({label, ".rec_edges"}, rec_edge_count, 76 * expected_iterations);
      expected_terminal_done = 73 + ((expected_iterations - 1) * 74);
      check_int({label, ".terminal_done"}, terminal_done_capture, expected_terminal_done);
      check_int({label, ".first_pc70"}, first_iteration_pc70_capture, 70);
      check_int({label, ".first_final"}, first_final_touch_cycle, PHASE8_FIRST_FINAL_CYCLE);
      check_int({label, ".last_final"}, last_final_touch_cycle, PHASE8_LAST_FINAL_CYCLE);
      check_int({label, ".syndrome_completion"}, syndrome_completion_cycle, PHASE8_EXPECTED_COMPLETION_CYCLE);
      check_int({label, ".tail"}, syndrome_completion_cycle - 71, PHASE8_EXPECTED_TAIL);
      check_int({label, ".finalized"}, finalized_columns_count_o, 26);
      check_int({label, ".work_items"}, consumed_work_items_count_o, 76);
      check_int({label, ".max_queue"}, syndrome_max_queue_occupancy_o, PHASE8_EXPECTED_MAX_QUEUE_OCCUPANCY);
      check_int({label, ".max_backlog"}, syndrome_max_backlog_o, PHASE8_EXPECTED_MAX_BACKLOG);
      check_int({label, ".final_seen"}, tb_final_seen, {PHASE9_ACTIVE_COLUMNS{1'b1}});
      if (mixed) begin
        check_bit({label, ".hard_ones_nonzero"}, final_hard_ones > 0, 1'b1);
        check_bit({label, ".hard_zeros_nonzero"}, final_hard_zeros > 0, 1'b1);
        if (expected_iterations == 1) begin
          mixed_final_ones = final_hard_ones;
          mixed_final_zeros = final_hard_zeros;
          check_int("mixed.ones", final_hard_ones, 5383);
          check_int("mixed.zeros", final_hard_zeros, 4601);
          check_bit("mixed.syndrome_zero", syndrome_zero_o, 1'b0);
          check_final_rows(label, 1);
        end else begin
          check_final_rows(label, 0);
        end
      end else begin
        positive_final_ones = final_hard_ones;
        positive_final_zeros = final_hard_zeros;
        check_int("positive.ones", final_hard_ones, 0);
        check_int("positive.zeros", final_hard_zeros, 9984);
        check_bit("positive.syndrome_zero", syndrome_zero_o, 1'b1);
        check_final_rows(label, 0);
      end
      if (expect_retry) begin
        check_int({label, ".pc0_count"}, pc0_count, expected_iterations);
        check_int({label, ".advance_count"}, accepted_generation_advances, expected_iterations - 1);
        check_int({label, ".pc0_epoch0"}, pc0_epoch[0], 0);
        check_int({label, ".pc0_epoch1"}, pc0_epoch[1], 1);
        check_int({label, ".second_pc0_epoch"}, current_iteration_epoch_o,
            expected_iterations - 1);
        check_int({label, ".retry_interval01"}, measured_retry_interval, 74);
        check_int({label, ".decision_cycle"}, first_syndrome_decision, 73);
        check_int({label, ".advance_cycle0"}, first_generation_advance_capture, 73);
        if (expected_iterations >= 3) begin
          check_int({label, ".pc0_epoch2"}, pc0_epoch[2], 2);
          check_int({label, ".pc0_sequence0"}, pc0_capture[0] - first_iteration_pc0_capture, 0);
          check_int({label, ".pc0_sequence1"}, pc0_capture[1] - first_iteration_pc0_capture, 74);
          check_int({label, ".pc0_sequence2"}, pc0_capture[2] - first_iteration_pc0_capture, 148);
          check_int({label, ".retry_interval12"}, measured_retry_interval_12, 74);
          check_int({label, ".advance_cycle1"}, second_generation_advance_capture, 147);
        end
      end else begin
        check_int({label, ".pc0_count"}, pc0_count, 1);
        check_int({label, ".advance_count"}, accepted_generation_advances, 0);
        check_int({label, ".pc0_epoch0"}, pc0_epoch[0], 0);
      end
      check_no_datapath_errors(label);
      $display("phase9_integrated_result label=%s iterations=%0d success=%0b max=%0b pc0_count=%0d generation_advances=%0d terminal_done=%0d pc0_sequence=%0d/%0d/%0d epochs=%0d/%0d/%0d retry_intervals=%0d/%0d acc_issues=%0d rec_issues=%0d acc_edges=%0d rec_edges=%0d",
          label,
          expected_iterations,
          decode_success_o,
          max_iterations_reached_o,
          pc0_count,
          accepted_generation_advances,
          terminal_done_capture,
          pc0_capture[0] - first_iteration_pc0_capture,
          pc0_capture[1] < 0 ? -1 : pc0_capture[1] - first_iteration_pc0_capture,
          pc0_capture[2] < 0 ? -1 : pc0_capture[2] - first_iteration_pc0_capture,
          pc0_epoch[0],
          pc0_epoch[1],
          pc0_epoch[2],
          measured_retry_interval,
          measured_retry_interval_12,
          acc_issue_count,
          rec_issue_count,
          acc_edge_count,
          rec_edge_count);
      if (expected_iterations == 1 && !mixed) begin
        positive_terminal_done = terminal_done_capture;
      end else if (expected_iterations == 2) begin
        mixed_retry_terminal_done = terminal_done_capture;
      end else if (expected_iterations == 3) begin
        mixed_three_terminal_done = terminal_done_capture;
        mixed_three_retry_interval_01 = measured_retry_interval;
        mixed_three_retry_interval_12 = measured_retry_interval_12;
        mixed_three_generation_advances = accepted_generation_advances;
        mixed_three_epoch0 = pc0_epoch[0];
        mixed_three_epoch1 = pc0_epoch[1];
        mixed_three_epoch2 = pc0_epoch[2];
      end
      tick_observed({label, ".sticky"}, 0);
      check_bit({label, ".done_sticky"}, done_o, 1'b1);
      integrated_cases++;
    end
  endtask

  task automatic test_reset_idle;
    begin
      reset_core();
      check_int("reset.state", debug_state_o, 0);
      check_bit("reset.start_ready", start_ready_o, 1'b1);
      check_bit("reset.busy", busy_o, 1'b0);
      check_bit("reset.done", done_o, 1'b0);
      check_bit("reset.error", error_valid_o, 1'b0);
      directed_cases++;
    end
  endtask

  task automatic test_illegal_max;
    begin
      reset_core();
      max_iterations_i = 4'd0;
      start_i = 1'b1;
      #1;
      check_bit("illegal_max.no_start_block", debug_start_block_o, 1'b0);
      tick();
      start_i = 1'b0;
      #1;
      check_bit("illegal_max.error", error_valid_o, 1'b1);
      check_int("illegal_max.code", error_code_o, 1);
      directed_cases++;
    end
  endtask

  task automatic test_start_when_busy;
    begin
      reset_core();
      begin_block(12);
      start_i = 1'b1;
      #1;
      check_bit("busy_start.ready", start_ready_o, 1'b0);
      tick();
      start_i = 1'b0;
      #1;
      check_bit("busy_start.error", error_valid_o, 1'b1);
      check_int("busy_start.code", error_code_o, 2);
      directed_cases++;
    end
  endtask

  task automatic test_app_load_errors;
    logic [P_VAL*W_APP-1:0] vec;
    begin
      reset_core();
      fill_app_vec(vec, 11);
      app_load_valid_i = 1'b1;
      app_load_column_i = 7'd0;
      app_load_i = vec;
      #1;
      check_bit("load_idle.ready", app_load_ready_o, 1'b0);
      tick();
      app_load_valid_i = 1'b0;
      #1;
      check_bit("load_idle.error", error_valid_o, 1'b1);
      check_int("load_idle.code", error_code_o, 3);
      directed_cases++;

      reset_core();
      begin_block(12);
      app_load_valid_i = 1'b1;
      app_load_column_i = 7'd30;
      app_load_i = vec;
      #1;
      check_bit("load_inactive.not_accepted", debug_app_load_accept_o, 1'b0);
      tick();
      app_load_valid_i = 1'b0;
      #1;
      check_bit("load_inactive.error", error_valid_o, 1'b1);
      check_int("load_inactive.code", error_code_o, 4);
      directed_cases++;

      reset_core();
      begin_block(12);
      drive_load_column(0, 0);
      app_load_valid_i = 1'b1;
      app_load_column_i = 7'd0;
      app_load_i = vec;
      #1;
      check_bit("load_duplicate.not_accepted", debug_app_load_accept_o, 1'b0);
      tick();
      app_load_valid_i = 1'b0;
      #1;
      check_bit("load_duplicate.error", error_valid_o, 1'b1);
      check_int("load_duplicate.code", error_code_o, 5);
      directed_cases++;
    end
  endtask

  task automatic reach_first_pc0(input int mixed);
    begin
      reset_core();
      reset_run_metrics();
      begin_block(12);
      load_all_columns(mixed);
      tick_observed("reach.iter_start", 0);
      #1;
      check_bit("reach.pc0_visible", debug_program_issue_valid_o, 1'b1);
      check_int("reach.pc0", program_counter_o, 0);
    end
  endtask

  task automatic test_not_ready_error;
    begin
      reach_first_pc0(0);
      force dut.u_controller.acc_issue_ready_i = 1'b0;
      #1;
      check_bit("not_ready.issue_suppressed", debug_acc_issue_valid_o, 1'b0);
      tick();
      release dut.u_controller.acc_issue_ready_i;
      #1;
      check_bit("not_ready.error", error_valid_o, 1'b1);
      check_int("not_ready.code", error_code_o, 7);
      directed_cases++;
    end
  endtask

  task automatic test_schedule_decode_error;
    begin
      reach_first_pc0(0);
      force dut.u_controller.program_word_w = 72'h000000000c00000003;
      #1;
      check_bit("decode_error.issue_suppressed", debug_acc_issue_valid_o, 1'b0);
      tick();
      release dut.u_controller.program_word_w;
      #1;
      check_bit("decode_error.error", error_valid_o, 1'b1);
      check_int("decode_error.code", error_code_o, 6);
      directed_cases++;
    end
  endtask

  task automatic test_datapath_error;
    begin
      reset_core();
      begin_block(12);
      force dut.datapath_error_valid = 1'b1;
      #1;
      tick();
      release dut.datapath_error_valid;
      #1;
      check_bit("datapath_error.error", error_valid_o, 1'b1);
      check_int("datapath_error.code", error_code_o, 8);
      directed_cases++;
    end
  endtask

  task automatic test_abort_during_load;
    begin
      reset_core();
      begin_block(12);
      abort_i = 1'b1;
      #1;
      check_bit("abort_load.start_block", debug_start_block_o, 1'b1);
      tick();
      abort_i = 1'b0;
      #1;
      check_bit("abort_load.aborted", aborted_o, 1'b1);
      check_bit("abort_load.busy", busy_o, 1'b0);
      check_bit("abort_load.done", done_o, 1'b0);
      check_bit("abort_load.ready", start_ready_o, 1'b1);
      directed_cases++;
    end
  endtask

  task automatic test_abort_during_run;
    begin
      reach_first_pc0(0);
      abort_i = 1'b1;
      #1;
      check_bit("abort_run.no_acc", debug_acc_issue_valid_o, 1'b0);
      check_bit("abort_run.no_rec", debug_rec_issue_valid_o, 1'b0);
      tick();
      abort_i = 1'b0;
      #1;
      check_bit("abort_run.aborted", aborted_o, 1'b1);
      check_bit("abort_run.busy", busy_o, 1'b0);
      tick();
      #1;
      check_bit("abort_run.no_late_acc", debug_acc_issue_valid_o, 1'b0);
      check_bit("abort_run.no_late_rec", debug_rec_issue_valid_o, 1'b0);
      directed_cases++;
    end
  endtask

  task automatic test_abort_during_wait;
    int guard;
    begin
      reset_core();
      reset_run_metrics();
      begin_block(12);
      load_all_columns(1);
      guard = 0;
      while ((debug_state_o != 4'd4) && !error_valid_o && guard < 100) begin
        tick_observed("abort_wait.reach", 0);
        guard++;
      end
      check_int("abort_wait.state", debug_state_o, 4);
      abort_i = 1'b1;
      #1;
      check_bit("abort_wait.no_acc", debug_acc_issue_valid_o, 1'b0);
      check_bit("abort_wait.no_rec", debug_rec_issue_valid_o, 1'b0);
      tick();
      abort_i = 1'b0;
      #1;
      check_bit("abort_wait.aborted", aborted_o, 1'b1);
      check_bit("abort_wait.busy", busy_o, 1'b0);
      directed_cases++;
    end
  endtask

  initial begin
    clk_i = 1'b0;
    rst_i = 1'b0;
    abs_cycle = 0;
    errors = 0;
    directed_cases = 0;
    integrated_cases = 0;
    positive_final_ones = 0;
    positive_final_zeros = 0;
    mixed_final_ones = 0;
    mixed_final_zeros = 0;
    measured_retry_interval = -1;
    measured_retry_interval_12 = -1;
    positive_terminal_done = -1;
    mixed_retry_terminal_done = -1;
    mixed_three_terminal_done = -1;
    mixed_three_retry_interval_01 = -1;
    mixed_three_retry_interval_12 = -1;
    mixed_three_generation_advances = -1;
    mixed_three_epoch0 = -1;
    mixed_three_epoch1 = -1;
    mixed_three_epoch2 = -1;

    if (P != 384 || B != 2 || D_A != 3 || D_R != 3
        || SYNDROME_S != 8 || SYNDROME_Q != 8
        || PHASE9_PROGRAM_LENGTH != 71
        || PHASE9_ACC_ISSUES != 40
        || PHASE9_REC_ISSUES != 40
        || PHASE9_ACC_EDGES != 76
        || PHASE9_REC_EDGES != 76) begin
      $display("FAIL frozen Phase-9 constants");
      errors++;
    end

    run_all_cases = !$value$plusargs("phase9_case=%0d", selected_case);

    if (run_all_cases || selected_case == 1) test_reset_idle();
    if (run_all_cases || selected_case == 2) test_illegal_max();
    if (run_all_cases || selected_case == 3) test_start_when_busy();
    if (run_all_cases || selected_case == 4) test_app_load_errors();
    if (run_all_cases || selected_case == 5) test_not_ready_error();
    if (run_all_cases || selected_case == 6) test_schedule_decode_error();
    if (run_all_cases || selected_case == 7) test_datapath_error();
    if (run_all_cases || selected_case == 8) test_abort_during_load();
    if (run_all_cases || selected_case == 9) test_abort_during_run();
    if (run_all_cases || selected_case == 10) test_abort_during_wait();

    if (run_all_cases || selected_case == 11) begin
      run_integrated_block("positive_success", 0, 12, 1, 1, 0, 0);
    end
    if (run_all_cases || selected_case == 12) begin
      run_integrated_block("mixed_max1", 1, 1, 1, 0, 1, 0);
    end
    if (run_all_cases || selected_case == 13) begin
      run_integrated_block("mixed_retry_max2", 1, 2, 2, 0, 1, 1);
    end
    if (run_all_cases || selected_case == 14) begin
      run_integrated_block("mixed_pingpong_max3", 1, 3, 3, -1, -1, 1);
    end

    if (errors == 0) begin
      $display("PASS phase9 decoder core controller");
      $display("directed_cases=%0d integrated_cases=%0d", directed_cases, integrated_cases);
      $display("positive_success_iterations=1 syndrome_zero=1 hard_ones=%0d hard_zeros=%0d", positive_final_ones, positive_final_zeros);
      $display("mixed_max1_iterations=1 syndrome_zero=0 hard_ones=%0d hard_zeros=%0d", mixed_final_ones, mixed_final_zeros);
      $display("one_iteration_terminal_done=%0d", positive_terminal_done);
      $display("mixed_retry_iterations=2 generation_advances=1 retry_pc0_interval=%0d terminal_done=%0d", measured_retry_interval, mixed_retry_terminal_done);
      $display("mixed_pingpong_iterations=3 generation_advances=%0d epochs=%0d/%0d/%0d retry_intervals=%0d/%0d terminal_done=%0d",
          mixed_three_generation_advances,
          mixed_three_epoch0,
          mixed_three_epoch1,
          mixed_three_epoch2,
          mixed_three_retry_interval_01,
          mixed_three_retry_interval_12,
          mixed_three_terminal_done);
      $display("decoder_schedule_cycles=71 syndrome_completion_cycle=%0d syndrome_decision_cycle=%0d controller_retry_pc0_to_pc0=%0d", syndrome_completion_cycle, first_syndrome_decision, measured_retry_interval);
      $display("acc_issue_count=%0d rec_issue_count=%0d acc_edges=%0d rec_edges=%0d", acc_issue_count, rec_issue_count, acc_edge_count, rec_edge_count);
      $display("finalized_columns=%0d consumed_work_items=%0d max_queue=%0d max_backlog=%0d", finalized_columns_count_o, consumed_work_items_count_o, syndrome_max_queue_occupancy_o, syndrome_max_backlog_o);
      $finish;
    end

    $display("FAIL phase9 decoder core controller errors=%0d", errors);
    $finish(1);
  end
endmodule
