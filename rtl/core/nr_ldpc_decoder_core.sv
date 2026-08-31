`ifndef NR_LDPC_DECODER_CORE_SV
`define NR_LDPC_DECODER_CORE_SV

module nr_ldpc_decoder_core #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic                         clk_i,
  input  logic                         rst_i,
  input  logic                         start_i,
  input  logic                         abort_i,
  input  logic [3:0]                   max_iterations_i,

  input  logic                         app_load_valid_i,
  input  logic [6:0]                   app_load_column_i,
  input  logic [P*8-1:0]               app_load_i,
  output logic                         app_load_ready_o,

  output logic                         start_ready_o,
  output logic                         busy_o,
  output logic                         done_o,
  output logic                         decode_success_o,
  output logic                         max_iterations_reached_o,
  output logic                         aborted_o,
  output logic                         error_valid_o,
  output logic [7:0]                   error_code_o,
  output logic [3:0]                   completed_iterations_o,
  output logic [3:0]                   current_iteration_epoch_o,
  output logic [8:0]                   program_counter_o,

  output logic                         syndrome_done_o,
  output logic                         syndrome_zero_o,
  output logic [P-1:0]                 syndrome_row0_o,
  output logic [P-1:0]                 syndrome_row1_o,
  output logic [P-1:0]                 syndrome_row2_o,
  output logic [P-1:0]                 syndrome_row3_o,
  output logic                         syndrome_error_valid_o,
  output logic [7:0]                   syndrome_error_code_o,
  output logic [5:0]                   finalized_columns_count_o,
  output logic [6:0]                   consumed_work_items_count_o,
  output logic [3:0]                   syndrome_queue_occupancy_o,
  output logic [3:0]                   syndrome_max_queue_occupancy_o,
  output logic [6:0]                   syndrome_max_backlog_o,
  output logic [3:0]                   syndrome_work_items_consumed_this_cycle_o,

  output logic [1:0]                   rec_final_touch_valid_o,
  output logic [6:0]                   rec_final_touch_base_column0_o,
  output logic [6:0]                   rec_final_touch_base_column1_o,
  output logic [3:0]                   rec_final_touch_iteration_epoch_o,
  output logic [P-1:0]                 rec_final_touch_hard0_o,
  output logic [P-1:0]                 rec_final_touch_hard1_o,

  output logic [3:0]                   debug_state_o,
  output logic                         debug_program_issue_valid_o,
  output logic [71:0]                  debug_schedule_word_o,
  output logic [35:0]                  debug_acc_word_o,
  output logic [35:0]                  debug_rec_word_o,
  output logic                         debug_start_block_o,
  output logic                         debug_start_iteration_o,
  output logic                         debug_advance_iteration_o,
  output logic                         debug_advance_accept_o,
  output logic                         debug_decision_valid_o,
  output logic                         debug_retry_decision_o,
  output logic                         debug_app_load_accept_o,
  output logic [25:0]                  debug_app_load_seen_o,
  output logic [3:0]                   debug_acc_seen_layers_o,

  output logic                         debug_acc_issue_valid_o,
  output logic                         debug_acc_issue_ready_o,
  output logic [1:0]                   debug_acc_issue_lane_mask_o,
  output logic [5:0]                   debug_acc_issue_layer_id_o,
  output logic [5:0]                   debug_acc_issue_layer_position_o,
  output logic [5:0]                   debug_acc_issue_layer_degree_o,
  output logic                         debug_acc_issue_start_layer_o,
  output logic [4:0]                   debug_acc_issue_edge0_id_o,
  output logic [4:0]                   debug_acc_issue_edge1_id_o,
  output logic [0:0]                   debug_acc_issue_qbuf_o,
  output logic [3:0]                   debug_acc_issue_qslot_o,
  output logic [3:0]                   debug_acc_issue_iteration_epoch_o,
  output logic [6:0]                   debug_acc_issue_base_column0_o,
  output logic [6:0]                   debug_acc_issue_base_column1_o,
  output logic [3:0]                   debug_acc_issue_aux0_o,
  output logic [3:0]                   debug_acc_issue_aux1_o,
  output logic [$clog2(P+1)-1:0]       debug_acc_issue_shift0_o,
  output logic [$clog2(P+1)-1:0]       debug_acc_issue_shift1_o,

  output logic                         debug_rec_issue_valid_o,
  output logic                         debug_rec_issue_ready_o,
  output logic [1:0]                   debug_rec_issue_lane_mask_o,
  output logic [5:0]                   debug_rec_issue_layer_id_o,
  output logic [4:0]                   debug_rec_issue_edge0_id_o,
  output logic [4:0]                   debug_rec_issue_edge1_id_o,
  output logic [0:0]                   debug_rec_issue_qbuf_o,
  output logic [3:0]                   debug_rec_issue_qslot_o,
  output logic [3:0]                   debug_rec_issue_iteration_epoch_o,
  output logic [$clog2(P+1)-1:0]       debug_rec_issue_shift0_o,
  output logic [$clog2(P+1)-1:0]       debug_rec_issue_shift1_o,
  output logic [6:0]                   debug_rec_issue_base_column0_o,
  output logic [6:0]                   debug_rec_issue_base_column1_o,
  output logic [3:0]                   debug_rec_issue_aux0_o,
  output logic [3:0]                   debug_rec_issue_aux1_o,
  output logic                         debug_rec_issue_final_touch0_o,
  output logic                         debug_rec_issue_final_touch1_o,

  output logic [1:0]                   debug_acc_source_valid_o,
  output logic [1:0]                   debug_acc_source_forwarded_o,
  output logic [1:0]                   debug_forward_alloc_valid_o,
  output logic [1:0]                   debug_forward_alloc_accept_o,
  output logic [5:0]                   debug_forward_live_count_o,
  output logic                         debug_app_same_bank_collision_o
);
  import nr_ldpc_pkg::*;

  logic ctrl_start_block;
  logic ctrl_advance_iteration;
  logic ctrl_start_iteration;
  logic [3:0] ctrl_syndrome_epoch;

  logic ctrl_app_load_valid;
  logic [6:0] ctrl_app_load_column;
  logic [3:0] ctrl_app_load_epoch;
  logic [P*W_APP-1:0] ctrl_app_load;

  logic ctrl_acc_issue_valid;
  logic ctrl_acc_issue_ready;
  logic [1:0] ctrl_acc_issue_lane_mask;
  logic [5:0] ctrl_acc_issue_layer_id;
  logic [5:0] ctrl_acc_issue_layer_position;
  logic [5:0] ctrl_acc_issue_layer_degree;
  logic ctrl_acc_issue_start_layer;
  logic [4:0] ctrl_acc_issue_edge0_id;
  logic [4:0] ctrl_acc_issue_edge1_id;
  logic [0:0] ctrl_acc_issue_qbuf;
  logic [3:0] ctrl_acc_issue_qslot;
  logic [3:0] ctrl_acc_issue_iteration_epoch;
  logic [6:0] ctrl_acc_issue_base_column0;
  logic [6:0] ctrl_acc_issue_base_column1;
  logic [3:0] ctrl_acc_issue_aux0;
  logic [3:0] ctrl_acc_issue_aux1;
  logic [$clog2(P+1)-1:0] ctrl_acc_issue_shift0;
  logic [$clog2(P+1)-1:0] ctrl_acc_issue_shift1;

  logic ctrl_rec_issue_valid;
  logic ctrl_rec_issue_ready;
  logic [1:0] ctrl_rec_issue_lane_mask;
  logic [5:0] ctrl_rec_issue_layer_id;
  logic [4:0] ctrl_rec_issue_edge0_id;
  logic [4:0] ctrl_rec_issue_edge1_id;
  logic [0:0] ctrl_rec_issue_qbuf;
  logic [3:0] ctrl_rec_issue_qslot;
  logic [3:0] ctrl_rec_issue_iteration_epoch;
  logic [$clog2(P+1)-1:0] ctrl_rec_issue_shift0;
  logic [$clog2(P+1)-1:0] ctrl_rec_issue_shift1;
  logic [6:0] ctrl_rec_issue_base_column0;
  logic [6:0] ctrl_rec_issue_base_column1;
  logic [3:0] ctrl_rec_issue_aux0;
  logic [3:0] ctrl_rec_issue_aux1;
  logic ctrl_rec_issue_final_touch0;
  logic ctrl_rec_issue_final_touch1;

  wire datapath_error_valid;
  wire datapath_advance_accept;

  nr_ldpc_schedule_controller #(
    .P(P)
  ) u_controller (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_i(start_i),
    .abort_i(abort_i),
    .max_iterations_i(max_iterations_i),
    .app_load_valid_i(app_load_valid_i),
    .app_load_column_i(app_load_column_i),
    .app_load_i(app_load_i),
    .app_load_ready_o(app_load_ready_o),
    .acc_issue_ready_i(ctrl_acc_issue_ready),
    .rec_issue_ready_i(ctrl_rec_issue_ready),
    .syndrome_done_i(syndrome_done_o),
    .syndrome_zero_i(syndrome_zero_o),
    .datapath_error_valid_i(datapath_error_valid),
    .datapath_advance_accept_i(datapath_advance_accept),
    .datapath_start_block_o(ctrl_start_block),
    .datapath_advance_iteration_o(ctrl_advance_iteration),
    .datapath_start_iteration_o(ctrl_start_iteration),
    .datapath_syndrome_iteration_epoch_o(ctrl_syndrome_epoch),
    .datapath_app_load_valid_o(ctrl_app_load_valid),
    .datapath_app_load_column_o(ctrl_app_load_column),
    .datapath_app_load_iteration_epoch_o(ctrl_app_load_epoch),
    .datapath_app_load_o(ctrl_app_load),
    .acc_issue_valid_o(ctrl_acc_issue_valid),
    .acc_issue_lane_mask_o(ctrl_acc_issue_lane_mask),
    .acc_issue_layer_id_o(ctrl_acc_issue_layer_id),
    .acc_issue_layer_position_o(ctrl_acc_issue_layer_position),
    .acc_issue_layer_degree_o(ctrl_acc_issue_layer_degree),
    .acc_issue_start_layer_o(ctrl_acc_issue_start_layer),
    .acc_issue_edge0_id_o(ctrl_acc_issue_edge0_id),
    .acc_issue_edge1_id_o(ctrl_acc_issue_edge1_id),
    .acc_issue_qbuf_o(ctrl_acc_issue_qbuf),
    .acc_issue_qslot_o(ctrl_acc_issue_qslot),
    .acc_issue_iteration_epoch_o(ctrl_acc_issue_iteration_epoch),
    .acc_issue_base_column0_o(ctrl_acc_issue_base_column0),
    .acc_issue_base_column1_o(ctrl_acc_issue_base_column1),
    .acc_issue_aux0_o(ctrl_acc_issue_aux0),
    .acc_issue_aux1_o(ctrl_acc_issue_aux1),
    .acc_issue_shift0_o(ctrl_acc_issue_shift0),
    .acc_issue_shift1_o(ctrl_acc_issue_shift1),
    .rec_issue_valid_o(ctrl_rec_issue_valid),
    .rec_issue_lane_mask_o(ctrl_rec_issue_lane_mask),
    .rec_issue_layer_id_o(ctrl_rec_issue_layer_id),
    .rec_issue_edge0_id_o(ctrl_rec_issue_edge0_id),
    .rec_issue_edge1_id_o(ctrl_rec_issue_edge1_id),
    .rec_issue_qbuf_o(ctrl_rec_issue_qbuf),
    .rec_issue_qslot_o(ctrl_rec_issue_qslot),
    .rec_issue_iteration_epoch_o(ctrl_rec_issue_iteration_epoch),
    .rec_issue_shift0_o(ctrl_rec_issue_shift0),
    .rec_issue_shift1_o(ctrl_rec_issue_shift1),
    .rec_issue_base_column0_o(ctrl_rec_issue_base_column0),
    .rec_issue_base_column1_o(ctrl_rec_issue_base_column1),
    .rec_issue_aux0_o(ctrl_rec_issue_aux0),
    .rec_issue_aux1_o(ctrl_rec_issue_aux1),
    .rec_issue_final_touch0_o(ctrl_rec_issue_final_touch0),
    .rec_issue_final_touch1_o(ctrl_rec_issue_final_touch1),
    .start_ready_o(start_ready_o),
    .busy_o(busy_o),
    .done_o(done_o),
    .decode_success_o(decode_success_o),
    .max_iterations_reached_o(max_iterations_reached_o),
    .aborted_o(aborted_o),
    .error_valid_o(error_valid_o),
    .error_code_o(error_code_o),
    .completed_iterations_o(completed_iterations_o),
    .current_iteration_epoch_o(current_iteration_epoch_o),
    .program_counter_o(program_counter_o),
    .debug_state_o(debug_state_o),
    .debug_program_issue_valid_o(debug_program_issue_valid_o),
    .debug_schedule_word_o(debug_schedule_word_o),
    .debug_acc_word_o(debug_acc_word_o),
    .debug_rec_word_o(debug_rec_word_o),
    .debug_start_block_o(debug_start_block_o),
    .debug_start_iteration_o(debug_start_iteration_o),
    .debug_advance_iteration_o(debug_advance_iteration_o),
    .debug_decision_valid_o(debug_decision_valid_o),
    .debug_retry_decision_o(debug_retry_decision_o),
    .debug_app_load_accept_o(debug_app_load_accept_o),
    .debug_app_load_seen_o(debug_app_load_seen_o),
    .debug_acc_seen_layers_o(debug_acc_seen_layers_o)
  );

  nr_ldpc_syndrome_datapath #(
    .P(P)
  ) u_datapath (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_block_i(ctrl_start_block),
    .advance_iteration_i(ctrl_advance_iteration),
    .start_iteration_i(ctrl_start_iteration),
    .syndrome_iteration_epoch_i(ctrl_syndrome_epoch),
    .app_load_valid_i(ctrl_app_load_valid),
    .app_load_column_i(ctrl_app_load_column),
    .app_load_iteration_epoch_i(ctrl_app_load_epoch),
    .app_load_i(ctrl_app_load),
    .acc_issue_valid_i(ctrl_acc_issue_valid),
    .acc_issue_ready_o(ctrl_acc_issue_ready),
    .acc_issue_lane_mask_i(ctrl_acc_issue_lane_mask),
    .acc_issue_layer_id_i(ctrl_acc_issue_layer_id),
    .acc_issue_layer_position_i(ctrl_acc_issue_layer_position),
    .acc_issue_layer_degree_i(ctrl_acc_issue_layer_degree),
    .acc_issue_start_layer_i(ctrl_acc_issue_start_layer),
    .acc_issue_edge0_id_i(ctrl_acc_issue_edge0_id),
    .acc_issue_edge1_id_i(ctrl_acc_issue_edge1_id),
    .acc_issue_qbuf_i(ctrl_acc_issue_qbuf),
    .acc_issue_qslot_i(ctrl_acc_issue_qslot),
    .acc_issue_iteration_epoch_i(ctrl_acc_issue_iteration_epoch),
    .acc_issue_base_column0_i(ctrl_acc_issue_base_column0),
    .acc_issue_base_column1_i(ctrl_acc_issue_base_column1),
    .acc_issue_aux0_i(ctrl_acc_issue_aux0),
    .acc_issue_aux1_i(ctrl_acc_issue_aux1),
    .acc_issue_shift0_i(ctrl_acc_issue_shift0),
    .acc_issue_shift1_i(ctrl_acc_issue_shift1),
    .rec_issue_valid_i(ctrl_rec_issue_valid),
    .rec_issue_ready_o(ctrl_rec_issue_ready),
    .rec_issue_lane_mask_i(ctrl_rec_issue_lane_mask),
    .rec_issue_layer_id_i(ctrl_rec_issue_layer_id),
    .rec_issue_edge0_id_i(ctrl_rec_issue_edge0_id),
    .rec_issue_edge1_id_i(ctrl_rec_issue_edge1_id),
    .rec_issue_qbuf_i(ctrl_rec_issue_qbuf),
    .rec_issue_qslot_i(ctrl_rec_issue_qslot),
    .rec_issue_iteration_epoch_i(ctrl_rec_issue_iteration_epoch),
    .rec_issue_shift0_i(ctrl_rec_issue_shift0),
    .rec_issue_shift1_i(ctrl_rec_issue_shift1),
    .rec_issue_base_column0_i(ctrl_rec_issue_base_column0),
    .rec_issue_base_column1_i(ctrl_rec_issue_base_column1),
    .rec_issue_aux0_i(ctrl_rec_issue_aux0),
    .rec_issue_aux1_i(ctrl_rec_issue_aux1),
    .rec_issue_final_touch0_i(ctrl_rec_issue_final_touch0),
    .rec_issue_final_touch1_i(ctrl_rec_issue_final_touch1),
    .rec_final_touch_valid_o(rec_final_touch_valid_o),
    .rec_final_touch_base_column0_o(rec_final_touch_base_column0_o),
    .rec_final_touch_base_column1_o(rec_final_touch_base_column1_o),
    .rec_final_touch_iteration_epoch_o(rec_final_touch_iteration_epoch_o),
    .rec_final_touch_hard0_o(rec_final_touch_hard0_o),
    .rec_final_touch_hard1_o(rec_final_touch_hard1_o),
    .syndrome_done_o(syndrome_done_o),
    .syndrome_zero_o(syndrome_zero_o),
    .syndrome_row0_o(syndrome_row0_o),
    .syndrome_row1_o(syndrome_row1_o),
    .syndrome_row2_o(syndrome_row2_o),
    .syndrome_row3_o(syndrome_row3_o),
    .syndrome_error_valid_o(syndrome_error_valid_o),
    .syndrome_error_code_o(syndrome_error_code_o),
    .finalized_columns_count_o(finalized_columns_count_o),
    .consumed_work_items_count_o(consumed_work_items_count_o),
    .syndrome_queue_occupancy_o(syndrome_queue_occupancy_o),
    .syndrome_max_queue_occupancy_o(syndrome_max_queue_occupancy_o),
    .syndrome_max_backlog_o(syndrome_max_backlog_o),
    .syndrome_work_items_consumed_this_cycle_o(syndrome_work_items_consumed_this_cycle_o),
    .error_valid_o(datapath_error_valid),
    .debug_acc_source_valid_o(debug_acc_source_valid_o),
    .debug_acc_source_forwarded_o(debug_acc_source_forwarded_o),
    .debug_forward_alloc_valid_o(debug_forward_alloc_valid_o),
    .debug_forward_alloc_accept_o(debug_forward_alloc_accept_o),
    .debug_forward_live_count_o(debug_forward_live_count_o),
    .debug_app_same_bank_collision_o(debug_app_same_bank_collision_o),
    .debug_advance_accept_o(datapath_advance_accept)
  );

  assign debug_advance_accept_o = datapath_advance_accept;

  assign debug_acc_issue_valid_o = ctrl_acc_issue_valid;
  assign debug_acc_issue_ready_o = ctrl_acc_issue_ready;
  assign debug_acc_issue_lane_mask_o = ctrl_acc_issue_lane_mask;
  assign debug_acc_issue_layer_id_o = ctrl_acc_issue_layer_id;
  assign debug_acc_issue_layer_position_o = ctrl_acc_issue_layer_position;
  assign debug_acc_issue_layer_degree_o = ctrl_acc_issue_layer_degree;
  assign debug_acc_issue_start_layer_o = ctrl_acc_issue_start_layer;
  assign debug_acc_issue_edge0_id_o = ctrl_acc_issue_edge0_id;
  assign debug_acc_issue_edge1_id_o = ctrl_acc_issue_edge1_id;
  assign debug_acc_issue_qbuf_o = ctrl_acc_issue_qbuf;
  assign debug_acc_issue_qslot_o = ctrl_acc_issue_qslot;
  assign debug_acc_issue_iteration_epoch_o = ctrl_acc_issue_iteration_epoch;
  assign debug_acc_issue_base_column0_o = ctrl_acc_issue_base_column0;
  assign debug_acc_issue_base_column1_o = ctrl_acc_issue_base_column1;
  assign debug_acc_issue_aux0_o = ctrl_acc_issue_aux0;
  assign debug_acc_issue_aux1_o = ctrl_acc_issue_aux1;
  assign debug_acc_issue_shift0_o = ctrl_acc_issue_shift0;
  assign debug_acc_issue_shift1_o = ctrl_acc_issue_shift1;

  assign debug_rec_issue_valid_o = ctrl_rec_issue_valid;
  assign debug_rec_issue_ready_o = ctrl_rec_issue_ready;
  assign debug_rec_issue_lane_mask_o = ctrl_rec_issue_lane_mask;
  assign debug_rec_issue_layer_id_o = ctrl_rec_issue_layer_id;
  assign debug_rec_issue_edge0_id_o = ctrl_rec_issue_edge0_id;
  assign debug_rec_issue_edge1_id_o = ctrl_rec_issue_edge1_id;
  assign debug_rec_issue_qbuf_o = ctrl_rec_issue_qbuf;
  assign debug_rec_issue_qslot_o = ctrl_rec_issue_qslot;
  assign debug_rec_issue_iteration_epoch_o = ctrl_rec_issue_iteration_epoch;
  assign debug_rec_issue_shift0_o = ctrl_rec_issue_shift0;
  assign debug_rec_issue_shift1_o = ctrl_rec_issue_shift1;
  assign debug_rec_issue_base_column0_o = ctrl_rec_issue_base_column0;
  assign debug_rec_issue_base_column1_o = ctrl_rec_issue_base_column1;
  assign debug_rec_issue_aux0_o = ctrl_rec_issue_aux0;
  assign debug_rec_issue_aux1_o = ctrl_rec_issue_aux1;
  assign debug_rec_issue_final_touch0_o = ctrl_rec_issue_final_touch0;
  assign debug_rec_issue_final_touch1_o = ctrl_rec_issue_final_touch1;
endmodule

`endif
