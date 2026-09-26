// Q004: uart_tx missing_fsm_transition -- shift-out branch removed
// Spec: "The TX module dequeues the byte from the FIFO and shifts it bit by bit
//         out to the UART TX pin on positive edges of the baud clock."
module tb_q004;
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
  reg [11:0] bits_o, bits_m;
  reg tq_o;
  integer n;
  always @(posedge clk) begin
    if (tq_o && n < 12) begin
      bits_o[n] <= tx_o;
      bits_m[n] <= tx_m;
      n <= n + 1;
    end
    tq_o <= dut_o.tick_baud_q;
  end
  initial begin
    n = 0; tq_o = 0;
    #20 rst_n = 1;
    repeat (4) @(posedge clk);
    @(posedge clk); wr = 1;
    @(posedge clk); wr = 0;
    wait (n == 12);
    repeat (4) @(posedge clk);
    $display("Q004 captured 12 line-bit slots, MSB=last:");
    $display("  orig = %b  idle_o=%b", bits_o, idle_o);
    $display("  mut  = %b  idle_m=%b", bits_m, idle_m);
    if (bits_o != bits_m || idle_o != idle_m)
      $display("Q004 RESULT: DIFFER -- mutated TX never shifts, stuck busy forever");
    else
      $display("Q004 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
