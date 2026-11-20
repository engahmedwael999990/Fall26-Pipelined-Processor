-- =============================================================================
-- DECODE.vhd  --  ID stage
-- IR mux (RAM word / injected HW-interrupt word), Control Unit, Register File,
-- destination mux (D, or B for the 2nd SWAP micro-op), RD2 mux (register or PC
-- = return address for CALL / INT), Forwarding Unit.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity DECODE is
  generic (RF_NEGEDGE : boolean := true);
  port (
    clk, rst  : in  std_logic;
    q_a       : in  slv32;      -- instruction word (RAM port-A output)
    inj       : in  std_logic;  -- issue the hardware-interrupt micro-op
    swap_ph   : in  std_logic;
    pc        : in  slv32;
    -- write back
    wb_we     : in  std_logic;
    wb_wa     : in  slv3;
    wb_wd     : in  slv32;
    -- older instructions (forwarding / load-use)
    e1_v, e1_wr, e1_memread : in std_logic;
    e1_dest   : in  slv3;
    e2_v, e2_wr, e2_memread : in std_logic;
    e2_dest   : in  slv3;
    m_wr      : in  std_logic;
    m_dest    : in  slv3;
    -- to ID/EX1 and hazard unit
    ctrl      : out dec_t;
    dest      : out slv3;
    fsA, fsB  : out slv2;
    rd1, rd2  : out slv32;
    imm       : out slv16;
    load_use  : out std_logic
  );
end entity;

architecture rtl of DECODE is
  signal ir         : slv32;
  signal c          : dec_t;
  signal rf1, rf2   : slv32;
begin
  ir <= HWINT_WORD when inj = '1' else q_a;

  u_cu : entity work.Control_unit
    port map (opcode => ir(31 downto 27), swap_ph => swap_ph, ctrl => c);

  u_rf : entity work.register_file
    generic map (NEGEDGE => RF_NEGEDGE)
    port map (clk => clk, rst => rst, we => wb_we, wa => wb_wa, wd => wb_wd,
              ra1 => ir(23 downto 21), ra2 => ir(20 downto 18), rd1 => rf1, rd2 => rf2);

  u_fwd : entity work.forwarding_unit
    port map (srcA => ir(23 downto 21), srcB => ir(20 downto 18),
              usesA => c.usesA, usesB => c.usesB, swap_ph => swap_ph,
              e1_v => e1_v, e1_wr => e1_wr, e1_memread => e1_memread, e1_dest => e1_dest,
              e2_v => e2_v, e2_wr => e2_wr, e2_memread => e2_memread, e2_dest => e2_dest,
              m_wr => m_wr, m_dest => m_dest,
              fsA => fsA, fsB => fsB, load_use => load_use);

  dest <= ir(20 downto 18) when c.destB = '1' else ir(26 downto 24);
  rd1  <= rf1;
  rd2  <= pc when c.pcB = '1' else rf2;
  imm  <= ir(15 downto 0);
  ctrl <= c;
end architecture;
