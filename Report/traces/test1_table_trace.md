# Pipeline trace: test1_table

Generated from the VHDL simulation (run_tests.py + trace_table.py).  
Cycle 1 = first rising edge after RESET is released. The first cycles are the reset vector fetch (PC <- M[0]).  F D E1 E2 M W = stages, x = flushed (wrong path).

## Instruction x cycle chart

| # | Instruction | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `LDM R0, 1` |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| 2 | `LDM R1, AAAA` |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| 3 | `LDM R2, FFFF` |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| 4 | `INC R0` |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |  |
| 5 | `MOV R4, R1` |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |
| 6 | `NOT R1` |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |
| 7 | `MOV R3, R0` |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |
| 8 | `IN R0` |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |
| 9 | `OUT R0` |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |
| 10 | `AND R5, R1, R0` |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |
| 11 | `MOV R6, R0` |  |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |
| 12 | `NOT R6` |  |  |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |
| 13 | `INC R0` |  |  |  |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |
| 14 | `HLT  (halts in ID)` |  |  |  |  |  |  |  |  |  |  |  |  |  |  | F | D | D | D | D | D | D | D | D |

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
| 8 | 16 | 15 | 14 | 13 | 12 | 11 | R0=00000001 |
| 9 | 17 | 16 | 15 | 14 | 13 | 12 | R1=0000AAAA |
| 10 | 18 | 17 | 16 | 15 | 14 | 13 | R2=0000FFFF, ZNC=010 |
| 11 | 19 | 18 | 17 | 16 | 15 | 14 | R0=00000002 |
| 12 | 1A | 19 | 18 | 17 | 16 | 15 | R4=0000AAAA |
| 13 | 1B | 1A | 19 | 18 | 17 | 16 | R1=FFFF5555 |
| 14 | 1C | 1B | 1A | 19 | 18 | 17 | R3=00000002, OUT=FFFFFFFF |
| 15 | 1D | 1C | 1B | 1A | 19 | 18 | R0=FFFFFFFF |
| 16 | 1E | 1D | 1C | 1B | 1A | 19 | ZNC=100 |
| 17 | 1E | 1D | · | 1C | 1B | 1A | R5=FFFF5555, ZNC=101 |
| 18 | 1E | 1D | · | · | 1C | 1B | R6=FFFFFFFF |
| 19 | 1E | 1D | · | · | · | 1C | R6=00000000 |
| 20 | 1E | 1D | · | · | · | · | R0=00000000 |
| 21 | 1E | 1D | · | · | · | · |  |
| 22 | 1E | 1D | · | · | · | · |  |
| 23 | 1E | 1D | · | · | · | · |  |
