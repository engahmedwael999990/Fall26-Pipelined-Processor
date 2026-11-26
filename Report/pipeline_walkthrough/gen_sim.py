"""Build data.json for the pipeline-simulation page.
- wires of the draw.io schematic (from g5.py) in schematic coordinates
- per-instruction stage highlights + explanations
- program replays from the VHDL simulation traces
"""
import json, sys, os, re, collections
SCR = '/tmp/claude-0/-home-claude/dac3a18a-7f00-5d16-b2ea-cf43e580be52/scratchpad'
F26 = '/home/claude/F26'
sys.path.insert(0, SCR)
sys.path.insert(0, F26 + '/assembler')
from assembler import assemble  # noqa

g = {}
exec(open(SCR + '/g5.py').read(), g)
S = g['S']
CTRL = json.load(open(SCR + '/doc/ctrl.json'))

# ------------------------------------------------------------------ wires
W = []
for w in S.wires:
    W.append(dict(net=w['net'], pts=[[round(x, 1), round(y, 1)] for x, y in w['pts']],
                  src=w['src'].shape if w['src'] else None, dst=w['dst'].shape if w['dst'] else None,
                  tap=list(w['tap_src']) if w['tap_src'] else None))


def on(p, a, b):
    return (a[0] == b[0] == p[0] and min(a[1], b[1]) - .5 <= p[1] <= max(a[1], b[1]) + .5) or \
           (a[1] == b[1] == p[1] and min(a[0], b[0]) - .5 <= p[0] <= max(a[0], b[0]) + .5)


def upstream(i, acc):
    w = W[i]
    if w['tap'] is None:
        return
    for j, v in enumerate(W):
        if j != i and v['net'] == w['net'] and j not in acc:
            if any(on(w['tap'], a, b) for a, b in zip(v['pts'], v['pts'][1:])):
                acc.add(j)
                upstream(j, acc)


def sel(specs):
    out = set()
    for s in specs:
        net, _, dst = s.partition('@')
        for i, w in enumerate(W):
            if w['net'] == net and (not dst or w['dst'] == dst):
                out.add(i)
                upstream(i, out)
    return sorted(out)


SHAPES = {k: [v['x'], v['y'], v['w'], v['h']] for k, v in S.shapes.items()}

# ------------------------------------------------------------------ instruction knowledge
OPS = ['NOP', 'HLT', 'SETC', 'NOT', 'INC', 'OUT', 'IN', 'MOV', 'SWAP', 'ADD', 'SUB', 'AND', 'IADD', 'CMP', 'SHR', 'SHL',
       'PUSH', 'POP', 'LDM', 'LDD', 'STD', 'JZ', 'JN', 'JC', 'JMP', 'CALL', 'RET', 'INT', 'RTI']


def ctrl(op, uop=1):
    key = op if op != 'SWAP' else f'SWAP (uop{uop})'
    d = {k: v.strip("'") for k, v in CTRL[key].items()}
    return d


