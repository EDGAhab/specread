`ifndef PRIM_ASSERT_STUB_SV
`define PRIM_ASSERT_STUB_SV
`define ASSERT(__name, __prop)
`define ASSERT_INIT(__name, __prop)
`define ASSERT_FINAL(__name, __prop)
`define ASSERT_NEVER(__name, __prop)
`define ASSERT_KNOWN(__name, __sig)
`define COVER(__name, __prop)
`define ASSERT_STATIC_LINT_ERROR
// Scout stub: real macro lives in hw/ip/prim (not in sparse checkout).
// Simplified to a plain state flop (no FI sparse-encoding checks).
`define PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __reset_val) \
  always_ff @(posedge clk_i or negedge rst_ni) begin \
    if (!rst_ni) __q <= __reset_val; \
    else         __q <= __d; \
  end
`endif
