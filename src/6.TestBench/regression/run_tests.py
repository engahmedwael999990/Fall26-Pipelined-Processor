#!/usr/bin/env python3
"""
run_tests.py  --  regression: VHDL (GHDL) vs. instruction-level reference model.

For every test run it
  1. assembles the program (assembler/assembler.py),
  2. simulates the processor with the self-checking testbench,
  3. runs the reference model with the same IN values and with hardware
     interrupts taken at the same instruction boundaries the hardware chose,
  4. compares R0-R7, Z/N/C, SP, PC, OUT history and the whole 4K RAM.

    python src/6.TestBench/regression/run_tests.py             # all runs
    python src/6.TestBench/regression/run_tests.py test2       # runs containing "test2"
    python src/6.TestBench/regression/run_tests.py --variants  # + DSP shifter / rising-edge RF
"""
import os
import sys
import subprocess
import random

HERE = os.path.dirname(os.path.abspath(__file__))                 # src/6.TestBench/regression
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))   # project root
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, 'assembler'))
from assembler import assemble, write_outputs   # noqa: E402
from model import Model                          # noqa: E402

BUILD = os.path.join(ROOT, 'build')
GHDL = os.environ.get('GHDL', 'ghdl')
SRCS = ['src/0.Package/cpu_pkg.vhd', 'src/6.TestBench/sim_pkg.vhd',
        'src/1.Components/memory_file.vhd', 'src/1.Components/register_file.vhd',
        'src/1.Components/incrementer.vhd', 'src/1.Components/sign_extend.vhd',
        'src/1.Components/alu.vhd', 'src/1.Components/shifter.vhd',
        'src/1.Components/forwarding_unit.vhd', 'src/1.Components/conditional_jump_decoder.vhd',
        'src/1.Components/ccr_register.vhd', 'src/1.Components/stack_pointer.vhd',
        'src/2.PIPELINE_REGISTERS/IF_ID.vhd', 'src/2.PIPELINE_REGISTERS/ID_EX1.vhd',
        'src/2.PIPELINE_REGISTERS/EX1_EX2.vhd', 'src/2.PIPELINE_REGISTERS/EX2_MEM.vhd',
        'src/2.PIPELINE_REGISTERS/MEM_WB.vhd',
        'src/4.Controlling/Control_unit.vhd', 'src/4.Controlling/hazard_unit.vhd',
        'src/4.Controlling/interrupt_unit.vhd',
        'src/3.Stages/FETCH.vhd', 'src/3.Stages/DECODE.vhd', 'src/3.Stages/EX1.vhd',
        'src/3.Stages/EX2.vhd', 'src/3.Stages/MEMORY.vhd', 'src/3.Stages/WB.vhd',
        'src/5.TOP/top_level.vhd', 'src/6.TestBench/top_level_tb.vhd']
T = os.path.join(ROOT, 'assembler')

# name, asm file, IN.PORT values (hex), interrupt cycles
RUNS = [
    ('OneOperand',  'OneOperand.asm', [0x5, 0x10], []),
    ('TwoOperand',  'TwoOperand.asm', [0x5, 0x19, 0xFFFFFFFF, 0xFFFFF320], []),
    ('Memory',      'Memory.asm',     [0x19, 0xFFFFFFFF, 0xFFFFF320, 0x10, 0x10, 0x19], []),
    ('Branch',      'Branch.asm',     [0x30, 0x50, 0x100, 0x300, 0x60, 0x70, 0x700, 0x5], []),
    ('test1',       'test1.asm',      [0x12345678], []),
    ('test2',       'test2.asm',      [], []),
    ('test1_table', 'test1_table.asm', [0xFFFFFFFF], []),
    ('test2_old',   'test2_old.asm',  [0x50, 0x30, 0x300, 0x100, 0x55, 0x75, 0x700, 0x6], []),
    ('testcase1',   'testcase1.asm',  [0xFFFFFFFF], []),
    ('testcase2',   'testcase2.asm',  [], []),
]
# hardware-interrupt runs: the IN list for test2/Branch has the handler's
# value inserted where the hardware will execute it, so we sweep the interrupt
# over many cycles and let the comparison use the hardware's actual boundary.
IRQ_SWEEP = {
    'test2_old': ('test2_old.asm', [0x50, 0x30, 0x300, 0x100, 0x55, 0x75, 0x700, 0x6]),
    'Branch':    ('Branch.asm',    [0x30, 0x50, 0x100, 0x300, 0x60, 0x70, 0x700, 0x5]),
    'testcase2': ('testcase2_irq.asm', []),
    'testcase1': ('testcase1.asm', [0xFFFFFFFF]),
}