EX1TXT = {
    'NOP': 'Nothing to compute; all control bits are 0, so the bubble-like NOP just moves on.',
    'HLT': '-',
    'SETC': 'fc = set: the CCR sets C = 1 at the end of EX1.',
    'NOT': 'Fwd A gives the newest R[Rdst]. ALU: X = ~A, Y = 0. CCR updates Z and N (C unchanged).',
    'INC': 'Fwd A gives R[Rdst]. ALU: A + 0 + cin(1). CCR updates Z, N and C (carry out).',
    'OUT': 'Fwd A gives R[Rsrc]. ALU passes A (A + 0) to Res.',
    'IN': 'B Sel takes IN.PORT. ALU passes B (X = B, Y = 0). No flags.',
    'MOV': 'Fwd B gives the newest R[Rsrc]. ALU passes B. No flags.',
    'SWAP': 'uop1: ALU passes B (old Rsrc) &rarr; Rdst. uop2: ALU passes A (old Rdst, not forwarded from uop1) &rarr; Rsrc.',
    'ADD': 'Fwd A/B give the newest R[Rsrc1], R[Rsrc2]. ALU: A + B. CCR updates Z, N, C.',
    'SUB': 'ALU: A + ~B + 1 (= A &minus; B). CCR updates Z, N, and C = borrow (Rsrc1 &lt; Rsrc2 unsigned).',
    'AND': 'ALU: X = A AND B, Y = 0. CCR updates Z and N (C unchanged).',
    'IADD': 'Sign Extend makes imm32 (sx = 1); B Sel takes imm32. ALU: A + imm. CCR updates Z, N, C.',
    'CMP': 'ALU: A + ~B + 1 like SUB, but wr = 0: only the CCR changes (Z, N, C).',
    'SHR': 'Shifter shifts fwdA right by imm (zeros in). Res mux takes the shifter. Z, N updated; C = last bit out if the count is not 0.',
    'SHL': 'Shifter shifts fwdA left by imm. Res mux takes the shifter. Z, N updated; C = last bit out if the count is not 0.',
    'PUSH': 'Fwd B gives R[Rsrc] &rarr; Data (the value to push).',
    'POP': 'Nothing to compute; control bits move on to EX2.',
    'LDM': 'Sign Extend with sx = 0 (zero-extend) &rarr; imm32; B Sel takes it; ALU passes B. No flags.',
    'LDD': 'Fwd A gives the base register; ALU passes it to Res. imm (offset) moves on to EX2.',
    'STD': 'Fwd A gives the base &rarr; Res; Fwd B gives the value to store &rarr; Data.',
    'JZ': 'Nothing to compute; the target (imm) and br move on to EX2.',
    'JN': 'Nothing to compute; the target (imm) and br move on to EX2.',
    'JC': 'Nothing to compute; the target (imm) and br move on to EX2.',
    'JMP': 'Nothing to compute; the target (imm) moves on to EX2.',
    'CALL': 'Data = RD2 = the return address (PC + 1 of the CALL).',
    'RET': 'Nothing to compute; stk/pop/ret move on to EX2.',
    'INT': 'Data = RD2 = the return address. imm = vector address (index + 2, or 1 for the hardware interrupt).',
    'RTI': 'The CCR is loaded from the shadow CCR at the end of EX1 (flags restored).',
}


