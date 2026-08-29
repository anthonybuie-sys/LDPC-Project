`ifndef NR_LDPC_FORWARD_CACHE_SV
`define NR_LDPC_FORWARD_CACHE_SV

module nr_ldpc_forward_cache #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z,
  parameter int DEPTH = nr_ldpc_pkg::FORWARD_DEPTH
) (
  input  logic                         clk_i,
  input  logic                         rst_i,
  input  logic                         start_block_i,
  input  logic                         advance_iteration_i,

  input  logic [1:0]                   reserve_valid_i,
  input  logic [2:0]                   reserve_slot0_i,
  input  logic [2:0]                   reserve_slot1_i,
  input  logic [6:0]                   reserve_column0_i,
  input  logic [6:0]                   reserve_column1_i,
  input  logic [3:0]                   reserve_iteration_epoch_i,

  input  logic [1:0]                   publish_valid_i,
  input  logic                         publish_commit_i,
  input  logic [2:0]                   publish_slot0_i,
  input  logic [2:0]                   publish_slot1_i,
  input  logic [6:0]                   publish_column0_i,
  input  logic [6:0]                   publish_column1_i,
  input  logic [3:0]                   publish_iteration_epoch_i,
  input  logic [P*8-1:0]               publish_app0_i,
  input  logic [P*8-1:0]               publish_app1_i,

  output logic [1:0]                   reserve_accept_o,
  output logic [1:0]                   alloc_accept_o,

  input  logic [1:0]                   read_valid_i,
  input  logic [2:0]                   read_slot0_i,
  input  logic [2:0]                   read_slot1_i,
  input  logic [6:0]                   read_column0_i,
  input  logic [6:0]                   read_column1_i,
  input  logic [3:0]                   read_iteration_epoch_i,

  output logic [1:0]                   read_accept_o,
  output logic [P*8-1:0]               read_app0_o,
  output logic [P*8-1:0]               read_app1_o,

  output logic [5:0]                   live_count_o,
  output logic                         error_valid_o,
  output logic [7:0]                   error_code_o
);
  import nr_ldpc_pkg::*;

  localparam logic [7:0] ERR_NONE = 8'd0;
  localparam logic [7:0] ERR_ALLOC_DUPLICATE = 8'd1;
  localparam logic [7:0] ERR_ALLOC_OVERWRITE = 8'd2;
  localparam logic [7:0] ERR_READ_INVALID = 8'd3;
  localparam logic [7:0] ERR_READ_TAG = 8'd4;
  localparam logic [7:0] ERR_READ_EPOCH = 8'd5;
  localparam logic [7:0] ERR_PUBLISH_TAG = 8'd6;

  logic [P*W_APP-1:0] app_mem [0:DEPTH-1];
  logic reserved_q [0:DEPTH-1];
  logic payload_valid_q [0:DEPTH-1];
  logic [6:0] column_q [0:DEPTH-1];
  logic [3:0] epoch_q [0:DEPTH-1];

  logic reserve_duplicate_w;
  logic reserve_overwrite0_w;
  logic reserve_overwrite1_w;
  logic reserve_error_w;
  logic publish_duplicate_w;
  logic publish0_match_w;
  logic publish1_match_w;
  logic publish_error_w;
  logic read0_stored_present_w;
  logic read1_stored_present_w;
  logic read0_bypass0_w;
  logic read0_bypass1_w;
  logic read1_bypass0_w;
  logic read1_bypass1_w;
  logic read0_any_present_w;
  logic read1_any_present_w;
  logic read0_tag_match_w;
  logic read1_tag_match_w;
  logic read0_epoch_match_w;
  logic read1_epoch_match_w;
  logic read_error_w;
  logic [7:0] error_code_w;
  logic [5:0] live_count_w;

  assign reserve_duplicate_w = reserve_valid_i[0]
      && reserve_valid_i[1]
      && (reserve_slot0_i == reserve_slot1_i);
  assign reserve_overwrite0_w = reserve_valid_i[0] && reserved_q[reserve_slot0_i];
  assign reserve_overwrite1_w = reserve_valid_i[1] && reserved_q[reserve_slot1_i];
  assign reserve_error_w = reserve_duplicate_w || reserve_overwrite0_w || reserve_overwrite1_w;
  assign reserve_accept_o = reserve_valid_i & {2{!reserve_error_w}};

  assign publish_duplicate_w = publish_valid_i[0]
      && publish_valid_i[1]
      && (publish_slot0_i == publish_slot1_i);
  assign publish0_match_w = publish_valid_i[0]
      && reserved_q[publish_slot0_i]
      && (column_q[publish_slot0_i] == publish_column0_i)
      && (epoch_q[publish_slot0_i] == publish_iteration_epoch_i);
  assign publish1_match_w = publish_valid_i[1]
      && reserved_q[publish_slot1_i]
      && (column_q[publish_slot1_i] == publish_column1_i)
      && (epoch_q[publish_slot1_i] == publish_iteration_epoch_i);
  assign publish_error_w = publish_duplicate_w
      || (publish_valid_i[0] && !publish0_match_w)
      || (publish_valid_i[1] && !publish1_match_w);
  assign alloc_accept_o = publish_valid_i & {2{!publish_error_w}};

  assign read0_stored_present_w = payload_valid_q[read_slot0_i];
  assign read1_stored_present_w = payload_valid_q[read_slot1_i];

  assign read0_bypass0_w = publish_commit_i
      && publish_valid_i[0]
      && !publish_error_w
      && (publish_slot0_i == read_slot0_i);
  assign read0_bypass1_w = publish_commit_i
      && publish_valid_i[1]
      && !publish_error_w
      && (publish_slot1_i == read_slot0_i);
  assign read1_bypass0_w = publish_commit_i
      && publish_valid_i[0]
      && !publish_error_w
      && (publish_slot0_i == read_slot1_i);
  assign read1_bypass1_w = publish_commit_i
      && publish_valid_i[1]
      && !publish_error_w
      && (publish_slot1_i == read_slot1_i);

  assign read0_any_present_w = read0_stored_present_w || read0_bypass0_w || read0_bypass1_w;
  assign read1_any_present_w = read1_stored_present_w || read1_bypass0_w || read1_bypass1_w;

  assign read0_tag_match_w =
      (read0_stored_present_w && (column_q[read_slot0_i] == read_column0_i))
      || (read0_bypass0_w && (publish_column0_i == read_column0_i))
      || (read0_bypass1_w && (publish_column1_i == read_column0_i));
  assign read1_tag_match_w =
      (read1_stored_present_w && (column_q[read_slot1_i] == read_column1_i))
      || (read1_bypass0_w && (publish_column0_i == read_column1_i))
      || (read1_bypass1_w && (publish_column1_i == read_column1_i));

  assign read0_epoch_match_w =
      (read0_stored_present_w && (epoch_q[read_slot0_i] == read_iteration_epoch_i))
      || (read0_bypass0_w && (publish_iteration_epoch_i == read_iteration_epoch_i))
      || (read0_bypass1_w && (publish_iteration_epoch_i == read_iteration_epoch_i));
  assign read1_epoch_match_w =
      (read1_stored_present_w && (epoch_q[read_slot1_i] == read_iteration_epoch_i))
      || (read1_bypass0_w && (publish_iteration_epoch_i == read_iteration_epoch_i))
      || (read1_bypass1_w && (publish_iteration_epoch_i == read_iteration_epoch_i));

  assign read_accept_o[0] = read_valid_i[0]
      && read0_any_present_w
      && read0_tag_match_w
      && read0_epoch_match_w;
  assign read_accept_o[1] = read_valid_i[1]
      && read1_any_present_w
      && read1_tag_match_w
      && read1_epoch_match_w;

  assign read_error_w = (read_valid_i[0] && !read_accept_o[0])
      || (read_valid_i[1] && !read_accept_o[1]);

  always @* begin
    read_app0_o = '0;
    if (read0_stored_present_w && read0_tag_match_w && read0_epoch_match_w) begin
      read_app0_o = app_mem[read_slot0_i];
    end else if (read0_bypass0_w && (publish_column0_i == read_column0_i)
        && (publish_iteration_epoch_i == read_iteration_epoch_i)) begin
      read_app0_o = publish_app0_i;
    end else if (read0_bypass1_w && (publish_column1_i == read_column0_i)
        && (publish_iteration_epoch_i == read_iteration_epoch_i)) begin
      read_app0_o = publish_app1_i;
    end

    read_app1_o = '0;
    if (read1_stored_present_w && read1_tag_match_w && read1_epoch_match_w) begin
      read_app1_o = app_mem[read_slot1_i];
    end else if (read1_bypass0_w && (publish_column0_i == read_column1_i)
        && (publish_iteration_epoch_i == read_iteration_epoch_i)) begin
      read_app1_o = publish_app0_i;
    end else if (read1_bypass1_w && (publish_column1_i == read_column1_i)
        && (publish_iteration_epoch_i == read_iteration_epoch_i)) begin
      read_app1_o = publish_app1_i;
    end
  end

  always @* begin
    if (reserve_duplicate_w || publish_duplicate_w) begin
      error_code_w = ERR_ALLOC_DUPLICATE;
    end else if (reserve_overwrite0_w || reserve_overwrite1_w) begin
      error_code_w = ERR_ALLOC_OVERWRITE;
    end else if (publish_error_w) begin
      error_code_w = ERR_PUBLISH_TAG;
    end else if (read_valid_i[0] && !read0_any_present_w) begin
      error_code_w = ERR_READ_INVALID;
    end else if (read_valid_i[1] && !read1_any_present_w) begin
      error_code_w = ERR_READ_INVALID;
    end else if (read_valid_i[0] && !read0_tag_match_w) begin
      error_code_w = ERR_READ_TAG;
    end else if (read_valid_i[1] && !read1_tag_match_w) begin
      error_code_w = ERR_READ_TAG;
    end else if (read_valid_i[0] && !read0_epoch_match_w) begin
      error_code_w = ERR_READ_EPOCH;
    end else if (read_valid_i[1] && !read1_epoch_match_w) begin
      error_code_w = ERR_READ_EPOCH;
    end else begin
      error_code_w = ERR_NONE;
    end
  end

  integer count_idx;
  always @* begin
    live_count_w = 6'd0;
    for (count_idx = 0; count_idx < DEPTH; count_idx++) begin
      if (reserved_q[count_idx]) begin
        live_count_w = live_count_w + 6'd1;
      end
    end
    if (reserve_valid_i[0] && !reserve_error_w) begin
      live_count_w = live_count_w + 6'd1;
    end
    if (reserve_valid_i[1] && !reserve_error_w) begin
      live_count_w = live_count_w + 6'd1;
    end
  end
  assign live_count_o = live_count_w;

  integer idx;
  always_ff @(posedge clk_i) begin
    if (rst_i || start_block_i || advance_iteration_i) begin
      for (idx = 0; idx < DEPTH; idx++) begin
        reserved_q[idx] <= 1'b0;
        payload_valid_q[idx] <= 1'b0;
        column_q[idx] <= 7'd0;
        epoch_q[idx] <= 4'd0;
      end
      error_valid_o <= 1'b0;
      error_code_o <= ERR_NONE;
    end else begin
      error_valid_o <= reserve_error_w || publish_error_w || read_error_w;
      error_code_o <= error_code_w;

      for (idx = 0; idx < DEPTH; idx++) begin
        payload_valid_q[idx] <= 1'b0;
      end

      if (publish_commit_i && !publish_error_w) begin
        if (publish_valid_i[0]) begin
          reserved_q[publish_slot0_i] <= 1'b0;
          payload_valid_q[publish_slot0_i] <= 1'b1;
          app_mem[publish_slot0_i] <= publish_app0_i;
        end
        if (publish_valid_i[1]) begin
          reserved_q[publish_slot1_i] <= 1'b0;
          payload_valid_q[publish_slot1_i] <= 1'b1;
          app_mem[publish_slot1_i] <= publish_app1_i;
        end
      end

      if (!reserve_error_w) begin
        if (reserve_valid_i[0]) begin
          reserved_q[reserve_slot0_i] <= 1'b1;
          payload_valid_q[reserve_slot0_i] <= 1'b0;
          column_q[reserve_slot0_i] <= reserve_column0_i;
          epoch_q[reserve_slot0_i] <= reserve_iteration_epoch_i;
        end
        if (reserve_valid_i[1]) begin
          reserved_q[reserve_slot1_i] <= 1'b1;
          payload_valid_q[reserve_slot1_i] <= 1'b0;
          column_q[reserve_slot1_i] <= reserve_column1_i;
          epoch_q[reserve_slot1_i] <= reserve_iteration_epoch_i;
        end
      end
    end
  end
endmodule

`endif
