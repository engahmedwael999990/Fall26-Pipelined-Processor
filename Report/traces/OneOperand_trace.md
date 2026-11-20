# Pipeline trace: OneOperand

Generated from the VHDL simulation (run_tests.py + trace_table.py).  
Cycle 1 = first rising edge after RESET is released. The first cycles are the reset vector fetch (PC <- M[0]).  F D E1 E2 M W = stages, x = flushed (wrong path).

## Instruction x cycle chart

| # | Instruction | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `NOP` |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| 2 | `NOT R1` |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |  |
| 3 | `INC R1` |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |  |
| 4 | `IN R1` |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |  |
| 5 | `IN R2` |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |  |
| 6 | `NOT R2` |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |  |
| 7 | `INC R1` |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |  |
| 8 | `OUT R1` |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |  |
| 9 | `OUT R2` |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |  |
| 10 | `SETC` |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |  |
| 11 | `INC R2` |  |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |  |
| 12 | `OUT R2` |  |  |  |  |  |  |  |  |  |  |  |  | F | D | E1 | E2 | M | W |  |  |  |
| 13 | `HLT  (halts in ID)` |  |  |  |  |  |  |  |  |  |  |  |  |  | F | D | D | D | D | D | D | D |

## Cycle-by-cycle state (addresses in each stage, register writes visible after the edge)

| cycle | IF (PC) | ID | EX1 | EX2 | MEM | WB | changes after this edge |
|---|---|---|---|---|---|---|---|
| 1 | 1 | · | · | · | · | · |  |
| 2 | A0 | · | · | · | · | · |  |
| 3 | A1 | A0 | · | · | · | · |  |
| 4 | A2 | A1 | A0 | · | · | · |  |
| 5 | A3 | A2 | A1 | A0 | · | · |  |
| 6 | A4 | A3 | A2 | A1 | A0 | · | ZNC=010 |
| 7 | A5 | A4 | A3 | A2 | A1 | A0 | ZNC=101 |
| 8 | A6 | A5 | A4 | A3 | A2 | A1 |  |
| 9 | A7 | A6 | A5 | A4 | A3 | A2 | R1=FFFFFFFF |
| 10 | A8 | A7 | A6 | A5 | A4 | A3 | R1=00000000, ZNC=011 |
| 11 | A9 | A8 | A7 | A6 | A5 | A4 | R1=00000005, ZNC=000 |
| 12 | AA | A9 | A8 | A7 | A6 | A5 | R2=00000010 |
| 13 | AB | AA | A9 | A8 | A7 | A6 | R2=FFFFFFEF, OUT=00000006 |
| 14 | AC | AB | AA | A9 | A8 | A7 | R1=00000006, ZNC=001, OUT=FFFFFFEF |
| 15 | AD | AC | AB | AA | A9 | A8 | ZNC=010 |
| 16 | AD | AC | · | AB | AA | A9 |  |
| 17 | AD | AC | · | · | AB | AA | OUT=FFFFFFF0 |
| 18 | AD | AC | · | · | · | AB | R2=FFFFFFF0 |
| 19 | AD | AC | · | · | · | · |  |
| 20 | AD | AC | · | · | · | · |  |
| 21 | AD | AC | · | · | · | · |  |
