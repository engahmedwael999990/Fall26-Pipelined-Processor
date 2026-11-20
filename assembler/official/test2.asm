# Test 2: two-operand ALU instructions and flags
# All numbers are hex. Expected results are in the comments.
# Reset vector: start of program at address 0010h
.org 0
10
.org 10
LDM R0, 0005        # R0 = 00000005
LDM R1, 0003        # R1 = 00000003
ADD R2, R0, R1      # R2 = 00000008, Z=0, N=0
SUB R3, R0, R1      # R3 = 00000002, Z=0, N=0
SUB R4, R1, R0      # R4 = FFFFFFFE, N=1
SUB R5, R0, R0      # R5 = 00000000, Z=1
AND R6, R0, R1      # R6 = 00000001, Z=0, N=0
IADD R7, R0, 0010   # R7 = 00000015
CMP R0, R1          # 5 - 3 = 2: Z=0, N=0; R0 and R1 unchanged
CMP R1, R0          # 3 - 5 = -2: N=1; R0 and R1 unchanged
SHL R3, 0004        # R3 = 00000020
SHR R2, 0001        # R2 = 00000004, C = last bit shifted out = 0
HLT
