// Q007: uart_rx counter_off_by_one -- start bit_cnt 11/10 -> 10/9 (parity on)
// The half-bit START confirmation compares bit_cnt_q against 11 when parity is
// enabled, so the mutated counter never matches and the glitch check is skipped.
// Spec: "When the input is detected low the receiver will check half a bit-time
//   later (i.e. 8 cycles of the oversample clock) that the line is still low before
//   detecting the START bit. If the line has returned high the glitch is ignored."
// Stimulus: 4-clock low glitch on an idle line. Orig must ignore it; mut must
// treat it as a START bit and deliver a garbage byte.
module tb_q007;
  reg clk = 0;
  always #5 clk = ~clk;
  reg rst_n = 0;
  reg rx_enable = 1, tick = 1, parity_enable = 1, parity_odd = 1, rx = 1;
  wire tick_baud_o, tick_baud_m, rx_valid_o, rx_valid_m;
  wire idle_o, idle_m, ferr_o, ferr_m, perr_o, perr_m;
  wire [7:0] rdata_o, rdata_m;
  uart_rx_o dut_o (.clk_i(clk), .rst_ni(rst_n), .rx_enable(rx_enable), .tick_baud_x16(tick),
    .parity_enable(parity_enable), .parity_odd(parity_odd), .tick_baud(tick_baud_o),
    .rx_valid(rx_valid_o), .rx_data(rdata_o), .idle(idle_o), .frame_err(ferr_o),
    .rx_parity_err(perr_o), .rx(rx));
  uart_rx_m dut_m (.clk_i(clk), .rst_ni(rst_n), .rx_enable(rx_enable), .tick_baud_x16(tick),
    .parity_enable(parity_enable), .parity_odd(parity_odd), .tick_baud(tick_baud_m),
    .rx_valid(rx_valid_m), .rx_data(rdata_m), .idle(idle_m), .frame_err(ferr_m),
    .rx_parity_err(perr_m), .rx(rx));
  reg seen_o = 0, seen_m = 0;
  reg [7:0] cap_o, cap_m;
  always @(posedge clk) begin
    if (dut_o.rx_valid && !seen_o) begin seen_o <= 1; cap_o <= dut_o.rx_data; end
    if (dut_m.rx_valid && !seen_m) begin seen_m <= 1; cap_m <= dut_m.rx_data; end
  end
  initial begin
    #20 rst_n = 1;
    repeat (8) @(posedge clk);
    rx = 0; repeat (4) @(posedge clk); rx = 1;   // 4-clock glitch, then idle
    repeat (16*14) @(posedge clk);               // let any reception finish
    $display("Q007 after 4-clk glitch: seen_o=%b data_o=%h idle_o=%b | seen_m=%b data_m=%h idle_m=%b",
             seen_o, cap_o, idle_o, seen_m, cap_m, idle_m);
    if (seen_o === 1'b0 && seen_m === 1'b1)
      $display("Q007 RESULT: DIFFER -- orig ignores glitch, mut receives garbage byte");
    else
      $display("Q007 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
