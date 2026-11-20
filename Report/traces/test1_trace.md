# Pipeline trace: test1

Generated from the VHDL simulation (run_tests.py + trace_table.py).  
Cycle 1 = first rising edge after RESET is released. The first cycles are the reset vector fetch (PC <- M[0]).  F D E1 E2 M W = stages, x = flushed (wrong path).

## Instruction x cycle chart

| # | Instruction | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `LDM R0, FFFF` |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |
| 2 | `INC R0` |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |
| 3 | `LDM R1, 0000` |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |
| 4 | `NOT R1` |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |
| 5 | `INC R1` |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |
| 6 | `NOT R1` |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |
| 7 | `SETC` |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |
| 8 | `IN R2` |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |
| 9 | `OUT R2` |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |
| 10 | `NOP` |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |
| 11 | `HLT  (halts in ID)` |  |  |  |  |  |  |  |  |  |  |  | F | D | D | D | D | D | D |

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
| 8 | 16 | 15 | 14 | 13 | 12 | 11 | R0=0000FFFF, ZNC=010 |
| 9 | 17 | 16 | 15 | 14 | 13 | 12 | R0=00010000, ZNC=101 |
| 10 | 18 | 17 | 16 | 15 | 14 | 13 | ZNC=011 |
| 11 | 19 | 18 | 17 | 16 | 15 | 14 | R1=FFFFFFFF |
| 12 | 1A | 19 | 18 | 17 | 16 | 15 | R1=00000000 |
| 13 | 1B | 1A | 19 | 18 | 17 | 16 | R1=FFFFFFFF |
| 14 | 1B | 1A | · | 19 | 18 | 17 | OUT=12345678 |
| 15 | 1B | 1A | · | · | 19 | 18 | R2=12345678 |
| 16 | 1B | 1A | · | · | · | 19 |  |
| 17 | 1B | 1A | · | · | · | · |  |
| 18 | 1B | 1A | · | · | · | · |  |
