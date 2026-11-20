-- =============================================================================
-- EX1_EX2.vhd  --  EX1/EX2 pipeline register
-- valid_in = EX1 valid and not flush (a taken jump kills the EX1 instruction)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity EX1_EX2 is
  port (
    clk, rst    : in  std_logic;
    valid_in    : in  std_logic;
    wr_in, memread_in, outp_in, int_in, ret_in, rti_in : in std_logic;
    stk_in, pop_in, we_in : in std_logic;
    br_in       : in  slv3;
    dest_in     : in  slv3;
    res_in      : in  slv32;
    data_in     : in  slv32;
    imm_in      : in  slv16;
    valid_out   : out std_logic;
    wr_out, memread_out, outp_out, int_out, ret_out, rti_out : out std_logic;
    stk_out, pop_out, we_out : out std_logic;
    br_out      : out slv3;
    dest_out    : out slv3;
    res_out     : out slv32;
    data_out    : out slv32;
    imm_out     : out slv16
  );
end entity;

architecture rtl of EX1_EX2 is
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
      wr_out  <= wr_in;  memread_out <= memread_in; outp_out <= outp_in;
      int_out <= int_in; ret_out <= ret_in; rti_out <= rti_in;
      stk_out <= stk_in; pop_out <= pop_in; we_out <= we_in;
      br_out  <= br_in;
      dest_out <= dest_in;
      res_out  <= res_in;
      data_out <= data_in;
      imm_out  <= imm_in;
    end if;
  end process;
end architecture;
