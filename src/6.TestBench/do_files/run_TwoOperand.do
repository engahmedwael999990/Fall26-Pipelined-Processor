# run_TwoOperand.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_TwoOperand.do
do compile.do
vsim -t ns work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/TwoOperand.mem \
  -gIN_FILE=../../../assembler/TwoOperand.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_TwoOperand.txt -gDUMP_FILE=ram_TwoOperand.mem
do wave.do
run -all
