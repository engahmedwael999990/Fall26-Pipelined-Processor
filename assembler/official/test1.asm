# Test 1: one-operand instructions and flags
# Expected results are in the comments.
.org 0
10
.org 10
LDM R0, FFFF        # R0 = 0000FFFF
INC R0              # R0 = 00010000, Z=0, N=0
LDM R1, 0000        # R1 = 00000000
NOT R1              # R1 = FFFFFFFF, N=1, Z=0
INC R1              # R1 = 00000000, Z=1
NOT R1              # R1 = FFFFFFFF, N=1
SETC                # C = 1
IN R2               # R2 = IN.PORT (set IN.PORT = 12345678 in the do file)
OUT R2              # OUT.PORT = 12345678
NOP                 # PC = PC + 1
HLT
