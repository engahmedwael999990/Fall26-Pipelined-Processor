-- =============================================================================
-- IF_ID.vhd  --  IF/ID pipeline register
-- The instruction word itself is the RAM port-A output register (q_a), held by
-- en_a during stalls, so this register only keeps the VALID bit.
--   clear : flush (taken jump), RET/RTI redirect, vector fetch, HW-interrupt slot
--   load  : a new word was fetched (adv)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity IF_ID is
  port (
    clk, rst : in  std_logic;
    clear    : in  std_logic;
    load     : in  std_logic;
    valid    : out std_logic
  );
end entity;

architecture rtl of IF_ID is
  signal v : std_logic := '0';
begin
  process (clk, rst)
  begin
    if rst = '1' then
      v <= '0';
    elsif rising_edge(clk) then
      if clear = '1' then
        v <= '0';
      elsif load = '1' then
        v <= '1';
      end if;
    end if;
  end process;
  valid <= v;
end architecture;
