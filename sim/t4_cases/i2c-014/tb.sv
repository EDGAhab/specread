
module tb;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  // open-drain bus (1 = released)
  wire scl_o_o, sda_o_o, scl_o_m, sda_o_m;
  reg scl_ext_o = 1, sda_ext_o = 1, scl_ext_m = 1, sda_ext_m = 1;
  wire scl_i_o = scl_o_o & scl_ext_o;
  wire sda_i_o = sda_o_o & sda_ext_o;
  wire scl_i_m = scl_o_m & scl_ext_m;
  wire sda_i_m = sda_o_m & sda_ext_m;
  reg bus_free_i = 1;
  reg host_enable_i = 0, halt_controller_i = 0;
  reg fmt_fifo_rvalid_i = 0;
  reg [6:0] fmt_fifo_depth_i = 7'd1;
  reg [7:0] fmt_byte_i = 8'hA5;
  reg fmt_flag_start_before_i = 0, fmt_flag_stop_after_i = 0;
  reg fmt_flag_read_bytes_i = 0, fmt_flag_read_continue_i = 0, fmt_flag_nak_ok_i = 0;
  reg unhandled_unexp_nak_i = 0, unhandled_nak_timeout_i = 0;
  reg [12:0] thigh_i = 13'd6, tlow_i = 13'd8, t_r_i = 13'd2, t_f_i = 13'd2;
  reg [12:0] thd_sta_i = 13'd4, tsu_sta_i = 13'd4, tsu_sto_i = 13'd4, thd_dat_i = 13'd2;
  reg sda_interference_i = 0;
  reg [29:0] stretch_timeout_i = 30'd0;
  reg timeout_enable_i = 0;
  reg [30:0] host_nack_handler_timeout_i = 31'd0;
  reg host_nack_handler_timeout_en_i = 0;
  wire ev_nak_o, ev_nak_m, ev_unhandled_nak_o, ev_unhandled_nak_m;
  wire ev_arb_o, ev_arb_m, ev_scl_int_o, ev_scl_int_m, ev_stretch_o, ev_stretch_m;
  wire ev_sda_unst_o, ev_sda_unst_m, cmd_complete_o, cmd_complete_m;
  wire rx_valid_o, rx_valid_m, transmitting_o, transmitting_m;
  wire host_idle_o, host_idle_m, fmt_rready_o, fmt_rready_m;
  wire [7:0] rx_data_o, rx_data_m;

  i2c_controller_fsm_o dut_o (
    .clk_i(clk), .rst_ni(rst_n),
    .scl_i(scl_i_o), .scl_o(scl_o_o), .sda_i(sda_i_o), .sda_o(sda_o_o),
    .bus_free_i(bus_free_i), .transmitting_o(transmitting_o),
    .host_enable_i(host_enable_i), .halt_controller_i(halt_controller_i),
    .fmt_fifo_rvalid_i(fmt_fifo_rvalid_i), .fmt_fifo_depth_i(fmt_fifo_depth_i),
    .fmt_fifo_rready_o(fmt_rready_o),
    .fmt_byte_i(fmt_byte_i),
    .fmt_flag_start_before_i(fmt_flag_start_before_i),
    .fmt_flag_stop_after_i(fmt_flag_stop_after_i),
    .fmt_flag_read_bytes_i(fmt_flag_read_bytes_i),
    .fmt_flag_read_continue_i(fmt_flag_read_continue_i),
    .fmt_flag_nak_ok_i(fmt_flag_nak_ok_i),
    .unhandled_unexp_nak_i(unhandled_unexp_nak_i),
    .unhandled_nak_timeout_i(unhandled_nak_timeout_i),
    .rx_fifo_wvalid_o(rx_valid_o), .rx_fifo_wdata_o(rx_data_o),
    .host_idle_o(host_idle_o),
    .thigh_i(thigh_i), .tlow_i(tlow_i), .t_r_i(t_r_i), .t_f_i(t_f_i),
    .thd_sta_i(thd_sta_i), .tsu_sta_i(tsu_sta_i), .tsu_sto_i(tsu_sto_i),
    .thd_dat_i(thd_dat_i),
    .sda_interference_i(sda_interference_i),
    .stretch_timeout_i(stretch_timeout_i), .timeout_enable_i(timeout_enable_i),
    .host_nack_handler_timeout_i(host_nack_handler_timeout_i),
    .host_nack_handler_timeout_en_i(host_nack_handler_timeout_en_i),
    .event_nak_o(ev_nak_o),
    .event_unhandled_nak_timeout_o(ev_unhandled_nak_o),
    .event_arbitration_lost_o(ev_arb_o),
    .event_scl_interference_o(ev_scl_int_o),
    .event_stretch_timeout_o(ev_stretch_o),
    .event_sda_unstable_o(ev_sda_unst_o),
    .event_cmd_complete_o(cmd_complete_o));
  i2c_controller_fsm_m dut_m (
    .clk_i(clk), .rst_ni(rst_n),
    .scl_i(scl_i_m), .scl_o(scl_o_m), .sda_i(sda_i_m), .sda_o(sda_o_m),
    .bus_free_i(bus_free_i), .transmitting_o(transmitting_m),
    .host_enable_i(host_enable_i), .halt_controller_i(halt_controller_i),
    .fmt_fifo_rvalid_i(fmt_fifo_rvalid_i), .fmt_fifo_depth_i(fmt_fifo_depth_i),
    .fmt_fifo_rready_o(fmt_rready_m),
    .fmt_byte_i(fmt_byte_i),
    .fmt_flag_start_before_i(fmt_flag_start_before_i),
    .fmt_flag_stop_after_i(fmt_flag_stop_after_i),
    .fmt_flag_read_bytes_i(fmt_flag_read_bytes_i),
    .fmt_flag_read_continue_i(fmt_flag_read_continue_i),
    .fmt_flag_nak_ok_i(fmt_flag_nak_ok_i),
    .unhandled_unexp_nak_i(unhandled_unexp_nak_i),
    .unhandled_nak_timeout_i(unhandled_nak_timeout_i),
    .rx_fifo_wvalid_o(rx_valid_m), .rx_fifo_wdata_o(rx_data_m),
    .host_idle_o(host_idle_m),
    .thigh_i(thigh_i), .tlow_i(tlow_i), .t_r_i(t_r_i), .t_f_i(t_f_i),
    .thd_sta_i(thd_sta_i), .tsu_sta_i(tsu_sta_i), .tsu_sto_i(tsu_sto_i),
    .thd_dat_i(thd_dat_i),
    .sda_interference_i(sda_interference_i),
    .stretch_timeout_i(stretch_timeout_i), .timeout_enable_i(timeout_enable_i),
    .host_nack_handler_timeout_i(host_nack_handler_timeout_i),
    .host_nack_handler_timeout_en_i(host_nack_handler_timeout_en_i),
    .event_nak_o(ev_nak_m),
    .event_unhandled_nak_timeout_o(ev_unhandled_nak_m),
    .event_arbitration_lost_o(ev_arb_m),
    .event_scl_interference_o(ev_scl_int_m),
    .event_stretch_timeout_o(ev_stretch_m),
    .event_sda_unstable_o(ev_sda_unst_m),
    .event_cmd_complete_o(cmd_complete_m));  always @* begin
    if (dut_o.state_q == 13) sda_ext_o = 1'b0; else sda_ext_o = 1'b1;
    if (dut_m.state_q == 13) sda_ext_m = 1'b0; else sda_ext_m = 1'b1;
  end

  integer cyc, en_o, ex_o, en_m, ex_m, po_q, pm_q;
  initial begin
    tsu_sta_i = 13'd9;

    host_enable_i = 1; fmt_fifo_rvalid_i = 1;
    fmt_flag_start_before_i = 1; fmt_flag_stop_after_i = 1;
    #30 rst_n = 1;

    cyc=0; en_o=-1; ex_o=-1; en_m=-1; ex_m=-1; po_q=0; pm_q=0;
    while (cyc < 6000 && (ex_o < 0 || ex_m < 0)) begin
      @(posedge clk); #1; cyc = cyc + 1;
      if (dut_o.state_q == 4 && !po_q) en_o = cyc;
      if (dut_o.state_q != 4 && po_q && en_o >= 0 && ex_o < 0) ex_o = cyc;
      po_q = (dut_o.state_q == 4);
      if (dut_m.state_q == 4 && !pm_q) en_m = cyc;
      if (dut_m.state_q != 4 && pm_q && en_m >= 0 && ex_m < 0) ex_m = cyc;
      pm_q = (dut_m.state_q == 4);
    end
    $display("CF014 O_holdstart_cycles=%0d M_holdstart_cycles=%0d (expect 6 vs 11)", ex_o-en_o, ex_m-en_m);
    if (en_o >= 0 && en_m >= 0 && (ex_o-en_o) == 6 && (ex_m-en_m) == 11)
      $display("RESULT: DIFFER -- START hold time 6 vs 11 cycles");
    else $display("RESULT: NO DIFFERENCE");
    $finish;
  end
endmodule
