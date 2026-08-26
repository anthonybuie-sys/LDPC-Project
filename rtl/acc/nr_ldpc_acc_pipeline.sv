`ifndef NR_LDPC_ACC_PIPELINE_SV
`define NR_LDPC_ACC_PIPELINE_SV

module nr_ldpc_acc_pipeline #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic                         clk_i,
  input  logic                         rst_i,

  input  logic                         issue_valid_i,
  output logic                         issue_ready_o,
  input  logic [1:0]                   issue_lane_mask_i,
  input  logic [5:0]                   issue_layer_id_i,
  input  logic [5:0]                   issue_layer_position_i,
  input  logic [5:0]                   issue_layer_degree_i,
  input  logic                         issue_start_layer_i,
  input  logic [4:0]                   issue_edge0_id_i,
  input  logic [4:0]                   issue_edge1_id_i,
  input  logic [0:0]                   issue_qbuf_i,
  input  logic [3:0]                   issue_qslot_i,
  input  logic                         issue_target_generation_i,
  input  logic [3:0]                   issue_iteration_epoch_i,
  input  logic [P*8-1:0]               issue_app0_canonical_i,
  input  logic [P*8-1:0]               issue_app1_canonical_i,
  input  logic                         issue_source0_valid_i,
  input  logic                         issue_source1_valid_i,
  input  logic [$clog2(P+1)-1:0]       issue_shift0_i,
  input  logic [$clog2(P+1)-1:0]       issue_shift1_i,

  output logic                         old_state_req_valid_o,
  output logic [1:0]                   old_state_req_lane_mask_o,
  output logic [5:0]                   old_state_req_layer_id_o,
  output logic [4:0]                   old_state_req_edge0_id_o,
  output logic [4:0]                   old_state_req_edge1_id_o,
  output logic [3:0]                   old_state_req_iteration_epoch_o,

  input  logic                         old_state_resp_valid_i,
  input  logic                         old_generation_valid_i,
  input  logic [P*6-1:0]               old_m1_i,
  input  logic [P*6-1:0]               old_m2_i,
  input  logic [P*5-1:0]               old_imin_i,
  input  logic [P-1:0]                 old_aggregate_sign_i,
  input  logic [P-1:0]                 old_qsign0_i,
  input  logic [P-1:0]                 old_qsign1_i,

  output logic                         q_write_valid_o,
  output logic [0:0]                   q_write_qbuf_o,
  output logic [3:0]                   q_write_qslot_o,
  output logic [1:0]                   q_write_lane_mask_o,
  output logic [P*8-1:0]               q_write_lane0_o,
  output logic [P*8-1:0]               q_write_lane1_o,
  output logic [5:0]                   q_write_layer_id_o,
  output logic [3:0]                   q_write_iteration_epoch_o,

  output logic [1:0]                   qsign_write_valid_o,
  output logic [4:0]                   qsign_write_edge0_id_o,
  output logic [4:0]                   qsign_write_edge1_id_o,
  output logic [P-1:0]                 qsign_write_lane0_o,
  output logic [P-1:0]                 qsign_write_lane1_o,
  output logic [5:0]                   qsign_write_layer_id_o,
  output logic                         qsign_write_target_generation_o,
  output logic [3:0]                   qsign_write_iteration_epoch_o,

  output logic                         layer_close_valid_o,
  output logic [5:0]                   layer_close_layer_id_o,
  output logic                         layer_close_target_generation_o,
  output logic [3:0]                   layer_close_iteration_epoch_o,
  output logic [P*6-1:0]               layer_close_m1_offset_o,
  output logic [P*6-1:0]               layer_close_m2_offset_o,
  output logic [P*5-1:0]               layer_close_imin_o,
  output logic [P-1:0]                 layer_close_aggregate_sign_o,

  output logic                         error_valid_o
);
  import nr_ldpc_pkg::*;

  localparam int SHIFT_W = $clog2(P+1);

  logic a0_valid_q;
  logic [1:0] a0_lane_mask_q;
  logic [5:0] a0_layer_id_q;
  logic [5:0] a0_layer_position_q;
  logic [5:0] a0_layer_degree_q;
  logic a0_start_layer_q;
  logic [4:0] a0_edge0_id_q;
  logic [4:0] a0_edge1_id_q;
  logic [0:0] a0_qbuf_q;
  logic [3:0] a0_qslot_q;
  logic a0_target_generation_q;
  logic [3:0] a0_iteration_epoch_q;
  logic [P*W_APP-1:0] a0_app0_canonical_q;
  logic [P*W_APP-1:0] a0_app1_canonical_q;
  logic a0_source0_valid_q;
  logic a0_source1_valid_q;
  logic [SHIFT_W-1:0] a0_shift0_q;
  logic [SHIFT_W-1:0] a0_shift1_q;

  logic [P*W_APP-1:0] a0_app0_check_w;
  logic [P*W_APP-1:0] a0_app1_check_w;
  logic a0_shift0_error_w;
  logic a0_shift1_error_w;
  logic a0_error_w;

  logic a1_valid_q;
  logic [1:0] a1_lane_mask_q;
  logic [5:0] a1_layer_id_q;
  logic [5:0] a1_layer_position_q;
  logic [5:0] a1_layer_degree_q;
  logic a1_start_layer_q;
  logic [4:0] a1_edge0_id_q;
  logic [4:0] a1_edge1_id_q;
  logic [0:0] a1_qbuf_q;
  logic [3:0] a1_qslot_q;
  logic a1_target_generation_q;
  logic [3:0] a1_iteration_epoch_q;
  logic [P*W_APP-1:0] a1_app0_check_q;
  logic [P*W_APP-1:0] a1_app1_check_q;
  logic a1_error_q;

  logic [P*W_Q-1:0] q0_w;
  logic [P*W_Q-1:0] q1_w;
  logic [P*W_M-1:0] q_mag0_w;
  logic [P*W_M-1:0] q_mag1_w;
  logic [P-1:0] q_sign0_w;
  logic [P-1:0] q_sign1_w;
  logic [P*W_C2V-1:0] old_c2v0_reconstructed_w;
  logic [P*W_C2V-1:0] old_c2v1_reconstructed_w;
  logic [P*W_C2V-1:0] old_c2v0_selected_w;
  logic [P*W_C2V-1:0] old_c2v1_selected_w;

  logic a2_valid_q;
  logic [1:0] a2_lane_mask_q;
  logic [5:0] a2_layer_id_q;
  logic [5:0] a2_layer_position_q;
  logic [5:0] a2_layer_degree_q;
  logic a2_start_layer_q;
  logic [4:0] a2_edge0_id_q;
  logic [4:0] a2_edge1_id_q;
  logic [0:0] a2_qbuf_q;
  logic [3:0] a2_qslot_q;
  logic a2_target_generation_q;
  logic [3:0] a2_iteration_epoch_q;
  logic [P*W_Q-1:0] a2_q0_q;
  logic [P*W_Q-1:0] a2_q1_q;
  logic [P*W_M-1:0] a2_q_mag0_q;
  logic [P*W_M-1:0] a2_q_mag1_q;
  logic [P-1:0] a2_q_sign0_q;
  logic [P-1:0] a2_q_sign1_q;
  logic a2_error_q;
  logic a2_context_id_q;

  logic ctx0_update_error;
  logic ctx1_update_error;
  logic selected_context_error;
  logic ctx0_error_valid;
  logic ctx1_error_valid;
  logic ctx0_close_valid;
  logic ctx1_close_valid;
  logic [5:0] ctx0_close_layer_id;
  logic [5:0] ctx1_close_layer_id;
  logic ctx0_close_target_generation;
  logic ctx1_close_target_generation;
  logic [3:0] ctx0_close_iteration_epoch;
  logic [3:0] ctx1_close_iteration_epoch;
  logic [5:0] ctx0_close_edge_count_unused;
  logic [5:0] ctx1_close_edge_count_unused;
  logic [P*W_M-1:0] ctx0_close_m1_offset;
  logic [P*W_M-1:0] ctx1_close_m1_offset;
  logic [P*W_M-1:0] ctx0_close_m2_offset;
  logic [P*W_M-1:0] ctx1_close_m2_offset;
  logic [P*5-1:0] ctx0_close_imin;
  logic [P*5-1:0] ctx1_close_imin;
  logic [P-1:0] ctx0_close_aggregate_sign;
  logic [P-1:0] ctx1_close_aggregate_sign;
  logic ctx0_open_unused;
  logic ctx1_open_unused;

  assign issue_ready_o = 1'b1;

  assign old_state_req_valid_o = a0_valid_q;
  assign old_state_req_lane_mask_o = a0_lane_mask_q;
  assign old_state_req_layer_id_o = a0_layer_id_q;
  assign old_state_req_edge0_id_o = a0_edge0_id_q;
  assign old_state_req_edge1_id_o = a0_edge1_id_q;
  assign old_state_req_iteration_epoch_o = a0_iteration_epoch_q;

  nr_ldpc_qc_forward #(
    .P(P),
    .LANE_W(W_APP)
  ) u_qc_forward0 (
    .canonical_i(a0_app0_canonical_q),
    .shift_i(a0_shift0_q),
    .check_o(a0_app0_check_w),
    .illegal_shift_o(a0_shift0_error_w)
  );

  nr_ldpc_qc_forward #(
    .P(P),
    .LANE_W(W_APP)
  ) u_qc_forward1 (
    .canonical_i(a0_app1_canonical_q),
    .shift_i(a0_shift1_q),
    .check_o(a0_app1_check_w),
    .illegal_shift_o(a0_shift1_error_w)
  );

  always @* begin
    a0_error_w = 1'b0;
    if (a0_valid_q) begin
      if (a0_lane_mask_q == 2'b00) begin
        a0_error_w = 1'b1;
      end
      if (a0_lane_mask_q[0] && (!a0_source0_valid_q || a0_shift0_error_w)) begin
        a0_error_w = 1'b1;
      end
      if (a0_lane_mask_q[1] && (!a0_source1_valid_q || a0_shift1_error_w)) begin
        a0_error_w = 1'b1;
      end
    end
  end

  nr_ldpc_compressed_c2v_reconstruct_vector #(
    .P(P)
  ) u_old_reconstruct0 (
    .m1_i(old_m1_i),
    .m2_i(old_m2_i),
    .imin_i(old_imin_i),
    .aggregate_sign_i(old_aggregate_sign_i),
    .q_sign_i(old_qsign0_i),
    .local_edge_id_i(a1_edge0_id_q),
    .c2v_o(old_c2v0_reconstructed_w)
  );

  nr_ldpc_compressed_c2v_reconstruct_vector #(
    .P(P)
  ) u_old_reconstruct1 (
    .m1_i(old_m1_i),
    .m2_i(old_m2_i),
    .imin_i(old_imin_i),
    .aggregate_sign_i(old_aggregate_sign_i),
    .q_sign_i(old_qsign1_i),
    .local_edge_id_i(a1_edge1_id_q),
    .c2v_o(old_c2v1_reconstructed_w)
  );

  assign old_c2v0_selected_w = old_generation_valid_i ? old_c2v0_reconstructed_w : '0;
  assign old_c2v1_selected_w = old_generation_valid_i ? old_c2v1_reconstructed_w : '0;

  genvar a1_lane;
  generate
    for (a1_lane = 0; a1_lane < P; a1_lane++) begin : gen_a1_arith
      nr_ldpc_q_sub u_q_sub0 (
        .app_i(a1_app0_check_q[a1_lane*W_APP +: W_APP]),
        .old_c2v_i(old_c2v0_selected_w[a1_lane*W_C2V +: W_C2V]),
        .q_o(q0_w[a1_lane*W_Q +: W_Q]),
        .raw_o()
      );

      nr_ldpc_q_sub u_q_sub1 (
        .app_i(a1_app1_check_q[a1_lane*W_APP +: W_APP]),
        .old_c2v_i(old_c2v1_selected_w[a1_lane*W_C2V +: W_C2V]),
        .q_o(q1_w[a1_lane*W_Q +: W_Q]),
        .raw_o()
      );

      nr_ldpc_q_magnitude u_q_mag0 (
        .q_i(q0_w[a1_lane*W_Q +: W_Q]),
        .sign_o(q_sign0_w[a1_lane]),
        .magnitude_raw_o(),
        .magnitude_m6_o(q_mag0_w[a1_lane*W_M +: W_M])
      );

      nr_ldpc_q_magnitude u_q_mag1 (
        .q_i(q1_w[a1_lane*W_Q +: W_Q]),
        .sign_o(q_sign1_w[a1_lane]),
        .magnitude_raw_o(),
        .magnitude_m6_o(q_mag1_w[a1_lane*W_M +: W_M])
      );
    end
  endgenerate

  assign selected_context_error = a2_context_id_q ? ctx1_update_error : ctx0_update_error;

  nr_ldpc_acc_context #(
    .P(P)
  ) u_context0 (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .valid_i(a2_valid_q && !a2_context_id_q),
    .upstream_error_i(a2_error_q),
    .lane_mask_i(a2_lane_mask_q),
    .layer_id_i(a2_layer_id_q),
    .layer_degree_i(a2_layer_degree_q),
    .start_layer_i(a2_start_layer_q),
    .edge0_id_i(a2_edge0_id_q),
    .edge1_id_i(a2_edge1_id_q),
    .target_generation_i(a2_target_generation_q),
    .iteration_epoch_i(a2_iteration_epoch_q),
    .q_mag0_i(a2_q_mag0_q),
    .q_mag1_i(a2_q_mag1_q),
    .q_sign0_i(a2_q_sign0_q),
    .q_sign1_i(a2_q_sign1_q),
    .open_o(ctx0_open_unused),
    .update_error_o(ctx0_update_error),
    .error_valid_o(ctx0_error_valid),
    .close_valid_o(ctx0_close_valid),
    .close_layer_id_o(ctx0_close_layer_id),
    .close_target_generation_o(ctx0_close_target_generation),
    .close_iteration_epoch_o(ctx0_close_iteration_epoch),
    .close_edge_count_o(ctx0_close_edge_count_unused),
    .close_m1_offset_o(ctx0_close_m1_offset),
    .close_m2_offset_o(ctx0_close_m2_offset),
    .close_imin_o(ctx0_close_imin),
    .close_aggregate_sign_o(ctx0_close_aggregate_sign)
  );

  nr_ldpc_acc_context #(
    .P(P)
  ) u_context1 (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .valid_i(a2_valid_q && a2_context_id_q),
    .upstream_error_i(a2_error_q),
    .lane_mask_i(a2_lane_mask_q),
    .layer_id_i(a2_layer_id_q),
    .layer_degree_i(a2_layer_degree_q),
    .start_layer_i(a2_start_layer_q),
    .edge0_id_i(a2_edge0_id_q),
    .edge1_id_i(a2_edge1_id_q),
    .target_generation_i(a2_target_generation_q),
    .iteration_epoch_i(a2_iteration_epoch_q),
    .q_mag0_i(a2_q_mag0_q),
    .q_mag1_i(a2_q_mag1_q),
    .q_sign0_i(a2_q_sign0_q),
    .q_sign1_i(a2_q_sign1_q),
    .open_o(ctx1_open_unused),
    .update_error_o(ctx1_update_error),
    .error_valid_o(ctx1_error_valid),
    .close_valid_o(ctx1_close_valid),
    .close_layer_id_o(ctx1_close_layer_id),
    .close_target_generation_o(ctx1_close_target_generation),
    .close_iteration_epoch_o(ctx1_close_iteration_epoch),
    .close_edge_count_o(ctx1_close_edge_count_unused),
    .close_m1_offset_o(ctx1_close_m1_offset),
    .close_m2_offset_o(ctx1_close_m2_offset),
    .close_imin_o(ctx1_close_imin),
    .close_aggregate_sign_o(ctx1_close_aggregate_sign)
  );

  assign layer_close_valid_o = ctx0_close_valid || ctx1_close_valid;
  assign layer_close_layer_id_o = ctx1_close_valid ? ctx1_close_layer_id : ctx0_close_layer_id;
  assign layer_close_target_generation_o = ctx1_close_valid ? ctx1_close_target_generation : ctx0_close_target_generation;
  assign layer_close_iteration_epoch_o = ctx1_close_valid ? ctx1_close_iteration_epoch : ctx0_close_iteration_epoch;
  assign layer_close_m1_offset_o = ctx1_close_valid ? ctx1_close_m1_offset : ctx0_close_m1_offset;
  assign layer_close_m2_offset_o = ctx1_close_valid ? ctx1_close_m2_offset : ctx0_close_m2_offset;
  assign layer_close_imin_o = ctx1_close_valid ? ctx1_close_imin : ctx0_close_imin;
  assign layer_close_aggregate_sign_o = ctx1_close_valid ? ctx1_close_aggregate_sign : ctx0_close_aggregate_sign;
  assign error_valid_o = ctx0_error_valid || ctx1_error_valid;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      a0_valid_q <= 1'b0;
      a1_valid_q <= 1'b0;
      a2_valid_q <= 1'b0;
      q_write_valid_o <= 1'b0;
      qsign_write_valid_o <= 2'b00;
    end else begin
      a0_valid_q <= issue_valid_i && issue_ready_o;
      a0_lane_mask_q <= issue_lane_mask_i;
      a0_layer_id_q <= issue_layer_id_i;
      a0_layer_position_q <= issue_layer_position_i;
      a0_layer_degree_q <= issue_layer_degree_i;
      a0_start_layer_q <= issue_start_layer_i;
      a0_edge0_id_q <= issue_edge0_id_i;
      a0_edge1_id_q <= issue_edge1_id_i;
      a0_qbuf_q <= issue_qbuf_i;
      a0_qslot_q <= issue_qslot_i;
      a0_target_generation_q <= issue_target_generation_i;
      a0_iteration_epoch_q <= issue_iteration_epoch_i;
      a0_app0_canonical_q <= issue_app0_canonical_i;
      a0_app1_canonical_q <= issue_app1_canonical_i;
      a0_source0_valid_q <= issue_source0_valid_i;
      a0_source1_valid_q <= issue_source1_valid_i;
      a0_shift0_q <= issue_shift0_i;
      a0_shift1_q <= issue_shift1_i;

      a1_valid_q <= a0_valid_q;
      a1_lane_mask_q <= a0_lane_mask_q;
      a1_layer_id_q <= a0_layer_id_q;
      a1_layer_position_q <= a0_layer_position_q;
      a1_layer_degree_q <= a0_layer_degree_q;
      a1_start_layer_q <= a0_start_layer_q;
      a1_edge0_id_q <= a0_edge0_id_q;
      a1_edge1_id_q <= a0_edge1_id_q;
      a1_qbuf_q <= a0_qbuf_q;
      a1_qslot_q <= a0_qslot_q;
      a1_target_generation_q <= a0_target_generation_q;
      a1_iteration_epoch_q <= a0_iteration_epoch_q;
      a1_app0_check_q <= a0_app0_check_w;
      a1_app1_check_q <= a0_app1_check_w;
      a1_error_q <= a0_error_w;

      a2_valid_q <= a1_valid_q;
      a2_lane_mask_q <= a1_lane_mask_q;
      a2_layer_id_q <= a1_layer_id_q;
      a2_layer_position_q <= a1_layer_position_q;
      a2_layer_degree_q <= a1_layer_degree_q;
      a2_start_layer_q <= a1_start_layer_q;
      a2_edge0_id_q <= a1_edge0_id_q;
      a2_edge1_id_q <= a1_edge1_id_q;
      a2_qbuf_q <= a1_qbuf_q;
      a2_qslot_q <= a1_qslot_q;
      a2_target_generation_q <= a1_target_generation_q;
      a2_iteration_epoch_q <= a1_iteration_epoch_q;
      a2_q0_q <= q0_w;
      a2_q1_q <= q1_w;
      a2_q_mag0_q <= q_mag0_w;
      a2_q_mag1_q <= q_mag1_w;
      a2_q_sign0_q <= q_sign0_w;
      a2_q_sign1_q <= q_sign1_w;
      a2_error_q <= a1_error_q || (a1_valid_q && !old_state_resp_valid_i);
      a2_context_id_q <= a1_layer_position_q[0];

      q_write_valid_o <= a2_valid_q && !selected_context_error;
      q_write_qbuf_o <= a2_qbuf_q;
      q_write_qslot_o <= a2_qslot_q;
      q_write_lane_mask_o <= a2_lane_mask_q;
      q_write_lane0_o <= a2_q0_q;
      q_write_lane1_o <= a2_q1_q;
      q_write_layer_id_o <= a2_layer_id_q;
      q_write_iteration_epoch_o <= a2_iteration_epoch_q;

      qsign_write_valid_o[0] <= a2_valid_q && a2_lane_mask_q[0] && !selected_context_error;
      qsign_write_valid_o[1] <= a2_valid_q && a2_lane_mask_q[1] && !selected_context_error;
      qsign_write_edge0_id_o <= a2_edge0_id_q;
      qsign_write_edge1_id_o <= a2_edge1_id_q;
      qsign_write_lane0_o <= a2_q_sign0_q;
      qsign_write_lane1_o <= a2_q_sign1_q;
      qsign_write_layer_id_o <= a2_layer_id_q;
      qsign_write_target_generation_o <= a2_target_generation_q;
      qsign_write_iteration_epoch_o <= a2_iteration_epoch_q;
    end
  end
endmodule

`endif