def stage_info(op, st, uop=1, taken=True, hw=False):
    c = ctrl(op, uop)
    b = lambda k: c.get(k, '0') == '1'
    br = c.get('br', 'BR_NONE')
    nets, txt = [], ''
    if st == 'F':
        nets = ['pc', 'pc_inc', 'pc_next', 'q_a@IFID', 'adv@PC']
        txt = (f'PC holds the address of {op}. pc[11:0] goes to RAM port A; at the end of the cycle the RAM latches it and '
               f'PC &larr; PC + 1 (adv = 1).')
        if hw:
            txt = 'The hardware interrupt has no fetch: the hazard unit accepted it (prep), froze the PC and cleared IF/ID.'
            nets = ['prep', 'ifid_clear']
    elif st == 'D':
        nets = ['q_a@IRM', 'ir', 'dec@IDEX', 'issue', 'ifv']
        parts = [f'IR = the word of {op}; the control unit decodes opcode {OPS.index(op):05b}.']
        if hw:
            nets = ['HWINT_WORD', 'inj', 'ir', 'dec@IDEX', 'issue', 'pc@RD2M', 'rd2']
            parts = ['inj = 1: the IR mux passes the constant "INT 1" word, so the interrupt enters as an INT micro-op.',
                     'RD2 mux passes the PC = the resume address.']
        if b('usesA'):
            nets += ['rd1', 'fsA']
            parts.append('Read port 1 gives R[A].')
        if b('usesB'):
            nets += ['rf2', 'rd2', 'fsB']
            parts.append('Read port 2 gives R[B].')
        if b('pcB') and not hw:
            nets += ['pc@RD2M', 'rd2']
            parts.append('pcB = 1: the RD2 mux passes the PC, which already points to the next word (= return address).')
        if b('usesA') or b('usesB'):
            nets += ['ir@FWD']
            parts.append('The forwarding unit compares A/B with the destinations in EX1, EX2 and MEM and sets fsA/fsB.')
        if b('wr'):
            nets += ['dstD']
            parts.append('dest = ' + ('B (destB, 2nd SWAP micro-op).' if b('destB') else 'D.'))
        if op == 'SWAP':
            nets += ['swap_ph']
            parts.append(f'swap_ph = {uop - 1}: micro-op {uop} of 2.')
        if op == 'HLT':
            parts = ['HLT stops in ID: halt_set = 1, the CPU enters halted. Nothing after it is issued and the PC freezes.']
            nets = ['q_a@IRM', 'ir', 'dec@HZ']
        else:
            parts.append('Hazard unit: issue = 1 &rarr; ID/EX1.valid.')
        txt = ' '.join(parts)
    elif st == 'E1':
        nets = ['e1_v', 'e1_we']
        if b('usesA'):
            nets += ['e1_rd1', 'e1_fsA', 'fwdA']
        if b('usesB') or b('pcB'):
            nets += ['e1_rd2', 'e1_fsB', 'fwdB']
        if c.get('bsel') == 'BS_IMM':
            nets += ['e1_imm@SEXT', 'imm32', 'opB', 'e1.sx', 'e1.bsel']
        elif c.get('bsel') == 'BS_IN':
            nets += ['in_port', 'opB', 'e1.bsel']
        elif b('usesB') and op not in ('STD', 'PUSH'):
            nets += ['opB']
        alu_used = op in ('NOT', 'INC', 'OUT', 'IN', 'MOV', 'SWAP', 'ADD', 'SUB', 'AND', 'IADD', 'CMP', 'LDM', 'LDD', 'STD')
        if alu_used:
            nets += ['alu_r', 'e1.xs']
        if b('shift'):
            nets += ['e1_imm@SHF', 'sh_r', 'e1.shift', 'sh_c', 'e1_imm@NZ', 'sh_cnt_nz']
        if alu_used or b('shift'):
            nets += ['res1@EX12']
        if b('fzn') or c.get('fc', 'FC_KEEP') != 'FC_KEEP':
            nets += ['e1.fzn', 'res1@CCR']
            if c.get('fc') == 'FC_ADD':
                nets += ['alu_c']
        if b('rti'):
            nets += ['e1.rti@CCR']
        if op in ('STD', 'PUSH', 'CALL', 'INT'):
            nets += ['fwdB@EX12']
        if op in ('LDD', 'STD', 'JZ', 'JN', 'JC', 'JMP', 'CALL', 'INT'):
            nets += ['e1_imm@EX12']
        if b('wr'):
            nets += ['e1_dest']
        for k in ('wr', 'memread', 'ret', 'rti', 'outp', 'int', 'stk', 'we', 'pop'):
            if b(k):
                nets.append('e1.' + k + '@EX12')
        if br != 'BR_NONE':
            nets.append('e1.br')
        txt = EX1TXT[op] if not hw else 'Data = the resume address; imm = 1 (vector address of the hardware interrupt).'
    elif st == 'E2':
        nets = ['e2_v']
        parts = []
        if b('wr'):
            nets += ['e2_wr', 'm_wr_i', 'e2_res@EXM', 'e2_dest']
        if b('memread'):
            nets += ['e2_memread', 'm_memread_i']
        if op in ('LDD', 'STD'):
            nets += ['e2_res@EAA', 'e2_imm@EAA', 'ea', 'addr_b']
            parts.append('EA adder: addr_b = Res (base) + offset.')
        if b('stk'):
            nets += ['e2_stk', 'sp_en', 'sp', 'sp_pop', 'e2_pop@SPA', 'e2_pop@SP', 'addr_b']
            parts.append('Stack: addr_b = ' + ('SP + 1, SP &larr; SP + 1.' if b('pop') else 'SP, SP &larr; SP &minus; 1.'))
        if b('we'):
            nets += ['e2_we', 'we_b', 'e2_data']
            parts.append('we_b = 1: the RAM writes data_b at the end of EX2.')
        if b('memread') or b('ret'):
            parts.append('The RAM samples addr_b at the end of EX2; the word comes out on q_b in MEM.')
        if br != 'BR_NONE':
            nets += ['e2_br@CJD']
            if br in ('BR_Z', 'BR_N', 'BR_C'):
                f = br[-1]
                nets += [f.lower()]
                parts.append(f'The conditional jump decoder tests {f}.')
                if taken:
                    nets += ['e2_br@CCR']
                    parts.append(f'{f} = 1 &rarr; taken: flush = 1, PC &larr; target, the 3 younger instructions are flushed and {f} is cleared.')
                else:
                    parts.append(f'{f} = 0 &rarr; not taken: prediction was right, nothing is flushed.')
            else:
                parts.append('Always taken: flush = 1, PC &larr; target (imm), the 3 younger instructions are flushed.')
            if taken or br == 'BR_ALW':
                nets += ['flush', 'e2_imm@MUXPC']
        if b('outp'):
            nets += ['e2_outp', 'outp_v', 'e2_res@OUTR', 'out_port']
            parts.append('The OUT register loads Res: OUT.PORT changes after this edge.')
        if b('int'):
            nets += ['e2_int', 'e2_int_v', 'ccr']
            parts.append('Shadow CCR &larr; flags (save); the vector fetch follows (vec1, vec2).')
        if b('ret'):
            nets += ['e2_ret', 'm_ret_i']
        if b('rti'):
            nets += ['e2_rti', 'm_rti_i']
        if b('wr') and not parts:
            parts.append('Res moves on to EX2/MEM (it can already be forwarded from EX1/EX2).')
        txt = ' '.join(parts) or 'Nothing to do in EX2.'
    elif st == 'M':
        nets, parts = [], []
        if b('wr'):
            nets += ['m_wr', 'm_dest', 'mem_res']
            if b('memread'):
                nets += ['q_b@WBM', 'm_memread']
                parts.append('q_b = the loaded word; WB Sel picks q_b (memread) &rarr; MEM/WB.Result.')
            else:
                nets += ['m_res@WBM']
                parts.append('WB Sel picks Res &rarr; MEM/WB.Result.')
        if b('ret'):
            nets += ['q_b@MUXPC', 'm_ret@MUXPC', 'm_ret@ORC']
            parts.append('q_b = the return address: m_ret = 1, PC &larr; q_b, IF/ID cleared.')
        if b('rti'):
            nets += ['m_rti']
            parts.append('m_rti clears in_isr: interrupts are allowed again.')
        txt = ' '.join(parts) or 'Nothing to do in MEM.'
    elif st == 'W':
        if b('wr'):
            nets = ['w_wr', 'w_dest', 'w_res@RF']
            txt = 'R[dest] &larr; Result on the falling edge of this cycle (so an instruction in ID reads it in the same cycle).'
        else:
            nets = []
            txt = 'No register write.'
    return sel(nets), txt


