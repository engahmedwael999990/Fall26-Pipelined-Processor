# run_test1_table.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_test1_table.do
do compile.do
vsim -t ns work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/test1_table.mem \
  -gIN_FILE=../../../assembler/test1_table.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_test1_table.txt -gDUMP_FILE=ram_test1_table.mem
do wave.do
run -all
