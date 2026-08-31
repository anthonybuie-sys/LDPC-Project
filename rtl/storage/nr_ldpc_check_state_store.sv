`ifndef NR_LDPC_CHECK_STATE_STORE_SV
`define NR_LDPC_CHECK_STATE_STORE_SV

module nr_ldpc_check_state_store #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z,
  parameter int MAX_LAYERS = 64,
  parameter int MAX_EDGES = 32
) (
  input  logic                         clk_i,
  input  logic                         rst_i,
  input  logic                         start_block_i,
  input  logic                         advance_iteration_i,

  output logic                         old_generation_o,
  output logic                         new_generation_o,

  input  logic                         acc_old_req_valid_i,
  input  logic [1:0]                   acc_old_req_lane_mask_i,
  input  logic [5:0]                   acc_old_req_layer_id_i,
  input  logic [4:0]                   acc_old_req_edge0_id_i,
  input  logic [4:0]                   acc_old_req_edge1_id_i,
  input  logic [3:0]                   acc_old_req_iteration_epoch_i,

  output logic                         acc_old_resp_valid_o,
  output logic                         acc_old_generation_valid_o,
  output logic [P*6-1:0]               acc_old_m1_o,
  output logic [P*6-1:0]               acc_old_m2_o,
  output logic [P*5-1:0]               acc_old_imin_o,
  output logic [P-1:0]                 acc_old_aggregate_sign_o,
  output logic [P-1:0]                 acc_old_qsign0_o,
  output logic [P-1:0]                 acc_old_qsign1_o,
  output logic [5:0]                   acc_old_resp_layer_id_o,
  output logic [3:0]                   acc_old_resp_iteration_epoch_o,
  output logic                         acc_old_resp_metadata_error_o,

  input  logic [1:0]                   qsign_write_valid_i,
  input  logic [4:0]                   qsign_write_edge0_id_i,
  input  logic [4:0]                   qsign_write_edge1_id_i,
  input  logic [P-1:0]                 qsign_write_lane0_i,
  input  logic [P-1:0]                 qsign_write_lane1_i,
  input  logic [5:0]                   qsign_write_layer_id_i,
  input  logic                         qsign_write_target_generation_i,
  input  logic [3:0]                   qsign_write_iteration_epoch_i,

  input  logic                         layer_close_valid_i,
  input  logic [5:0]                   layer_close_layer_id_i,
  input  logic                         layer_close_target_generation_i,
  input  logic [3:0]                   layer_close_iteration_epoch_i,
  input  logic [P*6-1:0]               layer_close_m1_i,
  input  logic [P*6-1:0]               layer_close_m2_i,
  input  logic [P*5-1:0]               layer_close_imin_i,
  input  logic [P-1:0]                 layer_close_aggregate_sign_i,

  input  logic                         rec_new_req_valid_i,
  input  logic [1:0]                   rec_new_req_lane_mask_i,
  input  logic [5:0]                   rec_new_req_layer_id_i,
  input  logic [4:0]                   rec_new_req_edge0_id_i,
  input  logic [4:0]                   rec_new_req_edge1_id_i,
  input  logic                         rec_new_req_generation_i,
  input  logic [3:0]                   rec_new_req_iteration_epoch_i,

  output logic                         rec_new_resp_valid_o,
  output logic                         rec_new_state_valid_o,
  output logic                         rec_new_state_closed_o,
  output logic [5:0]                   rec_new_state_layer_id_o,
  output logic                         rec_new_state_generation_o,
  output logic [3:0]                   rec_new_state_iteration_epoch_o,
  output logic [P*6-1:0]               rec_new_m1_o,
  output logic [P*6-1:0]               rec_new_m2_o,
  output logic [P*5-1:0]               rec_new_imin_o,
  output logic [P-1:0]                 rec_new_aggregate_sign_o,
  output logic [P-1:0]                 rec_new_qsign0_o,
  output logic [P-1:0]                 rec_new_qsign1_o,

  output logic                         error_valid_o,
  output logic [7:0]                   error_code_o
);
  import nr_ldpc_pkg::*;

  localparam int TOTAL_LAYER_STATES = 2 * MAX_LAYERS;
  localparam int TOTAL_QSIGN_STATES = 2 * MAX_LAYERS * MAX_EDGES;

  localparam logic [7:0] ERR_NONE = 8'd0;
  localparam logic [7:0] ERR_QSIGN_GENERATION = 8'd1;
  localparam logic [7:0] ERR_CLOSE_GENERATION = 8'd2;
  localparam logic [7:0] ERR_OLD_EPOCH = 8'd3;
  localparam logic [7:0] ERR_OLD_QSIGN = 8'd4;
  localparam logic [7:0] ERR_REC_GENERATION = 8'd5;
  localparam logic [7:0] ERR_REC_NOT_CLOSED = 8'd6;
  localparam logic [7:0] ERR_REC_EPOCH = 8'd7;
  localparam logic [7:0] ERR_REC_QSIGN = 8'd8;

  logic old_generation_q;
  logic new_generation_q;

  logic [P*W_M-1:0] m1_mem [0:TOTAL_LAYER_STATES-1];
  logic [P*W_M-1:0] m2_mem [0:TOTAL_LAYER_STATES-1];
  logic [P*5-1:0] imin_mem [0:TOTAL_LAYER_STATES-1];
  logic [P-1:0] aggregate_mem [0:TOTAL_LAYER_STATES-1];
  logic layer_valid_q [0:TOTAL_LAYER_STATES-1];
  logic layer_closed_q [0:TOTAL_LAYER_STATES-1];
  logic [3:0] layer_epoch_q [0:TOTAL_LAYER_STATES-1];

  logic [P-1:0] qsign_mem [0:TOTAL_QSIGN_STATES-1];
  logic qsign_valid_q [0:TOTAL_QSIGN_STATES-1];
  logic [3:0] qsign_epoch_q [0:TOTAL_QSIGN_STATES-1];

  logic [6:0] acc_old_layer_idx_w;
  logic [11:0] acc_old_edge0_idx_w;
  logic [11:0] acc_old_edge1_idx_w;
  logic old_layer_present_w;
  logic old_epoch_match_w;
  logic old_qsign0_present_w;
  logic old_qsign1_present_w;
  logic old_metadata_error_w;

  logic [6:0] rec_layer_idx_w;
  logic [11:0] rec_edge0_idx_w;
  logic [11:0] rec_edge1_idx_w;
  logic rec_close_bypass_w;
  logic rec_layer_valid_w;
  logic rec_layer_closed_w;
  logic rec_epoch_match_w;
  logic rec_qsign0_present_w;
  logic rec_qsign1_present_w;
  logic rec_error_w;
  logic [7:0] rec_error_code_w;

  logic qsign_write_error_w;
  logic close_error_w;
  logic old_error_q;
  logic [7:0] old_error_code_q;

  function automatic logic [6:0] layer_index(input logic generation, input logic [5:0] layer_id);
    begin
      layer_index = (generation ? 7'(MAX_LAYERS) : 7'd0) + {1'b0, layer_id};
    end
  endfunction

  function automatic logic [11:0] qsign_index(
    input logic generation,
    input logic [5:0] layer_id,
    input logic [4:0] edge_id
  );
    begin
      qsign_index = (generation ? 12'(MAX_LAYERS * MAX_EDGES) : 12'd0)
          + ({6'd0, layer_id} * 12'(MAX_EDGES))
          + {7'd0, edge_id};
    end
  endfunction

  assign old_generation_o = old_generation_q;
  assign new_generation_o = new_generation_q;

  assign acc_old_layer_idx_w = layer_index(old_generation_q, acc_old_req_layer_id_i);
  assign acc_old_edge0_idx_w = qsign_index(old_generation_q, acc_old_req_layer_id_i, acc_old_req_edge0_id_i);
  assign acc_old_edge1_idx_w = qsign_index(old_generation_q, acc_old_req_layer_id_i, acc_old_req_edge1_id_i);
  assign old_layer_present_w = layer_valid_q[acc_old_layer_idx_w] && layer_closed_q[acc_old_layer_idx_w];
  assign old_epoch_match_w = old_layer_present_w
      && (layer_epoch_q[acc_old_layer_idx_w] == acc_old_req_iteration_epoch_i);
  assign old_qsign0_present_w = !acc_old_req_lane_mask_i[0]
      || (qsign_valid_q[acc_old_edge0_idx_w]
          && (qsign_epoch_q[acc_old_edge0_idx_w] == acc_old_req_iteration_epoch_i));
  assign old_qsign1_present_w = !acc_old_req_lane_mask_i[1]
      || (qsign_valid_q[acc_old_edge1_idx_w]
          && (qsign_epoch_q[acc_old_edge1_idx_w] == acc_old_req_iteration_epoch_i));
  assign old_metadata_error_w = acc_old_req_valid_i && old_layer_present_w
      && (!old_epoch_match_w || !old_qsign0_present_w || !old_qsign1_present_w);

  assign qsign_write_error_w = (|qsign_write_valid_i)
      && (qsign_write_target_generation_i != new_generation_q);
  assign close_error_w = layer_close_valid_i
      && (layer_close_target_generation_i != new_generation_q);

  assign rec_layer_idx_w = layer_index(new_generation_q, rec_new_req_layer_id_i);
  assign rec_edge0_idx_w = qsign_index(new_generation_q, rec_new_req_layer_id_i, rec_new_req_edge0_id_i);
  assign rec_edge1_idx_w = qsign_index(new_generation_q, rec_new_req_layer_id_i, rec_new_req_edge1_id_i);
  assign rec_close_bypass_w = layer_close_valid_i
      && (layer_close_target_generation_i == new_generation_q)
      && (layer_close_layer_id_i == rec_new_req_layer_id_i)
      && (layer_close_iteration_epoch_i == rec_new_req_iteration_epoch_i);
  assign rec_layer_valid_w = rec_close_bypass_w || layer_valid_q[rec_layer_idx_w];
  assign rec_layer_closed_w = rec_close_bypass_w || layer_closed_q[rec_layer_idx_w];
  assign rec_epoch_match_w = rec_close_bypass_w
      || (layer_epoch_q[rec_layer_idx_w] == rec_new_req_iteration_epoch_i);

  always @* begin
    rec_new_qsign0_o = qsign_mem[rec_edge0_idx_w];
    rec_new_qsign1_o = qsign_mem[rec_edge1_idx_w];
    rec_qsign0_present_w = !rec_new_req_lane_mask_i[0]
        || (qsign_valid_q[rec_edge0_idx_w]
            && (qsign_epoch_q[rec_edge0_idx_w] == rec_new_req_iteration_epoch_i));
    rec_qsign1_present_w = !rec_new_req_lane_mask_i[1]
        || (qsign_valid_q[rec_edge1_idx_w]
            && (qsign_epoch_q[rec_edge1_idx_w] == rec_new_req_iteration_epoch_i));

    if (qsign_write_valid_i[0]
        && (qsign_write_target_generation_i == new_generation_q)
        && (qsign_write_layer_id_i == rec_new_req_layer_id_i)
        && (qsign_write_edge0_id_i == rec_new_req_edge0_id_i)
        && (qsign_write_iteration_epoch_i == rec_new_req_iteration_epoch_i)) begin
      rec_new_qsign0_o = qsign_write_lane0_i;
      rec_qsign0_present_w = 1'b1;
    end
    if (qsign_write_valid_i[1]
        && (qsign_write_target_generation_i == new_generation_q)
        && (qsign_write_layer_id_i == rec_new_req_layer_id_i)
        && (qsign_write_edge1_id_i == rec_new_req_edge0_id_i)
        && (qsign_write_iteration_epoch_i == rec_new_req_iteration_epoch_i)) begin
      rec_new_qsign0_o = qsign_write_lane1_i;
      rec_qsign0_present_w = 1'b1;
    end

    if (qsign_write_valid_i[0]
        && (qsign_write_target_generation_i == new_generation_q)
        && (qsign_write_layer_id_i == rec_new_req_layer_id_i)
        && (qsign_write_edge0_id_i == rec_new_req_edge1_id_i)
        && (qsign_write_iteration_epoch_i == rec_new_req_iteration_epoch_i)) begin
      rec_new_qsign1_o = qsign_write_lane0_i;
      rec_qsign1_present_w = 1'b1;
    end
    if (qsign_write_valid_i[1]
        && (qsign_write_target_generation_i == new_generation_q)
        && (qsign_write_layer_id_i == rec_new_req_layer_id_i)
        && (qsign_write_edge1_id_i == rec_new_req_edge1_id_i)
        && (qsign_write_iteration_epoch_i == rec_new_req_iteration_epoch_i)) begin
      rec_new_qsign1_o = qsign_write_lane1_i;
      rec_qsign1_present_w = 1'b1;
    end
  end

  always @* begin
    rec_error_w = 1'b0;
    rec_error_code_w = ERR_NONE;
    if (rec_new_req_valid_i) begin
      if (rec_new_req_generation_i != new_generation_q) begin
        rec_error_w = 1'b1;
        rec_error_code_w = ERR_REC_GENERATION;
      end else if (!rec_layer_valid_w || !rec_layer_closed_w) begin
        rec_error_w = 1'b1;
        rec_error_code_w = ERR_REC_NOT_CLOSED;
      end else if (!rec_epoch_match_w) begin
        rec_error_w = 1'b1;
        rec_error_code_w = ERR_REC_EPOCH;
      end else if (!rec_qsign0_present_w || !rec_qsign1_present_w) begin
        rec_error_w = 1'b1;
        rec_error_code_w = ERR_REC_QSIGN;
      end
    end
  end

  assign rec_new_resp_valid_o = rec_new_req_valid_i && !rec_error_w;
  assign rec_new_state_valid_o = rec_new_req_valid_i && rec_layer_valid_w && !rec_error_w;
  assign rec_new_state_closed_o = rec_new_req_valid_i && rec_layer_closed_w && !rec_error_w;
  assign rec_new_state_layer_id_o = rec_new_req_layer_id_i;
  assign rec_new_state_generation_o = new_generation_q;
  assign rec_new_state_iteration_epoch_o = rec_new_req_iteration_epoch_i;
  assign rec_new_m1_o = rec_close_bypass_w ? layer_close_m1_i : m1_mem[rec_layer_idx_w];
  assign rec_new_m2_o = rec_close_bypass_w ? layer_close_m2_i : m2_mem[rec_layer_idx_w];
  assign rec_new_imin_o = rec_close_bypass_w ? layer_close_imin_i : imin_mem[rec_layer_idx_w];
  assign rec_new_aggregate_sign_o = rec_close_bypass_w
      ? layer_close_aggregate_sign_i
      : aggregate_mem[rec_layer_idx_w];

  integer idx;
  integer layer_idx;
  integer edge_idx;
  always_ff @(posedge clk_i) begin
    if (rst_i || start_block_i) begin
      old_generation_q <= 1'b0;
      new_generation_q <= 1'b1;
      for (idx = 0; idx < TOTAL_LAYER_STATES; idx++) begin
        layer_valid_q[idx] <= 1'b0;
        layer_closed_q[idx] <= 1'b0;
        layer_epoch_q[idx] <= 4'd0;
      end
      for (idx = 0; idx < TOTAL_QSIGN_STATES; idx++) begin
        qsign_valid_q[idx] <= 1'b0;
        qsign_epoch_q[idx] <= 4'd0;
      end
      acc_old_resp_valid_o <= 1'b0;
      acc_old_generation_valid_o <= 1'b0;
      acc_old_m1_o <= '0;
      acc_old_m2_o <= '0;
      acc_old_imin_o <= '0;
      acc_old_aggregate_sign_o <= '0;
      acc_old_qsign0_o <= '0;
      acc_old_qsign1_o <= '0;
      acc_old_resp_layer_id_o <= 6'd0;
      acc_old_resp_iteration_epoch_o <= 4'd0;
      acc_old_resp_metadata_error_o <= 1'b0;
      old_error_q <= 1'b0;
      old_error_code_q <= ERR_NONE;
      error_valid_o <= 1'b0;
      error_code_o <= ERR_NONE;
    end else if (advance_iteration_i) begin
      old_generation_q <= new_generation_q;
      new_generation_q <= old_generation_q;
      for (layer_idx = 0; layer_idx < MAX_LAYERS; layer_idx++) begin
        layer_valid_q[layer_index(old_generation_q, layer_idx[5:0])] <= 1'b0;
        layer_closed_q[layer_index(old_generation_q, layer_idx[5:0])] <= 1'b0;
        layer_epoch_q[layer_index(old_generation_q, layer_idx[5:0])] <= 4'd0;
      end
      for (edge_idx = 0; edge_idx < (MAX_LAYERS * MAX_EDGES); edge_idx++) begin
        qsign_valid_q[(old_generation_q ? (MAX_LAYERS * MAX_EDGES) : 0) + edge_idx] <= 1'b0;
        qsign_epoch_q[(old_generation_q ? (MAX_LAYERS * MAX_EDGES) : 0) + edge_idx] <= 4'd0;
      end
      acc_old_resp_valid_o <= 1'b0;
      old_error_q <= 1'b0;
      old_error_code_q <= ERR_NONE;
      error_valid_o <= 1'b0;
      error_code_o <= ERR_NONE;
    end else begin
      old_error_q <= old_metadata_error_w;
      if (old_metadata_error_w && !old_epoch_match_w) begin
        old_error_code_q <= ERR_OLD_EPOCH;
      end else if (old_metadata_error_w) begin
        old_error_code_q <= ERR_OLD_QSIGN;
      end else begin
        old_error_code_q <= ERR_NONE;
      end

      acc_old_resp_valid_o <= acc_old_req_valid_i;
      acc_old_generation_valid_o <= acc_old_req_valid_i && old_layer_present_w && old_epoch_match_w && !old_metadata_error_w;
      acc_old_m1_o <= (old_layer_present_w && old_epoch_match_w) ? m1_mem[acc_old_layer_idx_w] : '0;
      acc_old_m2_o <= (old_layer_present_w && old_epoch_match_w) ? m2_mem[acc_old_layer_idx_w] : '0;
      acc_old_imin_o <= (old_layer_present_w && old_epoch_match_w) ? imin_mem[acc_old_layer_idx_w] : '0;
      acc_old_aggregate_sign_o <= (old_layer_present_w && old_epoch_match_w) ? aggregate_mem[acc_old_layer_idx_w] : '0;
      acc_old_qsign0_o <= (old_layer_present_w && old_epoch_match_w && old_qsign0_present_w)
          ? qsign_mem[acc_old_edge0_idx_w]
          : '0;
      acc_old_qsign1_o <= (old_layer_present_w && old_epoch_match_w && old_qsign1_present_w)
          ? qsign_mem[acc_old_edge1_idx_w]
          : '0;
      acc_old_resp_layer_id_o <= acc_old_req_layer_id_i;
      acc_old_resp_iteration_epoch_o <= acc_old_req_iteration_epoch_i;
      acc_old_resp_metadata_error_o <= old_metadata_error_w;

      error_valid_o <= qsign_write_error_w || close_error_w || old_error_q || rec_error_w;
      if (qsign_write_error_w) begin
        error_code_o <= ERR_QSIGN_GENERATION;
      end else if (close_error_w) begin
        error_code_o <= ERR_CLOSE_GENERATION;
      end else if (old_error_q) begin
        error_code_o <= old_error_code_q;
      end else if (rec_error_w) begin
        error_code_o <= rec_error_code_w;
      end else begin
        error_code_o <= ERR_NONE;
      end

      if (qsign_write_valid_i[0] && !qsign_write_error_w) begin
        qsign_mem[qsign_index(qsign_write_target_generation_i, qsign_write_layer_id_i, qsign_write_edge0_id_i)] <= qsign_write_lane0_i;
        qsign_valid_q[qsign_index(qsign_write_target_generation_i, qsign_write_layer_id_i, qsign_write_edge0_id_i)] <= 1'b1;
        qsign_epoch_q[qsign_index(qsign_write_target_generation_i, qsign_write_layer_id_i, qsign_write_edge0_id_i)] <= qsign_write_iteration_epoch_i;
      end
      if (qsign_write_valid_i[1] && !qsign_write_error_w) begin
        qsign_mem[qsign_index(qsign_write_target_generation_i, qsign_write_layer_id_i, qsign_write_edge1_id_i)] <= qsign_write_lane1_i;
        qsign_valid_q[qsign_index(qsign_write_target_generation_i, qsign_write_layer_id_i, qsign_write_edge1_id_i)] <= 1'b1;
        qsign_epoch_q[qsign_index(qsign_write_target_generation_i, qsign_write_layer_id_i, qsign_write_edge1_id_i)] <= qsign_write_iteration_epoch_i;
      end

      if (layer_close_valid_i && !close_error_w) begin
        m1_mem[layer_index(layer_close_target_generation_i, layer_close_layer_id_i)] <= layer_close_m1_i;
        m2_mem[layer_index(layer_close_target_generation_i, layer_close_layer_id_i)] <= layer_close_m2_i;
        imin_mem[layer_index(layer_close_target_generation_i, layer_close_layer_id_i)] <= layer_close_imin_i;
        aggregate_mem[layer_index(layer_close_target_generation_i, layer_close_layer_id_i)] <= layer_close_aggregate_sign_i;
        layer_valid_q[layer_index(layer_close_target_generation_i, layer_close_layer_id_i)] <= 1'b1;
        layer_closed_q[layer_index(layer_close_target_generation_i, layer_close_layer_id_i)] <= 1'b1;
        layer_epoch_q[layer_index(layer_close_target_generation_i, layer_close_layer_id_i)] <= layer_close_iteration_epoch_i;
      end
    end
  end
endmodule

`endif
