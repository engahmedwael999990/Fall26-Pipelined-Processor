-- =============================================================================
-- top_level_tb.vhd  --  self-checking regression testbench (simulation only)
--  * loads the program image (generic PROG_FILE) into the RAM
--  * drives IN.PORT from IN_FILE: the k-th executed IN instruction gets line k
--  * pulses INTR.IN at the cycles listed in IRQ_FILE (cycle 0 = first edge
--    after reset is released)
--  * stops when the CPU is halted and drained, then writes RES_FILE
--    (registers, flags, SP, PC, OUT history, interrupt points) and the RAM dump
--  * TRACE_FILE gets one line per cycle: addresses in every stage + state
-- The Python runner (src/6.TestBench/regression/run_tests.py) compares RES_FILE + dump against the
-- independent instruction-level model (regression/model.py).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.cpu_pkg.all;
use work.sim_pkg.all;

entity top_level_tb is
  generic (
    PROG_FILE   : string  := "program.mem";
    IN_FILE     : string  := "";
    IRQ_FILE    : string  := "";
    RES_FILE    : string  := "result.txt";
    DUMP_FILE   : string  := "ramdump.mem";
    TRACE_FILE  : string  := "";
    MAX_CYCLES  : integer := 20000;
    SHIFTER_DSP : boolean := false;
    RF_NEGEDGE  : boolean := true
  );
end entity;

architecture sim of top_level_tb is
  constant TCLK : time := 10 ns;
  signal clk, rst, intr : std_logic := '0';
  signal in_port, out_port : std_logic_vector(31 downto 0) := (others => '0');
  signal done : boolean := false;

  type int_arr is array (0 to 255) of integer;
  type slv_arr is array (0 to 255) of std_logic_vector(31 downto 0);

  function hex(v : std_logic_vector(31 downto 0)) return string is
    constant HX : string(1 to 16) := "0123456789ABCDEF";
    variable s : string(1 to 8);
  begin
    for k in 0 to 7 loop
      s(8 - k) := HX(to_integer(unsigned(v(4*k+3 downto 4*k))) + 1);
    end loop;
    return s;
  end function;

  -- reads hex words (one per line, '#' comments allowed) into an array
  procedure read_hex_list(fname : string; arr : out slv_arr; n : out integer) is
    file f : text;
    variable l : line;
    variable c : character;
    variable ok : boolean;
    variable v : unsigned(31 downto 0);
    variable nd, h, cnt : integer;
    variable st : file_open_status;
  begin
    cnt := 0;
    arr := (others => (others => '0'));
    if fname /= "" then
      file_open(st, f, fname, read_mode);
      if st = open_ok then
        while not endfile(f) loop
          readline(f, l);
          v := (others => '0'); nd := 0;
          loop
            read(l, c, ok);
            exit when not ok;
            h := -1;
            if    c >= '0' and c <= '9' then h := character'pos(c) - 48;
            elsif c >= 'A' and c <= 'F' then h := character'pos(c) - 55;
            elsif c >= 'a' and c <= 'f' then h := character'pos(c) - 87;
            end if;
            exit when h < 0;
            v := shift_left(v, 4) + to_unsigned(h, 32);
            nd := nd + 1;
          end loop;
          if nd > 0 and cnt < 256 then
            arr(cnt) := std_logic_vector(v);
            cnt := cnt + 1;
          end if;
        end loop;
        file_close(f);
      end if;
    end if;
    n := cnt;
  end procedure;

