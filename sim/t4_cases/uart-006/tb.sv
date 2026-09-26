// Q006: uart_rx wrong_reset_value -- idle_q reset 1'b1 -> 1'b0
// Spec (STATUS register): "|   4    |   ro   |   0x1   | RXIDLE  | RX is idle  |"
//   (Reset default 0x3c). uart_rx.idle -> uart_core rx_uart_idle -> STATUS.RXIDLE.
// After reset with the line idle-high, orig stays idle; mut believes a frame is
// in progress and eventually emits a phantom byte.
module tb_q006;
  reg clk = 0;
  always #5 clk = ~clk;
  reg rst_n = 0;
  reg rx_enable = 1, tick = 1, parity_enable = 0, parity_odd = 1, rx = 1;
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
    #7;   // one clock edge with reset held: async-reset branch has been applied
    $display("Q006 during reset: idle_o=%b idle_m=%b", idle_o, idle_m);
    #13 rst_n = 1;            // release at t=20
    repeat (50) @(posedge clk);   // ~3 bit-times; line stays idle-high
    $display("Q006 after reset, line idle: idle_o=%b idle_m=%b", idle_o, idle_m);
    $display("Q006 phantom byte: seen_o=%b data_o=%h | seen_m=%b data_m=%h",
             seen_o, cap_o, seen_m, cap_m);
    if (idle_o === 1'b1 && idle_m === 1'b0)
      $display("Q006 RESULT: DIFFER -- mutated RX comes out of reset non-idle (self-aborts ~7 bit-times later, never delivering)");
    else
      $display("Q006 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
