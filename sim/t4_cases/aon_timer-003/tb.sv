// aon_timer-t4-003 off_by_one: wdog bark on count>thold instead of >=
module tb;
  import aon_timer_reg_pkg::*;
  logic clk = 0; always #5 clk = ~clk;
  logic rst_n = 0;
  lc_ctrl_pkg::lc_tx_t esc;
  logic sleep_mode;
  aon_timer_reg2hw_t reg2hw_o, reg2hw_m;
  logic wkup_wr_o, wdog_wr_o, wkup_wr_m, wdog_wr_m;
  logic [63:0] wkup_data_o, wkup_data_m;
  logic [31:0] wdog_data_o, wdog_data_m;
  logic wkup_intr_o, wdog_intr_o, wdog_rst_o;
  logic wkup_intr_m, wdog_intr_m, wdog_rst_m;
  integer c; logic seen; integer co, cm; logic fo, fm; logic s1o, s1m;
  aon_timer_core_o dut_o(
    .clk_aon_i(clk), .rst_aon_ni(rst_n),
    .lc_escalate_en_i({3{esc}}),
    .sleep_mode_i(sleep_mode),
    .reg2hw_i(reg2hw_o),
    .wkup_count_reg_wr_o(wkup_wr_o), .wkup_count_wr_data_o(wkup_data_o),
    .wdog_count_reg_wr_o(wdog_wr_o), .wdog_count_wr_data_o(wdog_data_o),
    .wkup_intr_o(wkup_intr_o), .wdog_intr_o(wdog_intr_o), .wdog_reset_req_o(wdog_rst_o)
  );
  aon_timer_core_m dut_m(
    .clk_aon_i(clk), .rst_aon_ni(rst_n),
    .lc_escalate_en_i({3{esc}}),
    .sleep_mode_i(sleep_mode),
    .reg2hw_i(reg2hw_m),
    .wkup_count_reg_wr_o(wkup_wr_m), .wkup_count_wr_data_o(wkup_data_m),
    .wdog_count_reg_wr_o(wdog_wr_m), .wdog_count_wr_data_o(wdog_data_m),
    .wkup_intr_o(wkup_intr_m), .wdog_intr_o(wdog_intr_m), .wdog_reset_req_o(wdog_rst_m)
  );
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg2hw_o.wkup_count_lo.q <= 32'd0;
      reg2hw_o.wkup_count_hi.q <= 32'd0;
      reg2hw_o.wdog_count.q    <= 32'd0;
      reg2hw_m.wkup_count_lo.q <= 32'd0;
      reg2hw_m.wkup_count_hi.q <= 32'd0;
      reg2hw_m.wdog_count.q    <= 32'd0;
    end else begin
      if (wkup_wr_o) {reg2hw_o.wkup_count_hi.q, reg2hw_o.wkup_count_lo.q} <= wkup_data_o;
      if (wdog_wr_o) reg2hw_o.wdog_count.q <= wdog_data_o;
      if (wkup_wr_m) {reg2hw_m.wkup_count_hi.q, reg2hw_m.wkup_count_lo.q} <= wkup_data_m;
      if (wdog_wr_m) reg2hw_m.wdog_count.q <= wdog_data_m;
    end
  end
  initial begin
    rst_n = 0; sleep_mode = 0; esc = lc_ctrl_pkg::LcTxOff;
    reg2hw_o = '0; reg2hw_m = '0;
    #20; rst_n = 1;
    reg2hw_o.wdog_ctrl.enable.q = 1'b1; reg2hw_m.wdog_ctrl.enable.q = 1'b1;
    reg2hw_o.wdog_bark_thold.q = 32'd5; reg2hw_m.wdog_bark_thold.q = 32'd5;
    seen = 0;
    for (c = 0; c < 40 && !seen; c = c + 1) begin
      @(posedge clk); #1;
      if (reg2hw_o.wdog_count.q == 32'd5) begin
        seen = 1;
        $display("T4-003 count==bark(5): wdog_intr_o=%b wdog_intr_m=%b", wdog_intr_o, wdog_intr_m);
        if (wdog_intr_o === 1'b1 && wdog_intr_m === 1'b0)
          $display("T4-003 RESULT: DIFFER -- orig barks when count hits threshold (>=), mutated only above (>)");
        else
          $display("T4-003 RESULT: NO DIFFERENCE (unexpected)");
      end
    end
    if (!seen) $display("T4-003 RESULT: NO DIFFERENCE (count never reached 5)");
    $finish;
  end
endmodule
