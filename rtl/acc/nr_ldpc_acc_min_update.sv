`ifndef NR_LDPC_ACC_MIN_UPDATE_SV
`define NR_LDPC_ACC_MIN_UPDATE_SV

module nr_ldpc_acc_min_update
  import nr_ldpc_pkg::*;
(
  input  logic [5:0] edge_count_i,
  input  logic [5:0] min1_i,
  input  logic [5:0] min2_i,
  input  logic [4:0] imin_i,
  input  logic       aggregate_sign_i,

  input  logic       cand0_valid_i,
  input  logic [5:0] cand0_mag_i,
  input  logic [4:0] cand0_edge_id_i,
  input  logic       cand0_sign_i,

  input  logic       cand1_valid_i,
  input  logic [5:0] cand1_mag_i,
  input  logic [4:0] cand1_edge_id_i,
  input  logic       cand1_sign_i,

  output logic [5:0] edge_count_o,
  output logic [5:0] min1_o,
  output logic [5:0] min2_o,
  output logic [4:0] imin_o,
  output logic       aggregate_sign_o
);
  logic [5:0] next_edge_count;
  logic [5:0] next_min1;
  logic [5:0] next_min2;
  logic [4:0] next_imin;
  logic next_aggregate_sign;

  task automatic insert_candidate(
    input  logic [5:0] cand_mag,
    input  logic [4:0] cand_edge_id
  );
    begin
      if (next_edge_count == 6'd0) begin
        next_min1 = cand_mag;
        next_imin = cand_edge_id;
      end else if (next_edge_count == 6'd1) begin
        if (cand_mag < next_min1) begin
          next_min2 = next_min1;
          next_min1 = cand_mag;
          next_imin = cand_edge_id;
        end else if (cand_mag == next_min1) begin
          next_min2 = next_min1;
          if (cand_edge_id < next_imin) begin
            next_imin = cand_edge_id;
          end
        end else begin
          next_min2 = cand_mag;
        end
      end else begin
        if (cand_mag < next_min1) begin
          next_min2 = next_min1;
          next_min1 = cand_mag;
          next_imin = cand_edge_id;
        end else if (cand_mag == next_min1) begin
          next_min2 = next_min1;
          if (cand_edge_id < next_imin) begin
            next_imin = cand_edge_id;
          end
        end else if (cand_mag < next_min2) begin
          next_min2 = cand_mag;
        end
      end

      next_edge_count = next_edge_count + 6'd1;
    end
  endtask

  always @* begin
    next_edge_count = edge_count_i;
    next_min1 = min1_i;
    next_min2 = min2_i;
    next_imin = imin_i;
    next_aggregate_sign = aggregate_sign_i;

    if (cand0_valid_i && cand1_valid_i && (cand1_edge_id_i < cand0_edge_id_i)) begin
      insert_candidate(cand1_mag_i, cand1_edge_id_i);
      insert_candidate(cand0_mag_i, cand0_edge_id_i);
    end else begin
      if (cand0_valid_i) begin
        insert_candidate(cand0_mag_i, cand0_edge_id_i);
      end
      if (cand1_valid_i) begin
        insert_candidate(cand1_mag_i, cand1_edge_id_i);
      end
    end

    if (cand0_valid_i) begin
      next_aggregate_sign = next_aggregate_sign ^ cand0_sign_i;
    end
    if (cand1_valid_i) begin
      next_aggregate_sign = next_aggregate_sign ^ cand1_sign_i;
    end

    edge_count_o = next_edge_count;
    min1_o = next_min1;
    min2_o = next_min2;
    imin_o = next_imin;
    aggregate_sign_o = next_aggregate_sign;
  end
endmodule

`endif
