-- =============================================================================
-- conditional_jump_decoder.vhd  --  branch decision (EX2)
-- taken = valid and (JMP/CALL/INT  or  JZ&Z  or  JN&N  or  JC&C)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity conditional_jump_decoder is
  port (
    valid   : in  std_logic;
    br      : in  slv3;
    z, n, c : in  std_logic;
    taken   : out std_logic
  );
end entity;

architecture rtl of conditional_jump_decoder is
begin
  taken <= valid when (br = BR_ALW)
                   or (br = BR_Z and z = '1')
                   or (br = BR_N and n = '1')
                   or (br = BR_C and c = '1') else '0';
end architecture;
