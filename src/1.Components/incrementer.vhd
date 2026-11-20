-- =============================================================================
-- incrementer.vhd  --  PC + 1
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity incrementer is
  port (
    a : in  std_logic_vector(31 downto 0);
    y : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of incrementer is
begin
  y <= std_logic_vector(unsigned(a) + 1);
end architecture;
