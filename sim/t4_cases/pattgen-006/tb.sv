// pattgen-t4-006 off_by_one: reps completion limit reps_q+1
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
    // len=3, reps=1 (2 repetitions), prediv=1
    ctrl = {{1'b0, 1'b0, 1'b0, 1'b0, 32'd1, 64'hA5A5A5A5A5A5A5A5, 6'd3, 10'd1}};
    #20 rst_n = 1;
    repeat (4) @(posedge clk);
    ctrl[115] = 1'b1;
    n1 = 0; n2 = 0;
    while ((n1 < 400) && (!f1 || !f2)) begin
      @(posedge clk); #1;
      if (!f1) begin n1 = n1 + 1; if (done_o) f1 = 1; end
      if (!f2) begin n2 = n2 + 1; if (done_m) f2 = 1; end
    end
    $display("T4-006 cycles to done: orig=%0d mut=%0d", n1, n2);
    if (f1 && f2 && (n1 != n2))
      $display("T4-006 RESULT: DIFFER -- orig completes after 2 repetitions, mutated after 3");
    else
      $display("T4-006 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
