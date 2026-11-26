-- =============================================================================
-- alu.vhd  --  one carry chain:  result = X + Y + cin
--   X in {A, not A, A and B, B}     Y in {0, B, not B}
--   ADD  : A + B          SUB/CMP : A + not B + 1 (C = borrow = not carry-out,
--                                   i.e. C = 1 when A < B unsigned; Q&A #14)
--   INC  : A + 0 + 1      IADD    : A + imm
--   NOT  : not A + 0      AND     : (A and B) + 0
--   MOV / IN / LDM : B + 0           PASS (OUT, PUSH, LDD/STD base): A + 0
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity alu is
  port (
    a, b   : in  slv32;
    xs, ys : in  slv2;
    cin    : in  std_logic;
    result : out slv32;
    cout   : out std_logic
  );
end entity;

architecture rtl of alu is
  signal x, y  : slv32;
  signal cin_u : unsigned(0 downto 0);
  signal sum   : unsigned(32 downto 0);
begin
  with xs select x <= a when XS_A, not a when XS_NOTA, a and b when XS_AND, b when others;
  with ys select y <= b when YS_B, not b when YS_NOTB, (others => '0') when others;
  cin_u(0) <= cin;
  sum    <= ('0' & unsigned(x)) + ('0' & unsigned(y)) + cin_u;
  result <= std_logic_vector(sum(31 downto 0));
  -- ys = YS_NOTB ("10") only for SUB/CMP: invert carry-out to give borrow
  cout   <= sum(32) xor ys(1);
end architecture;
