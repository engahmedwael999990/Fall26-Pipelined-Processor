-- =============================================================================
-- EX2.vhd  --  EX2 stage: branch decision, CCR / shadow CCR, effective address,
--              stack pointer, RAM port-B request, OUT register
-- EA (12 bit):  LDD/STD: Res + offset     PUSH/CALL/INT: SP     POP/RET/RTI: SP+1
-- The RAM samples addr_b / data_b / we_b at the edge that ends EX2.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity EX2 is
  port (
    clk, rst   : in  std_logic;
    -- EX1/EX2 register
    valid      : in  std_logic;
    br         : in  slv3;
    stk, pop   : in  std_logic;
    we         : in  std_logic;
    outp       : in  std_logic;
    int        : in  std_logic;
    res        : in  slv32;
    imm        : in  slv16;
    -- flags written by the instruction in EX1
    e1_we      : in  std_logic;   -- EX1 valid and not flush
    e1_rti     : in  std_logic;
    e1_fzn     : in  std_logic;
    e1_fc      : in  slv2;
    e1_res     : in  slv32;
    alu_c      : in  std_logic;
    sh_c       : in  std_logic;
    sh_cnt_nz  : in  std_logic;
    -- outputs
    taken      : out std_logic;
    addr_b     : out std_logic_vector(11 downto 0);
    we_b       : out std_logic;
    sp         : out slv32;
    ccr        : out std_logic_vector(3 downto 0);
    out_port   : out slv32
  );
end entity;

architecture rtl of EX2 is
  signal z, n, c, tk : std_logic;
  signal sp_r        : slv32;
  signal pop_u       : unsigned(0 downto 0);
  signal out_r       : slv32 := (others => '0');
  signal save, sp_en : std_logic;
begin
  save  <= valid and int;    -- INT / HW interrupt: shadow CCR <- CCR
  sp_en <= valid and stk;

  u_cjd : entity work.conditional_jump_decoder
    port map (valid => valid, br => br, z => z, n => n, c => c, taken => tk);

  u_ccr : entity work.ccr_register
    port map (clk => clk, rst => rst, we => e1_we, rti => e1_rti, fzn => e1_fzn, fc => e1_fc,
              res => e1_res, alu_c => alu_c, sh_c => sh_c, sh_cnt_nz => sh_cnt_nz,
              taken => tk, br => br, save => save,
              z => z, n => n, c => c, ccr => ccr);

  u_sp : entity work.stack_pointer
    port map (clk => clk, rst => rst, en => sp_en, pop => pop, sp => sp_r);

  -- effective address adder (12 bit = 4K address space)
  pop_u(0) <= pop;
  addr_b <= std_logic_vector(unsigned(sp_r(11 downto 0)) + pop_u) when stk = '1'
            else std_logic_vector(unsigned(res(11 downto 0)) + unsigned(imm(11 downto 0)));
  we_b   <= valid and we;

  -- OUT.PORT register
  process (clk, rst)
  begin
    if rst = '1' then
      out_r <= (others => '0');
    elsif rising_edge(clk) then
      if valid = '1' and outp = '1' then out_r <= res; end if;
    end if;
  end process;

  taken    <= tk;
  sp       <= sp_r;
  out_port <= out_r;
end architecture;
