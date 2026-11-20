-- =============================================================================
-- sign_extend.vhd  --  16 -> 32 bit immediate extension
-- sx = 1 : sign extension  (IADD)
-- sx = 0 : zero extension  (LDM: R[Rdst] <- Imm<15:0>)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity sign_extend is
  port (
    imm   : in  slv16;
    sx    : in  std_logic;
    imm32 : out slv32
  );
end entity;

architecture rtl of sign_extend is
  signal s : std_logic;
begin
  s     <= imm(15) and sx;
  imm32 <= (31 downto 16 => s) & imm;
end architecture;
