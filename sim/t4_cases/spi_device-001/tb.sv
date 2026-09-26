// C1: sck_toggle reset 0->1; CSb deassert with NO SCK activity
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
    en = 0; csb = 0; #20; csb = 1;
    repeat (10) @(posedge clk); #1;
    $display("C1 saw_o=%b saw_m=%b", saw_o, saw_m);
    if (saw_o === 1'b0 && saw_m === 1'b1)
      $display("C1 RESULT: DIFFER -- orig emits no pulse (no SCK activity), mutated fabricates one from the wrong reset value");
    else $display("C1 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