SEQ = ['F', 'D', 'E1', 'E2', 'M', 'W']
NAMES = {'F': 'IF', 'D': 'ID', 'E1': 'EX1', 'E2': 'EX2', 'M': 'MEM', 'W': 'WB'}
EXAMPLE = {'NOP': 'NOP', 'HLT': 'HLT', 'SETC': 'SETC', 'NOT': 'NOT R1', 'INC': 'INC R0', 'OUT': 'OUT R2', 'IN': 'IN R2',
           'MOV': 'MOV R4, R1', 'SWAP': 'SWAP R1, R2', 'ADD': 'ADD R2, R0, R1', 'SUB': 'SUB R3, R0, R1', 'AND': 'AND R6, R0, R1',
           'IADD': 'IADD R7, R0, 0010', 'CMP': 'CMP R0, R1', 'SHR': 'SHR R2, 0001', 'SHL': 'SHL R3, 0004', 'PUSH': 'PUSH R3',
           'POP': 'POP R1', 'LDM': 'LDM R0, FFFF', 'LDD': 'LDD R3, 5(R4)', 'STD': 'STD R2, 5(R1)', 'JZ': 'JZ 30', 'JN': 'JN 30',
           'JC': 'JC 30', 'JMP': 'JMP 30', 'CALL': 'CALL 300', 'RET': 'RET', 'INT': 'INT 0', 'RTI': 'RTI'}
SUMMARY = {
    'NOP': 'Does nothing; PC + 1.', 'HLT': 'Freezes the CPU until RESET.', 'SETC': 'C &larr; 1.',
    'NOT': 'R[Rdst] &larr; ~R[Rdst]; Z, N.', 'INC': 'R[Rdst] &larr; R[Rdst] + 1; Z, N, C.', 'OUT': 'OUT.PORT &larr; R[Rsrc].',
    'IN': 'R[Rdst] &larr; IN.PORT.', 'MOV': 'R[Rdst] &larr; R[Rsrc].', 'SWAP': 'Exchange two registers (two micro-ops).',
    'ADD': 'Rdst &larr; Rsrc1 + Rsrc2; Z, N, C.', 'SUB': 'Rdst &larr; Rsrc1 &minus; Rsrc2; Z, N, C (C = borrow).',
    'AND': 'Rdst &larr; Rsrc1 AND Rsrc2; Z, N.', 'IADD': 'Rdst &larr; Rsrc + sext(Imm); Z, N, C.',
    'CMP': 'Flags of Rsrc1 &minus; Rsrc2, no register write.', 'SHR': 'Logical shift right by Imm; Z, N, C.',
    'SHL': 'Shift left by Imm; Z, N, C.', 'PUSH': 'M[SP] &larr; R[Rsrc]; SP &minus; 1.', 'POP': 'SP + 1; R[Rdst] &larr; M[SP].',
    'LDM': 'R[Rdst] &larr; 0000 &amp; Imm.', 'LDD': 'R[Rdst] &larr; M[R[Rsrc] + offset].', 'STD': 'M[R[Rsrc2] + offset] &larr; R[Rsrc1].',
    'JZ': 'If Z: PC &larr; Imm, Z &larr; 0.', 'JN': 'If N: PC &larr; Imm, N &larr; 0.', 'JC': 'If C: PC &larr; Imm, C &larr; 0.',
    'JMP': 'PC &larr; Imm.', 'CALL': 'Push PC + 1; PC &larr; Imm.', 'RET': 'Pop PC.', 'INT': 'Push PC + 1, save flags, PC &larr; M[index + 2].',
    'RTI': 'Pop PC, restore flags.'}

