`ifndef NR_LDPC_SYNDROME_DATAPATH_SV
`define NR_LDPC_SYNDROME_DATAPATH_SV

module nr_ldpc_syndrome_datapath #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic                         clk_i,
  input  logic                         rst_i,
  input  logic                         start_block_i,
  input  logic                         advance_iteration_i,
  input  logic                         start_iteration_i,
  input  logic [3:0]                   syndrome_iteration_epoch_i,

  input  logic                         app_load_valid_i,
  input  logic [6:0]                   app_load_column_i,
  input  logic [3:0]                   app_load_iteration_epoch_i,
  input  logic [P*8-1:0]               app_load_i,

  input  logic                         acc_issue_valid_i,
  output logic                         acc_issue_ready_o,
  input  logic [1:0]                   acc_issue_lane_mask_i,
  input  logic [5:0]                   acc_issue_layer_id_i,
  input  logic [5:0]                   acc_issue_layer_position_i,
  input  logic [5:0]                   acc_issue_layer_degree_i,
  input  logic                         acc_issue_start_layer_i,
  input  logic [4:0]                   acc_issue_edge0_id_i,
  input  logic [4:0]                   acc_issue_edge1_id_i,
  input  logic [0:0]                   acc_issue_qbuf_i,
  input  logic [3:0]                   acc_issue_qslot_i,
  input  logic [3:0]                   acc_issue_iteration_epoch_i,
  input  logic [6:0]                   acc_issue_base_column0_i,
  input  logic [6:0]                   acc_issue_base_column1_i,
  input  logic [3:0]                   acc_issue_aux0_i,
  input  logic [3:0]                   acc_issue_aux1_i,
  input  logic [$clog2(P+1)-1:0]       acc_issue_shift0_i,
  input  logic [$clog2(P+1)-1:0]       acc_issue_shift1_i,

  input  logic                         rec_issue_valid_i,
  output logic                         rec_issue_ready_o,
  input  logic [1:0]                   rec_issue_lane_mask_i,
  input  logic [5:0]                   rec_issue_layer_id_i,
  input  logic [4:0]                   rec_issue_edge0_id_i,
  input  logic [4:0]                   rec_issue_edge1_id_i,
  input  logic [0:0]                   rec_issue_qbuf_i,
  input  logic [3:0]                   rec_issue_qslot_i,
  input  logic [3:0]                   rec_issue_iteration_epoch_i,
  input  logic [$clog2(P+1)-1:0]       rec_issue_shift0_i,
  input  logic [$clog2(P+1)-1:0]       rec_issue_shift1_i,
  input  logic [6:0]                   rec_issue_base_column0_i,
  input  logic [6:0]                   rec_issue_base_column1_i,
  input  logic [3:0]                   rec_issue_aux0_i,
  input  logic [3:0]                   rec_issue_aux1_i,
  input  logic                         rec_issue_final_touch0_i,
  input  logic                         rec_issue_final_touch1_i,

  output logic [1:0]                   rec_final_touch_valid_o,
  output logic [6:0]                   rec_final_touch_base_column0_o,
  output logic [6:0]                   rec_final_touch_base_column1_o,
  output logic [3:0]                   rec_final_touch_iteration_epoch_o,
  output logic [P-1:0]                 rec_final_touch_hard0_o,
  output logic [P-1:0]                 rec_final_touch_hard1_o,

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

  output logic                         error_valid_o,
  output logic [1:0]                   debug_acc_source_valid_o,
  output logic [1:0]                   debug_acc_source_forwarded_o,
  output logic [1:0]                   debug_forward_alloc_valid_o,
  output logic [1:0]                   debug_forward_alloc_accept_o,
  output logic [5:0]                   debug_forward_live_count_o,
  output logic                         debug_app_same_bank_collision_o
);
  import nr_ldpc_pkg::*;

  logic [1:0] rec_app_write_valid_o;
  logic [P*8-1:0] rec_app_write_lane0_o;
  logic [P*8-1:0] rec_app_write_lane1_o;
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
  logic [P*8-1:0] rec_forward_app0_o;
  logic [P*8-1:0] rec_forward_app1_o;

  logic [5:0] rec_final_touch_layer_id_o;
  logic [4:0] rec_final_touch_edge0_id_o;
  logic [4:0] rec_final_touch_edge1_id_o;
  logic [P*8-1:0] rec_final_touch_app0_o;
  logic [P*8-1:0] rec_final_touch_app1_o;

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

  logic current_old_generation_o;
  logic current_new_generation_o;
  logic [P*8-1:0] debug_acc_source0_app_o;
  logic [P*8-1:0] debug_acc_source1_app_o;
  logic [2:0] debug_app_read_bank0_o;
  logic [2:0] debug_app_read_bank1_o;
  logic [2:0] debug_app_write_bank0_o;
  logic [2:0] debug_app_write_bank1_o;
  logic [1:0] debug_app_write_accept_o;
  logic debug_app_write_commit_o;
  logic [1:0] debug_forward_read_valid_o;
  logic [1:0] debug_forward_read_accept_o;
  logic [1:0] debug_forward_candidate_valid_o;
  logic [2:0] debug_forward_candidate_slot0_o;
  logic [2:0] debug_forward_candidate_slot1_o;
  logic [6:0] debug_forward_candidate_base_column0_o;
  logic [6:0] debug_forward_candidate_base_column1_o;
  logic [3:0] debug_forward_candidate_iteration_epoch_o;
  logic [P*8-1:0] debug_forward_candidate_app0_o;
  logic [P*8-1:0] debug_forward_candidate_app1_o;
  logic [1:0] debug_rec_publication_valid_o;
  logic debug_acc_q_write_valid_o;
  logic [0:0] debug_acc_q_write_qbuf_o;
  logic [3:0] debug_acc_q_write_qslot_o;
  logic [1:0] debug_acc_q_write_lane_mask_o;
  logic [P*8-1:0] debug_acc_q_write_lane0_o;
  logic [P*8-1:0] debug_acc_q_write_lane1_o;
  logic [5:0] debug_acc_q_write_layer_id_o;
  logic [3:0] debug_acc_q_write_iteration_epoch_o;
  logic [1:0] debug_acc_qsign_write_valid_o;
  logic [4:0] debug_acc_qsign_write_edge0_id_o;
  logic [4:0] debug_acc_qsign_write_edge1_id_o;
  logic [P-1:0] debug_acc_qsign_write_lane0_o;
  logic [P-1:0] debug_acc_qsign_write_lane1_o;
  logic debug_layer_close_valid_o;
  logic [5:0] debug_layer_close_layer_id_o;
  logic [P*6-1:0] debug_layer_close_m1_o;
  logic [P*6-1:0] debug_layer_close_m2_o;
  logic [P*5-1:0] debug_layer_close_imin_o;
  logic [P-1:0] debug_layer_close_aggregate_sign_o;
  logic debug_q_write_accept_o;
  logic debug_advance_accept_o;
  logic debug_acc_old_resp_valid_o;
  logic debug_acc_old_generation_valid_o;
  logic debug_rec_new_resp_valid_o;
  logic debug_rec_new_state_closed_o;
  logic [P*6-1:0] debug_rec_new_m1_o;
  logic [P*6-1:0] debug_rec_new_m2_o;
  logic [P*5-1:0] debug_rec_new_imin_o;
  logic [P-1:0] debug_rec_new_aggregate_sign_o;
  logic [P*8-1:0] debug_q_read_resp_lane0_o;
  logic [P*8-1:0] debug_q_read_resp_lane1_o;
  logic [5:0] debug_q_read_resp_layer_id_o;
  logic [3:0] debug_q_read_resp_qslot_o;
  logic [5:0] debug_q_live_count_o;

  nr_ldpc_app_forward_datapath #(
    .P(P)
  ) u_app_forward (.*);

  nr_ldpc_syndrome_engine #(
    .P(P),
    .S(SYNDROME_S),
    .Q(SYNDROME_Q)
  ) u_syndrome_engine (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_iteration_i(start_iteration_i),
    .iteration_epoch_i(syndrome_iteration_epoch_i),
    .final_touch_valid_i(rec_final_touch_valid_o),
    .final_touch_base_column0_i(rec_final_touch_base_column0_o),
    .final_touch_base_column1_i(rec_final_touch_base_column1_o),
    .final_touch_iteration_epoch_i(rec_final_touch_iteration_epoch_o),
    .final_touch_hard0_i(rec_final_touch_hard0_o),
    .final_touch_hard1_i(rec_final_touch_hard1_o),
    .syndrome_done_o(syndrome_done_o),
    .syndrome_zero_o(syndrome_zero_o),
    .syndrome_row0_o(syndrome_row0_o),
    .syndrome_row1_o(syndrome_row1_o),
    .syndrome_row2_o(syndrome_row2_o),
    .syndrome_row3_o(syndrome_row3_o),
    .error_valid_o(syndrome_error_valid_o),
    .error_code_o(syndrome_error_code_o),
    .finalized_columns_count_o(finalized_columns_count_o),
    .consumed_work_items_count_o(consumed_work_items_count_o),
    .queue_occupancy_o(syndrome_queue_occupancy_o),
    .max_queue_occupancy_o(syndrome_max_queue_occupancy_o),
    .max_syndrome_backlog_o(syndrome_max_backlog_o),
    .work_items_consumed_this_cycle_o(syndrome_work_items_consumed_this_cycle_o)
  );

  assign error_valid_o = acc_error_valid_o
      || rec_error_valid_o
      || q_scratch_error_valid_o
      || check_state_error_valid_o
      || old_state_alignment_error_o
      || unsafe_advance_error_o
      || phase6_storage_error_valid_o
      || app_memory_error_valid_o
      || forward_error_valid_o
      || app_forward_error_valid_o
      || storage_error_valid_o
      || syndrome_error_valid_o;
endmodule

`endif
