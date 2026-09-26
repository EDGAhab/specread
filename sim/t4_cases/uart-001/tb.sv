// Q001: uart_tx wrong_reset_value -- tx_q reset 1'b1 -> 1'b0
// Spec: "The TX/RX serial lines are high when idle."
module tb_q001;
  reg clk = 0;
  always #5 clk = ~clk;
  reg rst_n = 0;
  reg tx_enable = 1, tick = 1, parity_enable = 0, wr = 0, wr_parity = 0;
  reg [7:0] wr_data = 8'hA5;
  wire idle_o, idle_m, tx_o, tx_m;
  uart_tx_o dut_o (.clk_i(clk), .rst_ni(rst_n), .tx_enable(tx_enable), .tick_baud_x16(tick),
    .parity_enable(parity_enable), .wr(wr), .wr_parity(wr_parity), .wr_data(wr_data),
    .idle(idle_o), .tx(tx_o));
  uart_tx_m dut_m (.clk_i(clk), .rst_ni(rst_n), .tx_enable(tx_enable), .tick_baud_x16(tick),
    .parity_enable(parity_enable), .wr(wr), .wr_parity(wr_parity), .wr_data(wr_data),
    .idle(idle_m), .tx(tx_m));
  initial begin
    #7;   // one clock edge with reset held: async-reset branch has been applied
    $display("Q001 during reset: tx_o=%b tx_m=%b", tx_o, tx_m);
    #13 rst_n = 1;
    repeat (50) @(posedge clk);
    $display("Q001 after reset, TX enabled, line idle: tx_o=%b tx_m=%b idle_o=%b idle_m=%b",
             tx_o, tx_m, idle_o, idle_m);
    if (tx_o === 1'b1 && tx_m === 1'b0)
      $display("Q001 RESULT: DIFFER -- original drives idle-high, mutated holds idle-low");
    else
      $display("Q001 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
