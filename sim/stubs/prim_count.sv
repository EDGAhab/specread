module prim_count #(parameter int unsigned Width = 2) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             clr_i,
  input  logic             set_i,
  input  logic [Width-1:0] set_cnt_i,
  input  logic             incr_en_i,
  input  logic             decr_en_i,
  input  logic [Width-1:0] step_i,
  input  logic             commit_i,
  output logic [Width-1:0] cnt_o,
  output logic [Width-1:0] cnt_after_commit_o,
  output logic             err_o
);
  logic [Width-1:0] cnt_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)       cnt_q <= '0;
    else if (clr_i)    cnt_q <= '0;
    else if (set_i)    cnt_q <= set_cnt_i;
    else if (incr_en_i) cnt_q <= cnt_q + step_i;
    else if (decr_en_i) cnt_q <= cnt_q - step_i;
  end
  assign cnt_o = cnt_q;
  assign cnt_after_commit_o = cnt_q;
  assign err_o = 1'b0;
endmodule