INSTR = []
for op in OPS:
    variants = [(1, True)]
    if op == 'SWAP':
        variants = [(1, True), (2, True)]
    if op in ('JZ', 'JN', 'JC'):
        variants = [(1, True), (1, False)]
    for uop, tk in variants:
        stages = []
        for st in SEQ:
            if op == 'HLT' and st not in ('F', 'D'):
                break
            ws, txt = stage_info(op, st, uop, tk)
            stages.append(dict(st=st, wires=ws, text=txt))
        label = EXAMPLE[op] + (f'  (micro-op {uop})' if op == 'SWAP' else '') + \
            ('' if op not in ('JZ', 'JN', 'JC') else ('  (taken)' if tk else '  (not taken)'))
        INSTR.append(dict(op=op, label=label, summary=SUMMARY[op], opcode=f'{OPS.index(op):05b}', stages=stages))

# ------------------------------------------------------------------ programs from the VHDL traces
BUB, INJ = 0xFFFFFFFF, 0xFFFFFFFE


def load(run):
    rows = []
    for line in open(f'{F26}/build/runs/{run}/trace.txt'):
        p = line.split()
        h = [int(x, 16) for x in p[1:19]]
        rows.append(dict(cyc=int(p[0]), f=h[0], id=h[1], e1=h[2], e2=h[3], m=h[4], w=h[5], regs=h[6:14],
                         ccr=h[14], sp=h[15], out=h[16], inp=h[17], intr=p[19]))
    return rows


def instances(rows, src):
    byc = {r['cyc']: r for r in rows}
    inst = []
    for r in rows:
        c, a = r['cyc'], r['e1']
        if a == BUB:
            continue
        if a == INJ:
            inst.append(dict(name='HW interrupt (INT 1)', addr=None, hw=True, stages={c - 1: 'D', c: 'E1', c + 1: 'E2', c + 2: 'M', c + 3: 'W'}))
            continue
        st = {}
        k = c - 1
        while k in byc and byc[k]['id'] == a:
            st[k] = 'D'
            k -= 1
        st[k] = 'F'
        st[c] = 'E1'
        nxt = byc.get(c + 1)
        if nxt and nxt['e2'] == a:
            st[c + 1] = 'E2'; st[c + 2] = 'M'; st[c + 3] = 'W'
        else:
            st[c + 1] = 'x'
        inst.append(dict(name=src.get(a, f'{a:03X}'), addr=a, stages=st))
    prev = None
    for r in rows:
        a = r['id']
        if a != BUB and a != prev:
            start = r['cyc']
            k = start
            while k in byc and byc[k]['id'] == a:
                k += 1
            if byc.get(k, {}).get('e1') != a and a != INJ:
                st = {start - 1: 'F'}
                for j in range(start, k):
                    st[j] = 'D'
                nm = src.get(a, f'{a:03X}')
                if nm.upper().startswith('HLT'):
                    for j in range(start, k + 1):
                        st[j] = 'D'
                    halt = True
                else:
                    st[k] = 'x'
                    halt = False
                inst.append(dict(name=nm, addr=a, stages=st, halt=halt, killed_id=not halt))
        prev = a
    inst.sort(key=lambda i: min(i['stages']))
    # SWAP micro-op numbering: two consecutive EX1 instances of the same SWAP address
    for i in inst:
        i['uop'] = 1
    for x, y in zip(inst, inst[1:]):
        if x.get('addr') is not None and x.get('addr') == y.get('addr') and x['name'].upper().startswith('SWAP'):
            y['uop'] = 2
    return inst


