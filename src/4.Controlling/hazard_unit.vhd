-- =============================================================================
-- hazard_unit.vhd  --  issue / stall / advance decisions (combinational, ID)
--   issue    : the micro-op in ID enters EX1 this cycle (else a bubble)
--   complete : the IF/ID word is consumed (SWAP keeps it for its 2nd uop)
--   adv      : fetch the next word (PC enable = RAM en_a); 0 holds PC + IF/ID
--   prep     : take the hardware interrupt now (inject INT 1 next cycle)
--   halt_set : HLT reached ID and nothing older can redirect the PC
-- Stall in ID: load-use, RET/RTI in flight, HLT, halted.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity hazard_unit is
  port (
    ifv       : in  std_logic;   -- IF/ID valid
    load_use  : in  std_logic;
    ctrl      : in  dec_t;       -- micro-op in ID
    swap_ph   : in  std_logic;
    inj       : in  std_logic;
    halted    : in  std_logic;
    flush     : in  std_logic;   -- taken jump in EX2
    irq_pend  : in  std_logic;
    in_isr    : in  std_logic;
    vec1      : in  std_logic;
    vec2      : in  std_logic;
    e1_v      : in  std_logic;   -- older control transfers in flight
    e1_ret    : in  std_logic;
    e1_br     : in  slv3;
    e2_v      : in  std_logic;
    e2_ret    : in  std_logic;
    e2_br     : in  slv3;
    m_ret     : in  std_logic;
    issue     : out std_logic;
    issue_n   : out std_logic;   -- normal (non-injected) issue
    complete  : out std_logic;
    adv       : out std_logic;
    prep      : out std_logic;
    halt_set  : out std_logic
  );
end entity;

architecture rtl of hazard_unit is
  signal ret_inflight, ctl_inflight, iss_n, comp, pr, id_ctl : std_logic;
begin
  ret_inflight <= (e1_v and e1_ret) or (e2_v and e2_ret) or m_ret;
  ctl_inflight <= (e1_v and (e1_ret or e1_br(2) or e1_br(1) or e1_br(0)))
               or (e2_v and (e2_ret or e2_br(2) or e2_br(1) or e2_br(0)))
               or m_ret or vec1 or vec2;
  id_ctl       <= ctrl.br(2) or ctrl.br(1) or ctrl.br(0) or ctrl.ret;

  iss_n <= ifv and not load_use and not ret_inflight and not halted and not ctrl.hlt and not inj;
  comp  <= iss_n and not (ctrl.swap and not swap_ph);
  pr    <= irq_pend and not in_isr and not halted and not inj and not ctl_inflight and not flush
           and ((ifv and comp and not id_ctl) or not ifv);

  issue    <= (iss_n or inj) and not flush;
  issue_n  <= iss_n;
  complete <= comp;
  prep     <= pr;
  halt_set <= ifv and ctrl.hlt and not ctl_inflight and not inj;
  adv      <= (not ifv or comp) and not halted and not pr;
end architecture;
