`ifndef NR_LDPC_C2V_RECONSTRUCT_SV
`define NR_LDPC_C2V_RECONSTRUCT_SV

module nr_ldpc_compressed_c2v_reconstruct_lane (
  input  logic [5:0]        m1_i,
  input  logic [5:0]        m2_i,
  input  logic [4:0]        imin_i,
  input  logic              aggregate_sign_i,
  input  logic              q_sign_i,
  input  logic [4:0]        local_edge_id_i,
  output logic signed [6:0] c2v_o
);
  logic [5:0] selected_magnitude;
  logic negative;

  assign selected_magnitude = (local_edge_id_i == imin_i) ? m2_i : m1_i;
  assign negative = aggregate_sign_i ^ q_sign_i;

  nr_ldpc_c2v_reconstruct u_reconstruct (
    .magnitude_i(selected_magnitude),
    .negative_i(negative),
    .c2v_o(c2v_o)
  );
endmodule

module nr_ldpc_compressed_c2v_reconstruct_vector #(
  parameter int P = nr_ldpc_pkg::REFERENCE_Z
) (
  input  logic [P*6-1:0]        m1_i,
  input  logic [P*6-1:0]        m2_i,
  input  logic [P*5-1:0]        imin_i,
  input  logic [P-1:0]          aggregate_sign_i,
  input  logic [P-1:0]          q_sign_i,
  input  logic [4:0]            local_edge_id_i,
  output logic [P*7-1:0]        c2v_o
);
  import nr_ldpc_pkg::*;

`ifndef SYNTHESIS
  initial begin
    if (P != REFERENCE_Z) begin
      $error("Phase-3 compressed C2V production RTL only supports P=REFERENCE_Z=384.");
    end
  end
`endif

  genvar lane;
  generate
    for (lane = 0; lane < P; lane++) begin : gen_lane
      // Packed lane convention: lane k is vector[k*field_width +: field_width].
      nr_ldpc_compressed_c2v_reconstruct_lane u_lane (
        .m1_i(m1_i[lane*6 +: 6]),
        .m2_i(m2_i[lane*6 +: 6]),
        .imin_i(imin_i[lane*5 +: 5]),
        .aggregate_sign_i(aggregate_sign_i[lane]),
        .q_sign_i(q_sign_i[lane]),
        .local_edge_id_i(local_edge_id_i),
        .c2v_o(c2v_o[lane*7 +: 7])
      );
    end
  endgenerate
endmodule

`endif
