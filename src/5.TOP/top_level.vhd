-- =============================================================================
-- top_level.vhd  --  CMPS301 Fall26 6-stage pipelined Von-Neumann processor
--   FETCH -> IF/ID -> DECODE -> ID/EX1 -> EX1 -> EX1/EX2 -> EX2 -> EX2/MEM
--   -> MEMORY -> MEM/WB -> WB        + one shared 4096x32 RAM (memory_file)
-- Generics (static-prediction build is the default):
--   SHIFTER_DSP : false = LUT shifter, true = shifter in a DSP block
--   RF_NEGEDGE  : true  = register file written on the falling edge
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;
-- synthesis translate_off
use work.sim_pkg.all;
-- synthesis translate_on

entity top_level is
  generic (
    INIT_FILE   : string  := "";    -- simulation only: program image (.mem)
    DUMP_FILE   : string  := "";    -- simulation only: RAM dump at the end
    SHIFTER_DSP : boolean := false;
    RF_NEGEDGE  : boolean := true
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;                      -- RESET.IN
    intr_in  : in  std_logic;                      -- INTR.IN
    in_port  : in  std_logic_vector(31 downto 0);  -- IN.PORT
    out_port : out std_logic_vector(31 downto 0)   -- OUT.PORT
  );
end entity;

architecture structural of top_level is
  -- memory
  signal q_a, q_b, pc : slv32;
  signal addr_b       : std_logic_vector(11 downto 0);
  signal we_b         : std_logic;
  -- front-end control
  signal ifv, adv, issue, issue_n, complete, prep, halt_set, ifid_clear : std_logic;
  signal vec1, vec2, irq_pend, inj, in_isr, swap_ph, halted, load_use  : std_logic;
  -- ID
  signal dec          : dec_t;
  signal dstD         : slv3;
  signal fsA, fsB     : slv2;
  signal rd1, rd2     : slv32;
  signal imm_id       : slv16;
  -- ID/EX1
  signal e1_v         : std_logic;
  signal e1           : dec_t;
  signal e1_dest      : slv3;
  signal e1_fsA, e1_fsB : slv2;
  signal e1_rd1, e1_rd2 : slv32;
  signal e1_imm       : slv16;
  -- EX1
  signal res1, data1  : slv32;
  signal alu_c, sh_c, sh_cnt_nz, e1_we : std_logic;
  -- EX1/EX2
  signal e2_v, e2_wr, e2_memread, e2_outp, e2_int, e2_ret, e2_rti : std_logic;
  signal e2_stk, e2_pop, e2_we : std_logic;
  signal e2_br        : slv3;
  signal e2_dest      : slv3;
  signal e2_res, e2_data : slv32;
  signal e2_imm       : slv16;
  -- EX2
  signal flush, e2_int_v : std_logic;
  signal sp           : slv32;
  signal ccr          : std_logic_vector(3 downto 0);
  signal m_wr_i, m_memread_i, m_ret_i, m_rti_i : std_logic;
  -- EX2/MEM
  signal m_wr, m_memread, m_ret, m_rti : std_logic;
  signal m_dest       : slv3;
  signal m_res, mem_res : slv32;
  -- MEM/WB
  signal w_wr         : std_logic;
  signal w_dest       : slv3;
  signal w_res        : slv32;
  -- WB
  signal rf_we        : std_logic;
  signal rf_wa        : slv3;
  signal rf_wd        : slv32;
