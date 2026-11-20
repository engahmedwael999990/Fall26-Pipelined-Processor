# run_Memory.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_Memory.do
do compile.do
vsim -t ns -voptargs=+acc work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/Memory.mem \
  -gIN_FILE=../../../assembler/Memory.in \
  -gIRQ_FILE="" \
  -gRES_FILE=result_Memory.txt -gDUMP_FILE=ram_Memory.mem
do wave.do
run -all
