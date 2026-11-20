-- =============================================================================
-- cpu_pkg.vhd  --  shared types, opcodes and control encodings
--
-- Instruction word (one 32-bit word per instruction):
--   [31:27] opcode  [26:24] D (Rdst)  [23:21] A (Rsrc1 / base)
--   [20:18] B (Rsrc2 / store data)    [17:16] 0  [15:0] IMM / offset / target
-- The assembler duplicates fields so that register-file read port 1 is ALWAYS
-- addressed by A and read port 2 ALWAYS by B.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

package cpu_pkg is

  subtype slv32 is std_logic_vector(31 downto 0);
  subtype slv16 is std_logic_vector(15 downto 0);
  subtype slv5  is std_logic_vector(4 downto 0);
  subtype slv3  is std_logic_vector(2 downto 0);
  subtype slv2  is std_logic_vector(1 downto 0);

  type regfile_t is array (0 to 7) of slv32;
  type mem_t     is array (0 to 4095) of slv32;

  -- ---------------------------------------------------------------- opcodes
  constant OP_NOP  : slv5 := "00000";  constant OP_HLT  : slv5 := "00001";
  constant OP_SETC : slv5 := "00010";  constant OP_NOT  : slv5 := "00011";
  constant OP_INC  : slv5 := "00100";  constant OP_OUT  : slv5 := "00101";
  constant OP_IN   : slv5 := "00110";  constant OP_MOV  : slv5 := "00111";
  constant OP_SWAP : slv5 := "01000";  constant OP_ADD  : slv5 := "01001";
  constant OP_SUB  : slv5 := "01010";  constant OP_AND  : slv5 := "01011";
  constant OP_IADD : slv5 := "01100";  constant OP_CMP  : slv5 := "01101";
  constant OP_SHR  : slv5 := "01110";  constant OP_SHL  : slv5 := "01111";
  constant OP_PUSH : slv5 := "10000";  constant OP_POP  : slv5 := "10001";
  constant OP_LDM  : slv5 := "10010";  constant OP_LDD  : slv5 := "10011";
  constant OP_STD  : slv5 := "10100";  constant OP_JZ   : slv5 := "10101";
  constant OP_JN   : slv5 := "10110";  constant OP_JC   : slv5 := "10111";
  constant OP_JMP  : slv5 := "11000";  constant OP_CALL : slv5 := "11001";
  constant OP_RET  : slv5 := "11010";  constant OP_INT  : slv5 := "11011";
  constant OP_RTI  : slv5 := "11100";

  -- word injected in ID for a hardware interrupt: INT with vector address 1
  constant HWINT_WORD : slv32 := OP_INT & "000" & "000" & "000" & "00" & x"0001";

  -- ---------------------------------------------------------------- encodings
  -- ALU: result = X + Y + cin  (one carry chain for every arithmetic/logic op)
  constant XS_A    : slv2 := "00";  constant XS_NOTA : slv2 := "01";
  constant XS_AND  : slv2 := "10";  constant XS_B    : slv2 := "11";
  constant YS_0    : slv2 := "00";  constant YS_B    : slv2 := "01";
  constant YS_NOTB : slv2 := "10";
  -- operand-B source
  constant BS_REG  : slv2 := "00";  constant BS_IMM : slv2 := "01";  constant BS_IN : slv2 := "10";
  -- carry update
  constant FC_KEEP : slv2 := "00";  constant FC_ADD : slv2 := "01";
  constant FC_SHF  : slv2 := "10";  constant FC_SET : slv2 := "11";
  -- branch kind (resolved in EX2)
  constant BR_NONE : slv3 := "000"; constant BR_Z : slv3 := "001";
  constant BR_N    : slv3 := "010"; constant BR_C : slv3 := "011";
  constant BR_ALW  : slv3 := "100";
  -- forwarding select (pre-computed in ID)
  constant FS_RF   : slv2 := "00"; constant FS_E2 : slv2 := "01";
  constant FS_MEM  : slv2 := "10"; constant FS_WB : slv2 := "11";

  -- ---------------------------------------------------------------- control word
  type dec_t is record
    -- used in ID only
    usesA, usesB : std_logic;   -- real register sources (forwarding / load-use)
    pcB          : std_logic;   -- read port 2 := PC (return address, CALL / INT)
    hlt          : std_logic;
    swap         : std_logic;   -- SWAP, issued as two micro-ops
    destB        : std_logic;   -- destination = field B (2nd SWAP micro-op)
    -- EX1
    wr           : std_logic;   -- writes a register
    xs, ys       : slv2;
    cin          : std_logic;
    bsel         : slv2;
    sx           : std_logic;   -- immediate sign-extended (IADD); else zero-extended (LDM)
    shift, shr   : std_logic;
    fzn          : std_logic;   -- update Z and N
    fc           : slv2;        -- carry update mode
    rti          : std_logic;   -- CCR <- shadow CCR
    -- EX2 / MEM
    br           : slv3;
    stk, pop     : std_logic;   -- stack access, pop = SP+1
    we           : std_logic;   -- RAM write
    memread      : std_logic;   -- register result comes from RAM (LDD, POP)
    outp         : std_logic;   -- OUT
    int          : std_logic;   -- INT / hardware interrupt
    ret          : std_logic;   -- RET / RTI : PC <- M[SP+1]
  end record;

  constant DEC_NOP : dec_t := (
    usesA => '0', usesB => '0', pcB => '0', hlt => '0', swap => '0', destB => '0',
    wr => '0', xs => XS_A, ys => YS_0, cin => '0', bsel => BS_REG, sx => '0',
    shift => '0', shr => '0', fzn => '0', fc => FC_KEEP, rti => '0',
    br => BR_NONE, stk => '0', pop => '0', we => '0', memread => '0',
    outp => '0', int => '0', ret => '0');

end package;