def build(tag='', generics=()):
    os.makedirs(BUILD, exist_ok=True)
    work = os.path.join(BUILD, 'work' + tag)
    os.makedirs(work, exist_ok=True)
    flags = ['--std=08', '-frelaxed', f'--workdir={work}']
    srcs = [os.path.join(ROOT, s) for s in SRCS]
    subprocess.run([GHDL, '-a', *flags, *srcs], check=True, stderr=subprocess.DEVNULL)
    subprocess.run([GHDL, '-e', *flags, 'top_level_tb'], check=True, cwd=work)
    return work, flags


def sim(work, flags, name, mem, inputs, irq_cycles, generics=(), trace=False):
    d = os.path.join(BUILD, 'runs', name)
    os.makedirs(d, exist_ok=True)
    prog = os.path.join(d, 'prog.mem')
    with open(prog, 'w') as f:
        f.writelines(f'{w:08X}\n' for w in mem)
    inf = os.path.join(d, 'in.txt')
    with open(inf, 'w') as f:
        f.writelines(f'{v:08X}\n' for v in inputs)
    irqf = os.path.join(d, 'irq.txt')
    with open(irqf, 'w') as f:
        f.writelines(f'{c:08X}\n' for c in irq_cycles)
    res, dump, tr = (os.path.join(d, x) for x in ('result.txt', 'ram.mem', 'trace.txt'))
    for p in (res, dump):
        if os.path.exists(p):
            os.remove(p)
    g = [f'-gPROG_FILE={prog}', f'-gIN_FILE={inf}', f'-gIRQ_FILE={irqf}', f'-gRES_FILE={res}',
         f'-gDUMP_FILE={dump}', *[f'-g{x}' for x in generics]]
    if trace:
        g.append(f'-gTRACE_FILE={tr}')
    subprocess.run([GHDL, '-r', *flags, 'top_level_tb', *g, '--ieee-asserts=disable'],
                   check=True, cwd=work, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    r = {'irq': [], 'outs': []}
    for line in open(res):
        p = line.split()
        if p[0] == 'REGS':
            r['regs'] = [int(x, 16) for x in p[1:]]
        elif p[0] in ('CCR', 'SP', 'PC', 'OUT'):
            r[p[0].lower()] = int(p[1], 16)
        elif p[0] in ('RETIRED', 'CYCLES', 'INS_USED'):
            r[p[0].lower()] = int(p[1])
        elif p[0] == 'IRQ':
            r['irq'].append(int(p[1]))
        elif p[0] == 'TIMEOUT':
            r['timeout'] = True
    r['outs'] = [int(x, 16) for x in open(res + '.out').read().split()]
    r['ram'] = [int(x, 16) for x in open(dump).read().split()]
    return r


def compare(mem, inputs, r):
    m = Model(mem, inputs, r['irq'])
    ok_halt = m.run()
    errs = []
    if r.get('timeout'):
        errs.append('VHDL timeout (never halted)')
    if not ok_halt:
        errs.append('model did not halt')
    if r['regs'] != m.r:
        errs.append('regs ' + ' '.join(f'R{i}:{a:X}/{b:X}' for i, (a, b) in enumerate(zip(r['regs'], m.r)) if a != b))
    ccr = (m.c << 2) | (m.n << 1) | m.z
    if r['ccr'] != ccr:
        errs.append(f'CCR vhdl={r["ccr"]:X} model={ccr:X}')
    if r['sp'] != m.sp:
        errs.append(f'SP vhdl={r["sp"]:X} model={m.sp:X}')
    if m.hlt_addr is not None and r['pc'] != m.hlt_addr + 1:
        errs.append(f'PC vhdl={r["pc"]:X} model HLT at {m.hlt_addr:X}')
    if r['outs'] != m.outs:
        errs.append(f'OUT vhdl={[hex(x) for x in r["outs"]]} model={[hex(x) for x in m.outs]}')
    if r['ram'] != m.mem:
        bad = [i for i in range(4096) if r['ram'][i] != m.mem[i]]
        errs.append(f'RAM differs at {len(bad)} words, first {bad[0]:03X}: vhdl={r["ram"][bad[0]]:X} model={m.mem[bad[0]]:X}')
    if r['retired'] != m.retired:
        errs.append(f'retired vhdl={r["retired"]} model={m.retired}')
    if r['ins_used'] != m.in_idx:
        errs.append(f'IN count vhdl={r["ins_used"]} model={m.in_idx}')
    return errs, m


# ------------------------------------------------------------------ random programs
def random_program(seed):
    """random straight-line + forward-branch program, terminating in HLT.
    Exercises forwarding, load-use, SWAP, stack, CALL/RET, flags, shifts."""
    rnd = random.Random(seed)
    lines = ['.ORG 0', '20', '.ORG 1', 'E00', '.ORG 2', 'E80', '.ORG 3', 'F00',
             '.ORG E00', 'IN R7', 'AND R0,R0,R0', 'OUT R7', 'RTI',
             '.ORG E80', 'NOT R6', 'RTI', '.ORG F00', 'INC R5', 'RTI',
             '.ORG 600', 'ADD R1,R2,R3', 'SUB R4,R1,R2', 'RET',
             '.ORG 20']
    regs = [f'R{i}' for i in range(8)]
    n = rnd.randint(20, 60)
    addr = 0x20
    body = []
    for i in range(n):
        k = rnd.random()
        R = lambda: rnd.choice(regs)
        hx = lambda m: f'{rnd.randint(0, m):X}'
        if k < 0.30:
            body.append(f'{rnd.choice(["ADD", "SUB", "AND"])} {R()},{R()},{R()}')
        elif k < 0.38:
            body.append(f'{rnd.choice(["NOT", "INC"])} {R()}')
        elif k < 0.44:
            body.append(f'IADD {R()},{R()},{hx(0xFFFF)}')
        elif k < 0.50:
            body.append(f'LDM {R()},{hx(0xFFFF)}')
        elif k < 0.55:
            body.append(f'MOV {R()},{R()}')
        elif k < 0.60:
            body.append(f'SWAP {R()},{R()}')
        elif k < 0.64:
            body.append(f'CMP {R()},{R()}')
        elif k < 0.68:
            body.append(f'{rnd.choice(["SHL", "SHR"])} {R()},{rnd.choice(["0", "1", "5", "1F", "20", "21", hx(0x3F)])}')
        elif k < 0.77:
            rb = R()                                  # base loaded into the data region
            body.append(f'LDM {rb},{rnd.randint(0x800, 0xC00):X}')
            if rnd.random() < 0.5:
                body.append(f'STD {R()},{hx(0x7F)}({rb})')
            else:
                body.append(f'LDD {R()},{hx(0x7F)}({rb})')
        elif k < 0.81:
            r = R(); body += [f'PUSH {r}', f'POP {R()}']
        elif k < 0.84:
            body.append('IN ' + R())
        elif k < 0.86:
            body.append('OUT ' + R())
        elif k < 0.88:
            body.append('SETC')
        elif k < 0.90:
            body.append('CALL 600')
        elif k < 0.92:
            body.append(f'INT {rnd.randint(0, 1)}')
        else:
            body.append('@BR')                       # forward branch, fixed below
    # resolve forward branches: target = a later instruction (skips 0..3 words)
    out = []
    pos = []
    a = addr
    for s in body:
        pos.append(a)
        a += 1
    end = a
    for i, s in enumerate(body):
        if s == '@BR':
            tgt = min(pos[i] + rnd.randint(1, 4), end)
            s = f'{rnd.choice(["JZ", "JN", "JC", "JMP"])} {tgt:X}'
        out.append(s)
    fixed = out
    return '\n'.join(lines + fixed + ['HLT']) + '\n'


def main():
    sel = [a for a in sys.argv[1:] if not a.startswith('--')]
    variants = '--variants' in sys.argv
    nrand = 200
    for a in sys.argv[1:]:
        if a.startswith('--random='):
            nrand = int(a.split('=')[1])
    configs = [('', ())]
    if variants:
        configs += [('_dsp', ('SHIFTER_DSP=true',)), ('_posrf', ('RF_NEGEDGE=false',))]
    total = fails = 0
    for tag, gen in configs:
        work, flags = build(tag)
        label = tag or '_baseline'
        print(f'===== build {label[1:]} =====')
        # ---- official tests
        for name, asm, ins, irqs in RUNS:
            if sel and not any(s in name for s in sel):
                continue
            mem, _ = assemble(open(os.path.join(T, asm)).read())
            r = sim(work, flags, name + tag, mem, ins, irqs, gen, trace=True)
            errs, m = compare(mem, ins, r)
            total += 1
            fails += bool(errs)
            print(f'{"PASS" if not errs else "FAIL"}  {name:12s} cycles={r["cycles"]:5d} '
                  f'uops={r["retired"]:4d}  ' + ('; '.join(errs)))
        # ---- hardware-interrupt sweeps
        for name, (asm, ins) in IRQ_SWEEP.items():
            if sel and not any(s in name + '_irq' for s in sel):
                continue
            mem, _ = assemble(open(os.path.join(T, asm)).read())
            base = sim(work, flags, name + '_noirq' + tag, mem, ins, [], gen)
            npass = 0
            nrun = 0
            taken = 0
            bad = []
            for cyc in range(3, base['cycles'] + 2):
                r = sim(work, flags, f'{name}_irq{tag}', mem, ins, [cyc], gen)
                errs, m = compare(mem, ins, r)
                nrun += 1
                taken += len(r['irq'])
                if errs:
                    bad.append((cyc, errs))
                else:
                    npass += 1
            total += nrun
            fails += len(bad)
            print(f'{"PASS" if not bad else "FAIL"}  {name + "+INTR":12s} interrupt pulsed at every cycle '
                  f'3..{base["cycles"] + 1}: {npass}/{nrun} ok, {taken} taken')
            for cyc, e in bad[:5]:
                print(f'        cycle {cyc}: {"; ".join(e)}')
        # ---- random differential tests
        if not sel or 'random' in sel:
            rbad = []
            for seed in range(nrand):
                src = random_program(seed)
                mem, _ = assemble(src)
                ins = [random.Random(seed + 7).randint(0, 0xFFFFFFFF) for _ in range(64)]
                rr = random.Random(seed + 99)
                irqs = sorted(rr.sample(range(5, 120), rr.randint(0, 3)))
                r = sim(work, flags, f'random{tag}', mem, ins, irqs, gen)
                errs, m = compare(mem, ins, r)
                if errs:
                    rbad.append((seed, errs))
                    with open(os.path.join(BUILD, f'random_fail_{seed}.asm'), 'w') as f:
                        f.write(src)
            total += nrand
            fails += len(rbad)
            print(f'{"PASS" if not rbad else "FAIL"}  random       {nrand - len(rbad)}/{nrand} random programs '
                  f'(with random interrupts) match the model')
            for seed, e in rbad[:5]:
                print(f'        seed {seed}: {"; ".join(e)}')
    print(f'\n{total - fails}/{total} runs passed')
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
