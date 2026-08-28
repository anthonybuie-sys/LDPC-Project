`ifndef NR_LDPC_Q_SCRATCH_SV
`define NR_LDPC_Q_SCRATCH_SV

module nr_ldpc_q_scratch #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic                         clk_i,
  input  logic                         rst_i,
  input  logic                         start_block_i,
  input  logic                         advance_iteration_i,

  input  logic                         write_valid_i,
  input  logic [0:0]                   write_qbuf_i,
  input  logic [3:0]                   write_qslot_i,
  input  logic [1:0]                   write_lane_mask_i,
  input  logic [P*8-1:0]               write_lane0_i,
  input  logic [P*8-1:0]               write_lane1_i,
  input  logic [5:0]                   write_layer_id_i,
  input  logic [3:0]                   write_iteration_epoch_i,

  input  logic                         read_req_valid_i,
  input  logic [0:0]                   read_req_qbuf_i,
  input  logic [3:0]                   read_req_qslot_i,
  input  logic [1:0]                   read_req_lane_mask_i,
  input  logic [5:0]                   read_req_layer_id_i,
  input  logic [3:0]                   read_req_iteration_epoch_i,

  output logic                         read_resp_valid_o,
  output logic [0:0]                   read_resp_qbuf_o,
  output logic [3:0]                   read_resp_qslot_o,
  output logic [1:0]                   read_resp_lane_mask_o,
  output logic [5:0]                   read_resp_layer_id_o,
  output logic [3:0]                   read_resp_iteration_epoch_o,
  output logic [P*8-1:0]               read_resp_lane0_o,
  output logic [P*8-1:0]               read_resp_lane1_o,

  output logic                         write_accept_o,
  output logic                         error_valid_o,
  output logic [7:0]                   error_code_o,
  output logic [5:0]                   live_count_o
);
  import nr_ldpc_pkg::*;

  localparam int Q_SLOTS = 10;
  localparam int NUM_QBUFS = 2;
  localparam int TOTAL_SLOTS = Q_SLOTS * NUM_QBUFS;

  localparam logic [7:0] ERR_NONE = 8'd0;
  localparam logic [7:0] ERR_WRITE_QSLOT = 8'd1;
  localparam logic [7:0] ERR_OVERWRITE = 8'd2;
  localparam logic [7:0] ERR_READ_QSLOT = 8'd3;
  localparam logic [7:0] ERR_READ_INVALID = 8'd4;
  localparam logic [7:0] ERR_READ_METADATA = 8'd5;
  localparam logic [7:0] ERR_ADVANCE_LIVE = 8'd6;
  localparam logic [7:0] ERR_RELEASE = 8'd7;

  logic [P*W_Q-1:0] lane0_mem [0:TOTAL_SLOTS-1];
  logic [P*W_Q-1:0] lane1_mem [0:TOTAL_SLOTS-1];
  logic slot_valid_q [0:TOTAL_SLOTS-1];
  logic slot_live_q [0:TOTAL_SLOTS-1];
  logic [3:0] slot_epoch_q [0:TOTAL_SLOTS-1];
  logic [5:0] slot_layer_q [0:TOTAL_SLOTS-1];
  logic [1:0] slot_mask_q [0:TOTAL_SLOTS-1];

  logic release0_valid_q;
  logic release1_valid_q;
  logic release2_valid_q;
  logic [4:0] release0_idx_q;
  logic [4:0] release1_idx_q;
  logic [4:0] release2_idx_q;
  logic [3:0] release0_epoch_q;
  logic [3:0] release1_epoch_q;
  logic [3:0] release2_epoch_q;
  logic [5:0] release0_layer_q;
  logic [5:0] release1_layer_q;
  logic [5:0] release2_layer_q;

  logic [4:0] write_idx_raw_w;
  logic [4:0] read_idx_raw_w;
  logic [4:0] write_idx_w;
  logic [4:0] read_idx_w;
  logic write_slot_ok_w;
  logic read_slot_ok_w;
  logic write_releases_same_slot_w;
  logic write_error_w;
  logic read_metadata_match_w;
  logic read_error_w;
  logic release_error_w;
  logic [7:0] error_code_w;
  logic read_accept_w;
  logic [5:0] live_count_w;

  function automatic logic [4:0] slot_index(input logic qbuf, input logic [3:0] qslot);
    begin
      slot_index = (qbuf ? 5'd10 : 5'd0) + {1'b0, qslot};
    end
  endfunction

  assign write_slot_ok_w = (write_qslot_i < Q_SLOTS[3:0]);
  assign read_slot_ok_w = (read_req_qslot_i < Q_SLOTS[3:0]);
  assign write_idx_raw_w = slot_index(write_qbuf_i[0], write_qslot_i);
  assign read_idx_raw_w = slot_index(read_req_qbuf_i[0], read_req_qslot_i);
  assign write_idx_w = write_slot_ok_w ? write_idx_raw_w : 5'd0;
  assign read_idx_w = read_slot_ok_w ? read_idx_raw_w : 5'd0;

  assign write_releases_same_slot_w = release2_valid_q
      && (release2_idx_q == write_idx_w)
      && slot_live_q[write_idx_w]
      && (slot_layer_q[write_idx_w] == release2_layer_q)
      && (slot_epoch_q[write_idx_w] == release2_epoch_q);

  assign write_error_w = write_valid_i
      && (!write_slot_ok_w || (slot_live_q[write_idx_w] && !write_releases_same_slot_w));
  assign write_accept_o = write_valid_i && !write_error_w;

  assign read_metadata_match_w = read_slot_ok_w
      && slot_valid_q[read_idx_w]
      && slot_live_q[read_idx_w]
      && (slot_layer_q[read_idx_w] == read_req_layer_id_i)
      && (slot_epoch_q[read_idx_w] == read_req_iteration_epoch_i)
      && (slot_mask_q[read_idx_w] == read_req_lane_mask_i);

  assign read_error_w = read_req_valid_i
      && (!read_slot_ok_w
          || !slot_valid_q[read_idx_w]
          || !slot_live_q[read_idx_w]
          || !read_metadata_match_w);

  assign read_accept_w = read_req_valid_i && !read_error_w;

  assign release_error_w = release2_valid_q
      && (!slot_live_q[release2_idx_q]
          || (slot_layer_q[release2_idx_q] != release2_layer_q)
          || (slot_epoch_q[release2_idx_q] != release2_epoch_q));

  always @* begin
    if (advance_iteration_i && (live_count_w != 6'd0)) begin
      error_code_w = ERR_ADVANCE_LIVE;
    end else if (write_valid_i && !write_slot_ok_w) begin
      error_code_w = ERR_WRITE_QSLOT;
    end else if (write_valid_i && slot_live_q[write_idx_w] && !write_releases_same_slot_w) begin
      error_code_w = ERR_OVERWRITE;
    end else if (read_req_valid_i && !read_slot_ok_w) begin
      error_code_w = ERR_READ_QSLOT;
    end else if (read_req_valid_i && (!slot_valid_q[read_idx_w] || !slot_live_q[read_idx_w])) begin
      error_code_w = ERR_READ_INVALID;
    end else if (read_req_valid_i && !read_metadata_match_w) begin
      error_code_w = ERR_READ_METADATA;
    end else if (release_error_w) begin
      error_code_w = ERR_RELEASE;
    end else begin
      error_code_w = ERR_NONE;
    end
  end

  integer count_idx;
  always @* begin
    live_count_w = 6'd0;
    for (count_idx = 0; count_idx < TOTAL_SLOTS; count_idx++) begin
      if (slot_live_q[count_idx]) begin
        live_count_w = live_count_w + 6'd1;
      end
    end
  end
  assign live_count_o = live_count_w;

  integer idx;
  always_ff @(posedge clk_i) begin
    if (rst_i || start_block_i) begin
      for (idx = 0; idx < TOTAL_SLOTS; idx++) begin
        slot_valid_q[idx] <= 1'b0;
        slot_live_q[idx] <= 1'b0;
        slot_epoch_q[idx] <= 4'd0;
        slot_layer_q[idx] <= 6'd0;
        slot_mask_q[idx] <= 2'b00;
      end
      release0_valid_q <= 1'b0;
      release1_valid_q <= 1'b0;
      release2_valid_q <= 1'b0;
      read_resp_valid_o <= 1'b0;
      error_valid_o <= 1'b0;
      error_code_o <= ERR_NONE;
    end else begin
      error_valid_o <= write_error_w || read_error_w || release_error_w
          || (advance_iteration_i && (live_count_w != 6'd0));
      error_code_o <= error_code_w;

      read_resp_valid_o <= read_accept_w;
      read_resp_qbuf_o <= read_req_qbuf_i;
      read_resp_qslot_o <= read_req_qslot_i;
      read_resp_lane_mask_o <= read_req_lane_mask_i;
      read_resp_layer_id_o <= read_req_layer_id_i;
      read_resp_iteration_epoch_o <= read_req_iteration_epoch_i;
      read_resp_lane0_o <= read_slot_ok_w ? lane0_mem[read_idx_w] : '0;
      read_resp_lane1_o <= read_slot_ok_w ? lane1_mem[read_idx_w] : '0;

      release0_valid_q <= read_accept_w;
      release0_idx_q <= read_idx_w;
      release0_layer_q <= read_req_layer_id_i;
      release0_epoch_q <= read_req_iteration_epoch_i;
      release1_valid_q <= release0_valid_q;
      release1_idx_q <= release0_idx_q;
      release1_layer_q <= release0_layer_q;
      release1_epoch_q <= release0_epoch_q;
      release2_valid_q <= release1_valid_q;
      release2_idx_q <= release1_idx_q;
      release2_layer_q <= release1_layer_q;
      release2_epoch_q <= release1_epoch_q;

      if (release2_valid_q && !release_error_w) begin
        slot_live_q[release2_idx_q] <= 1'b0;
      end

      if (write_valid_i && !write_error_w) begin
        slot_valid_q[write_idx_w] <= 1'b1;
        slot_live_q[write_idx_w] <= 1'b1;
        slot_epoch_q[write_idx_w] <= write_iteration_epoch_i;
        slot_layer_q[write_idx_w] <= write_layer_id_i;
        slot_mask_q[write_idx_w] <= write_lane_mask_i;
        lane0_mem[write_idx_w] <= write_lane0_i;
        lane1_mem[write_idx_w] <= write_lane1_i;
      end
    end
  end
endmodule

`endif
