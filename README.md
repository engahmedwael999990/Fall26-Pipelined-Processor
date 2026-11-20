# CMPS301 Fall26 — 6-stage pipelined Von-Neumann processor

IF → ID → EX1 → EX2 → MEM → WB, one shared 4096 × 32 synchronous RAM (M10K, true dual port:
port A = fetch, port B = data), eight 32-bit registers, 32-bit PC and SP, static predict-not-taken.

## Folder layout

```
F26/
├── src/
│   ├── 0.Package/            cpu_pkg.vhd           types, opcodes, control-word record
│   ├── 1.Components/         memory_file, register_file, alu, shifter, sign_extend,
│   │                         incrementer, forwarding_unit, conditional_jump_decoder,
│   │                         ccr_register, stack_pointer
│   ├── 2.PIPELINE_REGISTERS/ IF_ID, ID_EX1, EX1_EX2, EX2_MEM, MEM_WB
│   ├── 3.Stages/             FETCH, DECODE, EX1, EX2, MEMORY, WB
│   ├── 4.Controlling/        Control_unit, hazard_unit, interrupt_unit
│   ├── 5.TOP/                top_level.vhd         (top entity: top_level)
│   └── 6.TestBench/          top_level_tb.vhd, sim_pkg.vhd,
│                             do_files/ (ModelSim), regression/ (GHDL + Python model)
├── assembler/                assembler.py, test programs (.asm/.in), official/, out/
├── quartus/                  Processor.qpf/.qsf/.sdc, program.mif
└── Report/                   Phase_1_Schema.drawio/.png/.pdf, Phase1_Report.pdf,
                              Study_Guide.pdf, traces/
```

## ISA choices (instructor-approved one-word format)

`[31:27] opcode | [26:24] Rdst | [23:21] Rsrc1 | [20:18] Rsrc2 | [17:16] 0 | [15:0] imm`

- IADD immediate and LDD/STD offsets are **sign-extended**. LDM is **zero-extended**: the Fall26
  test1 expects `LDM R0, FFFF` → `0000FFFF`.
- SUB/CMP carry = NOT borrow (C = 1 when Rsrc1 ≥ Rsrc2 unsigned).
- SHL/SHR are logical; SHR fills with zeros; carry = last bit shifted out. Count 0 keeps C.
  Count 32 gives 0 with C = bit0 (SHL) or bit31 (SHR). Count > 32 gives 0 with C = 0.
- A taken JZ/JN/JC clears the tested flag. CCR bit 3 = 0.
- Reset: PC ← M[0]. Hardware interrupt: PC ← M[1]. INT idx: PC ← M[idx + 2].
- Interrupts are not nested. The flags are saved to the shadow CCR on entry and restored by RTI.

## Simulation (ModelSim)

Fall26 test programs: `assembler/test1.asm` and `assembler/test2.asm` (from Google Classroom, unchanged).
The other programs are from earlier years and are used as extra tests.

In the ModelSim transcript: `cd <project>/src/6.TestBench/do_files`, then `do run_test1.do`
(or another `run_<test>.do`). `wave.do` shows only CLK, Reset, Interrupt, IN.PORT, OUT.PORT,
PC, SP, Flags and R0–R7. `run_test2_old_irq.do` pulses INTR.IN at the cycle in `irq.txt`.

Regression (GHDL): `python3 src/6.TestBench/regression/run_tests.py [--variants]`.
It compares registers, flags, SP, PC, OUT history and the full RAM against an independent
instruction-level model.
Last run: 470/470 baseline; 1410/1410 with the DSP-shifter and rising-edge-RF variants.

## Quartus (Prime Lite 16.1.0.196, Cyclone V 5CSEMA5F31C6)

1. Open `quartus/Processor.qpf`. To run a different program in hardware, copy
   `assembler/out/<test>.mif` over `quartus/program.mif`.
2. Leave every compiler setting at its default and run **Processing → Start Compilation**
   (the full flow includes the Assembler, which generates the .sof).
3. Record the Flow Summary (ALMs, total registers, block memory bits ≠ 0, RAM blocks) and the
   TimeQuest setup/hold slack.

First compile (static build): 614 ALMs, 677 registers, 131,072 block memory bits. Fmax and slack: not recorded yet.
