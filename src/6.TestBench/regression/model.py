#!/usr/bin/env python3
"""
model.py  --  instruction-level reference model of the Fall26 ISA.

It executes one instruction at a time (no pipeline), straight from the
specification, and is used as the golden reference for the VHDL simulation.
Hardware interrupts are taken after a given number of retired micro-ops
(the testbench reports where the hardware took them).
"""
M32 = 0xFFFFFFFF


def sext16(v):
    """16-bit immediate, sign-extended to 32 bits"""
    return (v | 0xFFFF0000) if v & 0x8000 else v


class Model:
    def __init__(self, mem, inputs=(), irq_points=()):
        self.mem = list(mem)
        self.r = [0] * 8
        self.z = self.n = self.c = 0
        self.shadow = (0, 0, 0)
        self.sp = 0xFFF
        self.pc = self.mem[0]
        self.inputs = list(inputs)
        self.in_idx = 0
        self.outs = []
        self.irq = sorted(irq_points)
        self.retired = 0          # micro-ops (SWAP = 2), like the hardware's EX2 count
        self.halted = False
        self.hlt_addr = None

    def rd(self, a):
        return self.mem[a & 0xFFF]

    def wr(self, a, v):
        self.mem[a & 0xFFF] = v & M32

    def zn(self, v):
        self.z = 1 if v == 0 else 0
        self.n = (v >> 31) & 1

    def push(self, v):
        self.wr(self.sp, v)
        self.sp = (self.sp - 1) & M32

    def pop(self):
        self.sp = (self.sp + 1) & M32
        return self.rd(self.sp)

    def hw_interrupt(self):
        self.push(self.pc)                     # address of the next instruction
        self.shadow = (self.z, self.n, self.c)
        self.pc = self.rd(1)

    def step(self):
        if self.irq and self.retired == self.irq[0]:
            self.irq.pop(0)
            self.hw_interrupt()
            return
        w = self.rd(self.pc)
        op, D, A, B, imm = w >> 27, (w >> 24) & 7, (w >> 21) & 7, (w >> 18) & 7, w & 0xFFFF
        r = self.r
        npc = (self.pc + 1) & M32
        cnt = 1
        if op == 0x00:                      # NOP
            pass
        elif op == 0x01:                    # HLT
            self.halted = True
            self.hlt_addr = self.pc
            return
        elif op == 0x02:                    # SETC
            self.c = 1
        elif op == 0x03:                    # NOT
            v = (~r[A]) & M32; r[D] = v; self.zn(v)
        elif op == 0x04:                    # INC
            s = r[A] + 1; v = s & M32; r[D] = v; self.zn(v); self.c = s >> 32
        elif op == 0x05:                    # OUT
            self.outs.append(r[A])
        elif op == 0x06:                    # IN
            v = self.inputs[self.in_idx] if self.in_idx < len(self.inputs) else 0
            self.in_idx += 1
            r[D] = v & M32
        elif op == 0x07:                    # MOV
            r[D] = r[B]
        elif op == 0x08:                    # SWAP
            r[D], r[B] = r[B], r[D]; cnt = 2
        elif op in (0x09, 0x0C):            # ADD / IADD (IADD imm sign-extended)
            b = sext16(imm) if op == 0x0C else r[B]
            s = r[A] + b; v = s & M32; r[D] = v; self.zn(v); self.c = s >> 32
        elif op in (0x0A, 0x0D):            # SUB / CMP : carry = NOT borrow
            s = r[A] + ((~r[B]) & M32) + 1; v = s & M32; self.zn(v); self.c = s >> 32
            if op == 0x0A:
                r[D] = v
        elif op == 0x0B:                    # AND
            v = r[A] & r[B]; r[D] = v; self.zn(v)
        elif op in (0x0E, 0x0F):            # SHR / SHL (logical)
            a, n = r[A], imm
            if n == 0:
                v = a
            elif n <= 32:
                if op == 0x0F:
                    v = (a << n) & M32; self.c = (a >> (32 - n)) & 1
                else:
                    v = a >> n; self.c = (a >> (n - 1)) & 1
            else:
                v = 0; self.c = 0
            r[D] = v; self.zn(v)
        elif op == 0x10:                    # PUSH
            self.push(r[B])
        elif op == 0x11:                    # POP
            r[D] = self.pop()
        elif op == 0x12:                    # LDM: R <- Imm<15:0> (zero-extended)
            r[D] = imm
        elif op == 0x13:                    # LDD
            r[D] = self.rd(r[A] + sext16(imm))
        elif op == 0x14:                    # STD
            self.wr(r[A] + sext16(imm), r[B])
        elif op in (0x15, 0x16, 0x17):      # JZ JN JC  (taken -> flag cleared)
            if op == 0x15 and self.z:
                npc = imm; self.z = 0
            elif op == 0x16 and self.n:
                npc = imm; self.n = 0
            elif op == 0x17 and self.c:
                npc = imm; self.c = 0
        elif op == 0x18:                    # JMP
            npc = imm
        elif op == 0x19:                    # CALL
            self.push(npc); npc = imm
        elif op == 0x1A:                    # RET
            npc = self.pop()
        elif op == 0x1B:                    # INT (imm = vector address idx+2)
            self.push(npc); self.shadow = (self.z, self.n, self.c); npc = self.rd(imm)
        elif op == 0x1C:                    # RTI
            npc = self.pop(); self.z, self.n, self.c = self.shadow
        else:
            raise RuntimeError(f'illegal opcode {op:02X} at {self.pc:03X}')
        self.r = r
        self.pc = npc
        self.retired += cnt

    def run(self, max_steps=200000):
        steps = 0
        while not self.halted and steps < max_steps:
            self.step()
            steps += 1
        return self.halted
