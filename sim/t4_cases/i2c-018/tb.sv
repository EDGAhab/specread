
module tb;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  // open-drain bus (1 = released)
  wire scl_o_o, sda_o_o, scl_o_m, sda_o_m;
  reg scl_ext = 1;
  wire scl_i = scl_o_o & scl_o_m & scl_ext;
  reg sda_ext = 1;
  wire sda_i = sda_o_o & sda_o_m & sda_ext;
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
    .scl_i(scl_i), .scl_o(scl_o_o), .sda_i(sda_i), .sda_o(sda_o_o),
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
    .scl_i(scl_i), .scl_o(scl_o_m), .sda_i(sda_i), .sda_o(sda_o_m),
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
    .event_cmd_complete_o(cmd_complete_m));  // target model: ACKs written bytes; supplies read data bits
  reg [7:0] read_pattern = 8'h3C;
  always @* begin
    if (dut_o.state_q == 16)
      sda_ext = read_pattern[dut_o.bit_index];
    else if (dut_m.state_q == 16)
      sda_ext = read_pattern[dut_m.bit_index];
    else if (dut_o.state_q == 13 || dut_m.state_q == 13)
      sda_ext = 1'b0;
    else
      sda_ext = 1'b1;
  end

  integer cyc, stop_o, stop_m, dis_done;
  initial begin
    host_enable_i = 1; fmt_fifo_rvalid_i = 1;
    fmt_flag_start_before_i = 1; fmt_flag_stop_after_i = 0;
    #30 rst_n = 1;
    cyc=0; stop_o=0; stop_m=0; dis_done=0;
    while (cyc < 12000 && !(stop_o && stop_m)) begin
      @(posedge clk); #1; cyc = cyc + 1;
      if (!dis_done && dut_o.state_q == 0 && dut_o.trans_started) begin
        host_enable_i = 0; // SW disables host between bytes
        dis_done = 1;
      end
      if (dut_o.state_q == 8) stop_o = 1;
      if (dut_m.state_q == 8) stop_m = 1;
    end
    $display("CF018 O_autostop=%0d M_autostop=%0d (expect 1 vs 0)", stop_o, stop_m);
    if (stop_o == 1 && stop_m == 0)
      $display("RESULT: DIFFER -- orig auto-generates STOP on disable, mut releases bus with no STOP");
    else $display("RESULT: NO DIFFERENCE");
    $finish;
  end
endmodule
