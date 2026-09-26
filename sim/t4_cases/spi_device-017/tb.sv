// S5: DualIO order=0 shift direction reversed; byte 0x9C content differs
module tb;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg [3:0] s_i = 4'h0;
  reg order = 0;
  reg [1:0] io_mode = 2'b00;
  reg [7:0] B;
  integer k;
  wire valid_o, valid_m;
  wire [7:0] data_o, data_m;
  spi_s2p_o dut_o (.clk_i(clk), .rst_ni(rst_n), .s_i(s_i),
    .data_valid_o(valid_o), .data_o(data_o), .order_i(order), .io_mode_i(io_mode));
  spi_s2p_m dut_m (.clk_i(clk), .rst_ni(rst_n), .s_i(s_i),
    .data_valid_o(valid_m), .data_o(data_m), .order_i(order), .io_mode_i(io_mode));
  initial begin
    #12 rst_n = 1;
    order = 0; io_mode = 2'b01; B = 8'h9C;
    for (k = 3; k >= 1; k = k - 1) begin s_i[1:0] = B[2*k+1 -: 2]; @(posedge clk); end
    s_i[1:0] = B[1:0]; #1;
    $display("S5 valid_o=%b data_o=%h valid_m=%b data_m=%h", valid_o, data_o, valid_m, data_m);
    if (valid_o === 1'b1 && valid_m === 1'b1 && data_o !== data_m)
      $display("S5 RESULT: DIFFER -- orig assembles 0x%h, mutated shifts pairs in from the wrong side (0x%h)", data_o, data_m);
    else $display("S5 RESULT: NO DIFFERENCE (unexpected)");
    $finish;
  end
endmodule
