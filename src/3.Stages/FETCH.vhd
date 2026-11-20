-- =============================================================================
-- FETCH.vhd  --  IF stage: PC register, PC + 1, PC mux
-- PC mux priority: taken jump (EX2) > RET/RTI (MEM) > vector word > PC + 1
-- pc[11:0] is the RAM port-A address; adv = en_a = PC enable.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity FETCH is
  port (
    clk, rst : in  std_logic;
    adv      : in  std_logic;   -- fetch the next word
    flush    : in  std_logic;   -- taken jump in EX2
    target   : in  slv16;       -- jump target (EX1/EX2 imm)
    m_ret    : in  std_logic;   -- RET / RTI in MEM
    q_b      : in  slv32;       -- return address  M[SP+1]
    vec2     : in  std_logic;   -- vector word on q_a
    q_a      : in  slv32;       -- vector word
    pc       : out slv32
  );
end entity;

architecture rtl of FETCH is
  signal pc_r, pc_inc : slv32 := (others => '0');
begin
  u_inc : entity work.incrementer port map (a => pc_r, y => pc_inc);

  process (clk, rst)
  begin
    if rst = '1' then
      pc_r <= (others => '0');
    elsif rising_edge(clk) then
      if flush = '1' then
        pc_r <= x"0000" & target;
      elsif m_ret = '1' then
        pc_r <= q_b;
      elsif vec2 = '1' then
        pc_r <= q_a;
      elsif adv = '1' then
        pc_r <= pc_inc;
      end if;
    end if;
  end process;
  pc <= pc_r;
end architecture;
