# testcase2_irq.asm -- copy of testcase2.asm used for the hardware-interrupt sweep.
# In the official test, INC R0 (FFFFFFFF -> 0) sets C=1 (Fall26: INC updates carry),
# so the 'JC 400' after the JN loop is taken and the handler restarts forever.
# Here those four JCs jump to the RTI (40C) instead, so the handler terminates.
.ORG 0  #this is the reset address
200

.ORG 1  #this is the address for hard interrupt
3FF     # [Fall26 adaptation] handler now starts one word earlier, see below

.ORG 2  #this is the address for INT0
600

.ORG 3  #this is the address of INT1
800

# Hard Interrupt Handler
# [Fall26 adaptation] LDM only has a 16-bit immediate (zero-extended), so the
# original "LDM R0,0FFFFFFF9" cannot be encoded. R0 = FFFFFFF9 is built with
# LDM R0,6 / NOT R0, starting at 3FF so every original address (400.., JN 406)
# stays the same.
.ORG 3FF
    LDM R0,6
    NOT R0          # R0 = FFFFFFF9
    INC R0          # Sets Negative Flag
    JC 400          #  |
    JC 400          #  |   Reducing the 2-bit branch predictor to 0
    JC 400          # \ /
    JC 400          #  '
    INC R0
                    #  .
                    # / \
    JN 406          #  |   # Address of the INC # Loop until R0 is not negative (5 times), Increases the 2-bit branch predictor to max
                    #  |
                    #  |
    
    JC 40C          #  |
    JC 40C          #  |   Reducing the 2-bit branch predictor to 0
    JC 40C          # \ /
    JC 40C          #  '
    RTI

# INT0 Handler
.ORG 600
    LDM R0,1
    LDM R1,2
    JN 605           # Address of the RTI # For loop that should execute 3 times
    SUB R1,R1,R0
    JMP 602          # Address of the JN
    RTI

# INT1 Handler
.ORG 800
    LDM R0,2
    LDM R1,0
    SUB R1,R1,R0
    JZ 806          # Address of the RTI # For loop that should execute 2 times
    INC R1
    JMP 803         # Address of the JZ
    RTI

# Main loop
.ORG 200
    CALL 300
    SETC            # Should be preserved
    NOP
    NOP
    NOP
    # Perform hard interrupt here
    INT 0
    INT 1
    HLT             # Should be executed, End of testcase \(^-^)/
	
# Function
.ORG 300
    LDM R0,5        # Some Value
    PUSH R0
    LDM R1,A0       # Some data memory address
    LDM R4,A5       # Same data memory address but plus 5
    POP R2
    STD R2,5(R1)    # Load-use here
    LDD R3,0(R4)
    SUB R0,R0,R3    # Should be zero, Load-use here
    JZ 30A          # RET Address # Should be executed and succeed
    JMP 300         # Should not be executed
    RET             # Should be executed
