# run_Branch.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_Branch.do
do compile.do
vsim -t ns -voptargs=+acc work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/Branch.mem \
  -gIN_FILE=../../../assembler/Branch.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_Branch.txt -gDUMP_FILE=ram_Branch.mem
do wave.do
run -all
