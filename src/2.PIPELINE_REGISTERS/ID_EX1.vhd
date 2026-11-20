-- =============================================================================
-- ID_EX1.vhd  --  ID/EX1 pipeline register
-- Only VALID is reset; the other fields are don't-care while valid = 0.
-- valid_in = issue (0 = bubble on stall / flush)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity ID_EX1 is
  port (
    clk, rst  : in  std_logic;
    valid_in  : in  std_logic;
    ctrl_in   : in  dec_t;
    dest_in   : in  slv3;
    fsA_in    : in  slv2;
    fsB_in    : in  slv2;
    rd1_in    : in  slv32;
    rd2_in    : in  slv32;
    imm_in    : in  slv16;
    valid_out : out std_logic;
    ctrl_out  : out dec_t;
    dest_out  : out slv3;
    fsA_out   : out slv2;
    fsB_out   : out slv2;
    rd1_out   : out slv32;
    rd2_out   : out slv32;
    imm_out   : out slv16
  );
end entity;

architecture rtl of ID_EX1 is
begin
  process (clk, rst)
  begin
    if rst = '1' then
      valid_out <= '0';
    elsif rising_edge(clk) then
      valid_out <= valid_in;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      ctrl_out <= ctrl_in;
      dest_out <= dest_in;
      fsA_out  <= fsA_in;
      fsB_out  <= fsB_in;
      rd1_out  <= rd1_in;
      rd2_out  <= rd2_in;
      imm_out  <= imm_in;
    end if;
  end process;
end architecture;
