# run_testcase2_irq.do  --  in ModelSim, cd to src/6.TestBench/do_files, then:  do run_testcase2_irq.do
do compile.do
vsim -t ns work.top_level_tb \
  -gPROG_FILE=../../../assembler/out/testcase2_irq.mem \
  -gIN_FILE=../../../assembler/testcase2_irq.in \
  -gIRQ_FILE=irq.txt \
  -gRES_FILE=result_testcase2_irq.txt -gDUMP_FILE=ram_testcase2_irq.mem
do wave.do
run -all
