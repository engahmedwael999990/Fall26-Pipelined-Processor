-- =============================================================================
-- memory_file.vhd  --  ONE shared 4096 x 32 synchronous RAM (Von Neumann)
-- Written in Intel's "true dual-port, single clock" template style so Quartus
-- maps it to M10K blocks:
--   Port A : instruction fetch, read only. q_a IS the IF/ID instruction register.
--            en_a = 0 holds q_a (used to hold IF/ID during stalls).
--   Port B : data / stack: LDD, STD, PUSH, POP, CALL, RET, INT, RTI.
-- Timing: address presented during a cycle is sampled at the rising edge that
-- ends the cycle; the data is on q during the next cycle.
-- No read-during-write logic is generated (no_rw_check): the program never
-- fetches a word in the same cycle it is being stored (no self-modifying code).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;
-- synthesis translate_off
use std.textio.all;
use work.sim_pkg.all;
-- synthesis translate_on

entity memory_file is
  generic (
    INIT_FILE : string := "";        -- simulation: hex image, one word per line
    DUMP_FILE : string := ""         -- simulation: written when sim_dump rises
  );
  port (
    clk    : in  std_logic;
    -- port A (fetch)
    en_a   : in  std_logic;
    addr_a : in  std_logic_vector(11 downto 0);
    q_a    : out slv32;
    -- port B (data)
    we_b   : in  std_logic;
    addr_b : in  std_logic_vector(11 downto 0);
    data_b : in  slv32;
    q_b    : out slv32
  );
end entity;

architecture rtl of memory_file is
  shared variable ram : mem_t;
  attribute ramstyle : string;
  attribute ramstyle of ram : variable is "M10K, no_rw_check";
  attribute ram_init_file : string;
  attribute ram_init_file of ram : variable is "program.mif";
  signal qa_r : slv32 := (others => '0');
  signal qb_r : slv32 := (others => '0');
begin

  port_b : process (clk)
  begin
    if rising_edge(clk) then
      if we_b = '1' then
        ram(to_integer(unsigned(addr_b))) := data_b;
      end if;
      qb_r <= ram(to_integer(unsigned(addr_b)));
    end if;
  end process;

  port_a : process (clk)
  begin
    if rising_edge(clk) then
      if en_a = '1' then
        qa_r <= ram(to_integer(unsigned(addr_a)));
      end if;
    end if;
  end process;

  q_a <= qa_r;
  q_b <= qb_r;

  -- synthesis translate_off
  loader : process
    file f     : text;
    variable l : line;
    variable c : character;
    variable ok : boolean;
    variable v : unsigned(31 downto 0);
    variable nd, a, h : integer;
    variable st : file_open_status;
  begin
    for i in mem_t'range loop
      ram(i) := (others => '0');
    end loop;
    if INIT_FILE /= "" then
      file_open(st, f, INIT_FILE, read_mode);
      assert st = open_ok report "cannot open " & INIT_FILE severity failure;
      a := 0;
      while not endfile(f) and a < 4096 loop
        readline(f, l);
        v := (others => '0'); nd := 0;
        loop
          read(l, c, ok);
          exit when not ok;
          h := -1;
          if    c >= '0' and c <= '9' then h := character'pos(c) - character'pos('0');
          elsif c >= 'A' and c <= 'F' then h := character'pos(c) - character'pos('A') + 10;
          elsif c >= 'a' and c <= 'f' then h := character'pos(c) - character'pos('a') + 10;
          end if;
          exit when h < 0;
          v := shift_left(v, 4) + to_unsigned(h, 32);
          nd := nd + 1;
        end loop;
        if nd > 0 then
          ram(a) := std_logic_vector(v);
          a := a + 1;
        end if;
      end loop;
      file_close(f);
    end if;
    wait;
  end process;

  dumper : process
    file f     : text;
    variable l : line;
    constant HX : string(1 to 16) := "0123456789ABCDEF";
    variable w : std_logic_vector(31 downto 0);
  begin
    wait until sim_dump = '1';
    if DUMP_FILE /= "" then
      file_open(f, DUMP_FILE, write_mode);
      for i in mem_t'range loop
        w := ram(i);
        for k in 7 downto 0 loop
          write(l, HX(to_integer(unsigned(w(4*k+3 downto 4*k))) + 1));
        end loop;
        writeline(f, l);
      end loop;
      file_close(f);
    end if;
    wait;
  end process;
  -- synthesis translate_on

end architecture;
