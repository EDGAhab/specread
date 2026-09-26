// Q010: uart_rx field_offset_error -- rx_data slice shifted by one bit
//   parity_enable ? sreg_q[9:2] : sreg_q[10:3]  (was [8:1] : [9:2])
// Spec: "The least significant bit is sent first."
// Stimulus: byte 0x45 with odd parity (parity bit 0). Orig must report 0x45;
// mut extracts the wrong window and reports 0x22.
module tb_q010;
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
  reg f_o, f_m, p_o, p_m;
  always @(posedge clk) begin
    if (dut_o.rx_valid && !seen_o) begin
      seen_o <= 1; cap_o <= dut_o.rx_data; f_o <= dut_o.frame_err; p_o <= dut_o.rx_parity_err;
    end
    if (dut_m.rx_valid && !seen_m) begin
      seen_m <= 1; cap_m <= dut_m.rx_data; f_m <= dut_m.frame_err; p_m <= dut_m.rx_parity_err;
    end
  end
  task automatic send_byte(input [7:0] data, input par_bit);
    integer i;
    begin
      rx = 0; repeat(16) @(posedge clk);
      for (i = 0; i < 8; i = i + 1) begin rx = data[i]; repeat(16) @(posedge clk); end
      rx = par_bit; repeat(16) @(posedge clk);
      rx = 1; repeat(16) @(posedge clk);
      repeat(48) @(posedge clk);
    end
  endtask
  initial begin
    #20 rst_n = 1;
    repeat (4) @(posedge clk);
    send_byte(8'h45, 1'b0);   // 0x45 has 3 ones; odd parity -> parity bit 0
    $display("Q010 byte 0x45 odd-parity: seen_o=%b data_o=%h ferr_o=%b perr_o=%b | seen_m=%b data_m=%h ferr_m=%b perr_m=%b",
             seen_o, cap_o, f_o, p_o, seen_m, cap_m, f_m, p_m);
    if (seen_o === 1'b1 && cap_o === 8'h45 && seen_m === 1'b1 && cap_m !== 8'h45)
      $display("Q010 RESULT: DIFFER -- mutated RX extracts wrong bit window (0x22 vs 0x45)");
    else
      $display("Q010 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
