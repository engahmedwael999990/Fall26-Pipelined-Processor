# run_testcase1.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_testcase1.do
do compile.do
vsim -t ns -voptargs=+acc work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/testcase1.mem \
  -gIN_FILE=../../../assembler/testcase1.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_testcase1.txt -gDUMP_FILE=ram_testcase1.mem
do wave.do
run -all
