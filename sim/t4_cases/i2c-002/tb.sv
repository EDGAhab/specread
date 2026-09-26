
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

  integer cyc, t_o, t_m;
  initial begin
    bus_active_timeout_i = 30'd40; bus_active_timeout_en_i = 1;
    controller_enable_i = 1;
    #30 rst_n = 1;
    waitc(5);
    scl_i = 0; // hold SCL low
    cyc = 0; t_o = -1; t_m = -1;
    while (cyc < 120 && (t_o < 0 || t_m < 0)) begin
      @(posedge clk); #1; cyc = cyc + 1;
      if (ev_act_o && t_o < 0) t_o = cyc;
      if (ev_act_m && t_m < 0) t_m = cyc;
    end
    $display("BM002 O_timeout_cyc=%0d M_timeout_cyc=%0d", t_o, t_m);
    if (t_o != t_m && t_o > 0 && t_m > 0)
      $display("RESULT: DIFFER -- active timeout fires at different cycle counts");
    else $display("RESULT: NO DIFFERENCE");
    $finish;
  end
endmodule
