-- =============================================================================
-- EX2_MEM.vhd  --  EX2/MEM pipeline register
-- The control bits are ANDed with valid on the way in, so no valid bit is kept.
-- The RAM address/data registers (inside the M10K) are the other half of this
-- boundary: the EX2 address is sampled at the same edge.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity EX2_MEM is
  port (
    clk, rst    : in  std_logic;
    wr_in, memread_in, ret_in, rti_in : in std_logic;   -- already ANDed with valid
    dest_in     : in  slv3;
    res_in      : in  slv32;
    wr_out, memread_out, ret_out, rti_out : out std_logic;
    dest_out    : out slv3;
    res_out     : out slv32
  );
end entity;

architecture rtl of EX2_MEM is
begin
  process (clk, rst)
  begin
    if rst = '1' then
      wr_out <= '0'; memread_out <= '0'; ret_out <= '0'; rti_out <= '0';
    elsif rising_edge(clk) then
      wr_out <= wr_in; memread_out <= memread_in; ret_out <= ret_in; rti_out <= rti_in;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      dest_out <= dest_in;
      res_out  <= res_in;
    end if;
  end process;
end architecture;
