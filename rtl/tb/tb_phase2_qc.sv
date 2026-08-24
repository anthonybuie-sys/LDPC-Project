`timescale 1ns/1ps

module tb_phase2_qc;
  import nr_ldpc_pkg::*;

  localparam int P_VAL = REFERENCE_Z;
  localparam int SHIFT_W = $clog2(P_VAL + 1);
  localparam int PROD_LANE_W = W_APP;
  localparam int LABEL_LANE_W = 16;

  logic [P_VAL*PROD_LANE_W-1:0] canonical8;
  logic [P_VAL*PROD_LANE_W-1:0] check8_in;
  logic [P_VAL*PROD_LANE_W-1:0] forward8_out;
  logic [P_VAL*PROD_LANE_W-1:0] inverse8_out;
  logic [P_VAL*PROD_LANE_W-1:0] structured8;
  logic [P_VAL*PROD_LANE_W-1:0] random8;
  logic [P_VAL*PROD_LANE_W-1:0] packing8;
  logic [P_VAL*PROD_LANE_W-1:0] onehot8;
  logic [P_VAL*PROD_LANE_W-1:0] tmp8;
  logic [P_VAL*PROD_LANE_W-1:0] tmp8_inverse;
  logic [SHIFT_W-1:0] shift8;
  logic illegal_fwd8;
  logic illegal_inv8;

  logic [P_VAL*LABEL_LANE_W-1:0] canonical16;
  logic [P_VAL*LABEL_LANE_W-1:0] check16_in;
  logic [P_VAL*LABEL_LANE_W-1:0] forward16_out;
  logic [P_VAL*LABEL_LANE_W-1:0] inverse16_out;
  logic [P_VAL*LABEL_LANE_W-1:0] label16;
  logic [P_VAL*LABEL_LANE_W-1:0] tmp16;
  logic [P_VAL*LABEL_LANE_W-1:0] tmp16_inverse;
  logic [SHIFT_W-1:0] shift16;
  logic illegal_fwd16;
  logic illegal_inv16;

  int errors;
  int obs_fd;

  nr_ldpc_qc_forward #(
    .P(P_VAL),
    .LANE_W(PROD_LANE_W)
  ) u_forward8 (
    .canonical_i(canonical8),
    .shift_i(shift8),
    .check_o(forward8_out),
    .illegal_shift_o(illegal_fwd8)
  );

  nr_ldpc_qc_inverse #(
    .P(P_VAL),
    .LANE_W(PROD_LANE_W)
  ) u_inverse8 (
    .check_i(check8_in),
    .shift_i(shift8),
    .canonical_o(inverse8_out),
    .illegal_shift_o(illegal_inv8)
  );

  nr_ldpc_qc_forward #(
    .P(P_VAL),
    .LANE_W(LABEL_LANE_W)
  ) u_forward16 (
    .canonical_i(canonical16),
    .shift_i(shift16),
    .check_o(forward16_out),
    .illegal_shift_o(illegal_fwd16)
  );

  nr_ldpc_qc_inverse #(
    .P(P_VAL),
    .LANE_W(LABEL_LANE_W)
  ) u_inverse16 (
    .check_i(check16_in),
    .shift_i(shift16),
    .canonical_o(inverse16_out),
    .illegal_shift_o(illegal_inv16)
  );

  function automatic int lane8(input logic [P_VAL*PROD_LANE_W-1:0] vec, input int lane);
    lane8 = vec[lane*PROD_LANE_W +: PROD_LANE_W];
  endfunction

  function automatic int lane16(input logic [P_VAL*LABEL_LANE_W-1:0] vec, input int lane);
    lane16 = vec[lane*LABEL_LANE_W +: LABEL_LANE_W];
  endfunction

  function automatic int src_forward(input int k, input int shift);
    int src;
    begin
      src = k + shift;
      if (src >= P_VAL) begin
        src = src - P_VAL;
      end
      src_forward = src;
    end
  endfunction

  function automatic int src_inverse(input int k, input int shift);
    int src;
    begin
      src = k - shift;
      if (src < 0) begin
        src = src + P_VAL;
      end
      src_inverse = src;
    end
  endfunction

  function automatic bit selected_shift(input int shift);
    begin
      case (shift)
        0, 1, 2, 17, 127, 191, 255, 383: selected_shift = 1'b1;
        default: selected_shift = 1'b0;
      endcase
    end
  endfunction

  task automatic fail(input string name, input int shift, input int lane, input int actual, input int expected);
    begin
      $display(
        "FAIL %s shift=%0d lane=%0d actual=0x%0h expected=0x%0h",
        name,
        shift,
        lane,
        actual,
        expected
      );
      errors++;
    end
  endtask

  task automatic check_int(input string name, input int actual, input int expected);
    begin
      if (actual != expected) begin
        $display("FAIL %s actual=%0d expected=%0d", name, actual, expected);
        errors++;
      end
    end
  endtask

  task automatic emit_observed8(
    input string vector_name,
    input string direction,
    input int shift,
    input logic [P_VAL*PROD_LANE_W-1:0] vec
  );
    int lane;
    begin
      for (lane = 0; lane < P_VAL; lane++) begin
        $fwrite(
          obs_fd,
          "%s,%s,%0d,%0d,%02x\n",
          vector_name,
          direction,
          shift,
          lane,
          lane8(vec, lane)
        );
      end
    end
  endtask

  task automatic check_forward8(
    input string vector_name,
    input logic [P_VAL*PROD_LANE_W-1:0] vec,
    input int shift,
    input bit emit_observed
  );
    int lane;
    int expected;
    begin
      canonical8 = vec;
      shift8 = shift;
      #1;
      check_int("forward8 illegal", illegal_fwd8, 0);
      for (lane = 0; lane < P_VAL; lane++) begin
        expected = lane8(vec, src_forward(lane, shift));
        if (lane8(forward8_out, lane) != expected) begin
          fail("forward8", shift, lane, lane8(forward8_out, lane), expected);
        end
      end
      if (emit_observed) begin
        emit_observed8(vector_name, "forward", shift, forward8_out);
      end
    end
  endtask

  task automatic check_inverse8(
    input string vector_name,
    input logic [P_VAL*PROD_LANE_W-1:0] vec,
    input int shift,
    input bit emit_observed
  );
    int lane;
    int expected;
    begin
      check8_in = vec;
      shift8 = shift;
      #1;
      check_int("inverse8 illegal", illegal_inv8, 0);
      for (lane = 0; lane < P_VAL; lane++) begin
        expected = lane8(vec, src_inverse(lane, shift));
        if (lane8(inverse8_out, lane) != expected) begin
          fail("inverse8", shift, lane, lane8(inverse8_out, lane), expected);
        end
      end
      if (emit_observed) begin
        emit_observed8(vector_name, "inverse", shift, inverse8_out);
      end
    end
  endtask

  task automatic check_roundtrip8(
    input string vector_name,
    input logic [P_VAL*PROD_LANE_W-1:0] vec,
    input int shift,
    input bit emit_observed
  );
    int lane;
    begin
      check_forward8(vector_name, vec, shift, emit_observed);
      tmp8 = forward8_out;
      check8_in = tmp8;
      shift8 = shift;
      #1;
      check_int("inverse(forward) illegal", illegal_inv8, 0);
      for (lane = 0; lane < P_VAL; lane++) begin
        if (lane8(inverse8_out, lane) != lane8(vec, lane)) begin
          fail("inverse(forward)8", shift, lane, lane8(inverse8_out, lane), lane8(vec, lane));
        end
      end

      check_inverse8(vector_name, vec, shift, emit_observed);
      tmp8_inverse = inverse8_out;
      canonical8 = tmp8_inverse;
      shift8 = shift;
      #1;
      check_int("forward(inverse) illegal", illegal_fwd8, 0);
      for (lane = 0; lane < P_VAL; lane++) begin
        if (lane8(forward8_out, lane) != lane8(vec, lane)) begin
          fail("forward(inverse)8", shift, lane, lane8(forward8_out, lane), lane8(vec, lane));
        end
      end
    end
  endtask

  task automatic check_forward16(
    input logic [P_VAL*LABEL_LANE_W-1:0] vec,
    input int shift
  );
    int lane;
    int expected;
    begin
      canonical16 = vec;
      shift16 = shift;
      #1;
      check_int("forward16 illegal", illegal_fwd16, 0);
      for (lane = 0; lane < P_VAL; lane++) begin
        expected = lane16(vec, src_forward(lane, shift));
        if (lane16(forward16_out, lane) != expected) begin
          fail("forward16", shift, lane, lane16(forward16_out, lane), expected);
        end
      end
    end
  endtask

  task automatic check_inverse16(
    input logic [P_VAL*LABEL_LANE_W-1:0] vec,
    input int shift
  );
    int lane;
    int expected;
    begin
      check16_in = vec;
      shift16 = shift;
      #1;
      check_int("inverse16 illegal", illegal_inv16, 0);
      for (lane = 0; lane < P_VAL; lane++) begin
        expected = lane16(vec, src_inverse(lane, shift));
        if (lane16(inverse16_out, lane) != expected) begin
          fail("inverse16", shift, lane, lane16(inverse16_out, lane), expected);
        end
      end
    end
  endtask

  task automatic check_roundtrip16(
    input logic [P_VAL*LABEL_LANE_W-1:0] vec,
    input int shift
  );
    int lane;
    begin
      check_forward16(vec, shift);
      tmp16 = forward16_out;
      check16_in = tmp16;
      shift16 = shift;
      #1;
      check_int("inverse(forward)16 illegal", illegal_inv16, 0);
      for (lane = 0; lane < P_VAL; lane++) begin
        if (lane16(inverse16_out, lane) != lane16(vec, lane)) begin
          fail("inverse(forward)16", shift, lane, lane16(inverse16_out, lane), lane16(vec, lane));
        end
      end

      check_inverse16(vec, shift);
      tmp16_inverse = inverse16_out;
      canonical16 = tmp16_inverse;
      shift16 = shift;
      #1;
      check_int("forward(inverse)16 illegal", illegal_fwd16, 0);
      for (lane = 0; lane < P_VAL; lane++) begin
        if (lane16(forward16_out, lane) != lane16(vec, lane)) begin
          fail("forward(inverse)16", shift, lane, lane16(forward16_out, lane), lane16(vec, lane));
        end
      end
    end
  endtask

  task automatic check_illegal_shift;
    begin
      canonical8 = structured8;
      check8_in = structured8;
      shift8 = 9'd384;
      #1;
      check_int("illegal forward shift flag", illegal_fwd8, 1);
      check_int("illegal inverse shift flag", illegal_inv8, 1);
      check_int("illegal forward output cleared", forward8_out === '0, 1);
      check_int("illegal inverse output cleared", inverse8_out === '0, 1);
    end
  endtask

  initial begin
    int lane;
    int shift;
    int seed;

    errors = 0;
    obs_fd = $fopen("results/rtl_phase2/qc_sv_observed.csv", "w");
    if (obs_fd == 0) begin
      $display("FAIL cannot open results/rtl_phase2/qc_sv_observed.csv");
      $finish(1);
    end
    $fwrite(obs_fd, "vector,direction,shift,lane,value_hex\n");

    structured8 = '0;
    random8 = '0;
    packing8 = '0;
    onehot8 = '0;
    label16 = '0;
    seed = 32'h4c445043;
    for (lane = 0; lane < P_VAL; lane++) begin
      structured8[lane*PROD_LANE_W +: PROD_LANE_W] =
          ((lane * 73) ^ (lane >> 1) ^ 8'hA5) & 8'hff;
      seed = (seed * 1103515245 + 12345) & 32'h7fffffff;
      random8[lane*PROD_LANE_W +: PROD_LANE_W] = (seed >> 8) & 8'hff;
      label16[lane*LABEL_LANE_W +: LABEL_LANE_W] = lane & 16'hffff;
    end

    packing8[0*PROD_LANE_W +: PROD_LANE_W] = 8'hA0;
    packing8[1*PROD_LANE_W +: PROD_LANE_W] = 8'hB1;
    packing8[383*PROD_LANE_W +: PROD_LANE_W] = 8'hC3;
    check_int("lane packing lane 0", lane8(packing8, 0), 8'hA0);
    check_int("lane packing lane 1", lane8(packing8, 1), 8'hB1);
    check_int("lane packing lane 383", lane8(packing8, 383), 8'hC3);

    onehot8[3*PROD_LANE_W +: PROD_LANE_W] = 8'h5A;
    check_forward8("onehot8", onehot8, 1, 1'b1);
    check_int("shift1 forward direction onehot", lane8(forward8_out, 2), 8'h5A);
    check_inverse8("onehot8", onehot8, 1, 1'b0);
    check_int("shift1 inverse direction onehot", lane8(inverse8_out, 4), 8'h5A);
    check_roundtrip8("onehot8", onehot8, 1, 1'b0);

    check_roundtrip8("packing8", packing8, 0, 1'b1);
    check_roundtrip8("packing8", packing8, 383, 1'b1);
    check_forward16(label16, 1);
    check_int("shift1 forward16 lane0", lane16(forward16_out, 0), 1);
    check_int("shift1 forward16 lane383", lane16(forward16_out, 383), 0);
    check_inverse16(label16, 1);
    check_int("shift1 inverse16 lane0", lane16(inverse16_out, 0), 383);
    check_int("shift1 inverse16 lane1", lane16(inverse16_out, 1), 0);
    check_roundtrip16(label16, 1);
    check_roundtrip16(label16, 383);

    for (shift = 0; shift < P_VAL; shift++) begin
      check_roundtrip8("structured8", structured8, shift, selected_shift(shift));
      check_roundtrip8("random8", random8, shift, selected_shift(shift));
      check_roundtrip16(label16, shift);
    end

    check_illegal_shift();
    $fclose(obs_fd);

    if (errors == 0) begin
      $display("PASS phase2 qc permutation");
      $finish;
    end

    $display("FAIL phase2 qc permutation errors=%0d", errors);
    $finish(1);
  end
endmodule
