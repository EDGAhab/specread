package prim_util_pkg;
  function automatic integer vbits(input integer value);
    vbits = $clog2(value + 1);
  endfunction
endpackage
