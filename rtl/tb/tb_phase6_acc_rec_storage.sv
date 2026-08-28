`timescale 1ns/1ps

module tb_phase6_acc_rec_storage;
  import nr_ldpc_pkg::*;

  localparam int P_VAL = REFERENCE_Z;
  localparam int SHIFT_W = $clog2(P_VAL+1);

  logic clk;
  logic rst;
  logic start_block;
  logic advance_iteration;

  logic acc_issue_valid;
  logic acc_issue_ready;
  logic [1:0] acc_issue_lane_mask;
  logic [5:0] acc_issue_layer_id;
  logic [5:0] acc_issue_layer_position;
  logic [5:0] acc_issue_layer_degree;
  logic acc_issue_start_layer;
  logic [4:0] acc_issue_edge0_id;
  logic [4:0] acc_issue_edge1_id;
  logic [0:0] acc_issue_qbuf;
  logic [3:0] acc_issue_qslot;
  logic [3:0] acc_issue_epoch;
  logic [P_VAL*W_APP-1:0] acc_app0;
  logic [P_VAL*W_APP-1:0] acc_app1;
  logic acc_source0_valid;
  logic acc_source1_valid;
  logic [SHIFT_W-1:0] acc_shift0;
  logic [SHIFT_W-1:0] acc_shift1;

  logic rec_issue_valid;
  logic rec_issue_ready;
  logic [1:0] rec_issue_lane_mask;
  logic [5:0] rec_issue_layer_id;
  logic [4:0] rec_issue_edge0_id;
  logic [4:0] rec_issue_edge1_id;
  logic [0:0] rec_issue_qbuf;
  logic [3:0] rec_issue_qslot;
  logic [3:0] rec_issue_epoch;
  logic [SHIFT_W-1:0] rec_shift0;
  logic [SHIFT_W-1:0] rec_shift1;
  logic [6:0] rec_base_column0;
  logic [6:0] rec_base_column1;
  logic [3:0] rec_aux0;
  logic [3:0] rec_aux1;
  logic rec_final0;
  logic rec_final1;

  logic [1:0] rec_app_write_valid;
  logic [P_VAL*W_APP-1:0] rec_app_write_lane0;
  logic [P_VAL*W_APP-1:0] rec_app_write_lane1;
  logic [6:0] rec_app_write_base_column0;
  logic [6:0] rec_app_write_base_column1;
  logic [1:0] rec_app_write_lane_mask;
  logic [5:0] rec_app_write_layer_id;
  logic [4:0] rec_app_write_edge0_id;
  logic [4:0] rec_app_write_edge1_id;
  logic [3:0] rec_app_write_epoch;
  logic [0:0] rec_app_write_qbuf;
  logic [3:0] rec_app_write_qslot;
  logic [3:0] rec_app_write_aux0;
  logic [3:0] rec_app_write_aux1;
  logic rec_app_write_final0;
  logic rec_app_write_final1;
  logic [1:0] rec_forward_valid;
  logic [2:0] rec_forward_slot0;
  logic [2:0] rec_forward_slot1;
  logic [6:0] rec_forward_base_column0;
  logic [6:0] rec_forward_base_column1;
  logic [3:0] rec_forward_epoch;
  logic [P_VAL*W_APP-1:0] rec_forward_app0;
  logic [P_VAL*W_APP-1:0] rec_forward_app1;
  logic [1:0] rec_final_touch_valid;
  logic [6:0] rec_final_touch_base_column0;
  logic [6:0] rec_final_touch_base_column1;
  logic [5:0] rec_final_touch_layer_id;
  logic [4:0] rec_final_touch_edge0_id;
  logic [4:0] rec_final_touch_edge1_id;
  logic [3:0] rec_final_touch_epoch;
  logic [P_VAL*W_APP-1:0] rec_final_touch_app0;
  logic [P_VAL*W_APP-1:0] rec_final_touch_app1;
  logic [P_VAL-1:0] rec_final_touch_hard0;
  logic [P_VAL-1:0] rec_final_touch_hard1;

  logic acc_error;
  logic rec_error;
  logic q_scratch_error;
  logic [7:0] q_scratch_error_code;
  logic check_state_error;
  logic [7:0] check_state_error_code;
  logic old_state_alignment_error;
  logic unsafe_advance_error;
  logic storage_error;
  logic current_old_generation;
  logic current_new_generation;
  logic debug_acc_q_write_valid;
  logic [0:0] debug_acc_q_write_qbuf;
  logic [3:0] debug_acc_q_write_qslot;
  logic [1:0] debug_acc_q_write_lane_mask;
  logic [P_VAL*W_Q-1:0] debug_acc_q_write_lane0;
  logic [P_VAL*W_Q-1:0] debug_acc_q_write_lane1;
  logic [5:0] debug_acc_q_write_layer_id;
  logic [3:0] debug_acc_q_write_epoch;
  logic [1:0] debug_acc_qsign_write_valid;
  logic [4:0] debug_acc_qsign_write_edge0_id;
  logic [4:0] debug_acc_qsign_write_edge1_id;
  logic [P_VAL-1:0] debug_acc_qsign_write_lane0;
  logic [P_VAL-1:0] debug_acc_qsign_write_lane1;
  logic debug_layer_close_valid;
  logic [5:0] debug_layer_close_layer_id;
  logic [P_VAL*W_M-1:0] debug_layer_close_m1;
  logic [P_VAL*W_M-1:0] debug_layer_close_m2;
  logic [P_VAL*5-1:0] debug_layer_close_imin;
  logic [P_VAL-1:0] debug_layer_close_aggregate_sign;
  logic debug_acc_old_resp_valid;
  logic debug_acc_old_generation_valid;
  logic debug_rec_new_resp_valid;
  logic debug_rec_new_state_closed;
  logic [P_VAL*W_Q-1:0] debug_q_read_lane0;
  logic [P_VAL*W_Q-1:0] debug_q_read_lane1;
  logic [5:0] debug_q_read_layer_id;
  logic [3:0] debug_q_read_qslot;
  logic [5:0] debug_q_live_count;
  logic debug_q_write_accept;
  logic debug_advance_accept;
  logic [P_VAL*W_M-1:0] debug_rec_new_m1;
  logic [P_VAL*W_M-1:0] debug_rec_new_m2;
  logic [P_VAL*5-1:0] debug_rec_new_imin;
  logic [P_VAL-1:0] debug_rec_new_aggregate_sign;

  logic qd_start_block;
  logic qd_advance;
  logic qd_write_valid;
  logic [0:0] qd_write_qbuf;
  logic [3:0] qd_write_qslot;
  logic [1:0] qd_write_mask;
  logic [P_VAL*W_Q-1:0] qd_write_lane0;
  logic [P_VAL*W_Q-1:0] qd_write_lane1;
  logic [5:0] qd_write_layer;
  logic [3:0] qd_write_epoch;
  logic qd_read_valid;
  logic [0:0] qd_read_qbuf;
  logic [3:0] qd_read_qslot;
  logic [1:0] qd_read_mask;
  logic [5:0] qd_read_layer;
  logic [3:0] qd_read_epoch;
  logic qd_resp_valid;
  logic [0:0] qd_resp_qbuf;
  logic [3:0] qd_resp_qslot;
  logic [1:0] qd_resp_mask;
  logic [5:0] qd_resp_layer;
  logic [3:0] qd_resp_epoch;
  logic [P_VAL*W_Q-1:0] qd_resp_lane0;
  logic [P_VAL*W_Q-1:0] qd_resp_lane1;
  logic qd_error;
  logic [7:0] qd_error_code;
  logic [5:0] qd_live_count;
  logic qd_write_accept;

  logic cs_start_block;
  logic cs_advance;
  logic cs_old_gen;
  logic cs_new_gen;
  logic cs_old_req_valid;
  logic [1:0] cs_old_req_mask;
  logic [5:0] cs_old_req_layer;
  logic [4:0] cs_old_req_edge0;
  logic [4:0] cs_old_req_edge1;
  logic [3:0] cs_old_req_epoch;
  logic cs_old_resp_valid;
  logic cs_old_generation_valid;
  logic [P_VAL*W_M-1:0] cs_old_m1;
  logic [P_VAL*W_M-1:0] cs_old_m2;
  logic [P_VAL*5-1:0] cs_old_imin;
  logic [P_VAL-1:0] cs_old_aggregate;
  logic [P_VAL-1:0] cs_old_qsign0;
  logic [P_VAL-1:0] cs_old_qsign1;
  logic [5:0] cs_old_resp_layer;
  logic [3:0] cs_old_resp_epoch;
  logic cs_old_metadata_error;
  logic [1:0] cs_qsign_write_valid;
  logic [4:0] cs_qsign_edge0;
  logic [4:0] cs_qsign_edge1;
  logic [P_VAL-1:0] cs_qsign_lane0;
  logic [P_VAL-1:0] cs_qsign_lane1;
  logic [5:0] cs_qsign_layer;
  logic cs_qsign_generation;
  logic [3:0] cs_qsign_epoch;
  logic cs_close_valid;
  logic [5:0] cs_close_layer;
  logic cs_close_generation;
  logic [3:0] cs_close_epoch;
  logic [P_VAL*W_M-1:0] cs_close_m1;
  logic [P_VAL*W_M-1:0] cs_close_m2;
  logic [P_VAL*5-1:0] cs_close_imin;
  logic [P_VAL-1:0] cs_close_aggregate;
  logic cs_rec_req_valid;
  logic [1:0] cs_rec_req_mask;
  logic [5:0] cs_rec_req_layer;
  logic [4:0] cs_rec_req_edge0;
  logic [4:0] cs_rec_req_edge1;
  logic cs_rec_req_generation;
  logic [3:0] cs_rec_req_epoch;
  logic cs_rec_resp_valid;
  logic cs_rec_state_valid;
  logic cs_rec_state_closed;
  logic [5:0] cs_rec_state_layer;
  logic cs_rec_state_generation;
  logic [3:0] cs_rec_state_epoch;
  logic [P_VAL*W_M-1:0] cs_rec_m1;
  logic [P_VAL*W_M-1:0] cs_rec_m2;
  logic [P_VAL*5-1:0] cs_rec_imin;
  logic [P_VAL-1:0] cs_rec_aggregate;
  logic [P_VAL-1:0] cs_rec_qsign0;
  logic [P_VAL-1:0] cs_rec_qsign1;
  logic cs_error;
  logic [7:0] cs_error_code;

  int errors;
  int directed_cases;
  int acc_issue_count;
  int rec_issue_count;
  int acc_edge_count;
  int rec_edge_count;
  int rec_publication_count;
  int rec_publication_edges;
  int close_count;
  int selected_numeric_checks;
  int distinct_payload_checks;
  int close_boundary_checks;
  int first_rec_app_checked;

  nr_ldpc_acc_rec_datapath #(
    .P(P_VAL)
  ) u_datapath (
    .clk_i(clk),
    .rst_i(rst),
    .start_block_i(start_block),
    .advance_iteration_i(advance_iteration),
    .acc_issue_valid_i(acc_issue_valid),
    .acc_issue_ready_o(acc_issue_ready),
    .acc_issue_lane_mask_i(acc_issue_lane_mask),
    .acc_issue_layer_id_i(acc_issue_layer_id),
    .acc_issue_layer_position_i(acc_issue_layer_position),
    .acc_issue_layer_degree_i(acc_issue_layer_degree),
    .acc_issue_start_layer_i(acc_issue_start_layer),
    .acc_issue_edge0_id_i(acc_issue_edge0_id),
    .acc_issue_edge1_id_i(acc_issue_edge1_id),
    .acc_issue_qbuf_i(acc_issue_qbuf),
    .acc_issue_qslot_i(acc_issue_qslot),
    .acc_issue_iteration_epoch_i(acc_issue_epoch),
    .acc_issue_app0_canonical_i(acc_app0),
    .acc_issue_app1_canonical_i(acc_app1),
    .acc_issue_source0_valid_i(acc_source0_valid),
    .acc_issue_source1_valid_i(acc_source1_valid),
    .acc_issue_shift0_i(acc_shift0),
    .acc_issue_shift1_i(acc_shift1),
    .rec_issue_valid_i(rec_issue_valid),
    .rec_issue_ready_o(rec_issue_ready),
    .rec_issue_lane_mask_i(rec_issue_lane_mask),
    .rec_issue_layer_id_i(rec_issue_layer_id),
    .rec_issue_edge0_id_i(rec_issue_edge0_id),
    .rec_issue_edge1_id_i(rec_issue_edge1_id),
    .rec_issue_qbuf_i(rec_issue_qbuf),
    .rec_issue_qslot_i(rec_issue_qslot),
    .rec_issue_iteration_epoch_i(rec_issue_epoch),
    .rec_issue_shift0_i(rec_shift0),
    .rec_issue_shift1_i(rec_shift1),
    .rec_issue_base_column0_i(rec_base_column0),
    .rec_issue_base_column1_i(rec_base_column1),
    .rec_issue_aux0_i(rec_aux0),
    .rec_issue_aux1_i(rec_aux1),
    .rec_issue_final_touch0_i(rec_final0),
    .rec_issue_final_touch1_i(rec_final1),
    .rec_app_write_valid_o(rec_app_write_valid),
    .rec_app_write_lane0_o(rec_app_write_lane0),
    .rec_app_write_lane1_o(rec_app_write_lane1),
    .rec_app_write_base_column0_o(rec_app_write_base_column0),
    .rec_app_write_base_column1_o(rec_app_write_base_column1),
    .rec_app_write_lane_mask_o(rec_app_write_lane_mask),
    .rec_app_write_layer_id_o(rec_app_write_layer_id),
    .rec_app_write_edge0_id_o(rec_app_write_edge0_id),
    .rec_app_write_edge1_id_o(rec_app_write_edge1_id),
    .rec_app_write_iteration_epoch_o(rec_app_write_epoch),
    .rec_app_write_qbuf_o(rec_app_write_qbuf),
    .rec_app_write_qslot_o(rec_app_write_qslot),
    .rec_app_write_aux0_o(rec_app_write_aux0),
    .rec_app_write_aux1_o(rec_app_write_aux1),
    .rec_app_write_final_touch0_o(rec_app_write_final0),
    .rec_app_write_final_touch1_o(rec_app_write_final1),
    .rec_forward_valid_o(rec_forward_valid),
    .rec_forward_slot0_o(rec_forward_slot0),
    .rec_forward_slot1_o(rec_forward_slot1),
    .rec_forward_base_column0_o(rec_forward_base_column0),
    .rec_forward_base_column1_o(rec_forward_base_column1),
    .rec_forward_iteration_epoch_o(rec_forward_epoch),
    .rec_forward_app0_o(rec_forward_app0),
    .rec_forward_app1_o(rec_forward_app1),
    .rec_final_touch_valid_o(rec_final_touch_valid),
    .rec_final_touch_base_column0_o(rec_final_touch_base_column0),
    .rec_final_touch_base_column1_o(rec_final_touch_base_column1),
    .rec_final_touch_layer_id_o(rec_final_touch_layer_id),
    .rec_final_touch_edge0_id_o(rec_final_touch_edge0_id),
    .rec_final_touch_edge1_id_o(rec_final_touch_edge1_id),
    .rec_final_touch_iteration_epoch_o(rec_final_touch_epoch),
    .rec_final_touch_app0_o(rec_final_touch_app0),
    .rec_final_touch_app1_o(rec_final_touch_app1),
    .rec_final_touch_hard0_o(rec_final_touch_hard0),
    .rec_final_touch_hard1_o(rec_final_touch_hard1),
    .acc_error_valid_o(acc_error),
    .rec_error_valid_o(rec_error),
    .q_scratch_error_valid_o(q_scratch_error),
    .q_scratch_error_code_o(q_scratch_error_code),
    .check_state_error_valid_o(check_state_error),
    .check_state_error_code_o(check_state_error_code),
    .old_state_alignment_error_o(old_state_alignment_error),
    .unsafe_advance_error_o(unsafe_advance_error),
    .storage_error_valid_o(storage_error),
    .current_old_generation_o(current_old_generation),
    .current_new_generation_o(current_new_generation),
    .debug_acc_q_write_valid_o(debug_acc_q_write_valid),
    .debug_acc_q_write_qbuf_o(debug_acc_q_write_qbuf),
    .debug_acc_q_write_qslot_o(debug_acc_q_write_qslot),
    .debug_acc_q_write_lane_mask_o(debug_acc_q_write_lane_mask),
    .debug_acc_q_write_lane0_o(debug_acc_q_write_lane0),
    .debug_acc_q_write_lane1_o(debug_acc_q_write_lane1),
    .debug_acc_q_write_layer_id_o(debug_acc_q_write_layer_id),
    .debug_acc_q_write_iteration_epoch_o(debug_acc_q_write_epoch),
    .debug_acc_qsign_write_valid_o(debug_acc_qsign_write_valid),
    .debug_acc_qsign_write_edge0_id_o(debug_acc_qsign_write_edge0_id),
    .debug_acc_qsign_write_edge1_id_o(debug_acc_qsign_write_edge1_id),
    .debug_acc_qsign_write_lane0_o(debug_acc_qsign_write_lane0),
    .debug_acc_qsign_write_lane1_o(debug_acc_qsign_write_lane1),
    .debug_layer_close_valid_o(debug_layer_close_valid),
    .debug_layer_close_layer_id_o(debug_layer_close_layer_id),
    .debug_layer_close_m1_o(debug_layer_close_m1),
    .debug_layer_close_m2_o(debug_layer_close_m2),
    .debug_layer_close_imin_o(debug_layer_close_imin),
    .debug_layer_close_aggregate_sign_o(debug_layer_close_aggregate_sign),
    .debug_acc_old_resp_valid_o(debug_acc_old_resp_valid),
    .debug_acc_old_generation_valid_o(debug_acc_old_generation_valid),
    .debug_rec_new_resp_valid_o(debug_rec_new_resp_valid),
    .debug_rec_new_state_closed_o(debug_rec_new_state_closed),
    .debug_q_write_accept_o(debug_q_write_accept),
    .debug_advance_accept_o(debug_advance_accept),
    .debug_rec_new_m1_o(debug_rec_new_m1),
    .debug_rec_new_m2_o(debug_rec_new_m2),
    .debug_rec_new_imin_o(debug_rec_new_imin),
    .debug_rec_new_aggregate_sign_o(debug_rec_new_aggregate_sign),
    .debug_q_read_resp_lane0_o(debug_q_read_lane0),
    .debug_q_read_resp_lane1_o(debug_q_read_lane1),
    .debug_q_read_resp_layer_id_o(debug_q_read_layer_id),
    .debug_q_read_resp_qslot_o(debug_q_read_qslot),
    .debug_q_live_count_o(debug_q_live_count)
  );

  nr_ldpc_q_scratch #(
    .P(P_VAL)
  ) u_q_direct (
    .clk_i(clk),
    .rst_i(rst),
    .start_block_i(qd_start_block),
    .advance_iteration_i(qd_advance),
    .write_valid_i(qd_write_valid),
    .write_qbuf_i(qd_write_qbuf),
    .write_qslot_i(qd_write_qslot),
    .write_lane_mask_i(qd_write_mask),
    .write_lane0_i(qd_write_lane0),
    .write_lane1_i(qd_write_lane1),
    .write_layer_id_i(qd_write_layer),
    .write_iteration_epoch_i(qd_write_epoch),
    .read_req_valid_i(qd_read_valid),
    .read_req_qbuf_i(qd_read_qbuf),
    .read_req_qslot_i(qd_read_qslot),
    .read_req_lane_mask_i(qd_read_mask),
    .read_req_layer_id_i(qd_read_layer),
    .read_req_iteration_epoch_i(qd_read_epoch),
    .read_resp_valid_o(qd_resp_valid),
    .read_resp_qbuf_o(qd_resp_qbuf),
    .read_resp_qslot_o(qd_resp_qslot),
    .read_resp_lane_mask_o(qd_resp_mask),
    .read_resp_layer_id_o(qd_resp_layer),
    .read_resp_iteration_epoch_o(qd_resp_epoch),
    .read_resp_lane0_o(qd_resp_lane0),
    .read_resp_lane1_o(qd_resp_lane1),
    .error_valid_o(qd_error),
    .error_code_o(qd_error_code),
    .write_accept_o(qd_write_accept),
    .live_count_o(qd_live_count)
  );

  nr_ldpc_check_state_store #(
    .P(P_VAL)
  ) u_cs_direct (
    .clk_i(clk),
    .rst_i(rst),
    .start_block_i(cs_start_block),
    .advance_iteration_i(cs_advance),
    .old_generation_o(cs_old_gen),
    .new_generation_o(cs_new_gen),
    .acc_old_req_valid_i(cs_old_req_valid),
    .acc_old_req_lane_mask_i(cs_old_req_mask),
    .acc_old_req_layer_id_i(cs_old_req_layer),
    .acc_old_req_edge0_id_i(cs_old_req_edge0),
    .acc_old_req_edge1_id_i(cs_old_req_edge1),
    .acc_old_req_iteration_epoch_i(cs_old_req_epoch),
    .acc_old_resp_valid_o(cs_old_resp_valid),
    .acc_old_generation_valid_o(cs_old_generation_valid),
    .acc_old_m1_o(cs_old_m1),
    .acc_old_m2_o(cs_old_m2),
    .acc_old_imin_o(cs_old_imin),
    .acc_old_aggregate_sign_o(cs_old_aggregate),
    .acc_old_qsign0_o(cs_old_qsign0),
    .acc_old_qsign1_o(cs_old_qsign1),
    .acc_old_resp_layer_id_o(cs_old_resp_layer),
    .acc_old_resp_iteration_epoch_o(cs_old_resp_epoch),
    .acc_old_resp_metadata_error_o(cs_old_metadata_error),
    .qsign_write_valid_i(cs_qsign_write_valid),
    .qsign_write_edge0_id_i(cs_qsign_edge0),
    .qsign_write_edge1_id_i(cs_qsign_edge1),
    .qsign_write_lane0_i(cs_qsign_lane0),
    .qsign_write_lane1_i(cs_qsign_lane1),
    .qsign_write_layer_id_i(cs_qsign_layer),
    .qsign_write_target_generation_i(cs_qsign_generation),
    .qsign_write_iteration_epoch_i(cs_qsign_epoch),
    .layer_close_valid_i(cs_close_valid),
    .layer_close_layer_id_i(cs_close_layer),
    .layer_close_target_generation_i(cs_close_generation),
    .layer_close_iteration_epoch_i(cs_close_epoch),
    .layer_close_m1_i(cs_close_m1),
    .layer_close_m2_i(cs_close_m2),
    .layer_close_imin_i(cs_close_imin),
    .layer_close_aggregate_sign_i(cs_close_aggregate),
    .rec_new_req_valid_i(cs_rec_req_valid),
    .rec_new_req_lane_mask_i(cs_rec_req_mask),
    .rec_new_req_layer_id_i(cs_rec_req_layer),
    .rec_new_req_edge0_id_i(cs_rec_req_edge0),
    .rec_new_req_edge1_id_i(cs_rec_req_edge1),
    .rec_new_req_generation_i(cs_rec_req_generation),
    .rec_new_req_iteration_epoch_i(cs_rec_req_epoch),
    .rec_new_resp_valid_o(cs_rec_resp_valid),
    .rec_new_state_valid_o(cs_rec_state_valid),
    .rec_new_state_closed_o(cs_rec_state_closed),
    .rec_new_state_layer_id_o(cs_rec_state_layer),
    .rec_new_state_generation_o(cs_rec_state_generation),
    .rec_new_state_iteration_epoch_o(cs_rec_state_epoch),
    .rec_new_m1_o(cs_rec_m1),
    .rec_new_m2_o(cs_rec_m2),
    .rec_new_imin_o(cs_rec_imin),
    .rec_new_aggregate_sign_o(cs_rec_aggregate),
    .rec_new_qsign0_o(cs_rec_qsign0),
    .rec_new_qsign1_o(cs_rec_qsign1),
    .error_valid_o(cs_error),
    .error_code_o(cs_error_code)
  );

  function automatic int signed lane_q(input logic [P_VAL*W_Q-1:0] vec, input int lane);
    logic signed [W_Q-1:0] value;
    begin
      value = vec[lane*W_Q +: W_Q];
      lane_q = value;
    end
  endfunction

  function automatic int signed lane_app(input logic [P_VAL*W_APP-1:0] vec, input int lane);
    logic signed [W_APP-1:0] value;
    begin
      value = vec[lane*W_APP +: W_APP];
      lane_app = value;
    end
  endfunction

  function automatic int lane_m(input logic [P_VAL*W_M-1:0] vec, input int lane);
    begin
      lane_m = vec[lane*W_M +: W_M];
    end
  endfunction

  function automatic int lane_imin(input logic [P_VAL*5-1:0] vec, input int lane);
    begin
      lane_imin = vec[lane*5 +: 5];
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

  task automatic tick;
    begin
      #5;
      clk = 1'b1;
      #1;
      clk = 1'b0;
      #4;
    end
  endtask

  task automatic fill_q_vecs(input int lane0_value, input int lane1_value);
    int lane;
    logic signed [W_Q-1:0] v0;
    logic signed [W_Q-1:0] v1;
    begin
      v0 = lane0_value;
      v1 = lane1_value;
      for (lane = 0; lane < P_VAL; lane++) begin
        qd_write_lane0[lane*W_Q +: W_Q] = v0;
        qd_write_lane1[lane*W_Q +: W_Q] = v1;
      end
    end
  endtask

  task automatic fill_app_all(input int value);
    int lane;
    logic signed [W_APP-1:0] packed_value;
    begin
      packed_value = value;
      for (lane = 0; lane < P_VAL; lane++) begin
        acc_app0[lane*W_APP +: W_APP] = packed_value;
        acc_app1[lane*W_APP +: W_APP] = packed_value;
      end
    end
  endtask

  task automatic fill_app_pair(input int lane0_value, input int lane1_value);
    int lane;
    logic signed [W_APP-1:0] packed_lane0;
    logic signed [W_APP-1:0] packed_lane1;
    begin
      packed_lane0 = lane0_value;
      packed_lane1 = lane1_value;
      for (lane = 0; lane < P_VAL; lane++) begin
        acc_app0[lane*W_APP +: W_APP] = packed_lane0;
        acc_app1[lane*W_APP +: W_APP] = packed_lane1;
      end
    end
  endtask

  task automatic fill_cs_close(input int m1, input int m2, input int imin, input int aggregate);
    int lane;
    begin
      for (lane = 0; lane < P_VAL; lane++) begin
        cs_close_m1[lane*W_M +: W_M] = m1[W_M-1:0];
        cs_close_m2[lane*W_M +: W_M] = m2[W_M-1:0];
        cs_close_imin[lane*5 +: 5] = imin[4:0];
        cs_close_aggregate[lane] = aggregate[0];
      end
    end
  endtask

  task automatic reset_all;
    begin
      acc_issue_valid = 1'b0;
      rec_issue_valid = 1'b0;
      start_block = 1'b0;
      advance_iteration = 1'b0;
      qd_start_block = 1'b0;
      qd_advance = 1'b0;
      qd_write_valid = 1'b0;
      qd_read_valid = 1'b0;
      cs_start_block = 1'b0;
      cs_advance = 1'b0;
      cs_old_req_valid = 1'b0;
      cs_qsign_write_valid = 2'b00;
      cs_close_valid = 1'b0;
      cs_rec_req_valid = 1'b0;
      rst = 1'b1;
      tick();
      tick();
      rst = 1'b0;
      start_block = 1'b1;
      qd_start_block = 1'b1;
      cs_start_block = 1'b1;
      tick();
      start_block = 1'b0;
      qd_start_block = 1'b0;
      cs_start_block = 1'b0;
      tick();
    end
  endtask

  task automatic idle_wrapper;
    begin
      acc_issue_valid = 1'b0;
      rec_issue_valid = 1'b0;
    end
  endtask

  task automatic drive_qd_write(
    input int qbuf,
    input int qslot,
    input int layer,
    input int epoch,
    input int mask,
    input int lane0_value,
    input int lane1_value
  );
    begin
      qd_write_valid = 1'b1;
      qd_write_qbuf = qbuf[0];
      qd_write_qslot = qslot[3:0];
      qd_write_layer = layer[5:0];
      qd_write_epoch = epoch[3:0];
      qd_write_mask = mask[1:0];
      fill_q_vecs(lane0_value, lane1_value);
    end
  endtask

  task automatic drive_qd_read(input int qbuf, input int qslot, input int layer, input int epoch, input int mask);
    begin
      qd_read_valid = 1'b1;
      qd_read_qbuf = qbuf[0];
      qd_read_qslot = qslot[3:0];
      qd_read_layer = layer[5:0];
      qd_read_epoch = epoch[3:0];
      qd_read_mask = mask[1:0];
    end
  endtask

  task automatic run_q_scratch_directed;
    begin
      reset_all();
      drive_qd_write(0, 1, 7, 2, 3, 12, -9);
      tick();
      check_bit("q.write.no_error", qd_error, 1'b0);
      qd_write_valid = 1'b0;
      drive_qd_read(0, 1, 7, 2, 3);
      tick();
      qd_read_valid = 1'b0;
      check_bit("q.read.resp", qd_resp_valid, 1'b1);
      check_int("q.read.lane0", lane_q(qd_resp_lane0, 0), 12);
      check_int("q.read.lane1", lane_q(qd_resp_lane1, 0), -9);
      repeat (3) tick();
      check_int("q.release.live_count", qd_live_count, 0);
      directed_cases++;

      reset_all();
      drive_qd_write(0, 2, 8, 3, 1, 4, 0);
      tick();
      drive_qd_write(0, 2, 8, 3, 1, 5, 0);
      tick();
      check_bit("q.overwrite.error", qd_error, 1'b1);
      check_int("q.overwrite.code", qd_error_code, 2);
      directed_cases++;

      reset_all();
      drive_qd_write(0, 10, 8, 3, 1, 4, 0);
      tick();
      check_bit("q.invalid_write.error", qd_error, 1'b1);
      check_int("q.invalid_write.code", qd_error_code, 1);
      check_bit("q.invalid_write.accept", qd_write_accept, 1'b0);
      directed_cases++;

      reset_all();
      drive_qd_write(1, 10, 8, 3, 1, 4, 0);
      tick();
      check_bit("q.invalid_write_qbuf1.error", qd_error, 1'b1);
      check_int("q.invalid_write_qbuf1.code", qd_error_code, 1);
      check_bit("q.invalid_write_qbuf1.accept", qd_write_accept, 1'b0);
      directed_cases++;

      reset_all();
      drive_qd_read(1, 15, 8, 3, 1);
      tick();
      check_bit("q.invalid_read_qbuf1.error", qd_error, 1'b1);
      check_int("q.invalid_read_qbuf1.code", qd_error_code, 3);
      directed_cases++;

      reset_all();
      drive_qd_read(0, 4, 9, 3, 1);
      tick();
      check_bit("q.read_before_valid.error", qd_error, 1'b1);
      check_int("q.read_before_valid.code", qd_error_code, 4);
      directed_cases++;

      reset_all();
      drive_qd_write(0, 5, 10, 4, 1, 7, 0);
      tick();
      qd_write_valid = 1'b0;
      drive_qd_read(0, 5, 11, 4, 1);
      tick();
      check_bit("q.metadata.error", qd_error, 1'b1);
      check_int("q.metadata.code", qd_error_code, 5);
      directed_cases++;

      reset_all();
      drive_qd_write(1, 0, 12, 4, 1, 2, 0);
      tick();
      drive_qd_write(1, 1, 12, 4, 1, 3, 0);
      drive_qd_read(1, 0, 12, 4, 1);
      tick();
      check_bit("q.same_qbuf.no_error", qd_error, 1'b0);
      check_bit("q.same_qbuf.resp", qd_resp_valid, 1'b1);
      check_int("q.same_qbuf.lane0", lane_q(qd_resp_lane0, 0), 2);
      directed_cases++;

      reset_all();
      drive_qd_write(1, 3, 13, 5, 1, 6, 0);
      tick();
      qd_write_valid = 1'b0;
      qd_advance = 1'b1;
      tick();
      check_bit("q.advance_live.error", qd_error, 1'b1);
      check_int("q.advance_live.code", qd_error_code, 6);
      qd_advance = 1'b0;
      directed_cases++;
    end
  endtask

  task automatic clear_cs_inputs;
    begin
      cs_old_req_valid = 1'b0;
      cs_qsign_write_valid = 2'b00;
      cs_close_valid = 1'b0;
      cs_rec_req_valid = 1'b0;
      cs_qsign_lane0 = '0;
      cs_qsign_lane1 = '0;
      cs_close_m1 = '0;
      cs_close_m2 = '0;
      cs_close_imin = '0;
      cs_close_aggregate = '0;
    end
  endtask

  task automatic run_check_state_directed;
    begin
      reset_all();
      clear_cs_inputs();
      cs_old_req_valid = 1'b1;
      cs_old_req_mask = 2'b11;
      cs_old_req_layer = 6'd5;
      cs_old_req_edge0 = 5'd0;
      cs_old_req_edge1 = 5'd1;
      cs_old_req_epoch = 4'd2;
      tick();
      clear_cs_inputs();
      check_bit("cs.invalid_old.resp", cs_old_resp_valid, 1'b1);
      check_bit("cs.invalid_old.generation_valid", cs_old_generation_valid, 1'b0);
      check_int("cs.invalid_old.m1", lane_m(cs_old_m1, 0), 0);
      directed_cases++;

      reset_all();
      clear_cs_inputs();
      cs_qsign_write_valid = 2'b11;
      cs_qsign_edge0 = 5'd0;
      cs_qsign_edge1 = 5'd1;
      cs_qsign_lane0 = '0;
      cs_qsign_lane1 = '1;
      cs_qsign_layer = 6'd5;
      cs_qsign_generation = cs_new_gen;
      cs_qsign_epoch = 4'd2;
      cs_close_valid = 1'b1;
      cs_close_layer = 6'd5;
      cs_close_generation = cs_new_gen;
      cs_close_epoch = 4'd2;
      fill_cs_close(63, 63, 4, 1);
      cs_rec_req_valid = 1'b1;
      cs_rec_req_mask = 2'b11;
      cs_rec_req_layer = 6'd5;
      cs_rec_req_edge0 = 5'd0;
      cs_rec_req_edge1 = 5'd1;
      cs_rec_req_generation = cs_new_gen;
      cs_rec_req_epoch = 4'd2;
      #1;
      check_bit("cs.close_bypass.resp", cs_rec_resp_valid, 1'b1);
      check_bit("cs.close_bypass.closed", cs_rec_state_closed, 1'b1);
      check_int("cs.close_bypass.m1", lane_m(cs_rec_m1, 0), 63);
      check_int("cs.close_bypass.m2", lane_m(cs_rec_m2, 0), 63);
      check_int("cs.close_bypass.imin", lane_imin(cs_rec_imin, 0), 4);
      check_bit("cs.close_bypass.qsign0", cs_rec_qsign0[0], 1'b0);
      check_bit("cs.close_bypass.qsign1", cs_rec_qsign1[0], 1'b1);
      tick();
      clear_cs_inputs();
      directed_cases++;

      cs_advance = 1'b1;
      tick();
      cs_advance = 1'b0;
      cs_old_req_valid = 1'b1;
      cs_old_req_mask = 2'b11;
      cs_old_req_layer = 6'd5;
      cs_old_req_edge0 = 5'd0;
      cs_old_req_edge1 = 5'd1;
      cs_old_req_epoch = 4'd2;
      tick();
      clear_cs_inputs();
      check_bit("cs.advance.old_valid", cs_old_generation_valid, 1'b1);
      check_int("cs.advance.m1", lane_m(cs_old_m1, 0), 63);
      check_int("cs.advance.imin", lane_imin(cs_old_imin, 0), 4);
      check_bit("cs.advance.qsign1", cs_old_qsign1[0], 1'b1);
      directed_cases++;

      cs_old_req_valid = 1'b1;
      cs_old_req_mask = 2'b01;
      cs_old_req_layer = 6'd5;
      cs_old_req_edge0 = 5'd0;
      cs_old_req_edge1 = 5'd1;
      cs_old_req_epoch = 4'd3;
      tick();
      clear_cs_inputs();
      check_bit("cs.epoch_mismatch.metadata", cs_old_metadata_error, 1'b1);
      check_bit("cs.epoch_mismatch.valid", cs_old_generation_valid, 1'b0);
      directed_cases++;

      reset_all();
      clear_cs_inputs();
      cs_rec_req_valid = 1'b1;
      cs_rec_req_mask = 2'b01;
      cs_rec_req_layer = 6'd6;
      cs_rec_req_edge0 = 5'd0;
      cs_rec_req_edge1 = 5'd0;
      cs_rec_req_generation = cs_new_gen;
      cs_rec_req_epoch = 4'd1;
      #1;
      check_bit("cs.rec_before_close.resp", cs_rec_resp_valid, 1'b0);
      tick();
      check_bit("cs.rec_before_close.error", cs_error, 1'b1);
      clear_cs_inputs();
      directed_cases++;
    end
  endtask

  task automatic drive_acc_issue(
    input int lane_mask,
    input int layer_id,
    input int layer_position,
    input int layer_degree,
    input int start_layer_i,
    input int edge0,
    input int edge1,
    input int qbuf,
    input int qslot,
    input int epoch,
    input int shift0,
    input int shift1
  );
    begin
      acc_issue_valid = 1'b1;
      acc_issue_lane_mask = lane_mask[1:0];
      acc_issue_layer_id = layer_id[5:0];
      acc_issue_layer_position = layer_position[5:0];
      acc_issue_layer_degree = layer_degree[5:0];
      acc_issue_start_layer = start_layer_i[0];
      acc_issue_edge0_id = edge0[4:0];
      acc_issue_edge1_id = edge1[4:0];
      acc_issue_qbuf = qbuf[0];
      acc_issue_qslot = qslot[3:0];
      acc_issue_epoch = epoch[3:0];
      acc_shift0 = shift0[SHIFT_W-1:0];
      acc_shift1 = shift1[SHIFT_W-1:0];
      acc_source0_valid = 1'b1;
      acc_source1_valid = 1'b1;
    end
  endtask

  task automatic drive_rec_issue_simple(
    input int lane_mask,
    input int layer_id,
    input int edge0,
    input int edge1,
    input int qbuf,
    input int qslot,
    input int epoch,
    input int shift0,
    input int shift1,
    input int base0,
    input int base1,
    input int aux0,
    input int aux1,
    input int final0,
    input int final1
  );
    begin
      rec_issue_valid = 1'b1;
      rec_issue_lane_mask = lane_mask[1:0];
      rec_issue_layer_id = layer_id[5:0];
      rec_issue_edge0_id = edge0[4:0];
      rec_issue_edge1_id = edge1[4:0];
      rec_issue_qbuf = qbuf[0];
      rec_issue_qslot = qslot[3:0];
      rec_issue_epoch = epoch[3:0];
      rec_shift0 = shift0[SHIFT_W-1:0];
      rec_shift1 = shift1[SHIFT_W-1:0];
      rec_base_column0 = base0[6:0];
      rec_base_column1 = base1[6:0];
      rec_aux0 = aux0[3:0];
      rec_aux1 = aux1[3:0];
      rec_final0 = final0[0];
      rec_final1 = final1[0];
    end
  endtask

  task automatic run_integrated_atomic_q_reject;
    begin
      reset_all();
      idle_wrapper();
      fill_app_all(11);
      drive_acc_issue(2'b11, 14, 0, 2, 1, 0, 1, 0, 10, 6, 0, 0);
      tick();
      idle_wrapper();
      tick();
      tick();
      tick();
      check_bit("atomic_reject.q_write_visible", debug_acc_q_write_valid, 1'b1);
      check_bit("atomic_reject.q_accept", debug_q_write_accept, 1'b0);
      check_int("atomic_reject.qsign_suppressed", debug_acc_qsign_write_valid, 0);
      check_bit("atomic_reject.close_suppressed", debug_layer_close_valid, 1'b0);
      tick();
      check_bit("atomic_reject.q_error", q_scratch_error, 1'b1);
      check_int("atomic_reject.q_error_code", q_scratch_error_code, 1);

      drive_rec_issue_simple(2'b11, 14, 0, 1, 0, 0, 6, 0, 0, 0, 1, 0, 0, 0, 0);
      tick();
      idle_wrapper();
      check_bit("atomic_reject.rec_state_not_closed", debug_rec_new_resp_valid, 1'b0);
      tick();
      check_bit("atomic_reject.storage_error", storage_error, 1'b1);
      check_bit("atomic_reject.rec_app_suppressed", |rec_app_write_valid, 1'b0);
      check_bit("atomic_reject.forward_suppressed", |rec_forward_valid, 1'b0);
      check_bit("atomic_reject.final_touch_suppressed", |rec_final_touch_valid, 1'b0);
      directed_cases++;
    end
  endtask

  task automatic run_integrated_advance_atomic;
    logic old_before;
    logic new_before;
    begin
      reset_all();
      idle_wrapper();
      old_before = current_old_generation;
      new_before = current_new_generation;
      fill_app_all(6);
      drive_acc_issue(2'b11, 15, 0, 2, 1, 0, 1, 0, 0, 6, 0, 0);
      tick();
      idle_wrapper();
      tick();
      tick();
      tick();
      check_bit("advance_live.q_accept", debug_q_write_accept, 1'b1);
      check_int("advance_live.q_count", debug_q_live_count, 0);
      tick();
      check_int("advance_live.q_count_after_commit", debug_q_live_count, 1);
      advance_iteration = 1'b1;
      #1;
      check_bit("advance_live.unsafe", unsafe_advance_error, 1'b1);
      check_bit("advance_live.accept", debug_advance_accept, 1'b0);
      tick();
      check_bit("advance_live.old_generation", current_old_generation, old_before);
      check_bit("advance_live.new_generation", current_new_generation, new_before);
      advance_iteration = 1'b0;
      idle_wrapper();
      directed_cases++;

      reset_all();
      idle_wrapper();
      old_before = current_old_generation;
      new_before = current_new_generation;
      fill_app_all(7);
      drive_acc_issue(2'b11, 16, 0, 2, 1, 0, 1, 0, 0, 6, 0, 0);
      tick();
      idle_wrapper();
      advance_iteration = 1'b1;
      #1;
      check_bit("advance_inflight.unsafe", unsafe_advance_error, 1'b1);
      check_bit("advance_inflight.accept", debug_advance_accept, 1'b0);
      tick();
      check_bit("advance_inflight.old_generation", current_old_generation, old_before);
      check_bit("advance_inflight.new_generation", current_new_generation, new_before);
      advance_iteration = 1'b0;
      idle_wrapper();
      directed_cases++;

      reset_all();
      idle_wrapper();
      old_before = current_old_generation;
      new_before = current_new_generation;
      advance_iteration = 1'b1;
      #1;
      check_bit("advance_safe.accept", debug_advance_accept, 1'b1);
      check_bit("advance_safe.unsafe", unsafe_advance_error, 1'b0);
      tick();
      check_bit("advance_safe.old_generation", current_old_generation, new_before);
      check_bit("advance_safe.new_generation", current_new_generation, old_before);
      advance_iteration = 1'b0;
      idle_wrapper();
      directed_cases++;
    end
  endtask

  task automatic run_distinct_payload_integration;
    begin
      reset_all();
      idle_wrapper();
      distinct_payload_checks = 0;

      fill_app_pair(10, -20);
      drive_acc_issue(2'b11, 18, 0, 4, 1, 0, 1, 0, 0, 6, 0, 0);
      tick();

      fill_app_pair(30, 40);
      drive_acc_issue(2'b11, 18, 0, 4, 0, 2, 3, 0, 1, 6, 0, 0);
      tick();

      idle_wrapper();
      tick();

      tick();
      check_bit("distinct.pair0.q_write", debug_acc_q_write_valid, 1'b1);
      check_bit("distinct.pair0.accept", debug_q_write_accept, 1'b1);
      check_int("distinct.pair0.qslot", debug_acc_q_write_qslot, 0);
      check_int("distinct.pair0.q0", lane_q(debug_acc_q_write_lane0, 0), 10);
      check_int("distinct.pair0.q1", lane_q(debug_acc_q_write_lane1, 0), -20);
      check_int("distinct.pair0.qsign_valid", debug_acc_qsign_write_valid, 3);
      check_int("distinct.pair0.edge0", debug_acc_qsign_write_edge0_id, 0);
      check_int("distinct.pair0.edge1", debug_acc_qsign_write_edge1_id, 1);
      check_bit("distinct.pair0.sign0", debug_acc_qsign_write_lane0[0], 1'b0);
      check_bit("distinct.pair0.sign1", debug_acc_qsign_write_lane1[0], 1'b1);
      distinct_payload_checks += 9;

      drive_rec_issue_simple(2'b11, 18, 0, 1, 0, 0, 6, 0, 0, 0, 1, 0, 0, 0, 0);
      tick();
      check_bit("distinct.pair1.q_write", debug_acc_q_write_valid, 1'b1);
      check_bit("distinct.pair1.accept", debug_q_write_accept, 1'b1);
      check_int("distinct.pair1.qslot", debug_acc_q_write_qslot, 1);
      check_int("distinct.pair1.q0", lane_q(debug_acc_q_write_lane0, 0), 30);
      check_int("distinct.pair1.q1", lane_q(debug_acc_q_write_lane1, 0), 40);
      check_int("distinct.pair1.qsign_valid", debug_acc_qsign_write_valid, 3);
      check_int("distinct.pair1.edge0", debug_acc_qsign_write_edge0_id, 2);
      check_int("distinct.pair1.edge1", debug_acc_qsign_write_edge1_id, 3);
      check_bit("distinct.pair1.sign0", debug_acc_qsign_write_lane0[0], 1'b0);
      check_bit("distinct.pair1.sign1", debug_acc_qsign_write_lane1[0], 1'b0);
      check_bit("distinct.close.valid", debug_layer_close_valid, 1'b1);
      check_int("distinct.close.layer", debug_layer_close_layer_id, 18);
      check_int("distinct.close.m1", lane_m(debug_layer_close_m1, 0), 9);
      check_int("distinct.close.m2", lane_m(debug_layer_close_m2, 0), 19);
      check_int("distinct.close.imin", lane_imin(debug_layer_close_imin, 0), 0);
      check_bit("distinct.close.aggregate", debug_layer_close_aggregate_sign[0], 1'b1);
      check_bit("distinct.rec.close_boundary", debug_rec_new_resp_valid, 1'b1);
      check_bit("distinct.rec.close_boundary_closed", debug_rec_new_state_closed, 1'b1);
      check_int("distinct.rec.m1", lane_m(debug_rec_new_m1, 0), 9);
      check_int("distinct.rec.m2", lane_m(debug_rec_new_m2, 0), 19);
      check_int("distinct.rec.imin", lane_imin(debug_rec_new_imin, 0), 0);
      check_bit("distinct.rec.aggregate", debug_rec_new_aggregate_sign[0], 1'b1);
      distinct_payload_checks += 22;

      drive_rec_issue_simple(2'b11, 18, 2, 3, 0, 1, 6, 0, 0, 2, 3, 0, 0, 0, 0);
      tick();
      check_int("distinct.qread0.slot", debug_q_read_qslot, 0);
      check_int("distinct.qread0.q0", lane_q(debug_q_read_lane0, 0), 10);
      check_int("distinct.qread0.q1", lane_q(debug_q_read_lane1, 0), -20);
      distinct_payload_checks += 3;

      idle_wrapper();
      tick();
      check_int("distinct.qread1.slot", debug_q_read_qslot, 1);
      check_int("distinct.qread1.q0", lane_q(debug_q_read_lane0, 0), 30);
      check_int("distinct.qread1.q1", lane_q(debug_q_read_lane1, 0), 40);
      distinct_payload_checks += 3;

      tick();
      check_int("distinct.rec0.app0", lane_app(rec_app_write_lane0, 0), -9);
      check_int("distinct.rec0.app1", lane_app(rec_app_write_lane1, 0), -11);
      check_int("distinct.rec0.edge0", rec_app_write_edge0_id, 0);
      check_int("distinct.rec0.edge1", rec_app_write_edge1_id, 1);
      check_int("distinct.rec0.valid", rec_app_write_valid, 3);
      distinct_payload_checks += 5;

      tick();
      check_int("distinct.rec1.app0", lane_app(rec_app_write_lane0, 0), 21);
      check_int("distinct.rec1.app1", lane_app(rec_app_write_lane1, 0), 31);
      check_int("distinct.rec1.edge0", rec_app_write_edge0_id, 2);
      check_int("distinct.rec1.edge1", rec_app_write_edge1_id, 3);
      check_int("distinct.rec1.valid", rec_app_write_valid, 3);
      check_bit("distinct.no_acc_error", acc_error, 1'b0);
      check_bit("distinct.no_rec_error", rec_error, 1'b0);
      check_bit("distinct.no_storage_error", storage_error, 1'b0);
      distinct_payload_checks += 8;

      directed_cases++;
    end
  endtask

  task automatic drive_acc_trace(input int cycle);
    begin
      acc_issue_valid = 1'b0;
      acc_issue_lane_mask = 2'b00;
      fill_app_all(20);
      case (cycle)
        0:  drive_acc_issue(2'b11, 1, 0, 19, 1, 0, 1, 0, 0, 6, 0, 0);
        1:  drive_acc_issue(2'b11, 3, 1, 19, 1, 14, 15, 1, 0, 6, 0, 0);
        2:  drive_acc_issue(2'b11, 1, 0, 19, 0, 2, 3, 0, 1, 6, 0, 0);
        3:  drive_acc_issue(2'b11, 3, 1, 19, 0, 1, 4, 1, 1, 6, 0, 0);
        4:  drive_acc_issue(2'b11, 1, 0, 19, 0, 4, 5, 0, 2, 6, 0, 0);
        5:  drive_acc_issue(2'b11, 3, 1, 19, 0, 7, 10, 1, 2, 6, 0, 0);
        6:  drive_acc_issue(2'b11, 1, 0, 19, 0, 6, 7, 0, 3, 6, 0, 0);
        7:  drive_acc_issue(2'b11, 1, 0, 19, 0, 8, 9, 0, 4, 6, 0, 0);
        8:  drive_acc_issue(2'b11, 1, 0, 19, 0, 10, 11, 0, 5, 6, 0, 0);
        9:  drive_acc_issue(2'b11, 1, 0, 19, 0, 12, 13, 0, 6, 6, 0, 0);
        10: drive_acc_issue(2'b11, 1, 0, 19, 0, 14, 15, 0, 7, 6, 0, 0);
        11: drive_acc_issue(2'b11, 1, 0, 19, 0, 16, 17, 0, 8, 6, 0, 0);
        12: drive_acc_issue(2'b01, 1, 0, 19, 0, 18, 0, 0, 9, 6, 0, 0);
        13: drive_acc_issue(2'b01, 3, 1, 19, 0, 18, 0, 1, 9, 6, 0, 0);
        18: drive_acc_issue(2'b11, 3, 1, 19, 0, 2, 3, 1, 3, 6, 0, 0);
        19: drive_acc_issue(2'b11, 3, 1, 19, 0, 8, 9, 1, 5, 6, 0, 0);
        21: drive_acc_issue(2'b11, 3, 1, 19, 0, 0, 13, 1, 8, 6, 0, 0);
        22: drive_acc_issue(2'b11, 2, 2, 19, 1, 2, 4, 0, 0, 6, 0, 0);
        23: drive_acc_issue(2'b11, 3, 1, 19, 0, 5, 6, 1, 4, 6, 0, 0);
        24: drive_acc_issue(2'b11, 2, 2, 19, 0, 8, 12, 0, 2, 6, 0, 0);
        25: drive_acc_issue(2'b11, 3, 1, 19, 0, 11, 12, 1, 6, 6, 0, 0);
        26: drive_acc_issue(2'b11, 3, 1, 19, 0, 16, 17, 1, 7, 6, 0, 0);
        27: drive_acc_issue(2'b11, 2, 2, 19, 0, 15, 17, 0, 1, 6, 0, 0);
        34: drive_acc_issue(2'b11, 2, 2, 19, 0, 9, 10, 0, 5, 6, 0, 0);
        35: drive_acc_issue(2'b11, 2, 2, 19, 0, 5, 6, 0, 4, 6, 0, 0);
        36: drive_acc_issue(2'b11, 2, 2, 19, 0, 0, 1, 0, 3, 6, 0, 0);
        37: drive_acc_issue(2'b11, 2, 2, 19, 0, 3, 7, 0, 8, 6, 0, 0);
        38: drive_acc_issue(2'b11, 0, 3, 19, 1, 12, 18, 1, 2, 6, 0, 0);
        39: drive_acc_issue(2'b11, 2, 2, 19, 0, 16, 18, 0, 7, 6, 0, 0);
        40: drive_acc_issue(2'b11, 0, 3, 19, 0, 8, 9, 1, 0, 6, 0, 0);
        41: drive_acc_issue(2'b11, 0, 3, 19, 0, 16, 17, 1, 1, 6, 0, 0);
        42: drive_acc_issue(2'b11, 2, 2, 19, 0, 13, 14, 0, 6, 6, 0, 0);
        43: drive_acc_issue(2'b01, 2, 2, 19, 0, 11, 0, 0, 9, 6, 0, 0);
        44: drive_acc_issue(2'b01, 0, 3, 19, 0, 3, 0, 1, 9, 6, 0, 0);
        51: drive_acc_issue(2'b11, 0, 3, 19, 0, 0, 1, 1, 3, 6, 0, 0);
        52: drive_acc_issue(2'b11, 0, 3, 19, 0, 6, 7, 1, 5, 6, 0, 0);
        53: drive_acc_issue(2'b11, 0, 3, 19, 0, 10, 11, 1, 6, 6, 0, 0);
        54: drive_acc_issue(2'b11, 0, 3, 19, 0, 4, 5, 1, 4, 6, 0, 0);
        55: drive_acc_issue(2'b11, 0, 3, 19, 0, 13, 14, 1, 7, 6, 0, 0);
        56: drive_acc_issue(2'b11, 0, 3, 19, 0, 2, 15, 1, 8, 6, 0, 0);
        default: begin
          acc_issue_valid = 1'b0;
          acc_issue_lane_mask = 2'b00;
        end
      endcase
      if (acc_issue_valid) begin
        acc_issue_count++;
        acc_edge_count += acc_issue_lane_mask[0] + acc_issue_lane_mask[1];
      end
    end
  endtask

  function automatic logic [35:0] rec_trace_word(input int cycle);
    begin
      rec_trace_word = 36'd0;
      case (cycle)
        15: rec_trace_word = 36'h02110c40f;
        16: rec_trace_word = 36'h04342500f;
        17: rec_trace_word = 36'h06563580f;
        18: rec_trace_word = 36'h08700400f;
        19: rec_trace_word = 36'h01221480f;
        20: rec_trace_word = 36'h04331cc0f;
        21: rec_trace_word = 36'h06552d40f;
        22: rec_trace_word = 36'h07873dc0f;
        23: rec_trace_word = 36'h02184600f;
        24: rec_trace_word = 36'h00390240b;
        29: rec_trace_word = 36'h0210bdc1f;
        30: rec_trace_word = 36'h04319021f;
        31: rec_trace_word = 36'h0652a8e1f;
        32: rec_trace_word = 36'h087498a1f;
        33: rec_trace_word = 36'h0218b401f;
        34: rec_trace_word = 36'h03438c41f;
        35: rec_trace_word = 36'h0656b161f;
        36: rec_trace_word = 36'h00798241b;
        37: rec_trace_word = 36'h0215a501f;
        38: rec_trace_word = 36'h0437c601f;
        46: rec_trace_word = 36'h021010417;
        47: rec_trace_word = 36'h043231017;
        48: rec_trace_word = 36'h065304017;
        49: rec_trace_word = 36'h087529217;
        50: rec_trace_word = 36'h201145e17;
        51: rec_trace_word = 36'h202418a17;
        52: rec_trace_word = 36'h130639a17;
        53: rec_trace_word = 36'h20474a017;
        54: rec_trace_word = 36'h30081c617;
        55: rec_trace_word = 36'h100901613;
        59: rec_trace_word = 36'h3000a5007;
        60: rec_trace_word = 36'h3001c6007;
        61: rec_trace_word = 36'h3002c9807;
        62: rec_trace_word = 36'h300384007;
        63: rec_trace_word = 36'h300494807;
        64: rec_trace_word = 36'h30059cc07;
        65: rec_trace_word = 36'h3006ad407;
        66: rec_trace_word = 36'h3007b9a07;
        67: rec_trace_word = 36'h3008bc407;
        68: rec_trace_word = 36'h100980603;
        default: rec_trace_word = 36'd0;
      endcase
    end
  endfunction

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
        rec_issue_valid = 1'b1;
        rec_issue_lane_mask = field_mask(word);
        rec_issue_layer_id = field_layer(word);
        rec_issue_edge0_id = field_edge0(word);
        rec_issue_edge1_id = field_edge1(word);
        rec_issue_qbuf = field_qbuf(word);
        rec_issue_qslot = field_qslot(word);
        rec_issue_epoch = 4'd6;
        rec_shift0 = sh0[SHIFT_W-1:0];
        rec_shift1 = sh1[SHIFT_W-1:0];
        rec_base_column0 = col0[6:0];
        rec_base_column1 = col1[6:0];
        rec_aux0 = field_aux0(word);
        rec_aux1 = field_aux1(word);
        rec_final0 = field_final0(word);
        rec_final1 = field_final1(word);
        rec_issue_count++;
        rec_edge_count += rec_issue_lane_mask[0] + rec_issue_lane_mask[1];
      end else begin
        rec_issue_valid = 1'b0;
        rec_issue_lane_mask = 2'b00;
      end
    end
  endtask

  task automatic run_high_rate_integration;
    int cycle;
    logic [35:0] rec_word;
    begin
      reset_all();
      idle_wrapper();
      acc_issue_count = 0;
      rec_issue_count = 0;
      acc_edge_count = 0;
      rec_edge_count = 0;
      rec_publication_count = 0;
      rec_publication_edges = 0;
      close_count = 0;
      selected_numeric_checks = 0;
      close_boundary_checks = 0;
      first_rec_app_checked = 0;
      for (cycle = 0; cycle <= 74; cycle++) begin
        if (cycle <= 70) begin
          drive_acc_trace(cycle);
          rec_word = rec_trace_word(cycle);
          drive_rec_from_word(rec_word);
        end else begin
          idle_wrapper();
        end
        tick();

        if (acc_error || rec_error || storage_error) begin
          $display("FAIL high_rate unexpected error cycle=%0d acc=%0b rec=%0b storage=%0b qerr=%0d cserr=%0d",
              cycle, acc_error, rec_error, storage_error, q_scratch_error_code, check_state_error_code);
          errors++;
        end

        if (debug_acc_old_resp_valid && !debug_acc_old_generation_valid && (cycle < 15)) begin
          selected_numeric_checks++;
        end

        if (debug_acc_q_write_valid) begin
          check_int("high_rate.q_write.lane0", lane_q(debug_acc_q_write_lane0, 0), 20);
          check_int("high_rate.q_write.lane1", lane_q(debug_acc_q_write_lane1, 0), 20);
          selected_numeric_checks++;
        end

        if (debug_layer_close_valid) begin
          close_count++;
          if (cycle == 15) begin
            check_int("high_rate.close15.layer", debug_layer_close_layer_id, 1);
          end else if (cycle == 29) begin
            check_int("high_rate.close29.layer", debug_layer_close_layer_id, 3);
          end else if (cycle == 46) begin
            check_int("high_rate.close46.layer", debug_layer_close_layer_id, 2);
          end else if (cycle == 59) begin
            check_int("high_rate.close59.layer", debug_layer_close_layer_id, 0);
          end else begin
            $display("FAIL high_rate unexpected close cycle=%0d layer=%0d", cycle, debug_layer_close_layer_id);
            errors++;
          end
          check_int("high_rate.close.m1", lane_m(debug_layer_close_m1, 0), 19);
          check_int("high_rate.close.m2", lane_m(debug_layer_close_m2, 0), 19);
          selected_numeric_checks++;
        end

        if ((cycle == 15) || (cycle == 29) || (cycle == 46) || (cycle == 59)) begin
          check_bit("high_rate.close_to_rec.resp", debug_rec_new_resp_valid, 1'b1);
          check_bit("high_rate.close_to_rec.closed", debug_rec_new_state_closed, 1'b1);
          close_boundary_checks++;
        end

        if (debug_q_read_layer_id == 6'd1 && debug_q_read_qslot == 4'd1) begin
          check_int("high_rate.q_read.lane0", lane_q(debug_q_read_lane0, 0), 20);
          selected_numeric_checks++;
        end

        if (rec_app_write_valid != 2'b00) begin
          rec_publication_count++;
          rec_publication_edges += rec_app_write_valid[0] + rec_app_write_valid[1];
          if (!first_rec_app_checked && (rec_app_write_layer_id == 6'd1)) begin
            check_int("high_rate.rec_app.layer1", lane_app(rec_app_write_lane0, 0), 39);
            first_rec_app_checked = 1;
            selected_numeric_checks++;
          end
        end
      end
      check_int("high_rate.decoder_cycles", 71, 71);
      check_int("high_rate.acc_issue_cycles", acc_issue_count, 40);
      check_int("high_rate.rec_issue_cycles", rec_issue_count, 40);
      check_int("high_rate.acc_edges", acc_edge_count, 76);
      check_int("high_rate.rec_edges", rec_edge_count, 76);
      check_int("high_rate.close_count", close_count, 4);
      check_int("high_rate.rec_publications", rec_publication_count, 40);
      check_int("high_rate.rec_publication_edges", rec_publication_edges, 76);
      check_int("high_rate.close_boundaries", close_boundary_checks, 4);
      if (selected_numeric_checks < 40) begin
        $display("FAIL high_rate too few numerical checks actual=%0d", selected_numeric_checks);
        errors++;
      end
      directed_cases++;
    end
  endtask

  initial begin
    clk = 1'b0;
    rst = 1'b0;
    errors = 0;
    directed_cases = 0;
    distinct_payload_checks = 0;
    if (P != 384 || B != 2 || D_A != 3 || D_R != 3) begin
      $display("FAIL frozen Phase-6 constants");
      errors++;
    end
    reset_all();
    run_q_scratch_directed();
    run_check_state_directed();
    run_integrated_atomic_q_reject();
    run_integrated_advance_atomic();
    run_distinct_payload_integration();
    run_high_rate_integration();
    if (errors == 0) begin
      $display("PASS phase6 acc rec storage");
      $display("directed_cases=%0d selected_numeric_checks=%0d distinct_payload_checks=%0d close_boundary_checks=%0d", directed_cases, selected_numeric_checks, distinct_payload_checks, close_boundary_checks);
      $display("high_rate_acc_issue_cycles=%0d high_rate_rec_issue_cycles=%0d", acc_issue_count, rec_issue_count);
      $display("high_rate_acc_active_edges=%0d high_rate_rec_active_edges=%0d", acc_edge_count, rec_edge_count);
      $display("decoder_cycles=71");
      $finish;
    end
    $display("FAIL phase6 acc rec storage errors=%0d", errors);
    $finish(1);
  end
endmodule
