package lc_ctrl_pkg;
  typedef logic [1:0] lc_tx_t;
  localparam lc_tx_t LcTxOff = 2'b01;
  localparam lc_tx_t LcTxOn  = 2'b10;
  function automatic logic lc_tx_test_false_strict(input lc_tx_t v);
    return (v == LcTxOff);
  endfunction
endpackage
