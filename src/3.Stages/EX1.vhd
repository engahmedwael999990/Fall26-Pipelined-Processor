-- =============================================================================
-- EX1.vhd  --  EX1 stage: forwarding muxes, operand-B mux, sign extend,
--              ALU, shifter, result mux
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity EX1 is
  generic (SHIFTER_DSP : boolean := false);
  port (
    ctrl      : in  dec_t;
    fsA, fsB  : in  slv2;
    rd1, rd2  : in  slv32;
    imm       : in  slv16;
    e2_res    : in  slv32;       -- forwarding sources
    m_res     : in  slv32;
    w_res     : in  slv32;
    in_port   : in  slv32;
    res       : out slv32;       -- -> EX1/EX2.Res
    data      : out slv32;       -- -> EX1/EX2.Data (store / push data, return address)
    alu_c     : out std_logic;
    sh_c      : out std_logic;
    sh_cnt_nz : out std_logic
  );
end entity;

architecture rtl of EX1 is
  signal fwdA, fwdB, imm32, opB, alu_r, sh_r : slv32;
begin
  with fsA select fwdA <= e2_res when FS_E2, m_res when FS_MEM, w_res when FS_WB, rd1 when others;
  with fsB select fwdB <= e2_res when FS_E2, m_res when FS_MEM, w_res when FS_WB, rd2 when others;

  u_ext : entity work.sign_extend port map (imm => imm, sx => ctrl.sx, imm32 => imm32);

  with ctrl.bsel select opB <= imm32 when BS_IMM, in_port when BS_IN, fwdB when others;

  u_alu : entity work.alu
    port map (a => fwdA, b => opB, xs => ctrl.xs, ys => ctrl.ys, cin => ctrl.cin,
              result => alu_r, cout => alu_c);

  u_shf : entity work.shifter
    generic map (DSP => SHIFTER_DSP)
    port map (a => fwdA, count => imm, shr => ctrl.shr, result => sh_r, cout => sh_c);

  res       <= sh_r when ctrl.shift = '1' else alu_r;
  data      <= fwdB;
  sh_cnt_nz <= '1' when imm /= x"0000" else '0';
end architecture;
