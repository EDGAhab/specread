// H18: rx_buf packs {sr_shifted,last_read} (last bit at LSB); capture with last_read=1
module tb;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg wr_en=0, rd_en=0, shift_en=0, sample_en=0, full_cyc=0, last_read=0, last_write=0, sw_rst=0;
  reg [1:0] speed = 2'b00;
  reg [7:0] tx_data = 8'h00;
  reg tx_valid=0, rx_ready=0;
  reg [3:0] sd_i = 4'h0;
  wire wr_ready_o, wr_ready_m, rd_ready_o, rd_ready_m;
  wire tx_ready_o, tx_ready_m, tx_flush_o, tx_flush_m;
  wire rx_valid_o, rx_valid_m, rx_last_o, rx_last_m;
  wire [7:0] rx_data_o, rx_data_m;
  wire [3:0] sd_o_o, sd_o_m;
  spi_host_shift_register_o dut_o (
    .clk_i(clk), .rst_ni(rst_n),
    .wr_en_i(wr_en), .wr_ready_o(wr_ready_o),
    .rd_en_i(rd_en), .rd_ready_o(rd_ready_o),
    .speed_i(speed), .shift_en_i(shift_en), .sample_en_i(sample_en),
    .full_cyc_i(full_cyc), .last_read_i(last_read), .last_write_i(last_write),
    .tx_data_i(tx_data), .tx_valid_i(tx_valid), .tx_ready_o(tx_ready_o), .tx_flush_o(tx_flush_o),
    .rx_data_o(rx_data_o), .rx_valid_o(rx_valid_o), .rx_ready_i(rx_ready), .rx_last_o(rx_last_o),
    .sd_i(sd_i), .sd_o(sd_o_o), .sw_rst_i(sw_rst)
  );
  spi_host_shift_register_m dut_m (
    .clk_i(clk), .rst_ni(rst_n),
    .wr_en_i(wr_en), .wr_ready_o(wr_ready_m),
    .rd_en_i(rd_en), .rd_ready_o(rd_ready_m),
    .speed_i(speed), .shift_en_i(shift_en), .sample_en_i(sample_en),
    .full_cyc_i(full_cyc), .last_read_i(last_read), .last_write_i(last_write),
    .tx_data_i(tx_data), .tx_valid_i(tx_valid), .tx_ready_o(tx_ready_m), .tx_flush_o(tx_flush_m),
    .rx_data_o(rx_data_m), .rx_valid_o(rx_valid_m), .rx_ready_i(rx_ready), .rx_last_o(rx_last_m),
    .sd_i(sd_i), .sd_o(sd_o_m), .sw_rst_i(sw_rst)
  );
  initial begin
    #12 rst_n = 1;
    tx_data = 8'hA5; tx_valid = 1; wr_en = 1; @(posedge clk); #1; wr_en = 0; tx_valid = 0;
    rd_en = 1; last_read = 1; @(posedge clk); #1; rd_en = 0;
    $display("H18 {last,data}_o=%b_%h {last,data}_m=%b_%h", rx_last_o, rx_data_o, rx_last_m, rx_data_m);
    if ({rx_last_o, rx_data_o} === 9'h14a && {rx_last_m, rx_data_m} === 9'h095)
      $display("H18 RESULT: DIFFER -- orig packs {last=1,data=0x4A}, mutated packs the last flag into the data LSB (0x95, last=0)");
    else $display("H18 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
