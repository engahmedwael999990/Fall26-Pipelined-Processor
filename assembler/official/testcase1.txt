
.ORG 0  #this is the reset address
200

.ORG 1  #this is the address for the hard interrupt handler
400

.ORG 2  #this is the address for INT0
600

.ORG 3  #this is the address for INT1
800

# Hard interrupt handler
.ORG 400
    NOP
    HLT

# INT0
.ORG 600
    NOP
    HLT

# INT1
.ORG 800
    NOP
    RTI

# Main loop
.ORG 200
    IN R0           # Force FFFFFFFF(-1) on IN port
    MOV R1,R0
    INC R1          # R1 -> 0, C -> 1, Z -> 1, N -> 0
    NOT R1          # R1 -> FFFFFFFF(-1), N -> 1, Z -> 0
    OUT R1
    IADD R0,R0,10   # R0 -> 0F
    ADD R4,R0,R1    # R4 -> 0E, C -> 1, Z -> 0, N -> 0  ALU-ALU Forwarding
    SUB R5,R0,R1    # R5 -> 10, C -> 1, Z -> 0, N -> 0  Memory-ALU Forwarding
    AND R6,R0,R1    # R6 -> 0F, Z -> 0, N -> 0          No forwarding
    SETC            # Sets Carry Flag
    JC 300          # Function jump, should be executed and succeed
    JMP 200         # Main loop jump, shouldn't be executed

# Function
.ORG 300
    JC 200          # Main loop jump, should be executed and fail
    SETC            # Sets Carry Flag
    LDM R7,0DEAD    # Instruction that doesn't modify the CCR
    SWAP R7,R6      # R7 -> 0F, R6 -> 0DEAD, Instruction that doesn't modify the CCR
    MOV R3,R6       # R3 should be DEAD (T_T)
    NOP
    NOP
    NOP
    JZ 300          # Should be executed and fail
    HLT             # Should be executed, End of testcase \(^-^)/