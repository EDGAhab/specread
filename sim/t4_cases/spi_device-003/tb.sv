// C3: sys_toggle_last reset 0->1; sample output right after reset
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
    rst_n = 0; #12; rst_n = 1; #1;
    $display("C3 p_o=%b p_m=%b", p_o, p_m);
    if (p_o === 1'b0 && p_m === 1'b1)
      $display("C3 RESULT: DIFFER -- orig output idle low after reset, mutated asserts a phantom pulse with no transaction");
    else $display("C3 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
