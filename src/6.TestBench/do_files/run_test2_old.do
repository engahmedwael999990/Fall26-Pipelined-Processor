# run_test2_old.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_test2_old.do
do compile.do
vsim -t ns work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/test2_old.mem \
  -gIN_FILE=../../../assembler/test2_old.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_test2_old.txt -gDUMP_FILE=ram_test2_old.mem
do wave.do
run -all
