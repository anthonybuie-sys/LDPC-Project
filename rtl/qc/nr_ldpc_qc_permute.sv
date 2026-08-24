`ifndef NR_LDPC_QC_PERMUTE_SV
`define NR_LDPC_QC_PERMUTE_SV

module nr_ldpc_qc_permute_core #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z,
  parameter int LANE_W = nr_ldpc_pkg::W_APP,
  parameter bit INVERSE = 1'b0
) (
  input  logic [P*LANE_W-1:0]                 vector_i,
  input  logic [$clog2(P+1)-1:0]              shift_i,
  output logic [P*LANE_W-1:0]                 vector_o,
  output logic                                illegal_shift_o
);
  import nr_ldpc_pkg::*;

  int k;
  int src;
  int shift_value;

`ifndef SYNTHESIS
  initial begin
    if (P != REFERENCE_Z) begin
      $error("Phase-2 QC production RTL only supports P=REFERENCE_Z=384.");
    end
    if (LANE_W <= 0) begin
      $error("LANE_W must be positive.");
    end
  end
`endif

  // Packed lane convention: lane k is vector[k*LANE_W +: LANE_W].
  always @* begin
    vector_o = '0;
    shift_value = int'(shift_i);
    illegal_shift_o = (shift_value < 0) || (shift_value >= P);

    if (!illegal_shift_o) begin
      for (k = 0; k < P; k++) begin
        if (INVERSE) begin
          src = k - shift_value;
          if (src < 0) begin
            src = src + P;
          end
        end else begin
          src = k + shift_value;
          if (src >= P) begin
            src = src - P;
          end
        end
        vector_o[k*LANE_W +: LANE_W] = vector_i[src*LANE_W +: LANE_W];
      end
    end
  end
endmodule

module nr_ldpc_qc_forward #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z,
  parameter int LANE_W = nr_ldpc_pkg::W_APP
) (
  input  logic [P*LANE_W-1:0]    canonical_i,
  input  logic [$clog2(P+1)-1:0] shift_i,
  output logic [P*LANE_W-1:0]    check_o,
  output logic                   illegal_shift_o
);
  nr_ldpc_qc_permute_core #(
    .P(P),
    .LANE_W(LANE_W),
    .INVERSE(1'b0)
  ) u_core (
    .vector_i(canonical_i),
    .shift_i(shift_i),
    .vector_o(check_o),
    .illegal_shift_o(illegal_shift_o)
  );
endmodule

module nr_ldpc_qc_inverse #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z,
  parameter int LANE_W = nr_ldpc_pkg::W_APP
) (
  input  logic [P*LANE_W-1:0]    check_i,
  input  logic [$clog2(P+1)-1:0] shift_i,
  output logic [P*LANE_W-1:0]    canonical_o,
  output logic                   illegal_shift_o
);
  nr_ldpc_qc_permute_core #(
    .P(P),
    .LANE_W(LANE_W),
    .INVERSE(1'b1)
  ) u_core (
    .vector_i(check_i),
    .shift_i(shift_i),
    .vector_o(canonical_o),
    .illegal_shift_o(illegal_shift_o)
  );
endmodule

`endif
