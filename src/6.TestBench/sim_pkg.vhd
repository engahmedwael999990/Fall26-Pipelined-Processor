-- =============================================================================
-- sim_pkg.vhd  --  SIMULATION ONLY (not part of the Quartus project)
-- Global signals that let the self-checking testbench observe the processor
-- without adding ports. The RTL drives them inside translate_off regions.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

package sim_pkg is
  signal sim_retire    : std_logic := '0';  -- a valid (committed) micro-op is in EX2
  signal sim_hwint     : std_logic := '0';  -- that micro-op is the injected HW interrupt
  signal sim_in_sample : std_logic := '0';  -- an IN instruction samples IN.PORT this edge
  signal sim_out_we    : std_logic := '0';  -- OUT register written this edge
  signal sim_halted    : std_logic := '0';
  signal sim_quiet     : std_logic := '0';  -- pipeline drained (EX1..WB empty)
  signal sim_dump      : std_logic := '0';  -- TB request: RAM dumps itself to file
  -- per-stage instruction address (for pipeline trace), x"FFFFFFFF" = bubble
  signal sim_pc_id, sim_pc_ex1, sim_pc_ex2, sim_pc_mem, sim_pc_wb : slv32 := (others => '1');
  signal sim_fetch_pc  : slv32 := (others => '1');
  signal sim_ifv       : std_logic := '0';
  signal sim_regs      : regfile_t := (others => (others => '0'));
  signal sim_pc, sim_sp : slv32 := (others => '0');
  signal sim_ccr       : std_logic_vector(3 downto 0) := "0000";
end package;
