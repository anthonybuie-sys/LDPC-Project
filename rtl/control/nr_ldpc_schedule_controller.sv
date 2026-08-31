`ifndef NR_LDPC_SCHEDULE_CONTROLLER_SV
`define NR_LDPC_SCHEDULE_CONTROLLER_SV

module nr_ldpc_schedule_controller #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic                         clk_i,
  input  logic                         rst_i,

  input  logic                         start_i,
  input  logic                         abort_i,
  input  logic [3:0]                   max_iterations_i,

  input  logic                         app_load_valid_i,
  input  logic [6:0]                   app_load_column_i,
  input  logic [P*8-1:0]               app_load_i,
  output logic                         app_load_ready_o,

  input  logic                         acc_issue_ready_i,
  input  logic                         rec_issue_ready_i,
  input  logic                         syndrome_done_i,
  input  logic                         syndrome_zero_i,
  input  logic                         datapath_error_valid_i,
  input  logic                         datapath_advance_accept_i,

  output logic                         datapath_start_block_o,
  output logic                         datapath_advance_iteration_o,
  output logic                         datapath_start_iteration_o,
  output logic [3:0]                   datapath_syndrome_iteration_epoch_o,

  output logic                         datapath_app_load_valid_o,
  output logic [6:0]                   datapath_app_load_column_o,
  output logic [3:0]                   datapath_app_load_iteration_epoch_o,
  output logic [P*8-1:0]               datapath_app_load_o,

  output logic                         acc_issue_valid_o,
  output logic [1:0]                   acc_issue_lane_mask_o,
  output logic [5:0]                   acc_issue_layer_id_o,
  output logic [5:0]                   acc_issue_layer_position_o,
  output logic [5:0]                   acc_issue_layer_degree_o,
  output logic                         acc_issue_start_layer_o,
  output logic [4:0]                   acc_issue_edge0_id_o,
  output logic [4:0]                   acc_issue_edge1_id_o,
  output logic [0:0]                   acc_issue_qbuf_o,
  output logic [3:0]                   acc_issue_qslot_o,
  output logic [3:0]                   acc_issue_iteration_epoch_o,
  output logic [6:0]                   acc_issue_base_column0_o,
  output logic [6:0]                   acc_issue_base_column1_o,
  output logic [3:0]                   acc_issue_aux0_o,
  output logic [3:0]                   acc_issue_aux1_o,
  output logic [$clog2(P+1)-1:0]       acc_issue_shift0_o,
  output logic [$clog2(P+1)-1:0]       acc_issue_shift1_o,

  output logic                         rec_issue_valid_o,
  output logic [1:0]                   rec_issue_lane_mask_o,
  output logic [5:0]                   rec_issue_layer_id_o,
  output logic [4:0]                   rec_issue_edge0_id_o,
  output logic [4:0]                   rec_issue_edge1_id_o,
  output logic [0:0]                   rec_issue_qbuf_o,
  output logic [3:0]                   rec_issue_qslot_o,
  output logic [3:0]                   rec_issue_iteration_epoch_o,
  output logic [$clog2(P+1)-1:0]       rec_issue_shift0_o,
  output logic [$clog2(P+1)-1:0]       rec_issue_shift1_o,
  output logic [6:0]                   rec_issue_base_column0_o,
  output logic [6:0]                   rec_issue_base_column1_o,
  output logic [3:0]                   rec_issue_aux0_o,
  output logic [3:0]                   rec_issue_aux1_o,
  output logic                         rec_issue_final_touch0_o,
  output logic                         rec_issue_final_touch1_o,

  output logic                         start_ready_o,
  output logic                         busy_o,
  output logic                         done_o,
  output logic                         decode_success_o,
  output logic                         max_iterations_reached_o,
  output logic                         aborted_o,
  output logic                         error_valid_o,
  output logic [7:0]                   error_code_o,
  output logic [3:0]                   completed_iterations_o,
  output logic [3:0]                   current_iteration_epoch_o,
  output logic [8:0]                   program_counter_o,

  output logic [3:0]                   debug_state_o,
  output logic                         debug_program_issue_valid_o,
  output logic [71:0]                  debug_schedule_word_o,
  output logic [35:0]                  debug_acc_word_o,
  output logic [35:0]                  debug_rec_word_o,
  output logic                         debug_start_block_o,
  output logic                         debug_start_iteration_o,
  output logic                         debug_advance_iteration_o,
  output logic                         debug_decision_valid_o,
  output logic                         debug_retry_decision_o,
  output logic                         debug_app_load_accept_o,
  output logic [25:0]                  debug_app_load_seen_o,
  output logic [3:0]                   debug_acc_seen_layers_o
);
  import nr_ldpc_pkg::*;
  import nr_ldpc_controller_profile_bg1_first4_pkg::*;

  localparam logic [7:0] ERR_NONE             = 8'd0;
  localparam logic [7:0] ERR_ILLEGAL_MAX      = 8'd1;
  localparam logic [7:0] ERR_START_BUSY       = 8'd2;
  localparam logic [7:0] ERR_APP_LOAD_STATE   = 8'd3;
  localparam logic [7:0] ERR_APP_LOAD_COLUMN  = 8'd4;
  localparam logic [7:0] ERR_APP_LOAD_DUP     = 8'd5;
  localparam logic [7:0] ERR_DECODE           = 8'd6;
  localparam logic [7:0] ERR_ISSUE_NOT_READY  = 8'd7;
  localparam logic [7:0] ERR_DATAPATH         = 8'd8;
  localparam logic [7:0] ERR_UNSAFE_ADVANCE   = 8'd9;
  localparam logic [6:0] ACTIVE_COLUMNS_W = 7'(PHASE9_ACTIVE_COLUMNS);
  localparam logic [8:0] PROGRAM_LENGTH_W = 9'(PHASE9_PROGRAM_LENGTH);

  typedef enum logic [3:0] {
    ST_IDLE            = 4'd0,
    ST_BLOCK_LOAD      = 4'd1,
    ST_ITERATION_START = 4'd2,
    ST_RUN_PROGRAM     = 4'd3,
    ST_WAIT_SYNDROME   = 4'd4,
    ST_DONE            = 4'd5,
    ST_ERROR           = 4'd6
  } state_t;

  state_t state_q;
  logic [25:0] app_load_seen_q;
  logic [3:0] completed_iterations_q;
  logic [3:0] current_epoch_q;
  logic [8:0] pc_q;
  logic [3:0] acc_seen_layers_q;
  logic decode_success_q;
  logic max_iterations_reached_q;
  logic aborted_q;
  logic error_q;
  logic [7:0] error_code_q;

  logic idle_safe_w;
  logic active_block_w;
  logic accepted_start_w;
  logic accepted_abort_w;
  logic legal_max_w;

  logic app_load_active_w;
  logic app_load_column_active_w;
  logic app_load_duplicate_w;
  logic app_load_accept_w;
  logic [25:0] app_load_seen_next_w;
  logic all_app_loaded_w;

  wire [71:0] program_word_w;
  logic [35:0] acc_word_w;
  logic [35:0] rec_word_w;
  logic run_cycle_w;
  logic retry_decision_w;
  logic retry_advance_accept_w;

  logic [1:0] acc_mask_w;
  logic [1:0] rec_mask_w;
  logic [5:0] acc_layer_w;
  logic [5:0] rec_layer_w;
  logic [4:0] acc_edge0_w;
  logic [4:0] acc_edge1_w;
  logic [4:0] rec_edge0_w;
  logic [4:0] rec_edge1_w;
  logic acc_word_valid_w;
  logic rec_word_valid_w;
  logic acc_lane0_w;
  logic acc_lane1_w;
  logic rec_lane0_w;
  logic rec_lane1_w;
  logic acc_decode_error_w;
  logic rec_decode_error_w;
  logic schedule_decode_error_w;
  logic issue_not_ready_w;
  logic control_error_w;
  logic [7:0] control_error_code_w;
  logic decision_valid_w;
  logic decision_success_w;
  logic decision_max_w;
  logic decision_retry_w;
  logic decision_illegal_w;
  logic [3:0] completed_after_decide_w;
  logic [3:0] next_epoch_w;

  function automatic logic field_valid(input logic [35:0] word);
    field_valid = word[0];
  endfunction

  function automatic logic [1:0] field_mask(input logic [35:0] word);
    field_mask = word[2:1];
  endfunction

  function automatic logic [5:0] field_layer(input logic [35:0] word);
    field_layer = word[8:3];
  endfunction

  function automatic logic [4:0] field_edge0(input logic [35:0] word);
    field_edge0 = word[13:9];
  endfunction

  function automatic logic [4:0] field_edge1(input logic [35:0] word);
    field_edge1 = word[18:14];
  endfunction

  function automatic logic field_qbuf(input logic [35:0] word);
    field_qbuf = word[19];
  endfunction

  function automatic logic [3:0] field_qslot(input logic [35:0] word);
    field_qslot = word[23:20];
  endfunction

  function automatic logic [3:0] field_aux0(input logic [35:0] word);
    field_aux0 = word[27:24];
  endfunction

  function automatic logic [3:0] field_aux1(input logic [35:0] word);
    field_aux1 = word[31:28];
  endfunction

  function automatic logic field_final0(input logic [35:0] word);
    field_final0 = word[32];
  endfunction

  function automatic logic field_final1(input logic [35:0] word);
    field_final1 = word[33];
  endfunction

  function automatic logic [1:0] field_reserved(input logic [35:0] word);
    field_reserved = word[35:34];
  endfunction

  nr_ldpc_iteration_decide u_decide (
    .syndrome_done_i(syndrome_done_i && (state_q == ST_WAIT_SYNDROME)),
    .syndrome_zero_i(syndrome_zero_i),
    .max_iterations_i(max_iterations_i),
    .completed_iterations_i(completed_iterations_q),
    .decision_valid_o(decision_valid_w),
    .terminate_success_o(decision_success_w),
    .terminate_max_iterations_o(decision_max_w),
    .retry_next_iteration_o(decision_retry_w),
    .illegal_config_o(decision_illegal_w),
    .completed_iterations_after_decide_o(completed_after_decide_w)
  );

  assign legal_max_w = (max_iterations_i != 4'd0);
  assign idle_safe_w = (state_q == ST_IDLE) || (state_q == ST_DONE);
  assign active_block_w = (state_q == ST_BLOCK_LOAD)
      || (state_q == ST_ITERATION_START)
      || (state_q == ST_RUN_PROGRAM)
      || (state_q == ST_WAIT_SYNDROME);
  assign accepted_abort_w = abort_i && active_block_w && !error_q;
  assign accepted_start_w = start_i && idle_safe_w && legal_max_w && !error_q && !abort_i;

  assign app_load_ready_o = (state_q == ST_BLOCK_LOAD) && !abort_i && !error_q;
  assign app_load_active_w = app_load_valid_i && (state_q == ST_BLOCK_LOAD) && !abort_i && !error_q;
  assign app_load_column_active_w = (app_load_column_i < ACTIVE_COLUMNS_W);
  assign app_load_duplicate_w = app_load_active_w
      && app_load_column_active_w
      && app_load_seen_q[app_load_column_i[4:0]];
  assign app_load_accept_w = app_load_active_w && app_load_column_active_w && !app_load_duplicate_w;

  always @* begin
    app_load_seen_next_w = app_load_seen_q;
    if (app_load_accept_w) begin
      app_load_seen_next_w[app_load_column_i[4:0]] = 1'b1;
    end
  end
  assign all_app_loaded_w = &app_load_seen_next_w;

  assign program_word_w = phase9_program_word(pc_q);
  assign acc_word_w = program_word_w[35:0];
  assign rec_word_w = program_word_w[71:36];
  assign run_cycle_w = (state_q == ST_RUN_PROGRAM) && !abort_i && !error_q;

  assign acc_mask_w = field_mask(acc_word_w);
  assign rec_mask_w = field_mask(rec_word_w);
  assign acc_layer_w = field_layer(acc_word_w);
  assign rec_layer_w = field_layer(rec_word_w);
  assign acc_edge0_w = field_edge0(acc_word_w);
  assign acc_edge1_w = field_edge1(acc_word_w);
  assign rec_edge0_w = field_edge0(rec_word_w);
  assign rec_edge1_w = field_edge1(rec_word_w);

  assign acc_word_valid_w = run_cycle_w && field_valid(acc_word_w);
  assign rec_word_valid_w = run_cycle_w && field_valid(rec_word_w);
  assign acc_lane0_w = acc_word_valid_w && acc_mask_w[0];
  assign acc_lane1_w = acc_word_valid_w && acc_mask_w[1];
  assign rec_lane0_w = rec_word_valid_w && rec_mask_w[0];
  assign rec_lane1_w = rec_word_valid_w && rec_mask_w[1];

  assign acc_decode_error_w = acc_word_valid_w
      && ((field_reserved(acc_word_w) != 2'b00)
          || (acc_mask_w == 2'b00)
          || !phase9_active_layer(acc_layer_w)
          || (phase9_layer_degree(acc_layer_w) == 6'd0)
          || (phase9_layer_position(acc_layer_w) == 6'd63)
          || (acc_lane0_w && !phase9_edge_valid(acc_layer_w, acc_edge0_w))
          || (acc_lane1_w && !phase9_edge_valid(acc_layer_w, acc_edge1_w))
          || field_final0(acc_word_w)
          || field_final1(acc_word_w));
  assign rec_decode_error_w = rec_word_valid_w
      && ((field_reserved(rec_word_w) != 2'b00)
          || (rec_mask_w == 2'b00)
          || !phase9_active_layer(rec_layer_w)
          || (rec_lane0_w && !phase9_edge_valid(rec_layer_w, rec_edge0_w))
          || (rec_lane1_w && !phase9_edge_valid(rec_layer_w, rec_edge1_w))
          || (field_final0(rec_word_w) && !rec_lane0_w)
          || (field_final1(rec_word_w) && !rec_lane1_w));
  assign schedule_decode_error_w = run_cycle_w && ((pc_q >= PROGRAM_LENGTH_W)
      || acc_decode_error_w || rec_decode_error_w);
  assign issue_not_ready_w = !schedule_decode_error_w
      && ((acc_word_valid_w && !acc_issue_ready_i)
          || (rec_word_valid_w && !rec_issue_ready_i));

  assign retry_decision_w = decision_valid_w && decision_retry_w;
  assign retry_advance_accept_w = retry_decision_w && datapath_advance_accept_i;
  assign next_epoch_w = current_epoch_q + 4'd1;

  always @* begin
    control_error_w = 1'b0;
    control_error_code_w = ERR_NONE;
    if (start_i && idle_safe_w && !legal_max_w) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_ILLEGAL_MAX;
    end else if (active_block_w && !legal_max_w) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_ILLEGAL_MAX;
    end else if (start_i && !idle_safe_w && !abort_i) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_START_BUSY;
    end else if (app_load_valid_i && (state_q != ST_BLOCK_LOAD) && !abort_i) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_APP_LOAD_STATE;
    end else if (app_load_active_w && !app_load_column_active_w) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_APP_LOAD_COLUMN;
    end else if (app_load_duplicate_w) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_APP_LOAD_DUP;
    end else if (schedule_decode_error_w) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_DECODE;
    end else if (issue_not_ready_w) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_ISSUE_NOT_READY;
    end else if (retry_decision_w && !datapath_advance_accept_i) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_UNSAFE_ADVANCE;
    end else if (datapath_error_valid_i && !abort_i) begin
      control_error_w = 1'b1;
      control_error_code_w = ERR_DATAPATH;
    end
  end

  assign datapath_start_block_o = accepted_start_w || accepted_abort_w;
  assign datapath_advance_iteration_o = retry_decision_w;
  assign datapath_start_iteration_o = (state_q == ST_ITERATION_START)
      || (retry_decision_w && datapath_advance_accept_i);
  assign datapath_syndrome_iteration_epoch_o =
      (retry_decision_w && datapath_advance_accept_i)
          ? next_epoch_w
          : current_epoch_q;

  assign datapath_app_load_valid_o = app_load_accept_w;
  assign datapath_app_load_column_o = app_load_column_i;
  assign datapath_app_load_iteration_epoch_o = 4'd0;
  assign datapath_app_load_o = app_load_i;

  assign acc_issue_valid_o = acc_word_valid_w && !schedule_decode_error_w && !issue_not_ready_w;
  assign acc_issue_lane_mask_o = acc_issue_valid_o ? acc_mask_w : 2'b00;
  assign acc_issue_layer_id_o = acc_layer_w;
  assign acc_issue_layer_position_o = phase9_layer_position(acc_layer_w);
  assign acc_issue_layer_degree_o = phase9_layer_degree(acc_layer_w);
  assign acc_issue_start_layer_o = acc_issue_valid_o
      && !acc_seen_layers_q[acc_layer_w[1:0]];
  assign acc_issue_edge0_id_o = acc_edge0_w;
  assign acc_issue_edge1_id_o = acc_edge1_w;
  assign acc_issue_qbuf_o = field_qbuf(acc_word_w);
  assign acc_issue_qslot_o = field_qslot(acc_word_w);
  assign acc_issue_iteration_epoch_o = current_epoch_q;
  assign acc_issue_base_column0_o = acc_lane0_w
      ? phase9_edge_base_column(acc_layer_w, acc_edge0_w)
      : 7'd0;
  assign acc_issue_base_column1_o = acc_lane1_w
      ? phase9_edge_base_column(acc_layer_w, acc_edge1_w)
      : 7'd0;
  assign acc_issue_aux0_o = field_aux0(acc_word_w);
  assign acc_issue_aux1_o = field_aux1(acc_word_w);
  assign acc_issue_shift0_o = acc_lane0_w
      ? phase9_edge_shift(acc_layer_w, acc_edge0_w)
      : '0;
  assign acc_issue_shift1_o = acc_lane1_w
      ? phase9_edge_shift(acc_layer_w, acc_edge1_w)
      : '0;

  assign rec_issue_valid_o = rec_word_valid_w && !schedule_decode_error_w && !issue_not_ready_w;
  assign rec_issue_lane_mask_o = rec_issue_valid_o ? rec_mask_w : 2'b00;
  assign rec_issue_layer_id_o = rec_layer_w;
  assign rec_issue_edge0_id_o = rec_edge0_w;
  assign rec_issue_edge1_id_o = rec_edge1_w;
  assign rec_issue_qbuf_o = field_qbuf(rec_word_w);
  assign rec_issue_qslot_o = field_qslot(rec_word_w);
  assign rec_issue_iteration_epoch_o = current_epoch_q;
  assign rec_issue_shift0_o = rec_lane0_w
      ? phase9_edge_shift(rec_layer_w, rec_edge0_w)
      : '0;
  assign rec_issue_shift1_o = rec_lane1_w
      ? phase9_edge_shift(rec_layer_w, rec_edge1_w)
      : '0;
  assign rec_issue_base_column0_o = rec_lane0_w
      ? phase9_edge_base_column(rec_layer_w, rec_edge0_w)
      : 7'd0;
  assign rec_issue_base_column1_o = rec_lane1_w
      ? phase9_edge_base_column(rec_layer_w, rec_edge1_w)
      : 7'd0;
  assign rec_issue_aux0_o = field_aux0(rec_word_w);
  assign rec_issue_aux1_o = field_aux1(rec_word_w);
  assign rec_issue_final_touch0_o = field_final0(rec_word_w);
  assign rec_issue_final_touch1_o = field_final1(rec_word_w);

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state_q <= ST_IDLE;
      app_load_seen_q <= '0;
      completed_iterations_q <= 4'd0;
      current_epoch_q <= 4'd0;
      pc_q <= 9'd0;
      acc_seen_layers_q <= 4'd0;
      decode_success_q <= 1'b0;
      max_iterations_reached_q <= 1'b0;
      aborted_q <= 1'b0;
      error_q <= 1'b0;
      error_code_q <= ERR_NONE;
    end else if (accepted_abort_w) begin
      state_q <= ST_IDLE;
      app_load_seen_q <= '0;
      completed_iterations_q <= 4'd0;
      current_epoch_q <= 4'd0;
      pc_q <= 9'd0;
      acc_seen_layers_q <= 4'd0;
      decode_success_q <= 1'b0;
      max_iterations_reached_q <= 1'b0;
      aborted_q <= 1'b1;
      error_q <= 1'b0;
      error_code_q <= ERR_NONE;
    end else if (control_error_w) begin
      state_q <= ST_ERROR;
      decode_success_q <= 1'b0;
      max_iterations_reached_q <= 1'b0;
      error_q <= 1'b1;
      error_code_q <= control_error_code_w;
      pc_q <= 9'd0;
      acc_seen_layers_q <= 4'd0;
    end else if (accepted_start_w) begin
      state_q <= ST_BLOCK_LOAD;
      app_load_seen_q <= '0;
      completed_iterations_q <= 4'd0;
      current_epoch_q <= 4'd0;
      pc_q <= 9'd0;
      acc_seen_layers_q <= 4'd0;
      decode_success_q <= 1'b0;
      max_iterations_reached_q <= 1'b0;
      aborted_q <= 1'b0;
      error_q <= 1'b0;
      error_code_q <= ERR_NONE;
    end else begin
      case (state_q)
        ST_IDLE: begin
          pc_q <= 9'd0;
          acc_seen_layers_q <= 4'd0;
        end

        ST_BLOCK_LOAD: begin
          app_load_seen_q <= app_load_seen_next_w;
          if (all_app_loaded_w) begin
            state_q <= ST_ITERATION_START;
          end
        end

        ST_ITERATION_START: begin
          state_q <= ST_RUN_PROGRAM;
          pc_q <= 9'd0;
          acc_seen_layers_q <= 4'd0;
        end

        ST_RUN_PROGRAM: begin
          if (acc_issue_valid_o) begin
            acc_seen_layers_q[acc_layer_w[1:0]] <= 1'b1;
          end
          if (pc_q == (PROGRAM_LENGTH_W - 9'd1)) begin
            state_q <= ST_WAIT_SYNDROME;
            pc_q <= 9'd0;
          end else begin
            pc_q <= pc_q + 9'd1;
          end
        end

        ST_WAIT_SYNDROME: begin
          if (decision_valid_w) begin
            completed_iterations_q <= completed_after_decide_w;
            if (decision_success_w) begin
              state_q <= ST_DONE;
              decode_success_q <= 1'b1;
              max_iterations_reached_q <= 1'b0;
            end else if (decision_max_w) begin
              state_q <= ST_DONE;
              decode_success_q <= 1'b0;
              max_iterations_reached_q <= 1'b1;
            end else if (decision_retry_w) begin
              state_q <= ST_RUN_PROGRAM;
              current_epoch_q <= next_epoch_w;
              pc_q <= 9'd0;
              acc_seen_layers_q <= 4'd0;
            end
          end
        end

        ST_DONE: begin
          pc_q <= 9'd0;
          acc_seen_layers_q <= 4'd0;
        end

        ST_ERROR: begin
          pc_q <= 9'd0;
          acc_seen_layers_q <= 4'd0;
        end

        default: begin
          state_q <= ST_ERROR;
          error_q <= 1'b1;
          error_code_q <= ERR_DECODE;
        end
      endcase
    end
  end

  assign start_ready_o = idle_safe_w && !error_q;
  assign busy_o = active_block_w && !abort_i && !error_q;
  assign done_o = (state_q == ST_DONE);
  assign decode_success_o = done_o && decode_success_q;
  assign max_iterations_reached_o = done_o && max_iterations_reached_q;
  assign aborted_o = aborted_q;
  assign error_valid_o = error_q;
  assign error_code_o = error_code_q;
  assign completed_iterations_o = completed_iterations_q;
  assign current_iteration_epoch_o = current_epoch_q;
  assign program_counter_o = pc_q;

  assign debug_state_o = state_q;
  assign debug_program_issue_valid_o = run_cycle_w && !schedule_decode_error_w && !issue_not_ready_w;
  assign debug_schedule_word_o = program_word_w;
  assign debug_acc_word_o = acc_word_w;
  assign debug_rec_word_o = rec_word_w;
  assign debug_start_block_o = datapath_start_block_o;
  assign debug_start_iteration_o = datapath_start_iteration_o;
  assign debug_advance_iteration_o = datapath_advance_iteration_o;
  assign debug_decision_valid_o = decision_valid_w;
  assign debug_retry_decision_o = decision_retry_w;
  assign debug_app_load_accept_o = app_load_accept_w;
  assign debug_app_load_seen_o = app_load_seen_q;
  assign debug_acc_seen_layers_o = acc_seen_layers_q;
endmodule

`endif
