// Stub: encodings assumed from OpenTitan prim_sha2_pkg convention (not verified
// against this checkout; prim/ is not in the sparse checkout).
package prim_sha2_pkg;
  typedef logic [31:0] sha_fifo32_t;
  typedef enum logic [2:0] {
    SHA2_None = 3'd0,
    SHA2_224  = 3'd1,
    SHA2_256  = 3'd2,
    SHA2_384  = 3'd3,
    SHA2_512  = 3'd4
  } digest_mode_e;
  typedef enum logic [2:0] {
    Key_None = 3'd0,
    Key_128  = 3'd1,
    Key_256  = 3'd2,
    Key_384  = 3'd3,
    Key_512  = 3'd4,
    Key_1024 = 3'd5
  } key_length_e;
endpackage
