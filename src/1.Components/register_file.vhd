-- =============================================================================
-- register_file.vhd  --  R0..R7, 8 x 32 bit, 2 read ports, 1 write port
-- NEGEDGE = true : written on the FALLING edge (WB in the 1st half of the cycle,
--                  ID reads in the 2nd half) -> no WB->ID bypass needed.
-- NEGEDGE = false: written on the rising edge + internal WB->ID bypass.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;
-- synthesis translate_off
use work.sim_pkg.all;
-- synthesis translate_on

entity register_file is
  generic (NEGEDGE : boolean := true);
  port (
    clk, rst : in  std_logic;
    -- write port (from WB)
    we       : in  std_logic;
    wa       : in  slv3;
    wd       : in  slv32;
    -- read ports (ID)
    ra1, ra2 : in  slv3;
    rd1, rd2 : out slv32
  );
end entity;

architecture rtl of register_file is
  signal regs : regfile_t := (others => (others => '0'));
begin

  neg : if NEGEDGE generate
    process (clk, rst)
    begin
      if rst = '1' then
        regs <= (others => (others => '0'));
      elsif falling_edge(clk) then
        if we = '1' then regs(to_integer(unsigned(wa))) <= wd; end if;
      end if;
    end process;
    rd1 <= regs(to_integer(unsigned(ra1)));
    rd2 <= regs(to_integer(unsigned(ra2)));
  end generate;

  pos : if not NEGEDGE generate
    process (clk, rst)
    begin
      if rst = '1' then
        regs <= (others => (others => '0'));
      elsif rising_edge(clk) then
        if we = '1' then regs(to_integer(unsigned(wa))) <= wd; end if;
      end if;
    end process;
    rd1 <= wd when (we = '1' and wa = ra1) else regs(to_integer(unsigned(ra1)));
    rd2 <= wd when (we = '1' and wa = ra2) else regs(to_integer(unsigned(ra2)));
  end generate;

  -- synthesis translate_off
  sim_regs <= regs;
  -- synthesis translate_on

end architecture;
