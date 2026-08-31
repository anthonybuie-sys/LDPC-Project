`ifndef NR_LDPC_ACC_REC_DATAPATH_SV
`define NR_LDPC_ACC_REC_DATAPATH_SV

module nr_ldpc_acc_rec_datapath #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic                         clk_i,
  input  logic                         rst_i,
  input  logic                         start_block_i,
  input  logic                         advance_iteration_i,

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
  input  logic [P*8-1:0]               acc_issue_app0_canonical_i,
  input  logic [P*8-1:0]               acc_issue_app1_canonical_i,
  input  logic                         acc_issue_source0_valid_i,
  input  logic                         acc_issue_source1_valid_i,
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

  output logic [1:0]                   rec_app_write_valid_o,
  output logic [P*8-1:0]               rec_app_write_lane0_o,
  output logic [P*8-1:0]               rec_app_write_lane1_o,
  output logic [6:0]                   rec_app_write_base_column0_o,
  output logic [6:0]                   rec_app_write_base_column1_o,
  output logic [1:0]                   rec_app_write_lane_mask_o,
  output logic [5:0]                   rec_app_write_layer_id_o,
  output logic [4:0]                   rec_app_write_edge0_id_o,
  output logic [4:0]                   rec_app_write_edge1_id_o,
  output logic [3:0]                   rec_app_write_iteration_epoch_o,
  output logic [0:0]                   rec_app_write_qbuf_o,
  output logic [3:0]                   rec_app_write_qslot_o,
  output logic [3:0]                   rec_app_write_aux0_o,
  output logic [3:0]                   rec_app_write_aux1_o,
  output logic                         rec_app_write_final_touch0_o,
  output logic                         rec_app_write_final_touch1_o,

  output logic [1:0]                   rec_forward_candidate_valid_o,
  output logic [P*8-1:0]               rec_forward_candidate_lane0_o,
  output logic [P*8-1:0]               rec_forward_candidate_lane1_o,
  output logic [6:0]                   rec_forward_candidate_base_column0_o,
  output logic [6:0]                   rec_forward_candidate_base_column1_o,
  output logic [3:0]                   rec_forward_candidate_iteration_epoch_o,
  output logic [3:0]                   rec_forward_candidate_aux0_o,
  output logic [3:0]                   rec_forward_candidate_aux1_o,

  output logic [1:0]                   rec_forward_valid_o,
  output logic [2:0]                   rec_forward_slot0_o,
  output logic [2:0]                   rec_forward_slot1_o,
  output logic [6:0]                   rec_forward_base_column0_o,
  output logic [6:0]                   rec_forward_base_column1_o,
  output logic [3:0]                   rec_forward_iteration_epoch_o,
  output logic [P*8-1:0]               rec_forward_app0_o,
  output logic [P*8-1:0]               rec_forward_app1_o,

  output logic [1:0]                   rec_final_touch_valid_o,
  output logic [6:0]                   rec_final_touch_base_column0_o,
  output logic [6:0]                   rec_final_touch_base_column1_o,
  output logic [5:0]                   rec_final_touch_layer_id_o,
  output logic [4:0]                   rec_final_touch_edge0_id_o,
  output logic [4:0]                   rec_final_touch_edge1_id_o,
  output logic [3:0]                   rec_final_touch_iteration_epoch_o,
  output logic [P*8-1:0]               rec_final_touch_app0_o,
  output logic [P*8-1:0]               rec_final_touch_app1_o,
  output logic [P-1:0]                 rec_final_touch_hard0_o,
  output logic [P-1:0]                 rec_final_touch_hard1_o,

  output logic                         acc_error_valid_o,
  output logic                         rec_error_valid_o,
  output logic                         q_scratch_error_valid_o,
  output logic [7:0]                   q_scratch_error_code_o,
  output logic                         check_state_error_valid_o,
  output logic [7:0]                   check_state_error_code_o,
  output logic                         old_state_alignment_error_o,
  output logic                         unsafe_advance_error_o,
  output logic                         storage_error_valid_o,

  output logic                         current_old_generation_o,
  output logic                         current_new_generation_o,

  output logic                         debug_acc_q_write_valid_o,
  output logic [0:0]                   debug_acc_q_write_qbuf_o,
  output logic [3:0]                   debug_acc_q_write_qslot_o,
  output logic [1:0]                   debug_acc_q_write_lane_mask_o,
  output logic [P*8-1:0]               debug_acc_q_write_lane0_o,
  output logic [P*8-1:0]               debug_acc_q_write_lane1_o,
  output logic [5:0]                   debug_acc_q_write_layer_id_o,
  output logic [3:0]                   debug_acc_q_write_iteration_epoch_o,
  output logic [1:0]                   debug_acc_qsign_write_valid_o,
  output logic [4:0]                   debug_acc_qsign_write_edge0_id_o,
  output logic [4:0]                   debug_acc_qsign_write_edge1_id_o,
  output logic [P-1:0]                 debug_acc_qsign_write_lane0_o,
  output logic [P-1:0]                 debug_acc_qsign_write_lane1_o,
  output logic                         debug_layer_close_valid_o,
  output logic [5:0]                   debug_layer_close_layer_id_o,
  output logic [P*6-1:0]               debug_layer_close_m1_o,
  output logic [P*6-1:0]               debug_layer_close_m2_o,
  output logic [P*5-1:0]               debug_layer_close_imin_o,
  output logic [P-1:0]                 debug_layer_close_aggregate_sign_o,
  output logic                         debug_q_write_accept_o,
  output logic                         debug_advance_accept_o,
  output logic                         debug_acc_old_resp_valid_o,
  output logic                         debug_acc_old_generation_valid_o,
  output logic                         debug_rec_new_resp_valid_o,
  output logic                         debug_rec_new_state_closed_o,
  output logic [P*6-1:0]               debug_rec_new_m1_o,
  output logic [P*6-1:0]               debug_rec_new_m2_o,
  output logic [P*5-1:0]               debug_rec_new_imin_o,
  output logic [P-1:0]                 debug_rec_new_aggregate_sign_o,
  output logic [P*8-1:0]               debug_q_read_resp_lane0_o,
  output logic [P*8-1:0]               debug_q_read_resp_lane1_o,
  output logic [5:0]                   debug_q_read_resp_layer_id_o,
  output logic [3:0]                   debug_q_read_resp_qslot_o,
  output logic [5:0]                   debug_q_live_count_o
);
  import nr_ldpc_pkg::*;

  localparam int SHIFT_W = $clog2(P+1);

  logic old_state_req_valid;
  logic [1:0] old_state_req_lane_mask;
  logic [5:0] old_state_req_layer_id;
  logic [4:0] old_state_req_edge0_id;
  logic [4:0] old_state_req_edge1_id;
  logic [3:0] old_state_req_iteration_epoch;

  logic old_state_resp_valid;
  logic old_generation_valid;
  logic [P*W_M-1:0] old_m1;
  logic [P*W_M-1:0] old_m2;
  logic [P*5-1:0] old_imin;
  logic [P-1:0] old_aggregate_sign;
  logic [P-1:0] old_qsign0;
  logic [P-1:0] old_qsign1;
  logic [5:0] old_resp_layer_id;
  logic [3:0] old_resp_epoch;
  logic old_resp_metadata_error;

  logic q_write_valid;
  logic q_write_accept;
  logic [0:0] q_write_qbuf;
  logic [3:0] q_write_qslot;
  logic [1:0] q_write_lane_mask;
  logic [P*W_Q-1:0] q_write_lane0;
  logic [P*W_Q-1:0] q_write_lane1;
  logic [5:0] q_write_layer_id;
  logic [3:0] q_write_iteration_epoch;

  logic [1:0] qsign_write_valid;
  logic [1:0] accepted_qsign_write_valid;
  logic [4:0] qsign_write_edge0_id;
  logic [4:0] qsign_write_edge1_id;
  logic [P-1:0] qsign_write_lane0;
  logic [P-1:0] qsign_write_lane1;
  logic [5:0] qsign_write_layer_id;
  logic qsign_write_target_generation;
  logic [3:0] qsign_write_iteration_epoch;

  logic layer_close_valid;
  logic accepted_layer_close_valid;
  logic [5:0] layer_close_layer_id;
  logic layer_close_target_generation;
  logic [3:0] layer_close_iteration_epoch;
  logic [P*W_M-1:0] layer_close_m1;
  logic [P*W_M-1:0] layer_close_m2;
  logic [P*5-1:0] layer_close_imin;
  logic [P-1:0] layer_close_aggregate_sign;

  logic rec_q_req_valid;
  logic [0:0] rec_q_req_qbuf;
  logic [3:0] rec_q_req_qslot;
  logic [1:0] rec_q_req_lane_mask;
  logic [5:0] rec_q_req_layer_id;
  logic [3:0] rec_q_req_iteration_epoch;

  logic q_read_resp_valid;
  logic [0:0] q_read_resp_qbuf;
  logic [3:0] q_read_resp_qslot;
  logic [1:0] q_read_resp_lane_mask;
  logic [5:0] q_read_resp_layer_id;
  logic [3:0] q_read_resp_iteration_epoch;
  logic [P*W_Q-1:0] q_read_resp_lane0;
  logic [P*W_Q-1:0] q_read_resp_lane1;

  logic rec_r0_valid_q;
  logic [1:0] rec_r0_lane_mask_q;
  logic [4:0] rec_r0_edge0_id_q;
  logic [4:0] rec_r0_edge1_id_q;
  logic rec_r0_generation_q;
  logic [3:0] rec_r0_epoch_q;

  logic rec_new_resp_valid;
  logic rec_new_state_valid;
  logic rec_new_state_closed;
  logic [5:0] rec_new_state_layer_id;
  logic rec_new_state_generation;
  logic [3:0] rec_new_state_epoch;
  logic [P*W_M-1:0] rec_new_m1;
  logic [P*W_M-1:0] rec_new_m2;
  logic [P*5-1:0] rec_new_imin;
  logic [P-1:0] rec_new_aggregate_sign;
  logic [P-1:0] rec_new_qsign0;
  logic [P-1:0] rec_new_qsign1;

  logic old_req_pending_q;
  logic [5:0] old_req_layer_q;
  logic [3:0] old_req_epoch_q;
  logic [3:0] old_state_lookup_epoch;
  logic old_alignment_error_w;
  logic [5:0] q_live_count;
  logic [2:0] acc_inflight_q;
  logic [2:0] rec_inflight_q;
  logic acc_issue_accept_w;
  logic rec_issue_accept_w;
  logic unsafe_advance_w;
  logic advance_accept_w;

  assign acc_issue_accept_w = acc_issue_valid_i && acc_issue_ready_o;
  assign rec_issue_accept_w = rec_issue_valid_i && rec_issue_ready_o;
  assign unsafe_advance_w = advance_iteration_i
      && ((q_live_count != 6'd0)
          || (|acc_inflight_q)
          || (|rec_inflight_q)
          || acc_issue_accept_w
          || rec_issue_accept_w
          || q_write_valid
          || rec_q_req_valid
          || q_read_resp_valid);
  assign advance_accept_w = advance_iteration_i && !unsafe_advance_w;
  assign accepted_qsign_write_valid = qsign_write_valid & {2{q_write_accept}};
  assign accepted_layer_close_valid = layer_close_valid && q_write_accept;
  assign old_state_lookup_epoch = (old_state_req_iteration_epoch == 4'd0)
      ? 4'd0
      : (old_state_req_iteration_epoch - 4'd1);

  nr_ldpc_acc_pipeline #(
    .P(P)
  ) u_acc_pipeline (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .issue_valid_i(acc_issue_valid_i),
    .issue_ready_o(acc_issue_ready_o),
    .issue_lane_mask_i(acc_issue_lane_mask_i),
    .issue_layer_id_i(acc_issue_layer_id_i),
    .issue_layer_position_i(acc_issue_layer_position_i),
    .issue_layer_degree_i(acc_issue_layer_degree_i),
    .issue_start_layer_i(acc_issue_start_layer_i),
    .issue_edge0_id_i(acc_issue_edge0_id_i),
    .issue_edge1_id_i(acc_issue_edge1_id_i),
    .issue_qbuf_i(acc_issue_qbuf_i),
    .issue_qslot_i(acc_issue_qslot_i),
    .issue_target_generation_i(current_new_generation_o),
    .issue_iteration_epoch_i(acc_issue_iteration_epoch_i),
    .issue_app0_canonical_i(acc_issue_app0_canonical_i),
    .issue_app1_canonical_i(acc_issue_app1_canonical_i),
    .issue_source0_valid_i(acc_issue_source0_valid_i),
    .issue_source1_valid_i(acc_issue_source1_valid_i),
    .issue_shift0_i(acc_issue_shift0_i),
    .issue_shift1_i(acc_issue_shift1_i),
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
    .layer_close_m1_offset_o(layer_close_m1),
    .layer_close_m2_offset_o(layer_close_m2),
    .layer_close_imin_o(layer_close_imin),
    .layer_close_aggregate_sign_o(layer_close_aggregate_sign),
    .error_valid_o(acc_error_valid_o)
  );

  nr_ldpc_q_scratch #(
    .P(P)
  ) u_q_scratch (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_block_i(start_block_i),
    .advance_iteration_i(advance_iteration_i),
    .write_valid_i(q_write_valid),
    .write_qbuf_i(q_write_qbuf),
    .write_qslot_i(q_write_qslot),
    .write_lane_mask_i(q_write_lane_mask),
    .write_lane0_i(q_write_lane0),
    .write_lane1_i(q_write_lane1),
    .write_layer_id_i(q_write_layer_id),
    .write_iteration_epoch_i(q_write_iteration_epoch),
    .read_req_valid_i(rec_q_req_valid),
    .read_req_qbuf_i(rec_q_req_qbuf),
    .read_req_qslot_i(rec_q_req_qslot),
    .read_req_lane_mask_i(rec_q_req_lane_mask),
    .read_req_layer_id_i(rec_q_req_layer_id),
    .read_req_iteration_epoch_i(rec_q_req_iteration_epoch),
    .read_resp_valid_o(q_read_resp_valid),
    .read_resp_qbuf_o(q_read_resp_qbuf),
    .read_resp_qslot_o(q_read_resp_qslot),
    .read_resp_lane_mask_o(q_read_resp_lane_mask),
    .read_resp_layer_id_o(q_read_resp_layer_id),
    .read_resp_iteration_epoch_o(q_read_resp_iteration_epoch),
    .read_resp_lane0_o(q_read_resp_lane0),
    .read_resp_lane1_o(q_read_resp_lane1),
    .write_accept_o(q_write_accept),
    .error_valid_o(q_scratch_error_valid_o),
    .error_code_o(q_scratch_error_code_o),
    .live_count_o(q_live_count)
  );

  nr_ldpc_check_state_store #(
    .P(P)
  ) u_check_state_store (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_block_i(start_block_i),
    .advance_iteration_i(advance_accept_w),
    .old_generation_o(current_old_generation_o),
    .new_generation_o(current_new_generation_o),
    .acc_old_req_valid_i(old_state_req_valid),
    .acc_old_req_lane_mask_i(old_state_req_lane_mask),
    .acc_old_req_layer_id_i(old_state_req_layer_id),
    .acc_old_req_edge0_id_i(old_state_req_edge0_id),
    .acc_old_req_edge1_id_i(old_state_req_edge1_id),
    .acc_old_req_iteration_epoch_i(old_state_lookup_epoch),
    .acc_old_resp_valid_o(old_state_resp_valid),
    .acc_old_generation_valid_o(old_generation_valid),
    .acc_old_m1_o(old_m1),
    .acc_old_m2_o(old_m2),
    .acc_old_imin_o(old_imin),
    .acc_old_aggregate_sign_o(old_aggregate_sign),
    .acc_old_qsign0_o(old_qsign0),
    .acc_old_qsign1_o(old_qsign1),
    .acc_old_resp_layer_id_o(old_resp_layer_id),
    .acc_old_resp_iteration_epoch_o(old_resp_epoch),
    .acc_old_resp_metadata_error_o(old_resp_metadata_error),
    .qsign_write_valid_i(accepted_qsign_write_valid),
    .qsign_write_edge0_id_i(qsign_write_edge0_id),
    .qsign_write_edge1_id_i(qsign_write_edge1_id),
    .qsign_write_lane0_i(qsign_write_lane0),
    .qsign_write_lane1_i(qsign_write_lane1),
    .qsign_write_layer_id_i(qsign_write_layer_id),
    .qsign_write_target_generation_i(qsign_write_target_generation),
    .qsign_write_iteration_epoch_i(qsign_write_iteration_epoch),
    .layer_close_valid_i(accepted_layer_close_valid),
    .layer_close_layer_id_i(layer_close_layer_id),
    .layer_close_target_generation_i(layer_close_target_generation),
    .layer_close_iteration_epoch_i(layer_close_iteration_epoch),
    .layer_close_m1_i(layer_close_m1),
    .layer_close_m2_i(layer_close_m2),
    .layer_close_imin_i(layer_close_imin),
    .layer_close_aggregate_sign_i(layer_close_aggregate_sign),
    .rec_new_req_valid_i(rec_q_req_valid),
    .rec_new_req_lane_mask_i(rec_r0_lane_mask_q),
    .rec_new_req_layer_id_i(rec_q_req_layer_id),
    .rec_new_req_edge0_id_i(rec_r0_edge0_id_q),
    .rec_new_req_edge1_id_i(rec_r0_edge1_id_q),
    .rec_new_req_generation_i(rec_r0_generation_q),
    .rec_new_req_iteration_epoch_i(rec_r0_epoch_q),
    .rec_new_resp_valid_o(rec_new_resp_valid),
    .rec_new_state_valid_o(rec_new_state_valid),
    .rec_new_state_closed_o(rec_new_state_closed),
    .rec_new_state_layer_id_o(rec_new_state_layer_id),
    .rec_new_state_generation_o(rec_new_state_generation),
    .rec_new_state_iteration_epoch_o(rec_new_state_epoch),
    .rec_new_m1_o(rec_new_m1),
    .rec_new_m2_o(rec_new_m2),
    .rec_new_imin_o(rec_new_imin),
    .rec_new_aggregate_sign_o(rec_new_aggregate_sign),
    .rec_new_qsign0_o(rec_new_qsign0),
    .rec_new_qsign1_o(rec_new_qsign1),
    .error_valid_o(check_state_error_valid_o),
    .error_code_o(check_state_error_code_o)
  );

  nr_ldpc_rec_pipeline #(
    .P(P)
  ) u_rec_pipeline (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .issue_valid_i(rec_issue_valid_i),
    .issue_ready_o(rec_issue_ready_o),
    .issue_lane_mask_i(rec_issue_lane_mask_i),
    .issue_layer_id_i(rec_issue_layer_id_i),
    .issue_edge0_id_i(rec_issue_edge0_id_i),
    .issue_edge1_id_i(rec_issue_edge1_id_i),
    .issue_qbuf_i(rec_issue_qbuf_i),
    .issue_qslot_i(rec_issue_qslot_i),
    .issue_target_generation_i(current_new_generation_o),
    .issue_iteration_epoch_i(rec_issue_iteration_epoch_i),
    .issue_shift0_i(rec_issue_shift0_i),
    .issue_shift1_i(rec_issue_shift1_i),
    .issue_base_column0_i(rec_issue_base_column0_i),
    .issue_base_column1_i(rec_issue_base_column1_i),
    .issue_aux0_i(rec_issue_aux0_i),
    .issue_aux1_i(rec_issue_aux1_i),
    .issue_final_touch0_i(rec_issue_final_touch0_i),
    .issue_final_touch1_i(rec_issue_final_touch1_i),
    .new_state_resp_valid_i(rec_new_resp_valid),
    .new_state_valid_i(rec_new_state_valid),
    .new_state_closed_i(rec_new_state_closed),
    .new_state_layer_id_i(rec_new_state_layer_id),
    .new_state_generation_i(rec_new_state_generation),
    .new_state_iteration_epoch_i(rec_new_state_epoch),
    .new_m1_i(rec_new_m1),
    .new_m2_i(rec_new_m2),
    .new_imin_i(rec_new_imin),
    .new_aggregate_sign_i(rec_new_aggregate_sign),
    .new_qsign0_i(rec_new_qsign0),
    .new_qsign1_i(rec_new_qsign1),
    .q_req_valid_o(rec_q_req_valid),
    .q_req_qbuf_o(rec_q_req_qbuf),
    .q_req_qslot_o(rec_q_req_qslot),
    .q_req_lane_mask_o(rec_q_req_lane_mask),
    .q_req_layer_id_o(rec_q_req_layer_id),
    .q_req_iteration_epoch_o(rec_q_req_iteration_epoch),
    .q_resp_valid_i(q_read_resp_valid),
    .q_resp_qbuf_i(q_read_resp_qbuf),
    .q_resp_qslot_i(q_read_resp_qslot),
    .q_resp_lane_mask_i(q_read_resp_lane_mask),
    .q_resp_layer_id_i(q_read_resp_layer_id),
    .q_resp_iteration_epoch_i(q_read_resp_iteration_epoch),
    .q_resp_lane0_i(q_read_resp_lane0),
    .q_resp_lane1_i(q_read_resp_lane1),
    .app_write_valid_o(rec_app_write_valid_o),
    .app_write_lane0_o(rec_app_write_lane0_o),
    .app_write_lane1_o(rec_app_write_lane1_o),
    .app_write_base_column0_o(rec_app_write_base_column0_o),
    .app_write_base_column1_o(rec_app_write_base_column1_o),
    .app_write_lane_mask_o(rec_app_write_lane_mask_o),
    .app_write_layer_id_o(rec_app_write_layer_id_o),
    .app_write_edge0_id_o(rec_app_write_edge0_id_o),
    .app_write_edge1_id_o(rec_app_write_edge1_id_o),
    .app_write_iteration_epoch_o(rec_app_write_iteration_epoch_o),
    .app_write_qbuf_o(rec_app_write_qbuf_o),
    .app_write_qslot_o(rec_app_write_qslot_o),
    .app_write_aux0_o(rec_app_write_aux0_o),
    .app_write_aux1_o(rec_app_write_aux1_o),
    .app_write_final_touch0_o(rec_app_write_final_touch0_o),
    .app_write_final_touch1_o(rec_app_write_final_touch1_o),
    .forward_candidate_valid_o(rec_forward_candidate_valid_o),
    .forward_candidate_lane0_o(rec_forward_candidate_lane0_o),
    .forward_candidate_lane1_o(rec_forward_candidate_lane1_o),
    .forward_candidate_base_column0_o(rec_forward_candidate_base_column0_o),
    .forward_candidate_base_column1_o(rec_forward_candidate_base_column1_o),
    .forward_candidate_iteration_epoch_o(rec_forward_candidate_iteration_epoch_o),
    .forward_candidate_aux0_o(rec_forward_candidate_aux0_o),
    .forward_candidate_aux1_o(rec_forward_candidate_aux1_o),
    .forward_valid_o(rec_forward_valid_o),
    .forward_slot0_o(rec_forward_slot0_o),
    .forward_slot1_o(rec_forward_slot1_o),
    .forward_base_column0_o(rec_forward_base_column0_o),
    .forward_base_column1_o(rec_forward_base_column1_o),
    .forward_iteration_epoch_o(rec_forward_iteration_epoch_o),
    .forward_app0_o(rec_forward_app0_o),
    .forward_app1_o(rec_forward_app1_o),
    .final_touch_valid_o(rec_final_touch_valid_o),
    .final_touch_base_column0_o(rec_final_touch_base_column0_o),
    .final_touch_base_column1_o(rec_final_touch_base_column1_o),
    .final_touch_layer_id_o(rec_final_touch_layer_id_o),
    .final_touch_edge0_id_o(rec_final_touch_edge0_id_o),
    .final_touch_edge1_id_o(rec_final_touch_edge1_id_o),
    .final_touch_iteration_epoch_o(rec_final_touch_iteration_epoch_o),
    .final_touch_app0_o(rec_final_touch_app0_o),
    .final_touch_app1_o(rec_final_touch_app1_o),
    .final_touch_hard0_o(rec_final_touch_hard0_o),
    .final_touch_hard1_o(rec_final_touch_hard1_o),
    .error_valid_o(rec_error_valid_o)
  );

  always_ff @(posedge clk_i) begin
    if (rst_i || start_block_i) begin
      rec_r0_valid_q <= 1'b0;
      old_req_pending_q <= 1'b0;
      old_state_alignment_error_o <= 1'b0;
      acc_inflight_q <= 3'b000;
      rec_inflight_q <= 3'b000;
    end else begin
      acc_inflight_q <= {acc_inflight_q[1:0], acc_issue_accept_w};
      rec_inflight_q <= {rec_inflight_q[1:0], rec_issue_accept_w};
      rec_r0_valid_q <= rec_issue_valid_i && rec_issue_ready_o;
      rec_r0_lane_mask_q <= rec_issue_lane_mask_i;
      rec_r0_edge0_id_q <= rec_issue_edge0_id_i;
      rec_r0_edge1_id_q <= rec_issue_edge1_id_i;
      rec_r0_generation_q <= current_new_generation_o;
      rec_r0_epoch_q <= rec_issue_iteration_epoch_i;

      old_req_pending_q <= old_state_req_valid;
      old_req_layer_q <= old_state_req_layer_id;
      old_req_epoch_q <= old_state_lookup_epoch;
      old_state_alignment_error_o <= old_alignment_error_w;
    end
  end

  assign old_alignment_error_w = old_req_pending_q
      && (!old_state_resp_valid
          || (old_resp_layer_id != old_req_layer_q)
          || (old_resp_epoch != old_req_epoch_q)
          || old_resp_metadata_error);

  assign storage_error_valid_o = q_scratch_error_valid_o
      || check_state_error_valid_o
      || old_state_alignment_error_o
      || unsafe_advance_error_o;
  assign unsafe_advance_error_o = unsafe_advance_w;

  assign debug_acc_q_write_valid_o = q_write_valid;
  assign debug_acc_q_write_qbuf_o = q_write_qbuf;
  assign debug_acc_q_write_qslot_o = q_write_qslot;
  assign debug_acc_q_write_lane_mask_o = q_write_lane_mask;
  assign debug_acc_q_write_lane0_o = q_write_lane0;
  assign debug_acc_q_write_lane1_o = q_write_lane1;
  assign debug_acc_q_write_layer_id_o = q_write_layer_id;
  assign debug_acc_q_write_iteration_epoch_o = q_write_iteration_epoch;
  assign debug_acc_qsign_write_valid_o = accepted_qsign_write_valid;
  assign debug_acc_qsign_write_edge0_id_o = qsign_write_edge0_id;
  assign debug_acc_qsign_write_edge1_id_o = qsign_write_edge1_id;
  assign debug_acc_qsign_write_lane0_o = qsign_write_lane0;
  assign debug_acc_qsign_write_lane1_o = qsign_write_lane1;
  assign debug_layer_close_valid_o = accepted_layer_close_valid;
  assign debug_layer_close_layer_id_o = layer_close_layer_id;
  assign debug_layer_close_m1_o = layer_close_m1;
  assign debug_layer_close_m2_o = layer_close_m2;
  assign debug_layer_close_imin_o = layer_close_imin;
  assign debug_layer_close_aggregate_sign_o = layer_close_aggregate_sign;
  assign debug_q_write_accept_o = q_write_accept;
  assign debug_advance_accept_o = advance_accept_w;
  assign debug_acc_old_resp_valid_o = old_state_resp_valid;
  assign debug_acc_old_generation_valid_o = old_generation_valid;
  assign debug_rec_new_resp_valid_o = rec_new_resp_valid;
  assign debug_rec_new_state_closed_o = rec_new_state_closed;
  assign debug_rec_new_m1_o = rec_new_m1;
  assign debug_rec_new_m2_o = rec_new_m2;
  assign debug_rec_new_imin_o = rec_new_imin;
  assign debug_rec_new_aggregate_sign_o = rec_new_aggregate_sign;
  assign debug_q_read_resp_lane0_o = q_read_resp_lane0;
  assign debug_q_read_resp_lane1_o = q_read_resp_lane1;
  assign debug_q_read_resp_layer_id_o = q_read_resp_layer_id;
  assign debug_q_read_resp_qslot_o = q_read_resp_qslot;
  assign debug_q_live_count_o = q_live_count;
endmodule

`endif
