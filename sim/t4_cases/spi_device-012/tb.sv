// C12: sys_toggle_last update deleted; pulse sticks high after transaction
module tb;
  reg clk = 0; always #5 clk = ~clk;
  reg sck = 0;
  reg rst_n = 1;
  reg en = 0;
  reg csb = 1;
  wire p_o, p_m;
  reg saw_o = 0, saw_m = 0;
  spid_csb_sync_o dut_o (.clk_i(clk), .rst_ni(rst_n), .sck_i(sck),
    .sck_pulse_en_i(en), .csb_i(csb), .csb_deasserted_pulse_o(p_o));
  spid_csb_sync_m dut_m (.clk_i(clk), .rst_ni(rst_n), .sck_i(sck),
    .sck_pulse_en_i(en), .csb_i(csb), .csb_deasserted_pulse_o(p_m));
  always @(posedge clk) begin if (p_o) saw_o <= 1; if (p_m) saw_m <= 1; end
  integer cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;
  initial begin
    rst_n = 0; #12; rst_n = 1;
    en = 1; csb = 0; #20;
    sck = 1; #10; sck = 0; #10;
    csb = 1;
    repeat (10) @(posedge clk); #1;
    $display("C12 p_o=%b p_m=%b", p_o, p_m);
    if (p_o === 1'b0 && p_m === 1'b1)
      $display("C12 RESULT: DIFFER -- orig pulse is one cycle, mutated output sticks high after the first de-assertion");
    else $display("C12 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
