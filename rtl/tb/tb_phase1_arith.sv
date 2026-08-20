`timescale 1ns/1ps

module tb_phase1_arith;
  import nr_ldpc_pkg::*;

  arith_t sat_in;
  app_t sat_out;

  app_t app_in;
  c2v_t old_c2v_in;
  q_t q_out;
  arith_t q_raw;

  q_t mag_q_in;
  logic mag_sign;
  arith_mag_t mag_raw;
  mag_t mag_m6;

  mag_t beta_raw_mag;
  mag_t beta_offset_mag;

  mag_t c2v_mag;
  logic c2v_negative;
  c2v_t c2v_out;

  q_t add_q_in;
  c2v_t add_c2v_in;
  app_t app_out;
  arith_t app_raw;

  ch_t ch_in;
  app_t init_app_out;
  arith_t init_raw;

  int errors;

  nr_ldpc_sat_signed #(.IN_W(W_ARITH), .OUT_W(W_APP)) u_sat (
    .in_i(sat_in),
    .out_o(sat_out)
  );

  nr_ldpc_q_sub u_q_sub (
    .app_i(app_in),
    .old_c2v_i(old_c2v_in),
    .q_o(q_out),
    .raw_o(q_raw)
  );

  nr_ldpc_q_magnitude u_q_mag (
    .q_i(mag_q_in),
    .sign_o(mag_sign),
    .magnitude_raw_o(mag_raw),
    .magnitude_m6_o(mag_m6)
  );

  nr_ldpc_beta_sub u_beta (
    .raw_mag_i(beta_raw_mag),
    .offset_mag_o(beta_offset_mag)
  );

  nr_ldpc_c2v_reconstruct u_c2v (
    .magnitude_i(c2v_mag),
    .negative_i(c2v_negative),
    .c2v_o(c2v_out)
  );

  nr_ldpc_app_add u_app_add (
    .q_i(add_q_in),
    .new_c2v_i(add_c2v_in),
    .app_o(app_out),
    .raw_o(app_raw)
  );

  nr_ldpc_ch_to_app_init u_init (
    .ch_i(ch_in),
    .app_o(init_app_out),
    .raw_o(init_raw)
  );

  function automatic int ref_sat_signed(input int value, input int width);
    int lo;
    int hi;
    begin
      lo = -(1 << (width - 1));
      hi = (1 << (width - 1)) - 1;
      if (value < lo) begin
        ref_sat_signed = lo;
      end else if (value > hi) begin
        ref_sat_signed = hi;
      end else begin
        ref_sat_signed = value;
      end
    end
  endfunction

  function automatic int ref_abs(input int value);
    begin
      ref_abs = (value < 0) ? -value : value;
    end
  endfunction

  task automatic check_int(input string name, input int actual, input int expected);
    begin
      if (actual != expected) begin
        $display("FAIL %s actual=%0d expected=%0d", name, actual, expected);
        errors++;
      end
    end
  endtask

  task automatic check_sat(input int raw);
    begin
      sat_in = raw;
      #1;
      check_int("sat9_to_8", $signed(sat_out), ref_sat_signed(raw, W_APP));
    end
  endtask

  task automatic check_q_sub(input int app, input int old_c2v);
    int expected_raw;
    int expected_q;
    begin
      app_in = app;
      old_c2v_in = old_c2v;
      #1;
      expected_raw = app - old_c2v;
      expected_q = ref_sat_signed(expected_raw, W_Q);
      check_int("q_sub.raw", $signed(q_raw), expected_raw);
      check_int("q_sub.q", $signed(q_out), expected_q);
    end
  endtask

  task automatic check_magnitude(input int q);
    int expected_sign;
    int expected_raw;
    int expected_m6;
    begin
      mag_q_in = q;
      #1;
      expected_sign = (q < 0) ? 1 : 0;
      expected_raw = ref_abs(q);
      expected_m6 = (expected_raw > 63) ? 63 : expected_raw;
      check_int("q_mag.sign", mag_sign, expected_sign);
      check_int("q_mag.raw", mag_raw, expected_raw);
      check_int("q_mag.m6", mag_m6, expected_m6);
    end
  endtask

  task automatic check_beta(input int raw_mag);
    int expected;
    begin
      beta_raw_mag = raw_mag;
      #1;
      expected = (raw_mag > BETA_INT) ? (raw_mag - BETA_INT) : 0;
      check_int("beta_sub", beta_offset_mag, expected);
    end
  endtask

  task automatic check_c2v(input int magnitude, input int negative);
    int expected;
    begin
      c2v_mag = magnitude;
      c2v_negative = negative[0];
      #1;
      if (magnitude == 0) begin
        expected = 0;
      end else if (negative) begin
        expected = -magnitude;
      end else begin
        expected = magnitude;
      end
      check_int("c2v_reconstruct", $signed(c2v_out), expected);
    end
  endtask

  task automatic check_app_add(input int q, input int c2v);
    int expected_raw;
    int expected_app;
    begin
      add_q_in = q;
      add_c2v_in = c2v;
      #1;
      expected_raw = q + c2v;
      expected_app = ref_sat_signed(expected_raw, W_APP);
      check_int("app_add.raw", $signed(app_raw), expected_raw);
      check_int("app_add.app", $signed(app_out), expected_app);
    end
  endtask

  task automatic check_ch_init(input int ch);
    int expected_raw;
    int expected_app;
    begin
      ch_in = ch;
      #1;
      expected_raw = ch <<< CH_TO_APP_SHIFT;
      expected_app = ref_sat_signed(expected_raw, W_APP);
      check_int("ch_to_app.raw", $signed(init_raw), expected_raw);
      check_int("ch_to_app.app", $signed(init_app_out), expected_app);
    end
  endtask

  initial begin
    int raw;
    int app;
    int c2v;
    int q;
    int mag;
    int ch;
    errors = 0;

    if (P != 384 || B != 2 || D_A != 3 || D_R != 3) begin
      $display("FAIL frozen architecture constants");
      errors++;
    end
    if (NUM_APP_BANKS != 8 || FORWARD_DEPTH != 8 || NUM_ACC_CONTEXTS != 2) begin
      $display("FAIL frozen memory/forward/context constants");
      errors++;
    end
    if (SYNDROME_S != 8 || SYNDROME_Q != 8) begin
      $display("FAIL frozen syndrome constants");
      errors++;
    end
    if (W_CH != 6 || W_APP != 8 || W_Q != 8 || W_M != 6 ||
        W_C2V != 7 || W_ARITH != 9) begin
      $display("FAIL frozen width constants");
      errors++;
    end
    if (CH_TO_APP_SHIFT != 1 || BETA_INT != 1 ||
        SCHEDULE_WORD_W != 36 || ISSUE_WORD_W != 72 || REFERENCE_Z != 384) begin
      $display("FAIL frozen scalar constants");
      errors++;
    end

    for (raw = -256; raw <= 255; raw++) begin
      check_sat(raw);
    end

    check_q_sub(-128, 63);
    check_magnitude(-128);
    check_q_sub(127, -63);
    check_magnitude(127);
    for (app = -128; app <= 127; app++) begin
      for (c2v = -63; c2v <= 63; c2v++) begin
        check_q_sub(app, c2v);
      end
    end

    check_magnitude(-128);
    check_magnitude(-64);
    check_magnitude(-63);
    check_magnitude(0);
    check_magnitude(63);
    check_magnitude(127);
    for (q = -128; q <= 127; q++) begin
      check_magnitude(q);
    end

    check_beta(0);
    check_beta(1);
    check_beta(2);
    check_beta(63);
    for (mag = 0; mag <= 63; mag++) begin
      check_beta(mag);
      check_c2v(mag, 0);
      check_c2v(mag, 1);
    end
    check_c2v(0, 1);

    check_app_add(-128, -63);
    check_app_add(127, 63);
    for (q = -128; q <= 127; q++) begin
      for (c2v = -63; c2v <= 63; c2v++) begin
        check_app_add(q, c2v);
      end
    end

    for (ch = -32; ch <= 31; ch++) begin
      check_ch_init(ch);
    end

    if (errors == 0) begin
      $display("PASS phase1 arithmetic primitives");
      $finish;
    end

    $display("FAIL phase1 arithmetic primitives errors=%0d", errors);
    $finish(1);
  end
endmodule
