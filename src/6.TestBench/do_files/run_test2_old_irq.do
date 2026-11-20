# run_test2_old_irq.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_test2_old_irq.do
do compile.do
vsim -t ns work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/test2_old.mem \
  -gIN_FILE=../../../assembler/test2_old.in \
  -gIRQ_FILE=irq.txt \
  -gRES_FILE=result_test2_old_irq.txt -gDUMP_FILE=ram_test2_old_irq.mem
do wave.do
run -all
