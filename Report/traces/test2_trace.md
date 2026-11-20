# Pipeline trace: test2

Generated from the VHDL simulation (run_tests.py + trace_table.py).  
Cycle 1 = first rising edge after RESET is released. The first cycles are the reset vector fetch (PC <- M[0]).  F D E1 E2 M W = stages, x = flushed (wrong path).

## Instruction x cycle chart

| # | Instruction | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `LDM R0, 0005` |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| 2 | `LDM R1, 0003` |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| 3 | `ADD R2, R0, R1` |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |  |
| 4 | `SUB R3, R0, R1` |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |
| 5 | `SUB R4, R1, R0` |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |
| 6 | `SUB R5, R0, R0` |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |
| 7 | `AND R6, R0, R1` |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |
| 8 | `IADD R7, R0, 0010` |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |
| 9 | `CMP R0, R1` |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |
| 10 | `CMP R1, R0` |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |
| 11 | `SHL R3, 0004` |  |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |
| 12 | `SHR R2, 0001` |  |  |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |
| 13 | `HLT  (halts in ID)` |  |  |  |  |  |  |  |  |  |  |  |  |  | F | D | D | D | D | D | D | D | D |

## Cycle-by-cycle state (addresses in each stage, register writes visible after the edge)

| cycle | IF (PC) | ID | EX1 | EX2 | MEM | WB | changes after this edge |
|---|---|---|---|---|---|---|---|
| 1 | 1 | · | · | · | · | · |  |
| 2 | 10 | · | · | · | · | · |  |
| 3 | 11 | 10 | · | · | · | · |  |
| 4 | 12 | 11 | 10 | · | · | · |  |
| 5 | 13 | 12 | 11 | 10 | · | · |  |
| 6 | 14 | 13 | 12 | 11 | 10 | · |  |
| 7 | 15 | 14 | 13 | 12 | 11 | 10 |  |
| 8 | 16 | 15 | 14 | 13 | 12 | 11 | R0=00000005, ZNC=001 |
| 9 | 17 | 16 | 15 | 14 | 13 | 12 | R1=00000003, ZNC=010 |
| 10 | 18 | 17 | 16 | 15 | 14 | 13 | R2=00000008, ZNC=101 |
| 11 | 19 | 18 | 17 | 16 | 15 | 14 | R3=00000002, ZNC=001 |
| 12 | 1A | 19 | 18 | 17 | 16 | 15 | R4=FFFFFFFE, ZNC=000 |
| 13 | 1B | 1A | 19 | 18 | 17 | 16 | ZNC=001 |
| 14 | 1C | 1B | 1A | 19 | 18 | 17 | R6=00000001, ZNC=010 |
| 15 | 1D | 1C | 1B | 1A | 19 | 18 | R7=00000015, ZNC=000 |
| 16 | 1D | 1C | · | 1B | 1A | 19 |  |
| 17 | 1D | 1C | · | · | 1B | 1A |  |
| 18 | 1D | 1C | · | · | · | 1B | R3=00000020 |
| 19 | 1D | 1C | · | · | · | · | R2=00000004 |
| 20 | 1D | 1C | · | · | · | · |  |
| 21 | 1D | 1C | · | · | · | · |  |
| 22 | 1D | 1C | · | · | · | · |  |
