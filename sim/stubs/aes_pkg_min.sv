// Auto-extracted enum typedefs from hw/ip/aes/rtl/aes_pkg.sv (verbatim).
// Struct-typed parameters and functions omitted (iverilog-12 incompatible).
package aes_pkg;
  parameter int unsigned SliceSizeCtr = 16;
  parameter int unsigned NumSlicesCtr = 8; // = NumRegsIv(4)*32/SliceSizeCtr
  parameter int unsigned SliceIdxWidth = 4;
  parameter int unsigned SliceIdxMaxInc32 = 1; // 32/SliceSizeCtr - 1
  parameter int NumSharesKey = 2;
  parameter int AES_OP_WIDTH = 2;
  parameter int AES_MODE_WIDTH = 6;
  parameter int AES_KEYLEN_WIDTH = 3;
  parameter int AES_PRNGRESEEDRATE_WIDTH = 3;
  parameter int AES_GCMPHASE_WIDTH = 6;
  parameter int BlockCtrWidth = 13;
  parameter int CipherCtrlStateWidth = 6;
  parameter int CtrStateWidth = 5;
  parameter int CtrlStateWidth = 6;
  parameter int GhashStateWidth = 7;
  parameter int Mux2SelWidth = 3;
  parameter int Mux3SelWidth = 5;
  parameter int Mux4SelWidth = 5;
  parameter int Mux5SelWidth = 6;
  parameter int Mux6SelWidth = 6;
  parameter int DIPSelWidth = Mux2SelWidth;
  parameter int SISelWidth = Mux2SelWidth;
  parameter int AddSISelWidth = Mux2SelWidth;
  parameter int AddSOSelWidth = Mux3SelWidth;
  parameter int GHashAddInSelWidth = 3;
  parameter int GHashStateSelWidth = Mux5SelWidth;
  parameter int GFMultInSelWidth = 3;
  parameter int StateSelWidth = Mux3SelWidth;
  parameter int KeyInitSelWidth = Mux3SelWidth;
  parameter int AddRKSelWidth = Mux3SelWidth;
  parameter int KeyFullSelWidth = Mux4SelWidth;
  parameter int KeyWordsSelWidth = Mux4SelWidth;
  parameter int IVSelWidth = Mux6SelWidth;
  parameter int KeyDecSelWidth = Mux2SelWidth;
  parameter int RoundKeySelWidth = Mux2SelWidth;
  parameter int GHashInSelWidth = Mux2SelWidth;
  parameter int DataOutSelWidth = Mux2SelWidth;
  parameter int Sp2VNum = 2;
  parameter int Sp2VWidth = Mux2SelWidth;
  typedef enum integer {
    SBoxImplLut,                   // Unmasked LUT-based S-Box
    SBoxImplCanright,              // Unmasked Canright S-Box, see aes_sbox_canright.sv
    SBoxImplCanrightMasked,        // First-order masked Canright S-Box
                                   // see aes_sbox_canright_masked.sv
    SBoxImplCanrightMaskedNoreuse, // First-order masked Canright S-Box without mask reuse,
                                   // see aes_sbox_canright_masked_noreuse.sv
    SBoxImplDom                    // First-order masked S-Box using domain-oriented masking,
                                   // see aes_sbox_canright_dom.sv
  } sbox_impl_e;
  typedef enum logic [AES_OP_WIDTH-1:0] {
    AES_ENC = 2'b01,
    AES_DEC = 2'b10
  } aes_op_e;
  typedef enum logic [AES_MODE_WIDTH-1:0] {
    AES_ECB  = 6'b00_0001,
    AES_CBC  = 6'b00_0010,
    AES_CFB  = 6'b00_0100,
    AES_OFB  = 6'b00_1000,
    AES_CTR  = 6'b01_0000,
    AES_GCM  = 6'b10_0000,
    AES_NONE = 6'b11_1111
  } aes_mode_e;
  typedef enum logic [AES_OP_WIDTH-1:0] {
    CIPH_FWD = 2'b01,
    CIPH_INV = 2'b10
  } ciph_op_e;
  typedef enum logic [AES_KEYLEN_WIDTH-1:0] {
    AES_128 = 3'b001,
    AES_192 = 3'b010,
    AES_256 = 3'b100
  } key_len_e;
  typedef enum logic [AES_PRNGRESEEDRATE_WIDTH-1:0] {
    PER_1  = 3'b001,
    PER_64 = 3'b010,
    PER_8K = 3'b100
  } prs_rate_e;
  typedef enum logic [AES_GCMPHASE_WIDTH-1:0] {
    GCM_INIT    = 6'b00_0001,
    GCM_RESTORE = 6'b00_0010,
    GCM_AAD     = 6'b00_0100,
    GCM_TEXT    = 6'b00_1000,
    GCM_SAVE    = 6'b01_0000,
    GCM_TAG     = 6'b10_0000
  } gcm_phase_e;
  typedef enum logic [CipherCtrlStateWidth-1:0] {
      CIPHER_CTRL_IDLE        = 6'b001001,
      CIPHER_CTRL_INIT        = 6'b100011,
      CIPHER_CTRL_ROUND       = 6'b111101,
      CIPHER_CTRL_FINISH      = 6'b010000,
      CIPHER_CTRL_PRNG_RESEED = 6'b100100,
      CIPHER_CTRL_CLEAR_S     = 6'b111010,
      CIPHER_CTRL_CLEAR_KD    = 6'b001110,
      CIPHER_CTRL_ERROR       = 6'b010111
    } aes_cipher_ctrl_e;
  typedef enum logic [CtrStateWidth-1:0] {
      CTR_IDLE  = 5'b01110,
      CTR_INCR  = 5'b11000,
      CTR_ERROR = 5'b00001
    } aes_ctr_e;
  typedef enum logic [CtrlStateWidth-1:0] {
      CTRL_IDLE        = 6'b001001,
      CTRL_LOAD        = 6'b100011,
      CTRL_GHASH_READY = 6'b111101,
      CTRL_PRNG_RESEED = 6'b010000,
      CTRL_FINISH      = 6'b100100,
      CTRL_CLEAR_I     = 6'b111010,
      CTRL_CLEAR_CO    = 6'b001110,
      CTRL_ERROR       = 6'b010111
    } aes_ctrl_e;
  typedef enum logic [GhashStateWidth-1:0] {
    GHASH_IDLE                    = 7'b1100001,
    GHASH_MULT                    = 7'b0010001,
    GHASH_ADD_S                   = 7'b0000110,
    GHASH_OUT                     = 7'b0110111,
    GHASH_ERROR                   = 7'b0111010,
    GHASH_MASKED_INIT             = 7'b1111100,
    GHASH_MASKED_ADD_STATE_SHARES = 7'b0101101,
    GHASH_MASKED_ADD_CORR         = 7'b0001000,
    GHASH_MASKED_SETTLE           = 7'b1001111
  } aes_ghash_e;
  typedef enum logic [Mux2SelWidth-1:0] {
    MUX2_SEL_0 = 3'b011,
    MUX2_SEL_1 = 3'b100
  } mux2_sel_e;
  typedef enum logic [Mux3SelWidth-1:0] {
    MUX3_SEL_0 = 5'b01110,
    MUX3_SEL_1 = 5'b11000,
    MUX3_SEL_2 = 5'b00001
  } mux3_sel_e;
  typedef enum logic [Mux4SelWidth-1:0] {
    MUX4_SEL_0 = 5'b01110,
    MUX4_SEL_1 = 5'b11000,
    MUX4_SEL_2 = 5'b00001,
    MUX4_SEL_3 = 5'b10111
  } mux4_sel_e;
  typedef enum logic [Mux5SelWidth-1:0] {
    MUX5_SEL_0 = 6'b110000,
    MUX5_SEL_1 = 6'b001000,
    MUX5_SEL_2 = 6'b000011,
    MUX5_SEL_3 = 6'b011101,
    MUX5_SEL_4 = 6'b111110
  } mux5_sel_e;
  typedef enum logic [Mux6SelWidth-1:0] {
    MUX6_SEL_0 = 6'b011101,
    MUX6_SEL_1 = 6'b110000,
    MUX6_SEL_2 = 6'b001000,
    MUX6_SEL_3 = 6'b000011,
    MUX6_SEL_4 = 6'b111110,
    MUX6_SEL_5 = 6'b100101
  } mux6_sel_e;
  typedef enum logic [DIPSelWidth-1:0] {
    DIP_DATA_IN = MUX2_SEL_0,
    DIP_CLEAR   = MUX2_SEL_1
  } dip_sel_e;
  typedef enum logic [SISelWidth-1:0] {
    SI_ZERO = MUX2_SEL_0,
    SI_DATA = MUX2_SEL_1
  } si_sel_e;
  typedef enum logic [AddSISelWidth-1:0] {
    ADD_SI_ZERO = MUX2_SEL_0,
    ADD_SI_IV   = MUX2_SEL_1
  } add_si_sel_e;
  typedef enum logic [StateSelWidth-1:0] {
    STATE_INIT  = MUX3_SEL_0,
    STATE_ROUND = MUX3_SEL_1,
    STATE_CLEAR = MUX3_SEL_2
  } state_sel_e;
  typedef enum logic [AddRKSelWidth-1:0] {
    ADD_RK_INIT  = MUX3_SEL_0,
    ADD_RK_ROUND = MUX3_SEL_1,
    ADD_RK_FINAL = MUX3_SEL_2
  } add_rk_sel_e;
  typedef enum logic [KeyInitSelWidth-1:0] {
    KEY_INIT_INPUT  = MUX3_SEL_0,
    KEY_INIT_KEYMGR = MUX3_SEL_1,
    KEY_INIT_CLEAR  = MUX3_SEL_2
  } key_init_sel_e;
  typedef enum logic [IVSelWidth-1:0] {
    IV_INPUT        = MUX6_SEL_0,
    IV_DATA_OUT     = MUX6_SEL_1,
    IV_DATA_OUT_RAW = MUX6_SEL_2,
    IV_DATA_IN_PREV = MUX6_SEL_3,
    IV_CTR          = MUX6_SEL_4,
    IV_CLEAR        = MUX6_SEL_5
  } iv_sel_e;
  typedef enum logic [KeyFullSelWidth-1:0] {
    KEY_FULL_ENC_INIT = MUX4_SEL_0,
    KEY_FULL_DEC_INIT = MUX4_SEL_1,
    KEY_FULL_ROUND    = MUX4_SEL_2,
    KEY_FULL_CLEAR    = MUX4_SEL_3
  } key_full_sel_e;
  typedef enum logic [KeyDecSelWidth-1:0] {
    KEY_DEC_EXPAND = MUX2_SEL_0,
    KEY_DEC_CLEAR  = MUX2_SEL_1
  } key_dec_sel_e;
  typedef enum logic [KeyWordsSelWidth-1:0] {
    KEY_WORDS_0123 = MUX4_SEL_0,
    KEY_WORDS_2345 = MUX4_SEL_1,
    KEY_WORDS_4567 = MUX4_SEL_2,
    KEY_WORDS_ZERO = MUX4_SEL_3
  } key_words_sel_e;
  typedef enum logic [RoundKeySelWidth-1:0] {
    ROUND_KEY_DIRECT = MUX2_SEL_0,
    ROUND_KEY_MIXED  = MUX2_SEL_1
  } round_key_sel_e;
  typedef enum logic [AddSOSelWidth-1:0] {
    ADD_SO_ZERO = MUX3_SEL_0,
    ADD_SO_IV   = MUX3_SEL_1,
    ADD_SO_DIP  = MUX3_SEL_2
  } add_so_sel_e;
  typedef enum logic [GHashInSelWidth-1:0] {
    GHASH_IN_DATA_IN_PREV = MUX2_SEL_0,
    GHASH_IN_DATA_OUT     = MUX2_SEL_1
  } ghash_in_sel_e;
  typedef enum logic [GHashAddInSelWidth-1:0] {
    ADD_IN_GHASH_IN = 3'b001,
    ADD_IN_CORR_A   = 3'b010,
    ADD_IN_CORR_B   = 3'b100,
    ADD_IN_ZERO     = 3'b000
  } ghash_add_in_sel_e;
  typedef enum logic [GHashStateSelWidth-1:0] {
    GHASH_STATE_RESTORE = MUX5_SEL_0,
    GHASH_STATE_INIT    = MUX5_SEL_1,
    GHASH_STATE_ADD     = MUX5_SEL_2,
    GHASH_STATE_ADD_S   = MUX5_SEL_3,
    GHASH_STATE_MULT    = MUX5_SEL_4
  } ghash_state_sel_e;
  typedef enum logic [GFMultInSelWidth-1:0] {
    MULT_IN_STATE0 = 3'b001,
    MULT_IN_STATE1 = 3'b010,
    MULT_IN_S1     = 3'b100,
    MULT_IN_ZERO   = 3'b000
  } gf_mult_in_sel_e;
  typedef enum logic [DataOutSelWidth-1:0] {
    DATA_OUT_CIPHER = MUX2_SEL_0,
    DATA_OUT_GHASH  = MUX2_SEL_1
  } data_out_sel_e;
  typedef enum logic [Sp2VWidth-1:0] {
    SP2V_HIGH = MUX2_SEL_0,
    SP2V_LOW  = MUX2_SEL_1
  } sp2v_e;
  function automatic logic [31:0] aes_circ_byte_shift(logic [31:0] in, logic [1:0] shift);
    logic [31:0] out;
    logic [31:0] s;
    s = {30'b0,shift};
    out = {in[8*((7-s)%4) +: 8], in[8*((6-s)%4) +: 8],
           in[8*((5-s)%4) +: 8], in[8*((4-s)%4) +: 8]};
    return out;
  endfunction
endpackage
