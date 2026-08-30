`ifndef NR_LDPC_ITERATION_DECIDE_SV
`define NR_LDPC_ITERATION_DECIDE_SV

module nr_ldpc_iteration_decide (
  input  logic       syndrome_done_i,
  input  logic       syndrome_zero_i,
  input  logic [3:0] max_iterations_i,
  input  logic [3:0] completed_iterations_i,

  output logic       decision_valid_o,
  output logic       terminate_success_o,
  output logic       terminate_max_iterations_o,
  output logic       retry_next_iteration_o,
  output logic       illegal_config_o,
  output logic [3:0] completed_iterations_after_decide_o
);
  logic [3:0] completed_next_w;
  logic max_iterations_legal_w;

  assign completed_next_w = completed_iterations_i + 4'd1;
  assign max_iterations_legal_w = (max_iterations_i != 4'd0);

  assign illegal_config_o = !max_iterations_legal_w;
  assign decision_valid_o = syndrome_done_i && max_iterations_legal_w;
  assign completed_iterations_after_decide_o = completed_next_w;

  assign terminate_success_o = decision_valid_o && syndrome_zero_i;
  assign terminate_max_iterations_o = decision_valid_o
      && !syndrome_zero_i
      && (completed_next_w >= max_iterations_i);
  assign retry_next_iteration_o = decision_valid_o
      && !syndrome_zero_i
      && (completed_next_w < max_iterations_i);
endmodule

`endif
