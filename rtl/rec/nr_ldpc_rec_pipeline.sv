`ifndef NR_LDPC_REC_PIPELINE_SV
`define NR_LDPC_REC_PIPELINE_SV

module nr_ldpc_rec_pipeline #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic                         clk_i,
  input  logic                         rst_i,

  input  logic                         issue_valid_i,
  output logic                         issue_ready_o,
  input  logic [1:0]                   issue_lane_mask_i,
  input  logic [5:0]                   issue_layer_id_i,
  input  logic [4:0]                   issue_edge0_id_i,
  input  logic [4:0]                   issue_edge1_id_i,
  input  logic [0:0]                   issue_qbuf_i,
  input  logic [3:0]                   issue_qslot_i,
  input  logic                         issue_target_generation_i,
  input  logic [3:0]                   issue_iteration_epoch_i,
  input  logic [$clog2(P+1)-1:0]       issue_shift0_i,
  input  logic [$clog2(P+1)-1:0]       issue_shift1_i,
  input  logic [6:0]                   issue_base_column0_i,
  input  logic [6:0]                   issue_base_column1_i,
  input  logic [3:0]                   issue_aux0_i,
  input  logic [3:0]                   issue_aux1_i,
  input  logic                         issue_final_touch0_i,
  input  logic                         issue_final_touch1_i,

  input  logic                         new_state_resp_valid_i,
  input  logic                         new_state_valid_i,
  input  logic                         new_state_closed_i,
  input  logic [5:0]                   new_state_layer_id_i,
  input  logic                         new_state_generation_i,
  input  logic [3:0]                   new_state_iteration_epoch_i,
  input  logic [P*6-1:0]               new_m1_i,
  input  logic [P*6-1:0]               new_m2_i,
  input  logic [P*5-1:0]               new_imin_i,
  input  logic [P-1:0]                 new_aggregate_sign_i,
  input  logic [P-1:0]                 new_qsign0_i,
  input  logic [P-1:0]                 new_qsign1_i,

  output logic                         q_req_valid_o,
  output logic [0:0]                   q_req_qbuf_o,
  output logic [3:0]                   q_req_qslot_o,
  output logic [1:0]                   q_req_lane_mask_o,
  output logic [5:0]                   q_req_layer_id_o,
  output logic [3:0]                   q_req_iteration_epoch_o,

  input  logic                         q_resp_valid_i,
  input  logic [0:0]                   q_resp_qbuf_i,
  input  logic [3:0]                   q_resp_qslot_i,
  input  logic [1:0]                   q_resp_lane_mask_i,
  input  logic [5:0]                   q_resp_layer_id_i,
  input  logic [3:0]                   q_resp_iteration_epoch_i,
  input  logic [P*8-1:0]               q_resp_lane0_i,
  input  logic [P*8-1:0]               q_resp_lane1_i,

  output logic [1:0]                   app_write_valid_o,
  output logic [P*8-1:0]               app_write_lane0_o,
  output logic [P*8-1:0]               app_write_lane1_o,
  output logic [6:0]                   app_write_base_column0_o,
  output logic [6:0]                   app_write_base_column1_o,
  output logic [1:0]                   app_write_lane_mask_o,
  output logic [5:0]                   app_write_layer_id_o,
  output logic [4:0]                   app_write_edge0_id_o,
  output logic [4:0]                   app_write_edge1_id_o,
  output logic [3:0]                   app_write_iteration_epoch_o,
  output logic [0:0]                   app_write_qbuf_o,
  output logic [3:0]                   app_write_qslot_o,
  output logic [3:0]                   app_write_aux0_o,
  output logic [3:0]                   app_write_aux1_o,
  output logic                         app_write_final_touch0_o,
  output logic                         app_write_final_touch1_o,

  output logic [1:0]                   forward_candidate_valid_o,
  output logic [P*8-1:0]               forward_candidate_lane0_o,
  output logic [P*8-1:0]               forward_candidate_lane1_o,
  output logic [6:0]                   forward_candidate_base_column0_o,
  output logic [6:0]                   forward_candidate_base_column1_o,
  output logic [3:0]                   forward_candidate_iteration_epoch_o,
  output logic [3:0]                   forward_candidate_aux0_o,
  output logic [3:0]                   forward_candidate_aux1_o,

  output logic [1:0]                   forward_valid_o,
  output logic [2:0]                   forward_slot0_o,
  output logic [2:0]                   forward_slot1_o,
  output logic [6:0]                   forward_base_column0_o,
  output logic [6:0]                   forward_base_column1_o,
  output logic [3:0]                   forward_iteration_epoch_o,
  output logic [P*8-1:0]               forward_app0_o,
  output logic [P*8-1:0]               forward_app1_o,

  output logic [1:0]                   final_touch_valid_o,
  output logic [6:0]                   final_touch_base_column0_o,
  output logic [6:0]                   final_touch_base_column1_o,
  output logic [5:0]                   final_touch_layer_id_o,
  output logic [4:0]                   final_touch_edge0_id_o,
  output logic [4:0]                   final_touch_edge1_id_o,
  output logic [3:0]                   final_touch_iteration_epoch_o,
  output logic [P*8-1:0]               final_touch_app0_o,
  output logic [P*8-1:0]               final_touch_app1_o,
  output logic [P-1:0]                 final_touch_hard0_o,
  output logic [P-1:0]                 final_touch_hard1_o,

  output logic                         error_valid_o
);
  import nr_ldpc_pkg::*;

  localparam int SHIFT_W = $clog2(P+1);

  logic r0_valid_q;
  logic [1:0] r0_lane_mask_q;
  logic [5:0] r0_layer_id_q;
  logic [4:0] r0_edge0_id_q;
  logic [4:0] r0_edge1_id_q;
  logic [0:0] r0_qbuf_q;
  logic [3:0] r0_qslot_q;
  logic r0_target_generation_q;
  logic [3:0] r0_iteration_epoch_q;
  logic [SHIFT_W-1:0] r0_shift0_q;
  logic [SHIFT_W-1:0] r0_shift1_q;
  logic [6:0] r0_base_column0_q;
  logic [6:0] r0_base_column1_q;
  logic [3:0] r0_aux0_q;
  logic [3:0] r0_aux1_q;
  logic r0_final_touch0_q;
  logic r0_final_touch1_q;
  logic r0_error_w;

  logic [P*W_C2V-1:0] r0_c2v0_w;
  logic [P*W_C2V-1:0] r0_c2v1_w;

  logic r1_valid_q;
  logic [1:0] r1_lane_mask_q;
  logic [5:0] r1_layer_id_q;
  logic [4:0] r1_edge0_id_q;
  logic [4:0] r1_edge1_id_q;
  logic [0:0] r1_qbuf_q;
  logic [3:0] r1_qslot_q;
  logic [3:0] r1_iteration_epoch_q;
  logic [SHIFT_W-1:0] r1_shift0_q;
  logic [SHIFT_W-1:0] r1_shift1_q;
  logic [6:0] r1_base_column0_q;
  logic [6:0] r1_base_column1_q;
  logic [3:0] r1_aux0_q;
  logic [3:0] r1_aux1_q;
  logic r1_final_touch0_q;
  logic r1_final_touch1_q;
  logic [P*W_C2V-1:0] r1_c2v0_q;
  logic [P*W_C2V-1:0] r1_c2v1_q;
  logic r1_error_q;
  logic r1_q_error_w;

  logic [P*W_APP-1:0] r1_app0_check_w;
  logic [P*W_APP-1:0] r1_app1_check_w;

  logic r2_valid_q;
  logic [1:0] r2_lane_mask_q;
  logic [5:0] r2_layer_id_q;
  logic [4:0] r2_edge0_id_q;
  logic [4:0] r2_edge1_id_q;
  logic [0:0] r2_qbuf_q;
  logic [3:0] r2_qslot_q;
  logic [3:0] r2_iteration_epoch_q;
  logic [SHIFT_W-1:0] r2_shift0_q;
  logic [SHIFT_W-1:0] r2_shift1_q;
  logic [6:0] r2_base_column0_q;
  logic [6:0] r2_base_column1_q;
  logic [3:0] r2_aux0_q;
  logic [3:0] r2_aux1_q;
  logic r2_final_touch0_q;
  logic r2_final_touch1_q;
  logic [P*W_APP-1:0] r2_app0_check_q;
  logic [P*W_APP-1:0] r2_app1_check_q;
  logic r2_error_q;

  logic [P*W_APP-1:0] r2_app0_canonical_w;
  logic [P*W_APP-1:0] r2_app1_canonical_w;
  logic r2_shift0_error_w;
  logic r2_shift1_error_w;
  logic r2_error_w;

  logic pub_valid_q;
  logic [1:0] pub_lane_mask_q;
  logic [5:0] pub_layer_id_q;
  logic [4:0] pub_edge0_id_q;
  logic [4:0] pub_edge1_id_q;
  logic [0:0] pub_qbuf_q;
  logic [3:0] pub_qslot_q;
  logic [3:0] pub_iteration_epoch_q;
  logic [6:0] pub_base_column0_q;
  logic [6:0] pub_base_column1_q;
  logic [3:0] pub_aux0_q;
  logic [3:0] pub_aux1_q;
  logic pub_final_touch0_q;
  logic pub_final_touch1_q;
  logic [P*W_APP-1:0] pub_app0_q;
  logic [P*W_APP-1:0] pub_app1_q;
  logic pub_error_q;

  logic [P-1:0] hard0_w;
  logic [P-1:0] hard1_w;

  assign issue_ready_o = 1'b1;

  assign q_req_valid_o = r0_valid_q;
  assign q_req_qbuf_o = r0_qbuf_q;
  assign q_req_qslot_o = r0_qslot_q;
  assign q_req_lane_mask_o = r0_lane_mask_q;
  assign q_req_layer_id_o = r0_layer_id_q;
  assign q_req_iteration_epoch_o = r0_iteration_epoch_q;

  always @* begin
    r0_error_w = 1'b0;
    if (r0_valid_q) begin
      if (r0_lane_mask_q == 2'b00) begin
        r0_error_w = 1'b1;
      end
      if (!new_state_resp_valid_i || !new_state_valid_i || !new_state_closed_i) begin
        r0_error_w = 1'b1;
      end
      if (new_state_layer_id_i != r0_layer_id_q) begin
        r0_error_w = 1'b1;
      end
      if (new_state_generation_i != r0_target_generation_q) begin
        r0_error_w = 1'b1;
      end
      if (new_state_iteration_epoch_i != r0_iteration_epoch_q) begin
        r0_error_w = 1'b1;
      end
    end
  end

  nr_ldpc_compressed_c2v_reconstruct_vector #(
    .P(P)
  ) u_reconstruct0 (
    .m1_i(new_m1_i),
    .m2_i(new_m2_i),
    .imin_i(new_imin_i),
    .aggregate_sign_i(new_aggregate_sign_i),
    .q_sign_i(new_qsign0_i),
    .local_edge_id_i(r0_edge0_id_q),
    .c2v_o(r0_c2v0_w)
  );

  nr_ldpc_compressed_c2v_reconstruct_vector #(
    .P(P)
  ) u_reconstruct1 (
    .m1_i(new_m1_i),
    .m2_i(new_m2_i),
    .imin_i(new_imin_i),
    .aggregate_sign_i(new_aggregate_sign_i),
    .q_sign_i(new_qsign1_i),
    .local_edge_id_i(r0_edge1_id_q),
    .c2v_o(r0_c2v1_w)
  );

  always @* begin
    r1_q_error_w = r1_error_q;
    if (r1_valid_q) begin
      if (!q_resp_valid_i) begin
        r1_q_error_w = 1'b1;
      end
      if (q_resp_qbuf_i != r1_qbuf_q) begin
        r1_q_error_w = 1'b1;
      end
      if (q_resp_qslot_i != r1_qslot_q) begin
        r1_q_error_w = 1'b1;
      end
      if (q_resp_lane_mask_i != r1_lane_mask_q) begin
        r1_q_error_w = 1'b1;
      end
      if (q_resp_layer_id_i != r1_layer_id_q) begin
        r1_q_error_w = 1'b1;
      end
      if (q_resp_iteration_epoch_i != r1_iteration_epoch_q) begin
        r1_q_error_w = 1'b1;
      end
    end
  end

  genvar lane;
  generate
    for (lane = 0; lane < P; lane++) begin : gen_r1_app_add
      nr_ldpc_app_add u_app_add0 (
        .q_i(q_resp_lane0_i[lane*W_Q +: W_Q]),
        .new_c2v_i(r1_c2v0_q[lane*W_C2V +: W_C2V]),
        .app_o(r1_app0_check_w[lane*W_APP +: W_APP]),
        .raw_o()
      );

      nr_ldpc_app_add u_app_add1 (
        .q_i(q_resp_lane1_i[lane*W_Q +: W_Q]),
        .new_c2v_i(r1_c2v1_q[lane*W_C2V +: W_C2V]),
        .app_o(r1_app1_check_w[lane*W_APP +: W_APP]),
        .raw_o()
      );

      assign hard0_w[lane] = pub_app0_q[lane*W_APP + W_APP - 1];
      assign hard1_w[lane] = pub_app1_q[lane*W_APP + W_APP - 1];
    end
  endgenerate

  nr_ldpc_qc_inverse #(
    .P(P),
    .LANE_W(W_APP)
  ) u_qc_inverse0 (
    .check_i(r2_app0_check_q),
    .shift_i(r2_shift0_q),
    .canonical_o(r2_app0_canonical_w),
    .illegal_shift_o(r2_shift0_error_w)
  );

  nr_ldpc_qc_inverse #(
    .P(P),
    .LANE_W(W_APP)
  ) u_qc_inverse1 (
    .check_i(r2_app1_check_q),
    .shift_i(r2_shift1_q),
    .canonical_o(r2_app1_canonical_w),
    .illegal_shift_o(r2_shift1_error_w)
  );

  assign r2_error_w = r2_error_q
      || (r2_valid_q && r2_lane_mask_q[0] && r2_shift0_error_w)
      || (r2_valid_q && r2_lane_mask_q[1] && r2_shift1_error_w);

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      r0_valid_q <= 1'b0;
      r1_valid_q <= 1'b0;
      r2_valid_q <= 1'b0;
      pub_valid_q <= 1'b0;
      pub_error_q <= 1'b0;
    end else begin
      r0_valid_q <= issue_valid_i && issue_ready_o;
      r0_lane_mask_q <= issue_lane_mask_i;
      r0_layer_id_q <= issue_layer_id_i;
      r0_edge0_id_q <= issue_edge0_id_i;
      r0_edge1_id_q <= issue_edge1_id_i;
      r0_qbuf_q <= issue_qbuf_i;
      r0_qslot_q <= issue_qslot_i;
      r0_target_generation_q <= issue_target_generation_i;
      r0_iteration_epoch_q <= issue_iteration_epoch_i;
      r0_shift0_q <= issue_shift0_i;
      r0_shift1_q <= issue_shift1_i;
      r0_base_column0_q <= issue_base_column0_i;
      r0_base_column1_q <= issue_base_column1_i;
      r0_aux0_q <= issue_aux0_i;
      r0_aux1_q <= issue_aux1_i;
      r0_final_touch0_q <= issue_final_touch0_i;
      r0_final_touch1_q <= issue_final_touch1_i;

      r1_valid_q <= r0_valid_q;
      r1_lane_mask_q <= r0_lane_mask_q;
      r1_layer_id_q <= r0_layer_id_q;
      r1_edge0_id_q <= r0_edge0_id_q;
      r1_edge1_id_q <= r0_edge1_id_q;
      r1_qbuf_q <= r0_qbuf_q;
      r1_qslot_q <= r0_qslot_q;
      r1_iteration_epoch_q <= r0_iteration_epoch_q;
      r1_shift0_q <= r0_shift0_q;
      r1_shift1_q <= r0_shift1_q;
      r1_base_column0_q <= r0_base_column0_q;
      r1_base_column1_q <= r0_base_column1_q;
      r1_aux0_q <= r0_aux0_q;
      r1_aux1_q <= r0_aux1_q;
      r1_final_touch0_q <= r0_final_touch0_q;
      r1_final_touch1_q <= r0_final_touch1_q;
      r1_c2v0_q <= r0_c2v0_w;
      r1_c2v1_q <= r0_c2v1_w;
      r1_error_q <= r0_error_w;

      r2_valid_q <= r1_valid_q;
      r2_lane_mask_q <= r1_lane_mask_q;
      r2_layer_id_q <= r1_layer_id_q;
      r2_edge0_id_q <= r1_edge0_id_q;
      r2_edge1_id_q <= r1_edge1_id_q;
      r2_qbuf_q <= r1_qbuf_q;
      r2_qslot_q <= r1_qslot_q;
      r2_iteration_epoch_q <= r1_iteration_epoch_q;
      r2_shift0_q <= r1_shift0_q;
      r2_shift1_q <= r1_shift1_q;
      r2_base_column0_q <= r1_base_column0_q;
      r2_base_column1_q <= r1_base_column1_q;
      r2_aux0_q <= r1_aux0_q;
      r2_aux1_q <= r1_aux1_q;
      r2_final_touch0_q <= r1_final_touch0_q;
      r2_final_touch1_q <= r1_final_touch1_q;
      r2_app0_check_q <= r1_app0_check_w;
      r2_app1_check_q <= r1_app1_check_w;
      r2_error_q <= r1_q_error_w;

      pub_valid_q <= r2_valid_q;
      pub_lane_mask_q <= r2_lane_mask_q;
      pub_layer_id_q <= r2_layer_id_q;
      pub_edge0_id_q <= r2_edge0_id_q;
      pub_edge1_id_q <= r2_edge1_id_q;
      pub_qbuf_q <= r2_qbuf_q;
      pub_qslot_q <= r2_qslot_q;
      pub_iteration_epoch_q <= r2_iteration_epoch_q;
      pub_base_column0_q <= r2_base_column0_q;
      pub_base_column1_q <= r2_base_column1_q;
      pub_aux0_q <= r2_aux0_q;
      pub_aux1_q <= r2_aux1_q;
      pub_final_touch0_q <= r2_final_touch0_q;
      pub_final_touch1_q <= r2_final_touch1_q;
      pub_app0_q <= r2_app0_canonical_w;
      pub_app1_q <= r2_app1_canonical_w;
      pub_error_q <= r2_error_w;
    end
  end

  assign app_write_valid_o[0] = pub_valid_q && !pub_error_q && pub_lane_mask_q[0];
  assign app_write_valid_o[1] = pub_valid_q && !pub_error_q && pub_lane_mask_q[1];
  assign app_write_lane0_o = pub_app0_q;
  assign app_write_lane1_o = pub_app1_q;
  assign app_write_base_column0_o = pub_base_column0_q;
  assign app_write_base_column1_o = pub_base_column1_q;
  assign app_write_lane_mask_o = pub_lane_mask_q;
  assign app_write_layer_id_o = pub_layer_id_q;
  assign app_write_edge0_id_o = pub_edge0_id_q;
  assign app_write_edge1_id_o = pub_edge1_id_q;
  assign app_write_iteration_epoch_o = pub_iteration_epoch_q;
  assign app_write_qbuf_o = pub_qbuf_q;
  assign app_write_qslot_o = pub_qslot_q;
  assign app_write_aux0_o = pub_aux0_q;
  assign app_write_aux1_o = pub_aux1_q;
  assign app_write_final_touch0_o = pub_final_touch0_q;
  assign app_write_final_touch1_o = pub_final_touch1_q;

  assign forward_candidate_valid_o[0] = r2_valid_q && !r2_error_w && r2_lane_mask_q[0];
  assign forward_candidate_valid_o[1] = r2_valid_q && !r2_error_w && r2_lane_mask_q[1];
  assign forward_candidate_lane0_o = r2_app0_canonical_w;
  assign forward_candidate_lane1_o = r2_app1_canonical_w;
  assign forward_candidate_base_column0_o = r2_base_column0_q;
  assign forward_candidate_base_column1_o = r2_base_column1_q;
  assign forward_candidate_iteration_epoch_o = r2_iteration_epoch_q;
  assign forward_candidate_aux0_o = r2_aux0_q;
  assign forward_candidate_aux1_o = r2_aux1_q;

  assign forward_valid_o[0] = app_write_valid_o[0] && (pub_aux0_q != 4'd0);
  assign forward_valid_o[1] = app_write_valid_o[1] && (pub_aux1_q != 4'd0);
  assign forward_slot0_o = pub_aux0_q[2:0] - 3'd1;
  assign forward_slot1_o = pub_aux1_q[2:0] - 3'd1;
  assign forward_base_column0_o = pub_base_column0_q;
  assign forward_base_column1_o = pub_base_column1_q;
  assign forward_iteration_epoch_o = pub_iteration_epoch_q;
  assign forward_app0_o = pub_app0_q;
  assign forward_app1_o = pub_app1_q;

  assign final_touch_valid_o[0] = app_write_valid_o[0] && pub_final_touch0_q;
  assign final_touch_valid_o[1] = app_write_valid_o[1] && pub_final_touch1_q;
  assign final_touch_base_column0_o = pub_base_column0_q;
  assign final_touch_base_column1_o = pub_base_column1_q;
  assign final_touch_layer_id_o = pub_layer_id_q;
  assign final_touch_edge0_id_o = pub_edge0_id_q;
  assign final_touch_edge1_id_o = pub_edge1_id_q;
  assign final_touch_iteration_epoch_o = pub_iteration_epoch_q;
  assign final_touch_app0_o = pub_app0_q;
  assign final_touch_app1_o = pub_app1_q;
  assign final_touch_hard0_o = hard0_w;
  assign final_touch_hard1_o = hard1_w;

  assign error_valid_o = pub_valid_q && pub_error_q;
endmodule

`endif
