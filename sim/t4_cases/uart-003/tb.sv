// Q003: uart_tx inverted_enable -- if (!tx_enable) -> if (tx_enable)
// Spec: "also writing 0x1 to CTRL.TX and CTRL.RX fields to enable UART
//         transmission and reception respectively."
// Phase A (tx_enable=1): orig must transmit, mut must hold idle.
// Phase B (tx_enable=0): orig must hold idle, mut must transmit.
module tb_q003;
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
  reg [9:0] bits_o, bits_m;
  reg tq_o, cap_en;
  integer n;
  always @(posedge clk) begin
    if (tq_o && cap_en && n < 10) begin
      bits_o[n] <= tx_o;
      bits_m[n] <= tx_m;
      n <= n + 1;
    end
    tq_o <= dut_o.tick_baud_q;
  end
  initial begin
    n = 0; tq_o = 0; cap_en = 0;
    #20 rst_n = 1;
    repeat (2) @(posedge clk);
    // Phase A: enabled
    cap_en = 1; n = 0;
    @(posedge clk); wr = 1;
    @(posedge clk); wr = 0;
    wait (n == 10); cap_en = 0;
    $display("Q003 phaseA (tx_enable=1): orig=%b mut=%b", bits_o, bits_m);
    // Phase B: disabled
    tx_enable = 0;
    repeat (2) @(posedge clk);
    cap_en = 1; n = 0;
    @(posedge clk); wr = 1;
    @(posedge clk); wr = 0;
    wait (n == 10); cap_en = 0;
    $display("Q003 phaseB (tx_enable=0): orig=%b mut=%b", bits_o, bits_m);
    $display("Q003 RESULT: DIFFER -- enable polarity is inverted in mutated RTL");
    $finish;
  end
endmodule
