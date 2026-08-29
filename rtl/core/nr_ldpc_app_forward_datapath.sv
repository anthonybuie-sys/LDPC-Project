`ifndef NR_LDPC_APP_FORWARD_DATAPATH_SV
`define NR_LDPC_APP_FORWARD_DATAPATH_SV

module nr_ldpc_app_forward_datapath #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic                         clk_i,
  input  logic                         rst_i,
  input  logic                         start_block_i,
  input  logic                         advance_iteration_i,

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
  output logic                         phase6_storage_error_valid_o,
  output logic                         app_memory_error_valid_o,
  output logic [7:0]                   app_memory_error_code_o,
  output logic                         forward_error_valid_o,
  output logic [7:0]                   forward_error_code_o,
  output logic                         app_forward_error_valid_o,
  output logic                         storage_error_valid_o,

  output logic                         current_old_generation_o,
  output logic                         current_new_generation_o,

  output logic [1:0]                   debug_acc_source_valid_o,
  output logic [1:0]                   debug_acc_source_forwarded_o,
  output logic [P*8-1:0]               debug_acc_source0_app_o,
  output logic [P*8-1:0]               debug_acc_source1_app_o,
  output logic [2:0]                   debug_app_read_bank0_o,
  output logic [2:0]                   debug_app_read_bank1_o,
  output logic [2:0]                   debug_app_write_bank0_o,
  output logic [2:0]                   debug_app_write_bank1_o,
  output logic                         debug_app_same_bank_collision_o,
  output logic [1:0]                   debug_app_write_accept_o,
  output logic                         debug_app_write_commit_o,
  output logic [1:0]                   debug_forward_alloc_valid_o,
  output logic [1:0]                   debug_forward_alloc_accept_o,
  output logic [1:0]                   debug_forward_read_valid_o,
  output logic [1:0]                   debug_forward_read_accept_o,
  output logic [5:0]                   debug_forward_live_count_o,
  output logic [1:0]                   debug_forward_candidate_valid_o,
  output logic [2:0]                   debug_forward_candidate_slot0_o,
  output logic [2:0]                   debug_forward_candidate_slot1_o,
  output logic [6:0]                   debug_forward_candidate_base_column0_o,
  output logic [6:0]                   debug_forward_candidate_base_column1_o,
  output logic [3:0]                   debug_forward_candidate_iteration_epoch_o,
  output logic [P*8-1:0]               debug_forward_candidate_app0_o,
  output logic [P*8-1:0]               debug_forward_candidate_app1_o,
  output logic [1:0]                   debug_rec_publication_valid_o,

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

  logic acc_lane0_active_w;
  logic acc_lane1_active_w;
  logic acc_aux0_legal_w;
  logic acc_aux1_legal_w;
  logic rec_issue_aux0_legal_w;
  logic rec_issue_aux1_legal_w;
  logic rec_publication_aux0_legal_w;
  logic rec_publication_aux1_legal_w;
  logic forward_candidate_aux0_legal_w;
  logic forward_candidate_aux1_legal_w;
  logic forward_candidate_column0_active_w;
  logic forward_candidate_column1_active_w;
  logic forward_candidate_duplicate_w;
  logic forward_candidate_error_w;
  logic [2:0] forward_candidate_bank0_w;
  logic [2:0] forward_candidate_bank1_w;
  logic r2_same_bank_collision_w;
  logic app_memory_same_bank_collision_w;
  logic app_source_error_w;
  logic rec_reserve_error_w;
  logic rec_commit_error_w;
  logic forward_candidate_commit_w;

  logic [1:0] app_read_valid;
  logic [1:0] app_read_accept;
  logic [P*W_APP-1:0] app_read0;
  logic [P*W_APP-1:0] app_read1;
  logic [1:0] app_write_accept;

  logic [1:0] forward_read_valid;
  logic [1:0] forward_read_accept;
  logic [P*W_APP-1:0] forward_read0;
  logic [P*W_APP-1:0] forward_read1;
  logic [1:0] forward_reserve_valid;
  logic [1:0] forward_reserve_accept;
  logic [1:0] forward_alloc_valid;
  logic [1:0] forward_alloc_accept;
  logic [5:0] forward_live_count;

  logic [P*W_APP-1:0] acc_source0_app;
  logic [P*W_APP-1:0] acc_source1_app;
  logic acc_source0_valid;
  logic acc_source1_valid;
  logic rec_commit_accept_w;
  logic app_write_commit_w;
  logic [1:0] rec_forward_candidate_valid;
  logic [P*W_APP-1:0] rec_forward_candidate_lane0;
  logic [P*W_APP-1:0] rec_forward_candidate_lane1;
  logic [6:0] rec_forward_candidate_base_column0;
  logic [6:0] rec_forward_candidate_base_column1;
  logic [3:0] rec_forward_candidate_iteration_epoch;
  logic [3:0] rec_forward_candidate_aux0;
  logic [3:0] rec_forward_candidate_aux1;

  function automatic logic column_active(input logic [6:0] column);
    begin
      case (column)
        7'd0, 7'd1, 7'd2, 7'd3, 7'd4, 7'd5, 7'd6, 7'd7,
        7'd8, 7'd9, 7'd10, 7'd11, 7'd12, 7'd13, 7'd14, 7'd15,
        7'd16, 7'd17, 7'd18, 7'd19, 7'd20, 7'd21, 7'd22, 7'd23,
        7'd24, 7'd25: column_active = 1'b1;
        default: column_active = 1'b0;
      endcase
    end
  endfunction

  function automatic logic [2:0] column_bank(input logic [6:0] column);
    begin
      case (column)
        7'd0:  column_bank = 3'd0;
        7'd1:  column_bank = 3'd3;
        7'd2:  column_bank = 3'd1;
        7'd3:  column_bank = 3'd5;
        7'd4:  column_bank = 3'd2;
        7'd5:  column_bank = 3'd3;
        7'd6:  column_bank = 3'd6;
        7'd7:  column_bank = 3'd4;
        7'd8:  column_bank = 3'd5;
        7'd9:  column_bank = 3'd6;
        7'd10: column_bank = 3'd7;
        7'd11: column_bank = 3'd0;
        7'd12: column_bank = 3'd1;
        7'd13: column_bank = 3'd4;
        7'd14: column_bank = 3'd7;
        7'd15: column_bank = 3'd2;
        7'd16: column_bank = 3'd2;
        7'd17: column_bank = 3'd1;
        7'd18: column_bank = 3'd5;
        7'd19: column_bank = 3'd4;
        7'd20: column_bank = 3'd3;
        7'd21: column_bank = 3'd6;
        7'd22: column_bank = 3'd7;
        7'd23: column_bank = 3'd3;
        7'd24: column_bank = 3'd0;
        7'd25: column_bank = 3'd1;
        default: column_bank = 3'd0;
      endcase
    end
  endfunction

  assign acc_lane0_active_w = acc_issue_valid_i && acc_issue_lane_mask_i[0];
  assign acc_lane1_active_w = acc_issue_valid_i && acc_issue_lane_mask_i[1];
  assign acc_aux0_legal_w = (acc_issue_aux0_i <= 4'd8);
  assign acc_aux1_legal_w = (acc_issue_aux1_i <= 4'd8);

  assign app_read_valid[0] = acc_lane0_active_w && acc_aux0_legal_w && (acc_issue_aux0_i == 4'd0);
  assign app_read_valid[1] = acc_lane1_active_w && acc_aux1_legal_w && (acc_issue_aux1_i == 4'd0);
  assign forward_read_valid[0] = acc_lane0_active_w && acc_aux0_legal_w && (acc_issue_aux0_i != 4'd0);
  assign forward_read_valid[1] = acc_lane1_active_w && acc_aux1_legal_w && (acc_issue_aux1_i != 4'd0);

  assign acc_source0_app = forward_read_valid[0] ? forward_read0 : app_read0;
  assign acc_source1_app = forward_read_valid[1] ? forward_read1 : app_read1;
  assign acc_source0_valid = !acc_lane0_active_w
      ? 1'b0
      : (acc_aux0_legal_w && (forward_read_valid[0] ? forward_read_accept[0] : app_read_accept[0]));
  assign acc_source1_valid = !acc_lane1_active_w
      ? 1'b0
      : (acc_aux1_legal_w && (forward_read_valid[1] ? forward_read_accept[1] : app_read_accept[1]));

  assign rec_issue_aux0_legal_w = (rec_issue_aux0_i <= 4'd8);
  assign rec_issue_aux1_legal_w = (rec_issue_aux1_i <= 4'd8);
  assign forward_reserve_valid[0] = rec_issue_valid_i
      && rec_issue_lane_mask_i[0]
      && rec_issue_aux0_legal_w
      && (rec_issue_aux0_i != 4'd0);
  assign forward_reserve_valid[1] = rec_issue_valid_i
      && rec_issue_lane_mask_i[1]
      && rec_issue_aux1_legal_w
      && (rec_issue_aux1_i != 4'd0);

  assign rec_publication_aux0_legal_w = (rec_app_write_aux0_o <= 4'd8);
  assign rec_publication_aux1_legal_w = (rec_app_write_aux1_o <= 4'd8);
  assign forward_candidate_aux0_legal_w = (rec_forward_candidate_aux0 <= 4'd8);
  assign forward_candidate_aux1_legal_w = (rec_forward_candidate_aux1 <= 4'd8);
  assign forward_candidate_column0_active_w = column_active(rec_forward_candidate_base_column0);
  assign forward_candidate_column1_active_w = column_active(rec_forward_candidate_base_column1);
  assign forward_candidate_bank0_w = column_bank(rec_forward_candidate_base_column0);
  assign forward_candidate_bank1_w = column_bank(rec_forward_candidate_base_column1);
  assign forward_candidate_duplicate_w =
      rec_forward_candidate_valid[0]
      && rec_forward_candidate_valid[1]
      && (rec_forward_candidate_aux0 != 4'd0)
      && (rec_forward_candidate_aux1 != 4'd0)
      && (rec_forward_candidate_aux0 == rec_forward_candidate_aux1);
  assign forward_candidate_error_w =
      forward_candidate_duplicate_w
      || (rec_forward_candidate_valid[0]
          && (rec_forward_candidate_aux0 != 4'd0)
          && (!forward_candidate_aux0_legal_w || !forward_candidate_column0_active_w))
      || (rec_forward_candidate_valid[1]
          && (rec_forward_candidate_aux1 != 4'd0)
          && (!forward_candidate_aux1_legal_w || !forward_candidate_column1_active_w));
  assign forward_alloc_valid[0] = rec_forward_candidate_valid[0]
      && !forward_candidate_error_w
      && forward_candidate_aux0_legal_w
      && (rec_forward_candidate_aux0 != 4'd0);
  assign forward_alloc_valid[1] = rec_forward_candidate_valid[1]
      && !forward_candidate_error_w
      && forward_candidate_aux1_legal_w
      && (rec_forward_candidate_aux1 != 4'd0);

  assign app_write_commit_w =
      (|rec_app_write_valid_o)
      && (!rec_app_write_valid_o[0] || rec_publication_aux0_legal_w)
      && (!rec_app_write_valid_o[1] || rec_publication_aux1_legal_w)
      && (!rec_app_write_valid_o[0] || app_write_accept[0])
      && (!rec_app_write_valid_o[1] || app_write_accept[1]);
  assign forward_candidate_commit_w =
      (|forward_alloc_valid)
      && !forward_candidate_error_w
      && (!forward_alloc_valid[0] || forward_alloc_accept[0])
      && (!forward_alloc_valid[1] || forward_alloc_accept[1]);

  assign app_source_error_w =
      (acc_lane0_active_w && (!acc_aux0_legal_w || !acc_source0_valid))
      || (acc_lane1_active_w && (!acc_aux1_legal_w || !acc_source1_valid));
  assign rec_reserve_error_w =
      (rec_issue_valid_i && rec_issue_lane_mask_i[0] && !rec_issue_aux0_legal_w)
      || (rec_issue_valid_i && rec_issue_lane_mask_i[1] && !rec_issue_aux1_legal_w);
  assign rec_commit_accept_w = app_write_commit_w;
  assign rec_commit_error_w =
      ((|rec_app_write_valid_o) && !app_write_commit_w)
      || ((|rec_forward_candidate_valid) && forward_candidate_error_w)
      || ((|forward_alloc_valid) && !forward_candidate_commit_w);
  assign r2_same_bank_collision_w =
      (app_read_valid[0]
          && ((rec_forward_candidate_valid[0] && forward_candidate_column0_active_w
                  && (debug_app_read_bank0_o == forward_candidate_bank0_w))
              || (rec_forward_candidate_valid[1] && forward_candidate_column1_active_w
                  && (debug_app_read_bank0_o == forward_candidate_bank1_w))))
      || (app_read_valid[1]
          && ((rec_forward_candidate_valid[0] && forward_candidate_column0_active_w
                  && (debug_app_read_bank1_o == forward_candidate_bank0_w))
              || (rec_forward_candidate_valid[1] && forward_candidate_column1_active_w
                  && (debug_app_read_bank1_o == forward_candidate_bank1_w))));

  nr_ldpc_app_memory #(
    .P(P)
  ) u_app_memory (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_block_i(start_block_i),
    .load_valid_i(app_load_valid_i),
    .load_column_i(app_load_column_i),
    .load_iteration_epoch_i(app_load_iteration_epoch_i),
    .load_app_i(app_load_i),
    .read_valid_i(app_read_valid),
    .read_column0_i(acc_issue_base_column0_i),
    .read_column1_i(acc_issue_base_column1_i),
    .read_accept_o(app_read_accept),
    .read_app0_o(app_read0),
    .read_app1_o(app_read1),
    .read_bank0_o(debug_app_read_bank0_o),
    .read_bank1_o(debug_app_read_bank1_o),
    .write_valid_i(rec_app_write_valid_o),
    .write_commit_i(app_write_commit_w),
    .write_column0_i(rec_app_write_base_column0_o),
    .write_column1_i(rec_app_write_base_column1_o),
    .write_iteration_epoch_i(rec_app_write_iteration_epoch_o),
    .write_app0_i(rec_app_write_lane0_o),
    .write_app1_i(rec_app_write_lane1_o),
    .write_accept_o(app_write_accept),
    .write_bank0_o(debug_app_write_bank0_o),
    .write_bank1_o(debug_app_write_bank1_o),
    .same_bank_read_write_collision_o(app_memory_same_bank_collision_w),
    .error_valid_o(app_memory_error_valid_o),
    .error_code_o(app_memory_error_code_o)
  );

  nr_ldpc_forward_cache #(
    .P(P),
    .DEPTH(FORWARD_DEPTH)
  ) u_forward_cache (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_block_i(start_block_i),
    .advance_iteration_i(debug_advance_accept_o),
    .reserve_valid_i(forward_reserve_valid),
    .reserve_slot0_i(rec_issue_aux0_i[2:0] - 3'd1),
    .reserve_slot1_i(rec_issue_aux1_i[2:0] - 3'd1),
    .reserve_column0_i(rec_issue_base_column0_i),
    .reserve_column1_i(rec_issue_base_column1_i),
    .reserve_iteration_epoch_i(rec_issue_iteration_epoch_i),
    .publish_valid_i(forward_alloc_valid),
    .publish_commit_i(forward_candidate_commit_w),
    .publish_slot0_i(rec_forward_candidate_aux0[2:0] - 3'd1),
    .publish_slot1_i(rec_forward_candidate_aux1[2:0] - 3'd1),
    .publish_column0_i(rec_forward_candidate_base_column0),
    .publish_column1_i(rec_forward_candidate_base_column1),
    .publish_iteration_epoch_i(rec_forward_candidate_iteration_epoch),
    .publish_app0_i(rec_forward_candidate_lane0),
    .publish_app1_i(rec_forward_candidate_lane1),
    .reserve_accept_o(forward_reserve_accept),
    .alloc_accept_o(forward_alloc_accept),
    .read_valid_i(forward_read_valid),
    .read_slot0_i(acc_issue_aux0_i[2:0] - 3'd1),
    .read_slot1_i(acc_issue_aux1_i[2:0] - 3'd1),
    .read_column0_i(acc_issue_base_column0_i),
    .read_column1_i(acc_issue_base_column1_i),
    .read_iteration_epoch_i(acc_issue_iteration_epoch_i),
    .read_accept_o(forward_read_accept),
    .read_app0_o(forward_read0),
    .read_app1_o(forward_read1),
    .live_count_o(forward_live_count),
    .error_valid_o(forward_error_valid_o),
    .error_code_o(forward_error_code_o)
  );

  nr_ldpc_acc_rec_datapath #(
    .P(P)
  ) u_phase6_datapath (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_block_i(start_block_i),
    .advance_iteration_i(advance_iteration_i),
    .acc_issue_valid_i(acc_issue_valid_i),
    .acc_issue_ready_o(acc_issue_ready_o),
    .acc_issue_lane_mask_i(acc_issue_lane_mask_i),
    .acc_issue_layer_id_i(acc_issue_layer_id_i),
    .acc_issue_layer_position_i(acc_issue_layer_position_i),
    .acc_issue_layer_degree_i(acc_issue_layer_degree_i),
    .acc_issue_start_layer_i(acc_issue_start_layer_i),
    .acc_issue_edge0_id_i(acc_issue_edge0_id_i),
    .acc_issue_edge1_id_i(acc_issue_edge1_id_i),
    .acc_issue_qbuf_i(acc_issue_qbuf_i),
    .acc_issue_qslot_i(acc_issue_qslot_i),
    .acc_issue_iteration_epoch_i(acc_issue_iteration_epoch_i),
    .acc_issue_app0_canonical_i(acc_source0_app),
    .acc_issue_app1_canonical_i(acc_source1_app),
    .acc_issue_source0_valid_i(acc_source0_valid),
    .acc_issue_source1_valid_i(acc_source1_valid),
    .acc_issue_shift0_i(acc_issue_shift0_i),
    .acc_issue_shift1_i(acc_issue_shift1_i),
    .rec_issue_valid_i(rec_issue_valid_i),
    .rec_issue_ready_o(rec_issue_ready_o),
    .rec_issue_lane_mask_i(rec_issue_lane_mask_i),
    .rec_issue_layer_id_i(rec_issue_layer_id_i),
    .rec_issue_edge0_id_i(rec_issue_edge0_id_i),
    .rec_issue_edge1_id_i(rec_issue_edge1_id_i),
    .rec_issue_qbuf_i(rec_issue_qbuf_i),
    .rec_issue_qslot_i(rec_issue_qslot_i),
    .rec_issue_iteration_epoch_i(rec_issue_iteration_epoch_i),
    .rec_issue_shift0_i(rec_issue_shift0_i),
    .rec_issue_shift1_i(rec_issue_shift1_i),
    .rec_issue_base_column0_i(rec_issue_base_column0_i),
    .rec_issue_base_column1_i(rec_issue_base_column1_i),
    .rec_issue_aux0_i(rec_issue_aux0_i),
    .rec_issue_aux1_i(rec_issue_aux1_i),
    .rec_issue_final_touch0_i(rec_issue_final_touch0_i),
    .rec_issue_final_touch1_i(rec_issue_final_touch1_i),
    .rec_app_write_valid_o(rec_app_write_valid_o),
    .rec_app_write_lane0_o(rec_app_write_lane0_o),
    .rec_app_write_lane1_o(rec_app_write_lane1_o),
    .rec_app_write_base_column0_o(rec_app_write_base_column0_o),
    .rec_app_write_base_column1_o(rec_app_write_base_column1_o),
    .rec_app_write_lane_mask_o(rec_app_write_lane_mask_o),
    .rec_app_write_layer_id_o(rec_app_write_layer_id_o),
    .rec_app_write_edge0_id_o(rec_app_write_edge0_id_o),
    .rec_app_write_edge1_id_o(rec_app_write_edge1_id_o),
    .rec_app_write_iteration_epoch_o(rec_app_write_iteration_epoch_o),
    .rec_app_write_qbuf_o(rec_app_write_qbuf_o),
    .rec_app_write_qslot_o(rec_app_write_qslot_o),
    .rec_app_write_aux0_o(rec_app_write_aux0_o),
    .rec_app_write_aux1_o(rec_app_write_aux1_o),
    .rec_app_write_final_touch0_o(rec_app_write_final_touch0_o),
    .rec_app_write_final_touch1_o(rec_app_write_final_touch1_o),
    .rec_forward_candidate_valid_o(rec_forward_candidate_valid),
    .rec_forward_candidate_lane0_o(rec_forward_candidate_lane0),
    .rec_forward_candidate_lane1_o(rec_forward_candidate_lane1),
    .rec_forward_candidate_base_column0_o(rec_forward_candidate_base_column0),
    .rec_forward_candidate_base_column1_o(rec_forward_candidate_base_column1),
    .rec_forward_candidate_iteration_epoch_o(rec_forward_candidate_iteration_epoch),
    .rec_forward_candidate_aux0_o(rec_forward_candidate_aux0),
    .rec_forward_candidate_aux1_o(rec_forward_candidate_aux1),
    .rec_forward_valid_o(rec_forward_valid_o),
    .rec_forward_slot0_o(rec_forward_slot0_o),
    .rec_forward_slot1_o(rec_forward_slot1_o),
    .rec_forward_base_column0_o(rec_forward_base_column0_o),
    .rec_forward_base_column1_o(rec_forward_base_column1_o),
    .rec_forward_iteration_epoch_o(rec_forward_iteration_epoch_o),
    .rec_forward_app0_o(rec_forward_app0_o),
    .rec_forward_app1_o(rec_forward_app1_o),
    .rec_final_touch_valid_o(rec_final_touch_valid_o),
    .rec_final_touch_base_column0_o(rec_final_touch_base_column0_o),
    .rec_final_touch_base_column1_o(rec_final_touch_base_column1_o),
    .rec_final_touch_layer_id_o(rec_final_touch_layer_id_o),
    .rec_final_touch_edge0_id_o(rec_final_touch_edge0_id_o),
    .rec_final_touch_edge1_id_o(rec_final_touch_edge1_id_o),
    .rec_final_touch_iteration_epoch_o(rec_final_touch_iteration_epoch_o),
    .rec_final_touch_app0_o(rec_final_touch_app0_o),
    .rec_final_touch_app1_o(rec_final_touch_app1_o),
    .rec_final_touch_hard0_o(rec_final_touch_hard0_o),
    .rec_final_touch_hard1_o(rec_final_touch_hard1_o),
    .acc_error_valid_o(acc_error_valid_o),
    .rec_error_valid_o(rec_error_valid_o),
    .q_scratch_error_valid_o(q_scratch_error_valid_o),
    .q_scratch_error_code_o(q_scratch_error_code_o),
    .check_state_error_valid_o(check_state_error_valid_o),
    .check_state_error_code_o(check_state_error_code_o),
    .old_state_alignment_error_o(old_state_alignment_error_o),
    .unsafe_advance_error_o(unsafe_advance_error_o),
    .storage_error_valid_o(phase6_storage_error_valid_o),
    .current_old_generation_o(current_old_generation_o),
    .current_new_generation_o(current_new_generation_o),
    .debug_acc_q_write_valid_o(debug_acc_q_write_valid_o),
    .debug_acc_q_write_qbuf_o(debug_acc_q_write_qbuf_o),
    .debug_acc_q_write_qslot_o(debug_acc_q_write_qslot_o),
    .debug_acc_q_write_lane_mask_o(debug_acc_q_write_lane_mask_o),
    .debug_acc_q_write_lane0_o(debug_acc_q_write_lane0_o),
    .debug_acc_q_write_lane1_o(debug_acc_q_write_lane1_o),
    .debug_acc_q_write_layer_id_o(debug_acc_q_write_layer_id_o),
    .debug_acc_q_write_iteration_epoch_o(debug_acc_q_write_iteration_epoch_o),
    .debug_acc_qsign_write_valid_o(debug_acc_qsign_write_valid_o),
    .debug_acc_qsign_write_edge0_id_o(debug_acc_qsign_write_edge0_id_o),
    .debug_acc_qsign_write_edge1_id_o(debug_acc_qsign_write_edge1_id_o),
    .debug_acc_qsign_write_lane0_o(debug_acc_qsign_write_lane0_o),
    .debug_acc_qsign_write_lane1_o(debug_acc_qsign_write_lane1_o),
    .debug_layer_close_valid_o(debug_layer_close_valid_o),
    .debug_layer_close_layer_id_o(debug_layer_close_layer_id_o),
    .debug_layer_close_m1_o(debug_layer_close_m1_o),
    .debug_layer_close_m2_o(debug_layer_close_m2_o),
    .debug_layer_close_imin_o(debug_layer_close_imin_o),
    .debug_layer_close_aggregate_sign_o(debug_layer_close_aggregate_sign_o),
    .debug_q_write_accept_o(debug_q_write_accept_o),
    .debug_advance_accept_o(debug_advance_accept_o),
    .debug_acc_old_resp_valid_o(debug_acc_old_resp_valid_o),
    .debug_acc_old_generation_valid_o(debug_acc_old_generation_valid_o),
    .debug_rec_new_resp_valid_o(debug_rec_new_resp_valid_o),
    .debug_rec_new_state_closed_o(debug_rec_new_state_closed_o),
    .debug_rec_new_m1_o(debug_rec_new_m1_o),
    .debug_rec_new_m2_o(debug_rec_new_m2_o),
    .debug_rec_new_imin_o(debug_rec_new_imin_o),
    .debug_rec_new_aggregate_sign_o(debug_rec_new_aggregate_sign_o),
    .debug_q_read_resp_lane0_o(debug_q_read_resp_lane0_o),
    .debug_q_read_resp_lane1_o(debug_q_read_resp_lane1_o),
    .debug_q_read_resp_layer_id_o(debug_q_read_resp_layer_id_o),
    .debug_q_read_resp_qslot_o(debug_q_read_resp_qslot_o),
    .debug_q_live_count_o(debug_q_live_count_o)
  );

  assign app_forward_error_valid_o = app_source_error_w
      || rec_reserve_error_w
      || rec_commit_error_w
      || app_memory_error_valid_o
      || forward_error_valid_o;
  assign storage_error_valid_o = phase6_storage_error_valid_o || app_forward_error_valid_o;

  assign debug_acc_source_valid_o = {acc_source1_valid, acc_source0_valid};
  assign debug_acc_source_forwarded_o = {forward_read_valid[1], forward_read_valid[0]};
  assign debug_acc_source0_app_o = acc_source0_app;
  assign debug_acc_source1_app_o = acc_source1_app;
  assign debug_app_write_accept_o = app_write_accept;
  assign debug_app_write_commit_o = app_write_commit_w;
  assign debug_app_same_bank_collision_o = r2_same_bank_collision_w;
  assign debug_forward_alloc_valid_o = forward_alloc_valid;
  assign debug_forward_alloc_accept_o = forward_alloc_accept;
  assign debug_forward_read_valid_o = forward_read_valid;
  assign debug_forward_read_accept_o = forward_read_accept;
  assign debug_forward_live_count_o = forward_live_count;
  assign debug_forward_candidate_valid_o = rec_forward_candidate_valid;
  assign debug_forward_candidate_slot0_o = rec_forward_candidate_aux0[2:0] - 3'd1;
  assign debug_forward_candidate_slot1_o = rec_forward_candidate_aux1[2:0] - 3'd1;
  assign debug_forward_candidate_base_column0_o = rec_forward_candidate_base_column0;
  assign debug_forward_candidate_base_column1_o = rec_forward_candidate_base_column1;
  assign debug_forward_candidate_iteration_epoch_o = rec_forward_candidate_iteration_epoch;
  assign debug_forward_candidate_app0_o = rec_forward_candidate_lane0;
  assign debug_forward_candidate_app1_o = rec_forward_candidate_lane1;
  assign debug_rec_publication_valid_o = rec_app_write_valid_o;
endmodule

`endif