begin

  dut : entity work.top_level
    generic map (INIT_FILE => PROG_FILE, DUMP_FILE => DUMP_FILE,
                 SHIFTER_DSP => SHIFTER_DSP, RF_NEGEDGE => RF_NEGEDGE)
    port map (clk => clk, rst => rst, intr_in => intr, in_port => in_port, out_port => out_port);

  clk <= not clk after TCLK / 2 when not done else '0';

  stim : process
    variable inv, irqv : slv_arr;
    variable nin, nirq, k, cyc, ret_cnt, quiet_cnt : integer;
    file fr, ft : text;
    variable l, lt : line;
    variable outs : slv_arr;
    variable nout : integer := 0;
    variable irq_at : int_arr;
    variable nirq_taken : integer := 0;
    variable timeout : boolean := false;
  begin
    read_hex_list(IN_FILE, inv, nin);
    read_hex_list(IRQ_FILE, irqv, nirq);
    if TRACE_FILE /= "" then file_open(ft, TRACE_FILE, write_mode); end if;
    k := 0;
    if nin > 0 then in_port <= inv(0); end if;
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 1 ns;
    rst <= '0';
    cyc := 0; ret_cnt := 0; quiet_cnt := 0;
    loop
      -- ---- interrupt pulse for this cycle (driven just after the edge)
      intr <= '0';
      for i in 0 to nirq - 1 loop
        if to_integer(unsigned(irqv(i))) = cyc then intr <= '1'; end if;
      end loop;
      wait until rising_edge(clk);
      -- ---- events of the edge that just happened (sampled pre-edge values)
      if sim_hwint = '1' then
        irq_at(nirq_taken) := ret_cnt; nirq_taken := nirq_taken + 1;
      elsif sim_retire = '1' then
        ret_cnt := ret_cnt + 1;
      end if;
      if sim_in_sample = '1' then
        k := k + 1;
      end if;
      wait for 1 ns;
      if k < nin then in_port <= inv(k); else in_port <= (others => '0'); end if;
      cyc := cyc + 1;
      -- ---- trace line (state after the edge)
      if TRACE_FILE /= "" then
        write(lt, cyc); write(lt, string'(" "));
        write(lt, hex(sim_fetch_pc)); write(lt, string'(" "));
        if sim_ifv = '1' then write(lt, hex(sim_pc_id)); else write(lt, string'("FFFFFFFF")); end if;
        write(lt, string'(" "));
        write(lt, hex(sim_pc_ex1)); write(lt, string'(" "));
        write(lt, hex(sim_pc_ex2)); write(lt, string'(" "));
        write(lt, hex(sim_pc_mem)); write(lt, string'(" "));
        write(lt, hex(sim_pc_wb));
        for r in 0 to 7 loop write(lt, string'(" ")); write(lt, hex(sim_regs(r))); end loop;
        write(lt, string'(" ")); write(lt, hex(x"0000000" & sim_ccr));
        write(lt, string'(" ")); write(lt, hex(sim_sp));
        write(lt, string'(" ")); write(lt, hex(out_port));
        write(lt, string'(" ")); write(lt, hex(in_port));
        write(lt, string'(" ")); write(lt, intr);
        writeline(ft, lt);
      end if;
      -- ---- termination
      if sim_halted = '1' and sim_quiet = '1' then
        quiet_cnt := quiet_cnt + 1;
      else
        quiet_cnt := 0;
      end if;
      exit when quiet_cnt >= 4;
      if cyc >= MAX_CYCLES then timeout := true; exit; end if;
    end loop;

    -- ---- result file
    file_open(fr, RES_FILE, write_mode);
    if timeout then write(l, string'("TIMEOUT")); writeline(fr, l); end if;
    write(l, string'("REGS"));
    for r in 0 to 7 loop write(l, string'(" ")); write(l, hex(sim_regs(r))); end loop;
    writeline(fr, l);
    write(l, string'("CCR ")); write(l, hex(x"0000000" & sim_ccr)); writeline(fr, l);
    write(l, string'("SP ")); write(l, hex(sim_sp)); writeline(fr, l);
    write(l, string'("PC ")); write(l, hex(sim_pc)); writeline(fr, l);
    write(l, string'("OUT ")); write(l, hex(out_port)); writeline(fr, l);
    write(l, string'("RETIRED ")); write(l, ret_cnt); writeline(fr, l);
    write(l, string'("CYCLES ")); write(l, cyc); writeline(fr, l);
    write(l, string'("INS_USED ")); write(l, k); writeline(fr, l);
    for i in 0 to nirq_taken - 1 loop
      write(l, string'("IRQ ")); write(l, irq_at(i)); writeline(fr, l);
    end loop;
    file_close(fr);
    if TRACE_FILE /= "" then file_close(ft); end if;
    sim_dump <= '1';
    wait for 1 ns;
    done <= true;
    wait;
  end process;

  -- OUT history (every OUT write, even if the value does not change)
  outmon : process
    file fo : text;
    variable l : line;
  begin
    file_open(fo, RES_FILE & ".out", write_mode);
    loop
      wait until rising_edge(clk) or done;
      exit when done;
      if sim_out_we = '1' then
        wait for 1 ns;
        write(l, hex(out_port)); writeline(fo, l);
      end if;
    end loop;
    file_close(fo);
    wait;
  end process;

end architecture;
