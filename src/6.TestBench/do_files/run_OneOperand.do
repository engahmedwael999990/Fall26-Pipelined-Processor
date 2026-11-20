# run_OneOperand.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_OneOperand.do
do compile.do
vsim -t ns -voptargs=+acc work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/OneOperand.mem \
  -gIN_FILE=../../../assembler/OneOperand.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_OneOperand.txt -gDUMP_FILE=ram_OneOperand.mem
do wave.do
run -all
