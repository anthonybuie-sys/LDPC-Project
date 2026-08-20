`ifndef NR_LDPC_PKG_SV
`define NR_LDPC_PKG_SV

package nr_ldpc_pkg;
  localparam int P = 384;
  localparam int B = 2;

  localparam int D_A = 3;
  localparam int D_R = 3;

  localparam int NUM_APP_BANKS = 8;
  localparam int FORWARD_DEPTH = 8;
  localparam int NUM_ACC_CONTEXTS = 2;

  localparam int SYNDROME_S = 8;
  localparam int SYNDROME_Q = 8;

  localparam int W_CH = 6;
  localparam int W_APP = 8;
  localparam int W_Q = 8;
  localparam int W_M = 6;
  localparam int W_C2V = 7;
  localparam int W_ARITH = 9;

  localparam int CH_TO_APP_SHIFT = 1;
  localparam int BETA_INT = 1;

  localparam int SCHEDULE_WORD_W = 36;
  localparam int ISSUE_WORD_W = 72;

  localparam int REFERENCE_Z = 384;

  typedef logic signed [W_CH-1:0] ch_t;
  typedef logic signed [W_APP-1:0] app_t;
  typedef logic signed [W_Q-1:0] q_t;
  typedef logic [W_M-1:0] mag_t;
  typedef logic signed [W_C2V-1:0] c2v_t;
  typedef logic signed [W_ARITH-1:0] arith_t;
  typedef logic [W_ARITH-1:0] arith_mag_t;
endpackage

`endif
