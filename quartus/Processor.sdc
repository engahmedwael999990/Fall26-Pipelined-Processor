# Processor.sdc
# The handout gives no frequency. 50 MHz (DE1-SoC CLOCK_50) is an ASSUMPTION.
# Read Fmax and setup/hold slack from TimeQuest. No false/multicycle paths.
# The register file writes on the falling edge; TimeQuest analyses those
# half-cycle paths automatically from this one clock.
create_clock -name clk -period 20.000 [get_ports {clk}]
derive_clock_uncertainty

# I/O: assume the external side (testbench / board logic) is clocked by the
# same clk with zero board delay. This constrains every I/O path so none is
# left unconstrained.
set_input_delay  -clock clk 0 [get_ports {rst intr_in in_port[*]}]
set_output_delay -clock clk 0 [get_ports {out_port[*]}]
