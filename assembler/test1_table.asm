# test1  --  reconstructed from the official cycle table (tests/official/test1.pdf)
# 13 instructions, no stalls expected: one write-back per cycle.
# IN.PORT = FFFFFFFF for the IN instruction.
.ORG 0
10

.ORG 10
LDM R0, 1        # R0 = 0000_0001
LDM R1, AAAA     # R1 = 0000_AAAA   (LDM is zero-extended)
LDM R2, FFFF     # R2 = 0000_FFFF
INC R0           # R0 = 0000_0002, Z,N,C = 0,0,0
MOV R4, R1       # R4 = 0000_AAAA
NOT R1           # R1 = FFFF_5555, Z,N = 0,1
MOV R3, R0       # R3 = 0000_0002
IN R0            # R0 = FFFF_FFFF
OUT R0           # OUT.PORT = FFFF_FFFF
AND R5, R1, R0   # R5 = FFFF_5555, Z,N = 0,1
MOV R6, R0       # R6 = FFFF_FFFF
NOT R6           # R6 = 0000_0000, Z,N = 1,0
INC R0           # R0 = 0000_0000, Z,N,C = 1,0,1
HLT
