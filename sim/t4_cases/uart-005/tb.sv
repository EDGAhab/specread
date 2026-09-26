// Q005: uart_tx field_offset_error -- parity bit loaded into d0 slot of sreg
// Spec: "If the parity feature is turned on, then an odd or even parity bit
//         follows after the data bits."
// Stimulus: parity on, wr_parity=1, data 0xA5. Capture 11 line bits at baud ticks.
module tb_q005;
  reg clk = 0;
  always #5 clk = ~clk;
  reg rst_n = 0;
  reg tx_enable = 1, tick = 1, parity_enable = 1, wr = 0, wr_parity = 1;
  reg [7:0] wr_data = 8'hA5;
  wire idle_o, idle_m, tx_o, tx_m;
  uart_tx_o dut_o (.clk_i(clk), .rst_ni(rst_n), .tx_enable(tx_enable), .tick_baud_x16(tick),
    .parity_enable(parity_enable), .wr(wr), .wr_parity(wr_parity), .wr_data(wr_data),
    .idle(idle_o), .tx(tx_o));
  uart_tx_m dut_m (.clk_i(clk), .rst_ni(rst_n), .tx_enable(tx_enable), .tick_baud_x16(tick),
    .parity_enable(parity_enable), .wr(wr), .wr_parity(wr_parity), .wr_data(wr_data),
    .idle(idle_m), .tx(tx_m));
  reg [10:0] bits_o, bits_m;
  reg tq_o;
  integer n;
  always @(posedge clk) begin
    if (tq_o && n < 11) begin
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
    wait (n == 11);
    repeat (4) @(posedge clk);
    $display("Q005 captured 11 line bits [start,d0..d7,par,stop], MSB=last:");
    $display("  orig = %b", bits_o);
    $display("  mut  = %b", bits_m);
    if (bits_o != bits_m)
      $display("Q005 RESULT: DIFFER -- mutated frame puts parity bit in data-bit-0 slot");
    else
      $display("Q005 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
