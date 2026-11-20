#!/usr/bin/env python3
"""
trace_table.py  --  turn the testbench cycle trace into a pipeline chart
(same layout as the course's test1 table: one row per dynamic instruction,
one column per cycle, F D E1 E2 M W) plus a per-cycle register/flag table.

    python src/6.TestBench/regression/trace_table.py test1 > Report/traces/test1_trace.md
Run run_tests.py first (it writes build/runs/<test>/trace.txt).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(ROOT, 'assembler'))
from assembler import assemble   # noqa: E402

BUB = 0xFFFFFFFF
INJ = 0xFFFFFFFE


def load(test, asm=None):
    rows = []
    for line in open(os.path.join(ROOT, 'build', 'runs', test, 'trace.txt')):
        p = line.split()
        c = int(p[0])
        h = [int(x, 16) for x in p[1:19]]
        rows.append(dict(cyc=c, f=h[0], id=h[1], e1=h[2], e2=h[3], m=h[4], w=h[5],
                         regs=h[6:14], ccr=h[14], sp=h[15], out=h[16], inp=h[17], intr=p[19]))
    src = {}
    if asm:
        _, lst = assemble(open(asm).read())
        for a, w, s in lst:
            src[a] = s.split('#')[0].strip()
    return rows, src


def chart(rows, src, max_cols=60):
    """dynamic instructions: every EX1 occupancy is one instance; ID cycles are the
    consecutive ID cycles before it with the same address; killed ones are marked x."""
    byc = {r['cyc']: r for r in rows}
    inst = []
    for r in rows:
        c, a = r['cyc'], r['e1']
        if a == BUB:
            continue
        if a == INJ:
            inst.append(dict(name='<HW INT>', stages={c: 'E1', c + 1: 'E2', c + 2: 'M', c + 3: 'W'}))
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
            st[c + 1] = 'x'                     # flushed in EX1 by a taken jump
        inst.append(dict(name=src.get(a, f'{a:03X}'), addr=a, stages=st))
    # instructions killed while in ID (never reached EX1)
    seen_ex1 = {(min(i['stages']), i.get('addr')) for i in inst}
    prev = None
    for r in rows:
        a = r['id']
        if a != BUB and a != prev:
            start = r['cyc']
            k = start
            while k in byc and byc[k]['id'] == a:
                k += 1
            ex1_next = byc.get(k, {}).get('e1') == a
            if not ex1_next and a != INJ:
                st = {start - 1: 'F'}
                for j in range(start, k):
                    st[j] = 'D'
                st[k] = 'x'
                nm = src.get(a, f'{a:03X}')
                if nm.upper().startswith('HLT'):
                    for j in range(start, k + 1):
                        st[j] = 'D'
                    nm += '  (halts in ID)'
                else:
                    nm += '  (flushed)'
                inst.append(dict(name=nm, addr=a, stages=st))
        prev = a
    inst.sort(key=lambda i: min(i['stages']))
    last = max(r['cyc'] for r in rows)
    cols = list(range(1, min(last, max_cols) + 1))
    w = max(len(i['name']) for i in inst) + 2
    out = ['| # | Instruction | ' + ' | '.join(str(c) for c in cols) + ' |',
           '|---|---|' + '---|' * len(cols)]
    for n, i in enumerate(inst, 1):
        out.append(f'| {n} | `{i["name"]}` | ' + ' | '.join(i['stages'].get(c, '') for c in cols) + ' |')
    return '\n'.join(out)


def state_table(rows, src):
    out = ['| cycle | IF (PC) | ID | EX1 | EX2 | MEM | WB | changes after this edge |',
           '|---|---|---|---|---|---|---|---|']
    prev = None
    for r in rows:
        def nm(a):
            if a == BUB:
                return '·'
            if a == INJ:
                return 'HW-INT'
            return f'{a:X}'
        ch = []
        if prev:
            for i in range(8):
                if r['regs'][i] != prev['regs'][i]:
                    ch.append(f'R{i}={r["regs"][i]:08X}')
            if r['ccr'] != prev['ccr']:
                z, n, c = r['ccr'] & 1, (r['ccr'] >> 1) & 1, (r['ccr'] >> 2) & 1
                ch.append(f'ZNC={z}{n}{c}')
            if r['sp'] != prev['sp']:
                ch.append(f'SP={r["sp"]:X}')
            if r['out'] != prev['out']:
                ch.append(f'OUT={r["out"]:08X}')
        if r['intr'] == '1':
            ch.append('INTR.IN=1')
        out.append(f'| {r["cyc"]} | {r["f"]:X} | {nm(r["id"])} | {nm(r["e1"])} | {nm(r["e2"])} | '
                   f'{nm(r["m"])} | {nm(r["w"])} | {", ".join(ch)} |')
        prev = r
    return '\n'.join(out)


def main():
    test = sys.argv[1]
    asm = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'assembler', test.split('_')[0] + '.asm')
    rows, src = load(test, asm)
    print(f'# Pipeline trace: {test}\n')
    print('Generated from the VHDL simulation (run_tests.py + trace_table.py).  ')
    print('Cycle 1 = first rising edge after RESET is released. The first cycles are the reset '
          'vector fetch (PC <- M[0]).  F D E1 E2 M W = stages, x = flushed (wrong path).\n')
    print('## Instruction x cycle chart\n')
    print(chart(rows, src))
    print('\n## Cycle-by-cycle state (addresses in each stage, register writes visible after the edge)\n')
    print(state_table(rows, src))


if __name__ == '__main__':
    main()
