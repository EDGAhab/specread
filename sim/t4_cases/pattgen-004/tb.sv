// pattgen-t4-004 missing_fsm_transition: ACTIVE->END on complete_q removed
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
    // data all-ones, len=3, reps=0, prediv=1, inactive levels 0
    ctrl = {{1'b0, 1'b0, 1'b0, 1'b0, 32'd1, 64'hFFFFFFFFFFFFFFFF, 6'd3, 10'd0}};
    #20 rst_n = 1;
    repeat (4) @(posedge clk);
    ctrl[115] = 1'b1;
    n1 = 0;
    while ((n1 < 300) && !f1) begin @(posedge clk); #1; n1 = n1 + 1; if (done_o) f1 = 1; end
    while ((n1 < 600) && !f2) begin @(posedge clk); #1; n1 = n1 + 1; if (done_m) f2 = 1; end
    repeat (10) @(posedge clk); #1;
    $display("T4-004 after completion: orig pda=%b pcl=%b | mut pda=%b pcl=%b",
             pda_o, pcl_o, pda_m, pcl_m);
    if (f1 && pda_o === 1'b0 && pda_m === 1'b1)
      $display("T4-004 RESULT: DIFFER -- orig returns pda to inactive 0 (END state), mutated stays active");
    else
      $display("T4-004 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
