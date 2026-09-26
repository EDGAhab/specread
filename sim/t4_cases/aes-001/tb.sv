// Generic tb for aes_shift_rows ORIG vs MUT.
// Checks orig against the FIPS-197 ShiftRows model (row r: left by r enc,
// right by r dec; row 0 untouched) and reports orig-vs-mut differences.
module tb; // aes-001 off_by_one
  reg [1:0] op;
  reg [127:0] di;
  wire [127:0] do_o, do_m;
  aes_shift_rows_o dut_o (.op_i(op), .data_i(di), .data_o(do_o));
  aes_shift_rows_m dut_m (.op_i(op), .data_i(di), .data_o(do_m));

  // packed [3:0][3:0][7:0]: byte [r][c] lives at these bits
  function [7:0] getb(input [127:0] v, input integer r, input integer c);
    getb = v[8*(4*r+c) +: 8];
  endfunction

  integer r, c, err_o, diff;
  reg [7:0] expb;
  reg [1:0] cur_op;

  task check_op;
    input [1:0] the_op;
    integer rr, cc;
    reg [7:0] e;
    begin
      op = the_op; #10;
      for (rr = 0; rr < 4; rr = rr + 1) begin
        for (cc = 0; cc < 4; cc = cc + 1) begin
          if (rr == 0) e = getb(di, rr, cc);
          else if (the_op == 2'b10) e = getb(di, rr, (cc-rr+4)%4); // dec: right by r
          else e = getb(di, rr, (cc+rr)%4);                       // enc (and default): left by r
          if (getb(do_o, rr, cc) !== e) begin
            err_o = err_o + 1;
            $display("ORIG_MODEL_MISMATCH op=%b r=%0d c=%0d", the_op, rr, cc);
          end
          if (getb(do_o, rr, cc) !== getb(do_m, rr, cc)) diff = diff + 1;
        end
      end
    end
  endtask

  initial begin
    err_o = 0; diff = 0;
    di = 128'h0f0e0d0c_0b0a0908_07060504_03020100;
    check_op(2'b01); // enc
    check_op(2'b10); // dec
    check_op(2'b00); // invalid op -> default branches
    di = 128'h00112233_44556677_8899aabb_ccddeeff;
    check_op(2'b01);
    check_op(2'b10);
    $display("ORIG_MODEL_ERRORS=%0d", err_o);
    if (diff > 0) $display("RESULT: DIFFER (%0d byte mismatches between orig and mut)", diff);
    else $display("RESULT: NO DIFFERENCE");
    $finish;
  end
endmodule
