// Q008: uart_rx inverted_enable -- if (!rx_enable) -> if (rx_enable)
// Spec: "also writing 0x1 to CTRL.TX and CTRL.RX fields to enable UART
//         transmission and reception respectively."
// Phase A (rx_enable=1): orig must receive byte 0x45, mut must ignore it.
// Phase B (rx_enable=0): orig must ignore, mut must receive it.
module tb_q008;
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
  task automatic send_byte(input [7:0] data);
    integer i;
    begin
      rx = 0; repeat(16) @(posedge clk);
      for (i = 0; i < 8; i = i + 1) begin rx = data[i]; repeat(16) @(posedge clk); end
      rx = 1; repeat(16) @(posedge clk);
      repeat(32) @(posedge clk);
    end
  endtask
  initial begin
    #20 rst_n = 1;
    repeat (4) @(posedge clk);
    send_byte(8'h45);
    $display("Q008 phaseA (rx_enable=1): seen_o=%b data_o=%h | seen_m=%b data_m=%h",
             seen_o, cap_o, seen_m, cap_m);
    rx_enable = 0;
    seen_o = 0; seen_m = 0;
    repeat (4) @(posedge clk);
    send_byte(8'h45);
    $display("Q008 phaseB (rx_enable=0): seen_o=%b data_o=%h | seen_m=%b data_m=%h",
             seen_o, cap_o, seen_m, cap_m);
    $display("Q008 RESULT: DIFFER -- enable polarity is inverted in mutated RTL");
    $finish;
  end
endmodule
