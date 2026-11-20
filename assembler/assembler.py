#!/usr/bin/env python3
"""
assembler.py  --  CMPS301 Fall26 processor assembler

Usage:
    python assembler.py program.asm [-o out_basename]

Produces:
    <out>.mem   4096 lines, one 32-bit hex word per line (ModelSim / testbench)
    <out>.mif   Quartus memory initialization file (RAM init for synthesis)
    <out>.lst   listing: address, word, source line

Input syntax (as in the official test files):
    * all numbers are hexadecimal (no prefix; a leading 0 is allowed: 0DEAD)
    * '#' starts a comment; empty lines are ignored; case-insensitive
    * .ORG <addr>  sets the location counter
    * a line that is only a number is a raw 32-bit data word (vectors, data)
    * optional labels:  name:   (usable wherever an immediate is expected)
    * LDD Rd, off(Rs)   STD Rs1, off(Rs2)
    * INT idx   (idx = 0 or 1)

Encoding (one word per instruction):
    [31:27] opcode  [26:24] D  [23:21] A  [20:18] B  [17:16] 0  [15:0] imm
Fields are duplicated so that register-file read port 1 always uses A and
read port 2 always uses B (see docs/README.md, "Instruction format").
Immediates are 16 bits:
    IADD imm, LDD/STD offset : SIGN-extended by the hardware. A 32-bit value is
                               accepted if it is a sign-extended 16-bit number
                               (e.g. FFFFFFF0 = -10).
    LDM imm                  : ZERO-extended (R[Rdst] <- Imm<15:0>), 0..FFFF.
    SHL/SHR count            : 0..FFFF (counts >= 32 give 0).
    JZ/JN/JC/JMP/CALL target : absolute address 0..FFF.
A value that does not fit is an error, never silently truncated.
INT idx is encoded with imm = idx + 2, i.e. the address of its vector word.
"""
import re
import sys
import argparse

OPC = {
    'NOP': 0x00, 'HLT': 0x01, 'SETC': 0x02, 'NOT': 0x03, 'INC': 0x04, 'OUT': 0x05,
    'IN': 0x06, 'MOV': 0x07, 'SWAP': 0x08, 'ADD': 0x09, 'SUB': 0x0A, 'AND': 0x0B,
    'IADD': 0x0C, 'CMP': 0x0D, 'SHR': 0x0E, 'SHL': 0x0F, 'PUSH': 0x10, 'POP': 0x11,
    'LDM': 0x12, 'LDD': 0x13, 'STD': 0x14, 'JZ': 0x15, 'JN': 0x16, 'JC': 0x17,
    'JMP': 0x18, 'CALL': 0x19, 'RET': 0x1A, 'INT': 0x1B, 'RTI': 0x1C,
}

# operand pattern -> how fields are filled.   r = register, i = immediate, m = off(Rs)
FORMS = {
    'NOP': '', 'HLT': '', 'SETC': '', 'RET': '', 'RTI': '',
    'NOT': 'r', 'INC': 'r', 'OUT': 'r', 'IN': 'r', 'PUSH': 'r', 'POP': 'r',
    'MOV': 'rr', 'SWAP': 'rr', 'CMP': 'rr',
    'ADD': 'rrr', 'SUB': 'rrr', 'AND': 'rrr',
    'IADD': 'rri', 'SHR': 'ri', 'SHL': 'ri', 'LDM': 'ri',
    'LDD': 'rm', 'STD': 'rm',
    'JZ': 'i', 'JN': 'i', 'JC': 'i', 'JMP': 'i', 'CALL': 'i', 'INT': 'i',
}


class AsmError(Exception):
    pass


def parse_num(tok, labels, line_no):
    t = tok.strip()
    if t.upper() in labels:
        return labels[t.upper()]
    if t.lower().startswith('0x'):
        t = t[2:]
    if not re.fullmatch(r'[0-9A-Fa-f]+', t):
        raise AsmError(f'line {line_no}: bad number "{tok}"')
    return int(t, 16)


def parse_reg(tok, line_no):
    m = re.fullmatch(r'[Rr]([0-7])', tok.strip())
    if not m:
        raise AsmError(f'line {line_no}: bad register "{tok}"')
    return int(m.group(1))