def decode(word):
    op = OPS[word >> 27] if (word >> 27) < len(OPS) else 'NOP'
    D, A, B = (word >> 24) & 7, (word >> 21) & 7, (word >> 18) & 7
    return op, D, A, B, word & 0xFFFF


PAL = 6


def program(run, asm_path, title, note):
    mem, lst = assemble(open(asm_path).read())
    src = {a: s.split('#')[0].strip() for a, w, s in lst}
    rows = load(run)
    inst = instances(rows, src)
    last = max(r['cyc'] for r in rows)
    first = 1
    byc = {r['cyc']: r for r in rows}
    # per-instance decode
    for n, i in enumerate(inst):
        i['color'] = n % PAL
        if i.get('hw'):
            i['op'], i['dest'], i['wr'], i['srcA'], i['srcB'] = 'INT', None, False, None, None
            continue
        op, D, A, B, imm = decode(mem[i['addr']])
        c = ctrl(op, i['uop'])
        i['op'] = op
        i['wr'] = c.get('wr') == '1'
        i['dest'] = B if c.get('destB') == '1' else D
        i['srcA'] = A if c.get('usesA') == '1' else None
        i['srcB'] = B if c.get('usesB') == '1' else None
        i['memread'] = c.get('memread') == '1'
        i['ret'] = c.get('ret') == '1'
    cycles = []
    for cyc in range(first, last + 1):
        occ = {}
        for n, i in enumerate(inst):
            s = i['stages'].get(cyc)
            if s in SEQ:
                occ.setdefault(s, []).append(n)
        flush_next = any(i['stages'].get(cyc + 1) == 'x' for i in inst)
        wires = []                                # [wire index, color]
        stage_txt = {}
        for s, lst_ in occ.items():
            n = lst_[-1]
            i = inst[n]
            stalled = s == 'D' and i['stages'].get(cyc + 1) == 'D'
            taken = flush_next if s == 'E2' else True
            if s == 'F' and i.get('hw'):
                continue
            ws, txt = stage_info(i['op'], s, i['uop'], taken, hw=i.get('hw', False))
            if s == 'D' and i.get('killed_id') and i['stages'].get(cyc + 1) == 'x':
                txt = 'This word is on the wrong path; it is discarded at the end of the cycle (flush / RET / interrupt).'
            if stalled:
                txt = 'Stalled in ID this cycle (see the events below); PC and IF/ID hold, a bubble enters EX1.'
            if s == 'E1' and i['stages'].get(cyc + 1) == 'x':
                txt = 'Killed: a jump is taken in EX2 this cycle, so e1_we = 0 and this instruction writes nothing.'
                ws = sel(['e1_v'])
            wires += [[k, i['color']] for k in ws]
            stage_txt[s] = dict(i=n, text=txt)
        ev = []
        # stalls
        for n, i in enumerate(inst):
            if i['stages'].get(cyc) == 'D' and i['stages'].get(cyc + 1) == 'D' and not i.get('halt'):
                why = 'load-use: an operand is still being loaded'
                for s in ('E1', 'E2', 'M'):
                    for m in occ.get(s, []):
                        if inst[m].get('ret'):
                            why = 'a RET/RTI is in flight, so nothing new is issued until the return address arrives'
                if i['op'] == 'SWAP' and i['uop'] == 1:
                    why = 'SWAP: the same word is decoded again for micro-op 2'
                ev.append(['stall', f'<b>{i["name"]}</b> waits in ID: {why}. PC holds, a bubble goes to EX1.'])
            if i.get('halt') and i['stages'].get(cyc) == 'D' and min(k for k, v in i['stages'].items() if v == 'D') == cyc:
                ev.append(['halt', 'HLT reached ID: the CPU is halted (only RESET restarts it).'])
        if flush_next:
            for m in occ.get('E2', []):
                ev.append(['flush', f'<b>{inst[m]["name"]}</b> is taken in EX2: flush. The instructions in IF/ID, ID and EX1 are discarded; PC &larr; target.'])
                wires += [[k, -1] for k in sel(['flush'])]
        # forwarding into EX1
        for n in occ.get('E1', []):
            i = inst[n]
            if i.get('hw') or i['stages'].get(cyc + 1) == 'x':
                continue
            for lab, src_reg, mux in (('A', i.get('srcA'), 'FWDA'), ('B', i.get('srcB'), 'FWDB')):
                if src_reg is None:
                    continue
                if lab == 'A' and i['op'] == 'SWAP' and i['uop'] == 2:
                    pass
                for s, net, nm in (('E2', 'e2_res', 'EX1/EX2.Res'), ('M', 'm_res', 'EX2/MEM.Res'), ('W', 'w_res', 'MEM/WB.Result')):
                    if lab == 'A' and i['op'] == 'SWAP' and i['uop'] == 2 and s == 'E2':
                        continue
                    hit = [m for m in occ.get(s, []) if inst[m]['wr'] and inst[m]['dest'] == src_reg]
                    if hit:
                        p = inst[hit[-1]]
                        ev.append(['fwd', f'<b>{i["name"]}</b> gets R{src_reg} (operand {lab}) from <b>{nm}</b>, the result of {p["name"]}.'])
                        wires += [[k, -2] for k in sel([f'{net}@{mux}'])]
                        break
        r, pr = byc.get(cyc), byc.get(cyc - 1)
        chg = []
        if r and pr:
            for k in range(8):
                if r['regs'][k] != pr['regs'][k]:
                    chg.append(f'R{k} = {r["regs"][k]:08X}')
            if r['ccr'] != pr['ccr']:
                chg.append(f'flags Z={r["ccr"] & 1} N={(r["ccr"] >> 1) & 1} C={(r["ccr"] >> 2) & 1}')
            if r['sp'] != pr['sp']:
                chg.append(f'SP = {r["sp"]:03X}')
            if r['out'] != pr['out']:
                chg.append(f'OUT.PORT = {r["out"]:08X}')
            if r['intr'] == '1':
                chg.append('INTR.IN pulse')
        cycles.append(dict(c=cyc, stages={k: v for k, v in stage_txt.items()}, wires=wires, ev=ev, chg=chg,
                           regs=[f'{x:08X}' for x in r['regs']] if r else None,
                           ccr=r['ccr'] if r else 0, sp=f'{r["sp"]:03X}' if r else '', pc=f'{r["f"]:03X}' if r else ''))
    return dict(id=run, title=title, note=note, inst=[dict(name=i['name'], color=i['color'], stages={str(k): v for k, v in i['stages'].items()}) for i in inst],
                first=first, last=last, cycles=cycles)


