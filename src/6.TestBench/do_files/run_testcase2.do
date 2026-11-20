# run_testcase2.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_testcase2.do
do compile.do
vsim -t ns work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/testcase2.mem \
  -gIN_FILE=../../../assembler/testcase2.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_testcase2.txt -gDUMP_FILE=ram_testcase2.mem
do wave.do
run -all
