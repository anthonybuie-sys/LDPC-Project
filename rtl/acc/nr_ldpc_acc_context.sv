`ifndef NR_LDPC_ACC_CONTEXT_SV
`define NR_LDPC_ACC_CONTEXT_SV

module nr_ldpc_acc_context #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic                 clk_i,
  input  logic                 rst_i,

  input  logic                 valid_i,
  input  logic                 upstream_error_i,
  input  logic [1:0]           lane_mask_i,
  input  logic [5:0]           layer_id_i,
  input  logic [5:0]           layer_degree_i,
  input  logic                 start_layer_i,
  input  logic [4:0]           edge0_id_i,
  input  logic [4:0]           edge1_id_i,
  input  logic                 target_generation_i,
  input  logic [3:0]           iteration_epoch_i,
  input  logic [P*6-1:0]       q_mag0_i,
  input  logic [P*6-1:0]       q_mag1_i,
  input  logic [P-1:0]         q_sign0_i,
  input  logic [P-1:0]         q_sign1_i,

  output logic                 open_o,
  output logic                 update_error_o,

  output logic                 error_valid_o,
  output logic                 close_valid_o,
  output logic [5:0]           close_layer_id_o,
  output logic                 close_target_generation_o,
  output logic [3:0]           close_iteration_epoch_o,
  output logic [5:0]           close_edge_count_o,
  output logic [P*6-1:0]       close_m1_offset_o,
  output logic [P*6-1:0]       close_m2_offset_o,
  output logic [P*5-1:0]       close_imin_o,
  output logic [P-1:0]         close_aggregate_sign_o
);
  import nr_ldpc_pkg::*;

  localparam logic [5:0] MIN_SUPPORTED_DEGREE = 6'd2;

  logic open_q;
  logic [5:0] layer_id_q;
  logic [5:0] edge_count_q;
  logic [P*W_M-1:0] min1_q;
  logic [P*W_M-1:0] min2_q;
  logic [P*5-1:0] imin_q;
  logic [P-1:0] aggregate_sign_q;

  logic [5:0] active_count;
  logic [5:0] effective_edge_count;
  logic [5:0] edge_count_new;
  logic local_error;
  logic close_w;

  logic [P*W_M-1:0] next_min1;
  logic [P*W_M-1:0] next_min2;
  logic [P*5-1:0] next_imin;
  logic [P-1:0] next_aggregate_sign;
  logic [P*W_M-1:0] next_m1_offset;
  logic [P*W_M-1:0] next_m2_offset;
  logic [P*W_M-1:0] effective_min1;
  logic [P*W_M-1:0] effective_min2;
  logic [P*5-1:0] effective_imin;
  logic [P-1:0] effective_aggregate_sign;

  assign open_o = open_q;
  assign active_count = {5'd0, lane_mask_i[0]} + {5'd0, lane_mask_i[1]};
  assign effective_edge_count = start_layer_i ? 6'd0 : edge_count_q;
  assign edge_count_new = effective_edge_count + active_count;
  assign effective_min1 = start_layer_i ? '0 : min1_q;
  assign effective_min2 = start_layer_i ? '0 : min2_q;
  assign effective_imin = start_layer_i ? '0 : imin_q;
  assign effective_aggregate_sign = start_layer_i ? '0 : aggregate_sign_q;

  always @* begin
    local_error = 1'b0;

    if (valid_i) begin
      if (active_count == 6'd0) begin
        local_error = 1'b1;
      end

      if (start_layer_i && open_q) begin
        local_error = 1'b1;
      end

      if (!start_layer_i && !open_q) begin
        local_error = 1'b1;
      end

      if (!start_layer_i && open_q && (layer_id_q != layer_id_i)) begin
        local_error = 1'b1;
      end

      if (edge_count_new > layer_degree_i) begin
        local_error = 1'b1;
      end

      if ((edge_count_new == layer_degree_i) && (layer_degree_i < MIN_SUPPORTED_DEGREE)) begin
        local_error = 1'b1;
      end
    end
  end

  assign update_error_o = valid_i && (upstream_error_i || local_error);
  assign close_w = valid_i && !upstream_error_i && !local_error && (edge_count_new == layer_degree_i);

  genvar lane;
  generate
    for (lane = 0; lane < P; lane++) begin : gen_lane_update
      nr_ldpc_acc_min_update u_update (
        .edge_count_i(effective_edge_count),
        .min1_i(effective_min1[lane*W_M +: W_M]),
        .min2_i(effective_min2[lane*W_M +: W_M]),
        .imin_i(effective_imin[lane*5 +: 5]),
        .aggregate_sign_i(effective_aggregate_sign[lane]),
        .cand0_valid_i(valid_i && lane_mask_i[0]),
        .cand0_mag_i(q_mag0_i[lane*W_M +: W_M]),
        .cand0_edge_id_i(edge0_id_i),
        .cand0_sign_i(q_sign0_i[lane]),
        .cand1_valid_i(valid_i && lane_mask_i[1]),
        .cand1_mag_i(q_mag1_i[lane*W_M +: W_M]),
        .cand1_edge_id_i(edge1_id_i),
        .cand1_sign_i(q_sign1_i[lane]),
        .edge_count_o(),
        .min1_o(next_min1[lane*W_M +: W_M]),
        .min2_o(next_min2[lane*W_M +: W_M]),
        .imin_o(next_imin[lane*5 +: 5]),
        .aggregate_sign_o(next_aggregate_sign[lane])
      );

      nr_ldpc_beta_sub u_beta_m1 (
        .raw_mag_i(next_min1[lane*W_M +: W_M]),
        .offset_mag_o(next_m1_offset[lane*W_M +: W_M])
      );

      nr_ldpc_beta_sub u_beta_m2 (
        .raw_mag_i(next_min2[lane*W_M +: W_M]),
        .offset_mag_o(next_m2_offset[lane*W_M +: W_M])
      );
    end
  endgenerate

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      open_q <= 1'b0;
      layer_id_q <= 6'd0;
      edge_count_q <= 6'd0;
      error_valid_o <= 1'b0;
      close_valid_o <= 1'b0;
      close_layer_id_o <= 6'd0;
      close_target_generation_o <= 1'b0;
      close_iteration_epoch_o <= 4'd0;
      close_edge_count_o <= 6'd0;
      close_m1_offset_o <= '0;
      close_m2_offset_o <= '0;
      close_imin_o <= '0;
      close_aggregate_sign_o <= '0;
    end else begin
      error_valid_o <= update_error_o;
      close_valid_o <= close_w;
      close_layer_id_o <= layer_id_i;
      close_target_generation_o <= target_generation_i;
      close_iteration_epoch_o <= iteration_epoch_i;
      close_edge_count_o <= edge_count_new;
      close_m1_offset_o <= close_w ? next_m1_offset : '0;
      close_m2_offset_o <= close_w ? next_m2_offset : '0;
      close_imin_o <= close_w ? next_imin : '0;
      close_aggregate_sign_o <= close_w ? next_aggregate_sign : '0;

      if (valid_i && !upstream_error_i && !local_error) begin
        if (close_w) begin
          open_q <= 1'b0;
          layer_id_q <= 6'd0;
          edge_count_q <= 6'd0;
        end else begin
          open_q <= 1'b1;
          layer_id_q <= layer_id_i;
          edge_count_q <= edge_count_new;
          min1_q <= next_min1;
          min2_q <= next_min2;
          imin_q <= next_imin;
          aggregate_sign_q <= next_aggregate_sign;
        end
      end
    end
  end
endmodule

`endif