A = F26 + '/assembler/'
PROGS = [
    program('test1', A + 'test1.asm', 'test1 (Fall26)', 'One-operand instructions and flags. IN.PORT = 12345678. OUT R2 gets R2 from the IN right before it by forwarding.'),
    program('test2', A + 'test2.asm', 'test2 (Fall26)', 'Two-operand ALU instructions, CMP and shifts. Every dependency is forwarded: no stalls.'),
    program('TwoOperand', A + 'TwoOperand.asm', 'SWAP and two-operand', 'Extra program: SWAP runs as two micro-ops (the same word is decoded twice).'),
    program('Memory', A + 'Memory.asm', 'Load-use and stack', 'Extra program: PUSH/POP, LDD/STD. A value loaded by POP or LDD used right away causes a 2-cycle stall.'),
    program('test2_old', A + 'test2_old.asm', 'Branches, CALL and RET', 'Extra program: taken and not-taken jumps (3 instructions flushed when taken), CALL and RET.'),
    program('test2_doc', A + 'test2_old.asm', 'Hardware interrupt', 'Same program with INTR.IN pulsed at cycle 8: the interrupt waits for JMP, then INT 1 is injected, the handler runs and RTI returns.'),
    program('testcase2', A + 'testcase2.asm', 'CALL, INT 0, INT 1', 'Extra program: CALL/RET, software interrupts INT 0 and INT 1 with RTI.'),
]

STAGEX = {'F': 400, 'D': 1230, 'E1': 2060, 'E2': 2930, 'M': 3560, 'W': 4130}
data = dict(wires=W, shapes=SHAPES, instr=INSTR, progs=PROGS, stagex=STAGEX, view=[90, 0, 4210, 1900])
out = SCR + '/sim/data.json'
json.dump(data, open(out, 'w'), separators=(',', ':'))
print(os.path.getsize(out), 'bytes;', len(W), 'wires;', len(INSTR), 'instruction views;', [len(p['cycles']) for p in PROGS])
