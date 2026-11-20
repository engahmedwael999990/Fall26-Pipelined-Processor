-- =============================================================================
-- Control_unit.vhd  --  instruction decoder (ID stage)
-- opcode (+ SWAP micro-op phase) -> control word
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity Control_unit is
  port (
    opcode  : in  slv5;
    swap_ph : in  std_logic;   -- 0 = 1st SWAP micro-op, 1 = 2nd
    ctrl    : out dec_t
  );
end entity;

architecture rtl of Control_unit is
begin
  process (opcode, swap_ph)
    variable d : dec_t;
  begin
    d := DEC_NOP;
    case opcode is
      when OP_HLT  => d.hlt := '1';
      when OP_SETC => d.fc := FC_SET;
      when OP_NOT  => d.usesA := '1'; d.wr := '1'; d.xs := XS_NOTA; d.fzn := '1';
      when OP_INC  => d.usesA := '1'; d.wr := '1'; d.cin := '1'; d.fzn := '1'; d.fc := FC_ADD;
      when OP_OUT  => d.usesA := '1'; d.outp := '1';
      when OP_IN   => d.wr := '1'; d.xs := XS_B; d.bsel := BS_IN;
      when OP_MOV  => d.usesB := '1'; d.wr := '1'; d.xs := XS_B;
      when OP_SWAP =>
        d.swap := '1'; d.wr := '1';
        if swap_ph = '0' then          -- uop1: Rd <- Rs
          d.usesA := '1'; d.usesB := '1'; d.xs := XS_B;
        else                           -- uop2: Rs <- old Rd
          d.usesA := '1'; d.destB := '1'; d.xs := XS_A;
        end if;
      when OP_ADD  => d.usesA := '1'; d.usesB := '1'; d.wr := '1'; d.ys := YS_B;
                      d.fzn := '1'; d.fc := FC_ADD;
      when OP_SUB  => d.usesA := '1'; d.usesB := '1'; d.wr := '1'; d.ys := YS_NOTB; d.cin := '1';
                      d.fzn := '1'; d.fc := FC_ADD;
      when OP_AND  => d.usesA := '1'; d.usesB := '1'; d.wr := '1'; d.xs := XS_AND; d.fzn := '1';
      when OP_IADD => d.usesA := '1'; d.wr := '1'; d.ys := YS_B; d.bsel := BS_IMM; d.sx := '1';
                      d.fzn := '1'; d.fc := FC_ADD;
      when OP_CMP  => d.usesA := '1'; d.usesB := '1'; d.ys := YS_NOTB; d.cin := '1';
                      d.fzn := '1'; d.fc := FC_ADD;
      when OP_SHR  => d.usesA := '1'; d.wr := '1'; d.shift := '1'; d.shr := '1';
                      d.fzn := '1'; d.fc := FC_SHF;
      when OP_SHL  => d.usesA := '1'; d.wr := '1'; d.shift := '1';
                      d.fzn := '1'; d.fc := FC_SHF;
      when OP_PUSH => d.usesB := '1'; d.stk := '1'; d.we := '1';
      when OP_POP  => d.wr := '1'; d.stk := '1'; d.pop := '1'; d.memread := '1';
      when OP_LDM  => d.wr := '1'; d.xs := XS_B; d.bsel := BS_IMM;
      when OP_LDD  => d.usesA := '1'; d.wr := '1'; d.memread := '1';
      when OP_STD  => d.usesA := '1'; d.usesB := '1'; d.we := '1';
      when OP_JZ   => d.br := BR_Z;
      when OP_JN   => d.br := BR_N;
      when OP_JC   => d.br := BR_C;
      when OP_JMP  => d.br := BR_ALW;
      when OP_CALL => d.br := BR_ALW; d.stk := '1'; d.we := '1'; d.pcB := '1';
      when OP_RET  => d.stk := '1'; d.pop := '1'; d.ret := '1';
      when OP_INT  => d.br := BR_ALW; d.stk := '1'; d.we := '1'; d.pcB := '1'; d.int := '1';
      when OP_RTI  => d.stk := '1'; d.pop := '1'; d.ret := '1'; d.rti := '1';
      when others  => null;
    end case;
    ctrl <= d;
  end process;
end architecture;
