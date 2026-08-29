`ifndef NR_LDPC_APP_MEMORY_SV
`define NR_LDPC_APP_MEMORY_SV

module nr_ldpc_app_memory #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z,
  parameter int MAX_COLUMNS = 128
) (
  input  logic                         clk_i,
  input  logic                         rst_i,
  input  logic                         start_block_i,

  input  logic                         load_valid_i,
  input  logic [6:0]                   load_column_i,
  input  logic [3:0]                   load_iteration_epoch_i,
  input  logic [P*8-1:0]               load_app_i,

  input  logic [1:0]                   read_valid_i,
  input  logic [6:0]                   read_column0_i,
  input  logic [6:0]                   read_column1_i,

  output logic [1:0]                   read_accept_o,
  output logic [P*8-1:0]               read_app0_o,
  output logic [P*8-1:0]               read_app1_o,
  output logic [2:0]                   read_bank0_o,
  output logic [2:0]                   read_bank1_o,

  input  logic [1:0]                   write_valid_i,
  input  logic                         write_commit_i,
  input  logic [6:0]                   write_column0_i,
  input  logic [6:0]                   write_column1_i,
  input  logic [3:0]                   write_iteration_epoch_i,
  input  logic [P*8-1:0]               write_app0_i,
  input  logic [P*8-1:0]               write_app1_i,

  output logic [1:0]                   write_accept_o,
  output logic [2:0]                   write_bank0_o,
  output logic [2:0]                   write_bank1_o,
  output logic                         same_bank_read_write_collision_o,

  output logic                         error_valid_o,
  output logic [7:0]                   error_code_o
);
  import nr_ldpc_pkg::*;

  localparam logic [7:0] ERR_NONE = 8'd0;
  localparam logic [7:0] ERR_LOAD_COLUMN = 8'd1;
  localparam logic [7:0] ERR_READ_COLUMN = 8'd2;
  localparam logic [7:0] ERR_READ_INVALID = 8'd3;
  localparam logic [7:0] ERR_WRITE_COLUMN = 8'd4;
  localparam logic [7:0] ERR_WRITE_DUPLICATE = 8'd5;

  logic [P*W_APP-1:0] app_mem [0:MAX_COLUMNS-1];
  logic column_valid_q [0:MAX_COLUMNS-1];
  logic [3:0] column_epoch_q [0:MAX_COLUMNS-1];

  logic [1:0] pending_valid_q;
  logic [6:0] pending_column0_q;
  logic [6:0] pending_column1_q;
  logic [3:0] pending_epoch_q;
  logic [P*W_APP-1:0] pending_app0_q;
  logic [P*W_APP-1:0] pending_app1_q;

  logic load_column_ok_w;
  logic read0_column_ok_w;
  logic read1_column_ok_w;
  logic write0_column_ok_w;
  logic write1_column_ok_w;
  logic read0_pending_w;
  logic read1_pending_w;
  logic read0_present_w;
  logic read1_present_w;
  logic write_duplicate_w;
  logic write_error_w;
  logic read_error_w;
  logic load_error_w;
  logic [7:0] error_code_w;

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

  assign load_column_ok_w = column_active(load_column_i);
  assign read0_column_ok_w = column_active(read_column0_i);
  assign read1_column_ok_w = column_active(read_column1_i);
  assign write0_column_ok_w = column_active(write_column0_i);
  assign write1_column_ok_w = column_active(write_column1_i);

  assign read_bank0_o = column_bank(read_column0_i);
  assign read_bank1_o = column_bank(read_column1_i);
  assign write_bank0_o = column_bank(write_column0_i);
  assign write_bank1_o = column_bank(write_column1_i);

  assign read0_pending_w = (pending_valid_q[0] && (pending_column0_q == read_column0_i))
      || (pending_valid_q[1] && (pending_column1_q == read_column0_i));
  assign read1_pending_w = (pending_valid_q[0] && (pending_column0_q == read_column1_i))
      || (pending_valid_q[1] && (pending_column1_q == read_column1_i));
  assign read0_present_w = read0_column_ok_w && (read0_pending_w || column_valid_q[read_column0_i]);
  assign read1_present_w = read1_column_ok_w && (read1_pending_w || column_valid_q[read_column1_i]);

  assign write_duplicate_w = write_valid_i[0]
      && write_valid_i[1]
      && (write_column0_i == write_column1_i);
  assign load_error_w = load_valid_i && !load_column_ok_w;
  assign read_error_w = (read_valid_i[0] && (!read0_column_ok_w || !read0_present_w))
      || (read_valid_i[1] && (!read1_column_ok_w || !read1_present_w));
  assign write_error_w = (write_valid_i[0] && !write0_column_ok_w)
      || (write_valid_i[1] && !write1_column_ok_w)
      || write_duplicate_w;

  assign read_accept_o[0] = read_valid_i[0] && read0_present_w;
  assign read_accept_o[1] = read_valid_i[1] && read1_present_w;
  assign write_accept_o = write_valid_i & {2{!write_error_w}};

  always @* begin
    read_app0_o = '0;
    if (pending_valid_q[0] && (pending_column0_q == read_column0_i)) begin
      read_app0_o = pending_app0_q;
    end else if (pending_valid_q[1] && (pending_column1_q == read_column0_i)) begin
      read_app0_o = pending_app1_q;
    end else if (read0_column_ok_w && column_valid_q[read_column0_i]) begin
      read_app0_o = app_mem[read_column0_i];
    end

    read_app1_o = '0;
    if (pending_valid_q[0] && (pending_column0_q == read_column1_i)) begin
      read_app1_o = pending_app0_q;
    end else if (pending_valid_q[1] && (pending_column1_q == read_column1_i)) begin
      read_app1_o = pending_app1_q;
    end else if (read1_column_ok_w && column_valid_q[read_column1_i]) begin
      read_app1_o = app_mem[read_column1_i];
    end
  end

  assign same_bank_read_write_collision_o =
      (read_valid_i[0] && read0_column_ok_w
          && ((write_valid_i[0] && write0_column_ok_w && (read_bank0_o == write_bank0_o))
              || (write_valid_i[1] && write1_column_ok_w && (read_bank0_o == write_bank1_o))))
      || (read_valid_i[1] && read1_column_ok_w
          && ((write_valid_i[0] && write0_column_ok_w && (read_bank1_o == write_bank0_o))
              || (write_valid_i[1] && write1_column_ok_w && (read_bank1_o == write_bank1_o))));

  always @* begin
    if (load_error_w) begin
      error_code_w = ERR_LOAD_COLUMN;
    end else if (write_valid_i[0] && !write0_column_ok_w) begin
      error_code_w = ERR_WRITE_COLUMN;
    end else if (write_valid_i[1] && !write1_column_ok_w) begin
      error_code_w = ERR_WRITE_COLUMN;
    end else if (write_duplicate_w) begin
      error_code_w = ERR_WRITE_DUPLICATE;
    end else if (read_valid_i[0] && !read0_column_ok_w) begin
      error_code_w = ERR_READ_COLUMN;
    end else if (read_valid_i[1] && !read1_column_ok_w) begin
      error_code_w = ERR_READ_COLUMN;
    end else if (read_valid_i[0] && !read0_present_w) begin
      error_code_w = ERR_READ_INVALID;
    end else if (read_valid_i[1] && !read1_present_w) begin
      error_code_w = ERR_READ_INVALID;
    end else begin
      error_code_w = ERR_NONE;
    end
  end

  integer idx;
  always_ff @(posedge clk_i) begin
    if (rst_i || start_block_i) begin
      for (idx = 0; idx < MAX_COLUMNS; idx++) begin
        column_valid_q[idx] <= 1'b0;
        column_epoch_q[idx] <= 4'd0;
      end
      pending_valid_q <= 2'b00;
      pending_column0_q <= 7'd0;
      pending_column1_q <= 7'd0;
      pending_epoch_q <= 4'd0;
      error_valid_o <= 1'b0;
      error_code_o <= ERR_NONE;
    end else begin
      error_valid_o <= load_error_w || read_error_w || write_error_w;
      error_code_o <= error_code_w;

      if (pending_valid_q[0]) begin
        app_mem[pending_column0_q] <= pending_app0_q;
        column_valid_q[pending_column0_q] <= 1'b1;
        column_epoch_q[pending_column0_q] <= pending_epoch_q;
      end
      if (pending_valid_q[1]) begin
        app_mem[pending_column1_q] <= pending_app1_q;
        column_valid_q[pending_column1_q] <= 1'b1;
        column_epoch_q[pending_column1_q] <= pending_epoch_q;
      end

      pending_valid_q <= 2'b00;

      if (load_valid_i && !load_error_w) begin
        app_mem[load_column_i] <= load_app_i;
        column_valid_q[load_column_i] <= 1'b1;
        column_epoch_q[load_column_i] <= load_iteration_epoch_i;
      end

      if (write_commit_i && !write_error_w) begin
        pending_valid_q <= write_valid_i;
        pending_column0_q <= write_column0_i;
        pending_column1_q <= write_column1_i;
        pending_epoch_q <= write_iteration_epoch_i;
        pending_app0_q <= write_app0_i;
        pending_app1_q <= write_app1_i;
      end
    end
  end
endmodule

`endif
