// aon_timer-t4-001 wrong_reset_value: prescaler reset to 1 on WKUP_CTRL write
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
    reg2hw_o.wkup_ctrl.enable.q = 1'b1; reg2hw_m.wkup_ctrl.enable.q = 1'b1;
    reg2hw_o.wkup_ctrl.prescaler.q = 12'd4; reg2hw_m.wkup_ctrl.prescaler.q = 12'd4;
    reg2hw_o.wkup_thold_lo.q = 32'd3; reg2hw_m.wkup_thold_lo.q = 32'd3;
    repeat (2) @(posedge clk);
    reg2hw_o.wkup_ctrl.prescaler.qe = 1'b1; reg2hw_m.wkup_ctrl.prescaler.qe = 1'b1;
    @(posedge clk); #1;
    reg2hw_o.wkup_ctrl.prescaler.qe = 1'b0; reg2hw_m.wkup_ctrl.prescaler.qe = 1'b0;
    co = 0; cm = 0; fo = 0; fm = 0;
    while ((co < 200) && (!fo || !fm)) begin
      @(posedge clk); #1;
      if (!fo) begin co = co + 1; if (wkup_intr_o) fo = 1; end
      if (!fm) begin cm = cm + 1; if (wkup_intr_m) fm = 1; end
    end
    $display("T4-001 cycles from prescaler-reset to wkup intr: orig=%0d mut=%0d", co, cm);
    if (fo && fm && (co != cm))
      $display("T4-001 RESULT: DIFFER -- orig resets prescaler to 0 on WKUP_CTRL write, mutated to 1");
    else
      $display("T4-001 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
