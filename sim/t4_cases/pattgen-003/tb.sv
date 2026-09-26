// pattgen-t4-003 inverted_enable: pcl polarity mux inverted
module tb;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg [115:0] ctrl;
  wire pda_o, pcl_o, done_o, pda_m, pcl_m, done_m;
  pattgen_chan_o dut_o(.clk_i(clk), .rst_ni(rst_n), .ctrl_i(ctrl),
    .pda_o(pda_o), .pcl_o(pcl_o), .event_done_o(done_o));
  pattgen_chan_m dut_m(.clk_i(clk), .rst_ni(rst_n), .ctrl_i(ctrl),
    .pda_o(pda_m), .pcl_o(pcl_m), .event_done_o(done_m));
  integer n1, n2; logic f1, f2;
  initial begin
    f1 = 0; f2 = 0;
    // polarity=0, prediv=0, len=1, reps=100 (never completes)
    ctrl = {{1'b0, 1'b0, 1'b0, 1'b0, 32'd0, 64'hA5A5A5A5A5A5A5A5, 6'd1, 10'd100}};
    #20 rst_n = 1;
    repeat (4) @(posedge clk);
    ctrl[115] = 1'b1;
    repeat (8) @(posedge clk); #1;
    $display("T4-003 polarity=0 active: orig pcl=%b mut pcl=%b", pcl_o, pcl_m);
    if (pcl_o !== pcl_m)
      $display("T4-003 RESULT: DIFFER -- orig pcl follows pcl_int, mutated inverts it");
    else
      $display("T4-003 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
