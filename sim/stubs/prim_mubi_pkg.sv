package prim_mubi_pkg;
  typedef logic [3:0] mubi4_t;
  localparam mubi4_t MuBi4True  = 4'b0101;
  localparam mubi4_t MuBi4False = 4'b1010;
  function automatic logic mubi4_test_true_strict(input mubi4_t v);
    return (v == MuBi4True);
  endfunction
endpackage
