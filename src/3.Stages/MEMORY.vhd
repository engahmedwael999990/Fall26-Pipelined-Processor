-- =============================================================================
-- MEMORY.vhd  --  MEM stage: the RAM port-B response (q_b) arrives here.
-- Result = q_b for LDD / POP, else the EX result.  (RET / RTI take q_b into PC.)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity MEMORY is
  port (
    memread : in  std_logic;
    q_b     : in  slv32;
    res     : in  slv32;
    result  : out slv32
  );
end entity;

architecture rtl of MEMORY is
begin
  result <= q_b when memread = '1' else res;
end architecture;
