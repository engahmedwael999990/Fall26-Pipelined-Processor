# run_test2.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_test2.do
do compile.do
vsim -t ns work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/test2.mem \
  -gIN_FILE=../../../assembler/test2.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_test2.txt -gDUMP_FILE=ram_test2.mem
do wave.do
run -all
