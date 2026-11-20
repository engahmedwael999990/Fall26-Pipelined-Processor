# run_test1.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_test1.do
do compile.do
vsim -t ns work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/test1.mem \
  -gIN_FILE=../../../assembler/test1.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_test1.txt -gDUMP_FILE=ram_test1.mem
do wave.do
run -all
