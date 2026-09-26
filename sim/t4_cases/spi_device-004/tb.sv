// C4: extra synchronizer stage; measure pulse latency in SYS_CLK cycles
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
    integer t0, co, cm;
    rst_n = 0; #12; rst_n = 1;
    en = 1; csb = 0; #20;
    sck = 1; #10; sck = 0; #10;
    csb = 1; t0 = cyc; co = 999; cm = 999;
    repeat (40) begin
      @(posedge clk); #1;
      if (p_o && co == 999) co = cyc - t0;
      if (p_m && cm == 999) cm = cyc - t0;
    end
    $display("C4 co=%0d cm=%0d", co, cm);
    if (co <= 3 && cm > co)
      $display("C4 RESULT: DIFFER -- orig pulse arrives in %0d cycles (within spec bound), mutated needs %0d (violates it)", co, cm);
    else $display("C4 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
