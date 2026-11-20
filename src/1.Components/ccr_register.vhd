-- =============================================================================
-- ccr_register.vhd  --  CCR (Z, N, C) and shadow CCR
--  * written at the end of EX1 by the instruction in EX1 (we = valid & !flush)
--  * RTI (in EX1): CCR <- shadow
--  * taken JZ / JN / JC (in EX2): clears the flag it tested
--  * INT / hardware interrupt (in EX2): shadow <- CCR
-- CCR(3) is reserved and reads as 0.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity ccr_register is
  port (
    clk, rst  : in  std_logic;
    -- from EX1
    we        : in  std_logic;
    rti       : in  std_logic;
    fzn       : in  std_logic;
    fc        : in  slv2;
    res       : in  slv32;      -- EX1 result (Z, N)
    alu_c     : in  std_logic;
    sh_c      : in  std_logic;
    sh_cnt_nz : in  std_logic;  -- shift count /= 0
    -- from EX2
    taken     : in  std_logic;
    br        : in  slv3;
    save      : in  std_logic;  -- INT in EX2
    z, n, c   : out std_logic;
    ccr       : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of ccr_register is
  signal fz, fn, fcy, sh_z, sh_n, sh_c_r : std_logic := '0';
begin
  process (clk, rst)
  begin
    if rst = '1' then
      fz <= '0'; fn <= '0'; fcy <= '0'; sh_z <= '0'; sh_n <= '0'; sh_c_r <= '0';
    elsif rising_edge(clk) then
      if we = '1' and rti = '1' then
        fz <= sh_z; fn <= sh_n; fcy <= sh_c_r;
      else
        if we = '1' and fzn = '1' then
          if res = x"00000000" then fz <= '1'; else fz <= '0'; end if;
          fn <= res(31);
        end if;
        if we = '1' then
          case fc is
            when FC_ADD => fcy <= alu_c;
            when FC_SHF => if sh_cnt_nz = '1' then fcy <= sh_c; end if;
            when FC_SET => fcy <= '1';
            when others => null;
          end case;
        end if;
        if taken = '1' then            -- EX1 is flushed in this cycle (we = 0)
          if br = BR_Z then fz  <= '0'; end if;
          if br = BR_N then fn  <= '0'; end if;
          if br = BR_C then fcy <= '0'; end if;
        end if;
      end if;
      if save = '1' then
        sh_z <= fz; sh_n <= fn; sh_c_r <= fcy;
      end if;
    end if;
  end process;
  z <= fz; n <= fn; c <= fcy;
  ccr <= '0' & fcy & fn & fz;
end architecture;
