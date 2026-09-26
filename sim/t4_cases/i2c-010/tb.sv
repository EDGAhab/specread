
module tb;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg scl_i = 1, sda_i = 1;
  reg controller_enable_i = 0, multi_controller_enable_i = 0;
  reg target_enable_i = 0, target_idle_i = 1;
  reg [12:0] thd_dat_i = 13'd2, t_buf_i = 13'd50;
  reg [29:0] bus_active_timeout_i = 30'd1000;
  reg bus_active_timeout_en_i = 0;
  reg [19:0] bus_inactive_timeout_i = 20'd0;
  wire bus_free_o, bus_free_m, start_o, start_m, stop_o, stop_m;
  wire ev_act_o, ev_act_m, ev_host_o, ev_host_m;
  i2c_bus_monitor_o dut_o (.clk_i(clk), .rst_ni(rst_n), .scl_i(scl_i), .sda_i(sda_i),
    .controller_enable_i(controller_enable_i), .multi_controller_enable_i(multi_controller_enable_i),
    .target_enable_i(target_enable_i), .target_idle_i(target_idle_i),
    .thd_dat_i(thd_dat_i), .t_buf_i(t_buf_i),
    .bus_active_timeout_i(bus_active_timeout_i), .bus_active_timeout_en_i(bus_active_timeout_en_i),
    .bus_inactive_timeout_i(bus_inactive_timeout_i),
    .bus_free_o(bus_free_o), .start_detect_o(start_o), .stop_detect_o(stop_o),
    .event_bus_active_timeout_o(ev_act_o), .event_host_timeout_o(ev_host_o));
  i2c_bus_monitor_m dut_m (.clk_i(clk), .rst_ni(rst_n), .scl_i(scl_i), .sda_i(sda_i),
    .controller_enable_i(controller_enable_i), .multi_controller_enable_i(multi_controller_enable_i),
    .target_enable_i(target_enable_i), .target_idle_i(target_idle_i),
    .thd_dat_i(thd_dat_i), .t_buf_i(t_buf_i),
    .bus_active_timeout_i(bus_active_timeout_i), .bus_active_timeout_en_i(bus_active_timeout_en_i),
    .bus_inactive_timeout_i(bus_inactive_timeout_i),
    .bus_free_o(bus_free_m), .start_detect_o(start_m), .stop_detect_o(stop_m),
    .event_bus_active_timeout_o(ev_act_m), .event_host_timeout_o(ev_host_m));
  task waitc; input integer n; integer k; begin for (k=0;k<n;k=k+1) @(posedge clk); end endtask

  integer cyc, seen_o, seen_m;
  initial begin
    controller_enable_i = 1;
    t_buf_i = 13'd100;
    #30 rst_n = 1;
    waitc(5); #1;
    sda_i = 0; // START
    seen_o = 0; seen_m = 0; cyc = 0;
    while (cyc < 40) begin
      @(posedge clk); #1; cyc = cyc + 1;
      if (start_o) seen_o = 1;
      if (start_m) seen_m = 1;
    end
    $display("BM010 O_start_seen=%0d M_start_seen=%0d (expect 1 vs 0)", seen_o, seen_m);
    if (seen_o == 1 && seen_m == 0)
      $display("RESULT: DIFFER -- orig detects START, mut (t_buf threshold) never does");
    else $display("RESULT: NO DIFFERENCE");
    $finish;
  end
endmodule
