-- =============================================================================
-- MEM_WB.vhd  --  MEM/WB pipeline register
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity MEM_WB is
  port (
    clk, rst   : in  std_logic;
    wr_in      : in  std_logic;
    dest_in    : in  slv3;
    result_in  : in  slv32;
    wr_out     : out std_logic;
    dest_out   : out slv3;
    result_out : out slv32
  );
end entity;

architecture rtl of MEM_WB is
begin
  process (clk, rst)
  begin
    if rst = '1' then
      wr_out <= '0';
    elsif rising_edge(clk) then
      wr_out <= wr_in;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      dest_out   <= dest_in;
      result_out <= result_in;
    end if;
  end process;
end architecture;
