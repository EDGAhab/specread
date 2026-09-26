// pattgen-t4-001 wrong_reset_value: pda_o/pcl_o output flops reset 1'b0 -> 1'b1
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
    // enable=0 (inactive), inactive levels 0; pulse reset and sample DURING reset
    ctrl = {{1'b0, 1'b0, 1'b0, 1'b0, 32'd1, 64'h0, 6'd3, 10'd0}};
    #20 rst_n = 1;
    repeat (4) @(posedge clk); #1;
    $display("T4-001 running disabled: orig pda=%b pcl=%b | mut pda=%b pcl=%b",
             pda_o, pcl_o, pda_m, pcl_m);
    rst_n = 0; #2;   // assert reset; async reset branch fires at the negedge
    $display("T4-001 during reset: orig pda=%b pcl=%b | mut pda=%b pcl=%b",
             pda_o, pcl_o, pda_m, pcl_m);
    if (pda_o === 1'b0 && pcl_o === 1'b0 && pda_m === 1'b1 && pcl_m === 1'b1)
      $display("T4-001 RESULT: DIFFER -- orig resets outputs to 0, mutated to 1");
    else
      $display("T4-001 RESULT: NO DIFFERENCE (unexpected)");
    rst_n = 1;
    $finish;
  end
endmodule
