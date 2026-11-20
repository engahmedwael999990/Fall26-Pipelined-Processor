# wave.do  --  ONLY the signals the handout asks for:
# CLK, Reset, Interrupt, IN.PORT, OUT.PORT, PC, SP, Flags, R0-R7
onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -label CLK                 /top_level_tb/clk
add wave -noupdate -label Reset               /top_level_tb/rst
add wave -noupdate -label Interrupt           /top_level_tb/intr
add wave -noupdate -label IN.PORT  -radix hex /top_level_tb/in_port
add wave -noupdate -label OUT.PORT -radix hex /top_level_tb/out_port
add wave -noupdate -label PC       -radix hex /top_level_tb/dut/pc
add wave -noupdate -label SP       -radix hex /top_level_tb/dut/sp
add wave -noupdate -label {Flags (-,C,N,Z)} -radix bin /top_level_tb/dut/ccr
add wave -noupdate -label R0 -radix hex {/top_level_tb/dut/u_decode/u_rf/regs(0)}
add wave -noupdate -label R1 -radix hex {/top_level_tb/dut/u_decode/u_rf/regs(1)}
add wave -noupdate -label R2 -radix hex {/top_level_tb/dut/u_decode/u_rf/regs(2)}
add wave -noupdate -label R3 -radix hex {/top_level_tb/dut/u_decode/u_rf/regs(3)}
add wave -noupdate -label R4 -radix hex {/top_level_tb/dut/u_decode/u_rf/regs(4)}
add wave -noupdate -label R5 -radix hex {/top_level_tb/dut/u_decode/u_rf/regs(5)}
add wave -noupdate -label R6 -radix hex {/top_level_tb/dut/u_decode/u_rf/regs(6)}
add wave -noupdate -label R7 -radix hex {/top_level_tb/dut/u_decode/u_rf/regs(7)}
TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 160 -valuecolwidth 90 -timelineunits ns
update
WaveRestoreZoom {0 ns} {400 ns}
