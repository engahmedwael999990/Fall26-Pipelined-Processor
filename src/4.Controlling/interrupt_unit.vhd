-- =============================================================================
-- interrupt_unit.vhd  --  front-end state machine
--   vec1 / vec2 : vector fetch.  Reset (PC = 0) or INT in EX2 (PC = vector
--                 address): the next fetched word is loaded into PC.
--   irq_pend    : rising edge of INTR.IN latched until taken (non-nested)
--   inj         : issue the HW-interrupt micro-op (INT 1) in ID this cycle
--   in_isr      : set by INT in EX2, cleared by RTI in MEM
--   swap_ph     : 2nd SWAP micro-op pending
--   halted      : HLT reached; only RESET.IN restarts the CPU
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity interrupt_unit is
  port (
    clk, rst  : in  std_logic;
    intr_in   : in  std_logic;   -- INTR.IN
    prep      : in  std_logic;
    flush     : in  std_logic;
    issue_n   : in  std_logic;
    id_swap   : in  std_logic;
    e2_int    : in  std_logic;   -- valid INT in EX2
    m_rti     : in  std_logic;   -- RTI in MEM
    halt_set  : in  std_logic;
    vec1      : out std_logic;
    vec2      : out std_logic;
    irq_pend  : out std_logic;
    inj       : out std_logic;
    in_isr    : out std_logic;
    swap_ph   : out std_logic;
    halted    : out std_logic
  );
end entity;

architecture rtl of interrupt_unit is
  signal v1, v2, pend, ij, isr, sph, hl, intr_d : std_logic := '0';
begin
  process (clk, rst)
  begin
    if rst = '1' then
      v1 <= '1'; v2 <= '0'; pend <= '0'; ij <= '0'; isr <= '0';
      sph <= '0'; hl <= '0'; intr_d <= '0';
    elsif rising_edge(clk) then
      v1 <= e2_int;
      v2 <= v1;
      ij <= prep;
      intr_d <= intr_in;
      pend <= (pend and not ij) or (intr_in and not intr_d);
      if e2_int = '1' then    isr <= '1';
      elsif m_rti = '1' then  isr <= '0';
      end if;
      if flush = '1' then
        sph <= '0';
      elsif issue_n = '1' and id_swap = '1' then
        sph <= not sph;
      end if;
      if halt_set = '1' then hl <= '1'; end if;
    end if;
  end process;
  vec1 <= v1; vec2 <= v2; irq_pend <= pend; inj <= ij;
  in_isr <= isr; swap_ph <= sph; halted <= hl;
end architecture;
