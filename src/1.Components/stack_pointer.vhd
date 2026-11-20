-- =============================================================================
-- stack_pointer.vhd  --  SP, 32 bit, reset value 2^12 - 1 = 0FFF
-- en = valid stack op in EX2:  push / CALL / INT : SP - 1
--                              pop  / RET  / RTI : SP + 1
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity stack_pointer is
  port (
    clk, rst : in  std_logic;
    en, pop  : in  std_logic;
    sp       : out slv32
  );
end entity;

architecture rtl of stack_pointer is
  signal r : unsigned(31 downto 0) := x"00000FFF";
begin
  process (clk, rst)
  begin
    if rst = '1' then
      r <= x"00000FFF";
    elsif rising_edge(clk) then
      if en = '1' then
        if pop = '1' then r <= r + 1; else r <= r - 1; end if;
      end if;
    end if;
  end process;
  sp <= std_logic_vector(r);
end architecture;