def encode(mn, ops, labels, line_no):
    form = FORMS[mn]
    op = OPC[mn]
    D = A = B = 0
    imm = 0

    def imm16(tok):                         # zero-extended / raw 16-bit field
        v = parse_num(tok, labels, line_no)
        if v > 0xFFFF:
            raise AsmError(f'line {line_no}: immediate {tok} does not fit in 16 bits')
        return v

    def simm16(tok):                        # sign-extended immediate / offset
        v = parse_num(tok, labels, line_no)
        if v <= 0xFFFF:
            return v
        if 0xFFFF8000 <= v <= 0xFFFFFFFF:
            return v & 0xFFFF
        raise AsmError(f'line {line_no}: immediate {tok} is not a sign-extended 16-bit value')

    def addr12(tok):
        v = parse_num(tok, labels, line_no)
        if v > 0xFFF:
            raise AsmError(f'line {line_no}: target {tok} is outside the 4K memory')
        return v

    if len(ops) != len(form):
        raise AsmError(f'line {line_no}: {mn} expects {len(form)} operand(s), got {len(ops)}')

    if mn in ('NOT', 'INC'):
        D = A = parse_reg(ops[0], line_no)
    elif mn == 'OUT':
        A = parse_reg(ops[0], line_no)
    elif mn in ('IN', 'POP'):
        D = parse_reg(ops[0], line_no)
    elif mn == 'PUSH':
        B = parse_reg(ops[0], line_no)
    elif mn == 'MOV':                       # MOV Rdst, Rsrc
        D = parse_reg(ops[0], line_no); B = parse_reg(ops[1], line_no)
    elif mn == 'SWAP':                      # SWAP Rdst, Rsrc
        D = A = parse_reg(ops[0], line_no); B = parse_reg(ops[1], line_no)
    elif mn == 'CMP':                       # CMP Rsrc1, Rsrc2  (Rsrc1 - Rsrc2)
        A = parse_reg(ops[0], line_no); B = parse_reg(ops[1], line_no)
    elif mn in ('ADD', 'SUB', 'AND'):
        D = parse_reg(ops[0], line_no); A = parse_reg(ops[1], line_no); B = parse_reg(ops[2], line_no)
    elif mn == 'IADD':
        D = parse_reg(ops[0], line_no); A = parse_reg(ops[1], line_no); imm = simm16(ops[2])
    elif mn in ('SHR', 'SHL'):
        D = A = parse_reg(ops[0], line_no); imm = imm16(ops[1])
    elif mn == 'LDM':
        D = parse_reg(ops[0], line_no); imm = imm16(ops[1])
    elif mn in ('LDD', 'STD'):
        m = re.fullmatch(r'\s*([^()\s]+)\s*\(\s*([Rr][0-7])\s*\)\s*', ops[1])
        if not m:
            raise AsmError(f'line {line_no}: expected offset(Rn), got "{ops[1]}"')
        imm = simm16(m.group(1))
        base = parse_reg(m.group(2), line_no)
        r = parse_reg(ops[0], line_no)
        if mn == 'LDD':                     # LDD Rdst, off(Rsrc)
            D = r; A = base
        else:                               # STD Rsrc1, off(Rsrc2): data=B, base=A
            B = r; A = base
    elif mn in ('JZ', 'JN', 'JC', 'JMP', 'CALL'):
        imm = addr12(ops[0])
    elif mn == 'INT':
        idx = parse_num(ops[0], labels, line_no)
        if idx not in (0, 1):
            raise AsmError(f'line {line_no}: INT index must be 0 or 1')
        imm = idx + 2                       # address of the vector word M[idx+2]
    return (op << 27) | (D << 24) | (A << 21) | (B << 18) | (imm & 0xFFFF)


def split_ops(rest):
    rest = rest.strip()
    if not rest:
        return []
    return [p.strip() for p in rest.split(',')]


def assemble(text):
    """two passes; returns (mem[4096], listing)"""
    lines = text.splitlines()
    # pass 1: labels
    labels, loc = {}, 0
    for n, raw in enumerate(lines, 1):
        s = raw.split('#', 1)[0].strip()
        if not s:
            continue
        while ':' in s.split()[0] if s.split() else False:
            lab, s = s.split(':', 1)
            labels[lab.strip().upper()] = loc
            s = s.strip()
            if not s:
                break
        if not s:
            continue
        if s.upper().startswith('.ORG'):
            loc = int(s.split()[1], 16)
        else:
            loc += 1
    # pass 2
    mem = [0] * 4096
    used = {}
    listing = []
    loc = 0
    for n, raw in enumerate(lines, 1):
        s = raw.split('#', 1)[0].strip()
        if not s:
            continue
        while s.split() and ':' in s.split()[0]:
            _, s = s.split(':', 1)
            s = s.strip()
        if not s:
            continue
        if s.upper().startswith('.ORG'):
            loc = parse_num(s.split()[1], labels, n)
            continue
        parts = s.split(None, 1)
        mn = parts[0].upper()
        if mn in OPC:
            word = encode(mn, split_ops(parts[1] if len(parts) > 1 else ''), labels, n)
        elif re.fullmatch(r'[0-9A-Fa-f]+', parts[0]) and len(parts) == 1:
            word = int(parts[0], 16) & 0xFFFFFFFF      # raw data word
        else:
            raise AsmError(f'line {n}: unknown mnemonic "{parts[0]}"')
        if loc > 0xFFF:
            raise AsmError(f'line {n}: address {loc:X} outside the 4K memory')
        if loc in used:
            raise AsmError(f'line {n}: address {loc:X} already used by line {used[loc]}')
        used[loc] = n
        mem[loc] = word
        listing.append((loc, word, raw.rstrip()))
        loc += 1
    return mem, listing


def write_outputs(mem, listing, base):
    with open(base + '.mem', 'w') as f:
        for w in mem:
            f.write(f'{w:08X}\n')
    with open(base + '.mif', 'w') as f:
        f.write('DEPTH = 4096;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n')
        f.write('  [000..FFF] : 00000000;\n')
        for a, w in sorted((a, w) for a, w, _ in listing):
            f.write(f'  {a:03X} : {w:08X};\n')
        f.write('END;\n')
    with open(base + '.lst', 'w') as f:
        for a, w, src in sorted(listing):
            f.write(f'{a:03X}  {w:08X}  {src.strip()}\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('asm')
    ap.add_argument('-o', '--out')
    a = ap.parse_args()
    base = a.out or re.sub(r'\.[^.]*$', '', a.asm)
    try:
        mem, listing = assemble(open(a.asm).read())
    except AsmError as e:
        print(f'{a.asm}: error: {e}', file=sys.stderr)
        sys.exit(1)
    write_outputs(mem, listing, base)
    print(f'{a.asm}: {len(listing)} words -> {base}.mem / .mif / .lst')


if __name__ == '__main__':
    main()
