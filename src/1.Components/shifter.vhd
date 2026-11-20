-- =============================================================================
-- shifter.vhd  --  SHL / SHR (logical), carry = last bit shifted out
--   count 0 : result = A      (carry is kept: the CCR logic ignores cout)
--   count 32: result = 0, carry = A(0) for SHL / A(31) for SHR
--   count >32: result = 0, carry = 0
-- DSP = false : LUT barrel shifter (33-bit, SHR = reverse / shift / reverse)
-- DSP = true  : multiplier block (A * 2^n), for an ALM comparison in Quartus
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity shifter is
  generic (DSP : boolean := false);
  port (
    a      : in  slv32;
    count  : in  slv16;
    shr    : in  std_logic;
    result : out slv32;
    cout   : out std_logic
  );
end entity;

architecture rtl of shifter is
begin

  barrel : if not DSP generate
    process (a, count, shr)
      variable v : unsigned(32 downto 0);
      variable r : slv32;
      variable n : integer range 0 to 63;
    begin
      for i in 0 to 31 loop
        if shr = '1' then v(i) := a(31 - i); else v(i) := a(i); end if;
      end loop;
      v(32) := '0';
      if count(15 downto 6) /= "0000000000" then
        v := (others => '0');
      else
        n := to_integer(unsigned(count(5 downto 0)));
        v := shift_left(v, n);
      end if;
      for i in 0 to 31 loop
        if shr = '1' then r(i) := v(31 - i); else r(i) := v(i); end if;
      end loop;
      result <= r;
      cout   <= v(32);
    end process;
  end generate;

  mult : if DSP generate
    -- SHL n : A * 2^n      -> result = P[31:0],  carry = P[32]
    -- SHR n : A * 2^(32-n) -> result = P[63:32], carry = P[31]
    process (a, count, shr)
      variable k : integer range 0 to 63;
      variable m : unsigned(32 downto 0);
      variable p : unsigned(64 downto 0);
    begin
      m := (others => '0');
      if count(15 downto 6) = "0000000000" and unsigned(count(5 downto 0)) <= 32 then
        if shr = '1' then k := 32 - to_integer(unsigned(count(5 downto 0)));
        else              k := to_integer(unsigned(count(5 downto 0)));
        end if;
        m(k) := '1';
      end if;
      p := unsigned(a) * m;
      if shr = '1' then result <= std_logic_vector(p(63 downto 32)); cout <= p(31);
      else              result <= std_logic_vector(p(31 downto 0));  cout <= p(32);
      end if;
    end process;
  end generate;

end architecture;
