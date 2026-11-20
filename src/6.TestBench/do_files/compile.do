# compile.do  --  RTL as VHDL-93, testbench as VHDL-2008 (run from do_files/)
if {[file exists work]} { vdel -lib work -all }
vlib work
vcom -93   ../../../src/0.Package/cpu_pkg.vhd
vcom -93   ../../../src/6.TestBench/sim_pkg.vhd
vcom -93   ../../../src/1.Components/memory_file.vhd
vcom -93   ../../../src/1.Components/register_file.vhd
vcom -93   ../../../src/1.Components/incrementer.vhd
vcom -93   ../../../src/1.Components/sign_extend.vhd
vcom -93   ../../../src/1.Components/alu.vhd
vcom -93   ../../../src/1.Components/shifter.vhd
vcom -93   ../../../src/1.Components/forwarding_unit.vhd
vcom -93   ../../../src/1.Components/conditional_jump_decoder.vhd
vcom -93   ../../../src/1.Components/ccr_register.vhd
vcom -93   ../../../src/1.Components/stack_pointer.vhd
vcom -93   ../../../src/2.PIPELINE_REGISTERS/IF_ID.vhd
vcom -93   ../../../src/2.PIPELINE_REGISTERS/ID_EX1.vhd
vcom -93   ../../../src/2.PIPELINE_REGISTERS/EX1_EX2.vhd
vcom -93   ../../../src/2.PIPELINE_REGISTERS/EX2_MEM.vhd
vcom -93   ../../../src/2.PIPELINE_REGISTERS/MEM_WB.vhd
vcom -93   ../../../src/4.Controlling/Control_unit.vhd
vcom -93   ../../../src/4.Controlling/hazard_unit.vhd
vcom -93   ../../../src/4.Controlling/interrupt_unit.vhd
vcom -93   ../../../src/3.Stages/FETCH.vhd
vcom -93   ../../../src/3.Stages/DECODE.vhd
vcom -93   ../../../src/3.Stages/EX1.vhd
vcom -93   ../../../src/3.Stages/EX2.vhd
vcom -93   ../../../src/3.Stages/MEMORY.vhd
vcom -93   ../../../src/3.Stages/WB.vhd
vcom -93   ../../../src/5.TOP/top_level.vhd
vcom -2008 ../../../src/6.TestBench/top_level_tb.vhd