begin

  -- ======================================================== shared memory
  u_mem : entity work.memory_file
    generic map (INIT_FILE => INIT_FILE, DUMP_FILE => DUMP_FILE)
    port map (clk => clk,
              en_a => adv, addr_a => pc(11 downto 0), q_a => q_a,
              we_b => we_b, addr_b => addr_b, data_b => e2_data, q_b => q_b);

  -- ======================================================== IF
  u_fetch : entity work.FETCH
    port map (clk => clk, rst => rst, adv => adv, flush => flush, target => e2_imm,
              m_ret => m_ret, q_b => q_b, vec2 => vec2, q_a => q_a, pc => pc);

  ifid_clear <= flush or m_ret or vec1 or vec2 or prep;
  u_ifid : entity work.IF_ID
    port map (clk => clk, rst => rst, clear => ifid_clear, load => adv, valid => ifv);

  -- ======================================================== ID
  u_decode : entity work.DECODE
    generic map (RF_NEGEDGE => RF_NEGEDGE)
    port map (clk => clk, rst => rst, q_a => q_a, inj => inj, swap_ph => swap_ph, pc => pc,
              wb_we => rf_we, wb_wa => rf_wa, wb_wd => rf_wd,
              e1_v => e1_v, e1_wr => e1.wr, e1_memread => e1.memread, e1_dest => e1_dest,
              e2_v => e2_v, e2_wr => e2_wr, e2_memread => e2_memread, e2_dest => e2_dest,
              m_wr => m_wr, m_dest => m_dest,
              ctrl => dec, dest => dstD, fsA => fsA, fsB => fsB, rd1 => rd1, rd2 => rd2,
              imm => imm_id, load_use => load_use);

  u_hazard : entity work.hazard_unit
    port map (ifv => ifv, load_use => load_use, ctrl => dec, swap_ph => swap_ph, inj => inj,
              halted => halted, flush => flush, irq_pend => irq_pend, in_isr => in_isr,
              vec1 => vec1, vec2 => vec2,
              e1_v => e1_v, e1_ret => e1.ret, e1_br => e1.br,
              e2_v => e2_v, e2_ret => e2_ret, e2_br => e2_br, m_ret => m_ret,
              issue => issue, issue_n => issue_n, complete => complete, adv => adv,
              prep => prep, halt_set => halt_set);

  u_int : entity work.interrupt_unit
    port map (clk => clk, rst => rst, intr_in => intr_in, prep => prep, flush => flush,
              issue_n => issue_n, id_swap => dec.swap, e2_int => e2_int_v, m_rti => m_rti,
              halt_set => halt_set, vec1 => vec1, vec2 => vec2, irq_pend => irq_pend,
              inj => inj, in_isr => in_isr, swap_ph => swap_ph, halted => halted);

  u_idex1 : entity work.ID_EX1
    port map (clk => clk, rst => rst, valid_in => issue, ctrl_in => dec, dest_in => dstD,
              fsA_in => fsA, fsB_in => fsB, rd1_in => rd1, rd2_in => rd2, imm_in => imm_id,
              valid_out => e1_v, ctrl_out => e1, dest_out => e1_dest, fsA_out => e1_fsA,
              fsB_out => e1_fsB, rd1_out => e1_rd1, rd2_out => e1_rd2, imm_out => e1_imm);

  -- ======================================================== EX1
  u_ex1 : entity work.EX1
    generic map (SHIFTER_DSP => SHIFTER_DSP)
    port map (ctrl => e1, fsA => e1_fsA, fsB => e1_fsB, rd1 => e1_rd1, rd2 => e1_rd2,
              imm => e1_imm, e2_res => e2_res, m_res => m_res, w_res => w_res,
              in_port => in_port, res => res1, data => data1,
              alu_c => alu_c, sh_c => sh_c, sh_cnt_nz => sh_cnt_nz);

  e1_we <= e1_v and not flush;   -- a taken jump in EX2 kills the EX1 instruction

  u_ex1ex2 : entity work.EX1_EX2
    port map (clk => clk, rst => rst, valid_in => e1_we,
              wr_in => e1.wr, memread_in => e1.memread, outp_in => e1.outp, int_in => e1.int,
              ret_in => e1.ret, rti_in => e1.rti, stk_in => e1.stk, pop_in => e1.pop,
              we_in => e1.we, br_in => e1.br, dest_in => e1_dest, res_in => res1,
              data_in => data1, imm_in => e1_imm,
              valid_out => e2_v, wr_out => e2_wr, memread_out => e2_memread, outp_out => e2_outp,
              int_out => e2_int, ret_out => e2_ret, rti_out => e2_rti, stk_out => e2_stk,
              pop_out => e2_pop, we_out => e2_we, br_out => e2_br, dest_out => e2_dest,
              res_out => e2_res, data_out => e2_data, imm_out => e2_imm);

  -- ======================================================== EX2
  u_ex2 : entity work.EX2
    port map (clk => clk, rst => rst, valid => e2_v, br => e2_br, stk => e2_stk, pop => e2_pop,
              we => e2_we, outp => e2_outp, int => e2_int, res => e2_res, imm => e2_imm,
              e1_we => e1_we, e1_rti => e1.rti, e1_fzn => e1.fzn, e1_fc => e1.fc,
              e1_res => res1, alu_c => alu_c, sh_c => sh_c, sh_cnt_nz => sh_cnt_nz,
              taken => flush, addr_b => addr_b, we_b => we_b, sp => sp, ccr => ccr,
              out_port => out_port);

  e2_int_v    <= e2_v and e2_int;
  m_wr_i      <= e2_v and e2_wr;
  m_memread_i <= e2_v and e2_memread;
  m_ret_i     <= e2_v and e2_ret;
  m_rti_i     <= e2_v and e2_rti;

  u_ex2mem : entity work.EX2_MEM
    port map (clk => clk, rst => rst, wr_in => m_wr_i, memread_in => m_memread_i,
              ret_in => m_ret_i, rti_in => m_rti_i, dest_in => e2_dest, res_in => e2_res,
              wr_out => m_wr, memread_out => m_memread, ret_out => m_ret, rti_out => m_rti,
              dest_out => m_dest, res_out => m_res);

  -- ======================================================== MEM
  u_memory : entity work.MEMORY
    port map (memread => m_memread, q_b => q_b, res => m_res, result => mem_res);

  u_memwb : entity work.MEM_WB
    port map (clk => clk, rst => rst, wr_in => m_wr, dest_in => m_dest, result_in => mem_res,
              wr_out => w_wr, dest_out => w_dest, result_out => w_res);

  -- ======================================================== WB
  u_wb : entity work.WB
    port map (wr => w_wr, dest => w_dest, result => w_res,
              rf_we => rf_we, rf_wa => rf_wa, rf_wd => rf_wd);

  -- ======================================================== simulation only
  -- synthesis translate_off
  sim_retire    <= e2_v;
  sim_hwint     <= e2_v and e2_int when e2_imm = x"0001" else '0';
  sim_in_sample <= e1_v and not flush when e1.bsel = BS_IN else '0';
  sim_out_we    <= e2_v and e2_outp;
  sim_halted    <= halted;
  sim_quiet     <= not (e1_v or e2_v or m_wr or m_memread or m_ret or w_wr);
  sim_fetch_pc  <= pc;
  sim_ifv       <= ifv;
  sim_pc        <= pc;
  sim_sp        <= sp;
  sim_ccr       <= ccr;
  trace : process (clk)
  begin
    if rising_edge(clk) then
      sim_pc_wb <= sim_pc_mem;
      if e2_v = '1' then sim_pc_mem <= sim_pc_ex2; else sim_pc_mem <= (others => '1'); end if;
      if e1_v = '1' and flush = '0' then sim_pc_ex2 <= sim_pc_ex1; else sim_pc_ex2 <= (others => '1'); end if;
      if issue = '1' then
        if inj = '1' then sim_pc_ex1 <= x"FFFFFFFE";
        else sim_pc_ex1 <= sim_pc_id; end if;
      else
        sim_pc_ex1 <= (others => '1');
      end if;
      if adv = '1' then sim_pc_id <= pc; end if;
    end if;
  end process;
  -- synthesis translate_on

end architecture;
