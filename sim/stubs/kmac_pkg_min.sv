// SCOUT stub: selected kmac_pkg declarations (verbatim), struct-typed params omitted.
package kmac_pkg;

  typedef struct packed {
      logic        valid;
      err_code_e   code; // Type of error
      logic [23:0] info; // Additional Debug info
    } err_t;
  typedef enum logic [5:0] {
      //CmdNone      = 6'b001011, // dec 10
      // CmdNone is manually set to all zero by design!
      // The minimum Hamming distance is still 3
      CmdNone      = 6'b000000, // dec  0
      CmdStart     = 6'b011101, // dec 29
      CmdProcess   = 6'b101110, // dec 46
      CmdManualRun = 6'b110001, // dec 49
      CmdDone      = 6'b010110  // dec 22
    } kmac_cmd_e;
  typedef enum logic [AppStateWidth-1:0] {
      StIdle = 10'b0110100101,
  
      // In StAppCfg state, it latches the cfg from AppCfg parameter to determine the kmac_mode,
      // sha3_mode, and keccak strength.
      // In StAppOutLen, the app interface pushes encoded output length into the core.
      StAppCfg        = 10'b1000001010,
      StAppMsg        = 10'b1011100000,
      StAppOutLen     = 10'b0011101110,
      StAppProcess    = 10'b0100111111,
      StAppWait       = 10'b0100010001,
      StAppPushDigest = 10'b1100100011,
      StAppFinish     = 10'b1001110010,
  
      // SW Controlled
      // If start request comes from SW first, until the operation ends, all
      // requests from apps will be stalled.
      StSw = 10'b1101000010,
  
      // Error KeyNotValid triggers if key is used but it is not valid at the time.
      StErrorKeyNotValid = 10'b0000001111,
  
      StErrorAwaitMsg         = 10'b1100100100,
      StErrorNotify           = 10'b0111100010,
      StErrorAwaitTermination = 10'b0101101000,
      StErrorFinish           = 10'b0011111101,
      StErrorAwaitSw          = 10'b0100001100,
      StErrorAwaitAbsorbed    = 10'b1110001111,
      StErrorPush             = 10'b0010110100,
  
      // This state is used for terminal errors
      StTerminalError = 10'b1101111001
    } st_e;
endpackage
