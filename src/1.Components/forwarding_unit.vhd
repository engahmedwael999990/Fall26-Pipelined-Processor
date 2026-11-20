-- =============================================================================
-- forwarding_unit.vhd  --  runs in ID, one stage early
-- Compares the sources of the instruction in ID with the destinations of the
-- three older instructions (in EX1, EX2, MEM).  Newest match wins.  The select
-- is registered in ID/EX1, so EX1 only has a 4:1 mux in front of the ALU:
--   producer in EX1 now  -> will be in EX1/EX2 : FS_E2
--   producer in EX2 now  -> will be in EX2/MEM : FS_MEM
--   producer in MEM now  -> will be in MEM/WB  : FS_WB
-- load_use: a load (LDD / POP) has no value before MEM/WB -> stall in ID.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity forwarding_unit is
  port (
    srcA, srcB     : in  slv3;
    usesA, usesB   : in  std_logic;
    swap_ph        : in  std_logic;   -- 2nd SWAP uop must not see the 1st one
    -- instruction in EX1 (ID/EX1 register)
    e1_v, e1_wr, e1_memread : in std_logic;
    e1_dest        : in  slv3;
    -- instruction in EX2 (EX1/EX2 register)
    e2_v, e2_wr, e2_memread : in std_logic;
    e2_dest        : in  slv3;
    -- instruction in MEM (EX2/MEM register, already ANDed with valid)
    m_wr           : in  std_logic;
    m_dest         : in  slv3;
    fsA, fsB       : out slv2;
    load_use       : out std_logic
  );
end entity;

architecture rtl of forwarding_unit is
begin
  process (srcA, srcB, usesA, usesB, swap_ph, e1_v, e1_wr, e1_memread, e1_dest,
           e2_v, e2_wr, e2_memread, e2_dest, m_wr, m_dest)
    variable a1, a2, a3, b1, b2, b3 : std_logic;
  begin
    a1 := '0'; a2 := '0'; a3 := '0'; b1 := '0'; b2 := '0'; b3 := '0';
    if e1_v = '1' and e1_wr = '1' and e1_dest = srcA and swap_ph = '0' then a1 := '1'; end if;
    if e2_v = '1' and e2_wr = '1' and e2_dest = srcA then a2 := '1'; end if;
    if m_wr = '1' and m_dest = srcA then a3 := '1'; end if;
    if e1_v = '1' and e1_wr = '1' and e1_dest = srcB then b1 := '1'; end if;
    if e2_v = '1' and e2_wr = '1' and e2_dest = srcB then b2 := '1'; end if;
    if m_wr = '1' and m_dest = srcB then b3 := '1'; end if;

    if    usesA = '0' then fsA <= FS_RF;
    elsif a1 = '1'    then fsA <= FS_E2;
    elsif a2 = '1'    then fsA <= FS_MEM;
    elsif a3 = '1'    then fsA <= FS_WB;
    else                   fsA <= FS_RF;
    end if;
    if    usesB = '0' then fsB <= FS_RF;
    elsif b1 = '1'    then fsB <= FS_E2;
    elsif b2 = '1'    then fsB <= FS_MEM;
    elsif b3 = '1'    then fsB <= FS_WB;
    else                   fsB <= FS_RF;
    end if;

    load_use <= (usesA and ((a1 and e1_memread) or (not a1 and a2 and e2_memread)))
             or (usesB and ((b1 and e1_memread) or (not b1 and b2 and e2_memread)));
  end process;
end architecture;
