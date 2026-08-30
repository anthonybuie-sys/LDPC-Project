`ifndef NR_LDPC_SYNDROME_ENGINE_SV
`define NR_LDPC_SYNDROME_ENGINE_SV

module nr_ldpc_syndrome_engine #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z,
  parameter int S = nr_ldpc_pkg::SYNDROME_S,
  parameter int Q = nr_ldpc_pkg::SYNDROME_Q
) (
  input  logic                         clk_i,
  input  logic                         rst_i,
  input  logic                         start_iteration_i,
  input  logic [3:0]                   iteration_epoch_i,

  input  logic [1:0]                   final_touch_valid_i,
  input  logic [6:0]                   final_touch_base_column0_i,
  input  logic [6:0]                   final_touch_base_column1_i,
  input  logic [3:0]                   final_touch_iteration_epoch_i,
  input  logic [P-1:0]                 final_touch_hard0_i,
  input  logic [P-1:0]                 final_touch_hard1_i,

  output logic                         syndrome_done_o,
  output logic                         syndrome_zero_o,
  output logic [P-1:0]                 syndrome_row0_o,
  output logic [P-1:0]                 syndrome_row1_o,
  output logic [P-1:0]                 syndrome_row2_o,
  output logic [P-1:0]                 syndrome_row3_o,

  output logic                         error_valid_o,
  output logic [7:0]                   error_code_o,

  output logic [5:0]                   finalized_columns_count_o,
  output logic [6:0]                   consumed_work_items_count_o,
  output logic [3:0]                   queue_occupancy_o,
  output logic [3:0]                   max_queue_occupancy_o,
  output logic [6:0]                   max_syndrome_backlog_o,
  output logic [3:0]                   work_items_consumed_this_cycle_o
);
  import nr_ldpc_pkg::*;
  import nr_ldpc_syndrome_profile_bg1_first4_pkg::*;

  localparam int SHIFT_W = $clog2(P + 1);
  localparam int PLAN_Q = Q + 2;

  localparam logic [5:0] PHASE8_ACTIVE_COLUMNS_W = PHASE8_ACTIVE_COLUMNS;
  localparam logic [6:0] PHASE8_WORK_ITEMS_W = PHASE8_WORK_ITEMS;
  localparam logic [PHASE8_ACTIVE_COLUMNS-1:0] ALL_COLUMNS_MASK = {PHASE8_ACTIVE_COLUMNS{1'b1}};
  localparam logic [PHASE8_WORK_ITEMS-1:0] ALL_WORK_MASK = {PHASE8_WORK_ITEMS{1'b1}};

  localparam logic [7:0] ERR_QUEUE_OVERFLOW      = 8'd1;
  localparam logic [7:0] ERR_DUPLICATE_COLUMN    = 8'd2;
  localparam logic [7:0] ERR_INACTIVE_COLUMN     = 8'd3;
  localparam logic [7:0] ERR_EPOCH_MISMATCH      = 8'd4;
  localparam logic [7:0] ERR_MALFORMED_DUAL_LANE = 8'd5;
  localparam logic [7:0] ERR_DUPLICATE_WORK      = 8'd6;
  localparam logic [7:0] ERR_INVALID_WORK_TABLE  = 8'd7;
  localparam logic [7:0] ERR_IMPOSSIBLE_ITERATOR = 8'd8;
  localparam logic [7:0] ERR_COMPLETION_MISMATCH = 8'd9;

  logic [6:0] queue_column_q [0:Q-1];
  logic [P-1:0] queue_hard_q [0:Q-1];
  logic [4:0] queue_next_work_q [0:Q-1];
  logic [3:0] queue_count_q;

  logic [PHASE8_ACTIVE_COLUMNS-1:0] finalized_mask_q;
  logic [PHASE8_WORK_ITEMS-1:0] work_seen_q;
  logic [5:0] finalized_count_q;
  logic [6:0] consumed_count_q;

  logic [P-1:0] row0_q;
  logic [P-1:0] row1_q;
  logic [P-1:0] row2_q;
  logic [P-1:0] row3_q;

  logic [3:0] max_queue_q;
  logic [6:0] max_backlog_q;
  logic [3:0] consumed_this_cycle_q;
  logic done_q;
  logic zero_q;
  logic error_q;
  logic [7:0] error_code_q;

  logic [6:0] queue_column_next_w [0:Q-1];
  logic [P-1:0] queue_hard_next_w [0:Q-1];
  logic [4:0] queue_next_work_next_w [0:Q-1];
  logic [3:0] queue_count_next_w;

  logic [PHASE8_ACTIVE_COLUMNS-1:0] finalized_mask_next_w;
  logic [PHASE8_WORK_ITEMS-1:0] work_seen_next_w;
  logic [5:0] finalized_count_next_w;
  logic [6:0] consumed_count_next_w;

  logic [6:0] plan_column [0:PLAN_Q-1];
  logic [P-1:0] plan_hard [0:PLAN_Q-1];
  logic [4:0] plan_next_work [0:PLAN_Q-1];
  logic [3:0] plan_count;

  logic [S-1:0] consume_valid_w;
  logic [6:0] consume_work_id_w [0:S-1];
  logic [1:0] consume_row_w [0:S-1];
  logic [6:0] consume_column_w [0:S-1];
  logic [8:0] consume_shift_w [0:S-1];
  logic [P-1:0] consume_hard_w [0:S-1];
  logic [P-1:0] consume_check_w [0:S-1];
  logic [S-1:0] consume_shift_error_w;

  logic [P-1:0] row_delta0_w;
  logic [P-1:0] row_delta1_w;
  logic [P-1:0] row_delta2_w;
  logic [P-1:0] row_delta3_w;
  logic [P-1:0] row0_next_w;
  logic [P-1:0] row1_next_w;
  logic [P-1:0] row2_next_w;
  logic [P-1:0] row3_next_w;

  logic plan_error_w;
  logic [7:0] plan_error_code_w;
  logic shift_error_w;
  logic completion_candidate_w;
  logic completion_mismatch_w;
  logic cycle_error_w;
  logic [7:0] cycle_error_code_w;
  logic done_next_w;
  logic zero_next_w;
  logic [3:0] cycle_queue_occupancy_w;
  logic [6:0] cycle_work_backlog_w;
  logic [3:0] consumed_this_cycle_w;

  genvar g;
  generate
    for (g = 0; g < S; g++) begin : gen_qc_forward
      nr_ldpc_qc_forward #(
        .P(P),
        .LANE_W(1)
      ) u_qc_forward (
        .canonical_i(consume_hard_w[g]),
        .shift_i(consume_shift_w[g][SHIFT_W-1:0]),
        .check_o(consume_check_w[g]),
        .illegal_shift_o(consume_shift_error_w[g])
      );
    end
  endgenerate

  integer i;
  integer j;
  integer slot;
  integer backlog_int;
  integer enq_count_int;
  logic [4:0] column_index_w;
  logic [6:0] work_id_w;
  logic [4:0] work_index_w;
  logic [4:0] work_count_w;

  always @* begin
    for (i = 0; i < Q; i = i + 1) begin
      queue_column_next_w[i] = queue_column_q[i];
      queue_hard_next_w[i] = queue_hard_q[i];
      queue_next_work_next_w[i] = queue_next_work_q[i];
    end

    for (i = 0; i < PLAN_Q; i = i + 1) begin
      plan_column[i] = 7'd0;
      plan_hard[i] = '0;
      plan_next_work[i] = 5'd0;
    end

    for (i = 0; i < S; i = i + 1) begin
      consume_valid_w[i] = 1'b0;
      consume_work_id_w[i] = 7'd0;
      consume_row_w[i] = 2'd0;
      consume_column_w[i] = 7'd0;
      consume_shift_w[i] = 9'd0;
      consume_hard_w[i] = '0;
    end

    plan_error_w = 1'b0;
    plan_error_code_w = 8'd0;
    finalized_mask_next_w = finalized_mask_q;
    work_seen_next_w = work_seen_q;
    finalized_count_next_w = finalized_count_q;
    consumed_count_next_w = consumed_count_q;
    queue_count_next_w = queue_count_q;
    cycle_queue_occupancy_w = queue_count_q;
    cycle_work_backlog_w = 7'd0;
    consumed_this_cycle_w = 4'd0;
    plan_count = queue_count_q;
    enq_count_int = 0;

    for (i = 0; i < Q; i = i + 1) begin
      if (i < queue_count_q) begin
        plan_column[i] = queue_column_q[i];
        plan_hard[i] = queue_hard_q[i];
        plan_next_work[i] = queue_next_work_q[i];
      end
    end

    if (!done_q && !error_q) begin
      if ((final_touch_valid_i == 2'b11)
          && (final_touch_base_column0_i == final_touch_base_column1_i)) begin
        plan_error_w = 1'b1;
        plan_error_code_w = ERR_MALFORMED_DUAL_LANE;
      end

      if (|final_touch_valid_i && (final_touch_iteration_epoch_i != iteration_epoch_i)) begin
        plan_error_w = 1'b1;
        if (plan_error_code_w == 8'd0) begin
          plan_error_code_w = ERR_EPOCH_MISMATCH;
        end
      end

      if (final_touch_valid_i[0]) begin
        if (!phase8_active_column(final_touch_base_column0_i)) begin
          plan_error_w = 1'b1;
          if (plan_error_code_w == 8'd0) begin
            plan_error_code_w = ERR_INACTIVE_COLUMN;
          end
        end else begin
          column_index_w = phase8_column_index(final_touch_base_column0_i);
          if (finalized_mask_next_w[column_index_w]) begin
            plan_error_w = 1'b1;
            if (plan_error_code_w == 8'd0) begin
              plan_error_code_w = ERR_DUPLICATE_COLUMN;
            end
          end else begin
            finalized_mask_next_w[column_index_w] = 1'b1;
            finalized_count_next_w = finalized_count_next_w + 6'd1;
            plan_column[plan_count] = final_touch_base_column0_i;
            plan_hard[plan_count] = final_touch_hard0_i;
            plan_next_work[plan_count] = 5'd0;
            plan_count = plan_count + 4'd1;
            enq_count_int = enq_count_int + 1;
          end
        end
      end

      if (final_touch_valid_i[1]) begin
        if (!phase8_active_column(final_touch_base_column1_i)) begin
          plan_error_w = 1'b1;
          if (plan_error_code_w == 8'd0) begin
            plan_error_code_w = ERR_INACTIVE_COLUMN;
          end
        end else begin
          column_index_w = phase8_column_index(final_touch_base_column1_i);
          if (finalized_mask_next_w[column_index_w]) begin
            plan_error_w = 1'b1;
            if (plan_error_code_w == 8'd0) begin
              plan_error_code_w = ERR_DUPLICATE_COLUMN;
            end
          end else begin
            finalized_mask_next_w[column_index_w] = 1'b1;
            finalized_count_next_w = finalized_count_next_w + 6'd1;
            plan_column[plan_count] = final_touch_base_column1_i;
            plan_hard[plan_count] = final_touch_hard1_i;
            plan_next_work[plan_count] = 5'd0;
            plan_count = plan_count + 4'd1;
            enq_count_int = enq_count_int + 1;
          end
        end
      end

      if ((queue_count_q + enq_count_int) > Q) begin
        plan_error_w = 1'b1;
        if (plan_error_code_w == 8'd0) begin
          plan_error_code_w = ERR_QUEUE_OVERFLOW;
        end
      end

      cycle_queue_occupancy_w = plan_count;
      backlog_int = 0;
      for (i = 0; i < PLAN_Q; i = i + 1) begin
        if (i < plan_count) begin
          work_count_w = phase8_column_work_count(plan_column[i]);
          if (plan_next_work[i] > work_count_w) begin
            plan_error_w = 1'b1;
            if (plan_error_code_w == 8'd0) begin
              plan_error_code_w = ERR_IMPOSSIBLE_ITERATOR;
            end
          end else begin
            backlog_int = backlog_int + int'(work_count_w - plan_next_work[i]);
          end
        end
      end
      cycle_work_backlog_w = backlog_int[6:0];

      if (!plan_error_w) begin
        for (slot = 0; slot < S; slot = slot + 1) begin
          if (plan_count != 4'd0) begin
            work_index_w = plan_next_work[0];
            work_count_w = phase8_column_work_count(plan_column[0]);
            if (work_index_w >= work_count_w) begin
              plan_error_w = 1'b1;
              if (plan_error_code_w == 8'd0) begin
                plan_error_code_w = ERR_IMPOSSIBLE_ITERATOR;
              end
            end else begin
              work_id_w = phase8_column_work_start(plan_column[0]) + work_index_w;
              consume_valid_w[slot] = 1'b1;
              consume_work_id_w[slot] = work_id_w;
              consume_row_w[slot] = phase8_work_row(work_id_w);
              consume_column_w[slot] = phase8_work_column(work_id_w);
              consume_shift_w[slot] = phase8_work_shift(work_id_w);
              consume_hard_w[slot] = plan_hard[0];
              consumed_this_cycle_w = consumed_this_cycle_w + 4'd1;

              if (!phase8_work_valid(work_id_w)
                  || (phase8_work_column(work_id_w) != plan_column[0])) begin
                plan_error_w = 1'b1;
                if (plan_error_code_w == 8'd0) begin
                  plan_error_code_w = ERR_INVALID_WORK_TABLE;
                end
              end else if (work_seen_next_w[work_id_w]) begin
                plan_error_w = 1'b1;
                if (plan_error_code_w == 8'd0) begin
                  plan_error_code_w = ERR_DUPLICATE_WORK;
                end
              end else begin
                work_seen_next_w[work_id_w] = 1'b1;
                consumed_count_next_w = consumed_count_next_w + 7'd1;
              end

              plan_next_work[0] = plan_next_work[0] + 5'd1;
              if (plan_next_work[0] >= work_count_w) begin
                for (j = 0; j < PLAN_Q - 1; j = j + 1) begin
                  plan_column[j] = plan_column[j + 1];
                  plan_hard[j] = plan_hard[j + 1];
                  plan_next_work[j] = plan_next_work[j + 1];
                end
                plan_column[PLAN_Q - 1] = 7'd0;
                plan_hard[PLAN_Q - 1] = '0;
                plan_next_work[PLAN_Q - 1] = 5'd0;
                plan_count = plan_count - 4'd1;
              end
            end
          end
        end
      end
    end

    queue_count_next_w = plan_count;
    for (i = 0; i < Q; i = i + 1) begin
      if (i < plan_count) begin
        queue_column_next_w[i] = plan_column[i];
        queue_hard_next_w[i] = plan_hard[i];
        queue_next_work_next_w[i] = plan_next_work[i];
      end else begin
        queue_column_next_w[i] = 7'd0;
        queue_next_work_next_w[i] = 5'd0;
      end
    end
  end

  always @* begin
    row_delta0_w = '0;
    row_delta1_w = '0;
    row_delta2_w = '0;
    row_delta3_w = '0;
    for (i = 0; i < S; i = i + 1) begin
      if (consume_valid_w[i]) begin
        case (consume_row_w[i])
          2'd0: row_delta0_w = row_delta0_w ^ consume_check_w[i];
          2'd1: row_delta1_w = row_delta1_w ^ consume_check_w[i];
          2'd2: row_delta2_w = row_delta2_w ^ consume_check_w[i];
          2'd3: row_delta3_w = row_delta3_w ^ consume_check_w[i];
          default: begin end
        endcase
      end
    end

    row0_next_w = row0_q ^ row_delta0_w;
    row1_next_w = row1_q ^ row_delta1_w;
    row2_next_w = row2_q ^ row_delta2_w;
    row3_next_w = row3_q ^ row_delta3_w;
  end

  always @* begin
    shift_error_w = 1'b0;
    for (i = 0; i < S; i = i + 1) begin
      shift_error_w = shift_error_w || (consume_valid_w[i] && consume_shift_error_w[i]);
    end

    completion_candidate_w = !done_q
        && !error_q
        && (finalized_count_next_w == PHASE8_ACTIVE_COLUMNS_W)
        && (consumed_count_next_w == PHASE8_WORK_ITEMS_W)
        && (queue_count_next_w == 4'd0);
    completion_mismatch_w = completion_candidate_w
        && ((finalized_mask_next_w != ALL_COLUMNS_MASK)
            || (work_seen_next_w != ALL_WORK_MASK));
    cycle_error_w = plan_error_w || shift_error_w || completion_mismatch_w;
    cycle_error_code_w = plan_error_code_w;
    if (shift_error_w && (cycle_error_code_w == 8'd0)) begin
      cycle_error_code_w = ERR_INVALID_WORK_TABLE;
    end
    if (completion_mismatch_w && (cycle_error_code_w == 8'd0)) begin
      cycle_error_code_w = ERR_COMPLETION_MISMATCH;
    end

    done_next_w = completion_candidate_w && !cycle_error_w;
    zero_next_w = (row0_next_w == '0) && (row1_next_w == '0)
        && (row2_next_w == '0) && (row3_next_w == '0);
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      queue_count_q <= 4'd0;
      finalized_mask_q <= '0;
      work_seen_q <= '0;
      finalized_count_q <= 6'd0;
      consumed_count_q <= 7'd0;
      row0_q <= '0;
      row1_q <= '0;
      row2_q <= '0;
      row3_q <= '0;
      max_queue_q <= 4'd0;
      max_backlog_q <= 7'd0;
      consumed_this_cycle_q <= 4'd0;
      done_q <= 1'b0;
      zero_q <= 1'b0;
      error_q <= 1'b0;
      error_code_q <= 8'd0;
      for (i = 0; i < Q; i = i + 1) begin
        queue_column_q[i] <= 7'd0;
        queue_next_work_q[i] <= 5'd0;
      end
    end else if (start_iteration_i) begin
      queue_count_q <= 4'd0;
      finalized_mask_q <= '0;
      work_seen_q <= '0;
      finalized_count_q <= 6'd0;
      consumed_count_q <= 7'd0;
      row0_q <= '0;
      row1_q <= '0;
      row2_q <= '0;
      row3_q <= '0;
      max_queue_q <= 4'd0;
      max_backlog_q <= 7'd0;
      consumed_this_cycle_q <= 4'd0;
      done_q <= 1'b0;
      zero_q <= 1'b0;
      error_q <= 1'b0;
      error_code_q <= 8'd0;
      for (i = 0; i < Q; i = i + 1) begin
        queue_column_q[i] <= 7'd0;
        queue_next_work_q[i] <= 5'd0;
      end
    end else if (error_q || done_q) begin
      consumed_this_cycle_q <= 4'd0;
    end else if (cycle_error_w) begin
      error_q <= 1'b1;
      error_code_q <= cycle_error_code_w;
      consumed_this_cycle_q <= 4'd0;
    end else begin
      queue_count_q <= queue_count_next_w;
      finalized_mask_q <= finalized_mask_next_w;
      work_seen_q <= work_seen_next_w;
      finalized_count_q <= finalized_count_next_w;
      consumed_count_q <= consumed_count_next_w;
      row0_q <= row0_next_w;
      row1_q <= row1_next_w;
      row2_q <= row2_next_w;
      row3_q <= row3_next_w;
      consumed_this_cycle_q <= consumed_this_cycle_w;
      if (cycle_queue_occupancy_w > max_queue_q) begin
        max_queue_q <= cycle_queue_occupancy_w;
      end
      if (cycle_work_backlog_w > max_backlog_q) begin
        max_backlog_q <= cycle_work_backlog_w;
      end
      if (done_next_w) begin
        done_q <= 1'b1;
        zero_q <= zero_next_w;
      end
      for (i = 0; i < Q; i = i + 1) begin
        queue_column_q[i] <= queue_column_next_w[i];
        queue_hard_q[i] <= queue_hard_next_w[i];
        queue_next_work_q[i] <= queue_next_work_next_w[i];
      end
    end
  end

  assign syndrome_done_o = done_q;
  assign syndrome_zero_o = zero_q;
  assign syndrome_row0_o = row0_q;
  assign syndrome_row1_o = row1_q;
  assign syndrome_row2_o = row2_q;
  assign syndrome_row3_o = row3_q;
  assign error_valid_o = error_q;
  assign error_code_o = error_code_q;
  assign finalized_columns_count_o = finalized_count_q;
  assign consumed_work_items_count_o = consumed_count_q;
  assign queue_occupancy_o = queue_count_q;
  assign max_queue_occupancy_o = max_queue_q;
  assign max_syndrome_backlog_o = max_backlog_q;
  assign work_items_consumed_this_cycle_o = consumed_this_cycle_q;
endmodule

`endif
