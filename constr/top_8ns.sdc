# Same as top.sdc but with a tighter clock
create_clock -name core_clk -period 8.000 [get_ports clk]
set_clock_uncertainty 0.10  [get_clocks core_clk]
set_clock_transition  0.10  [get_clocks core_clk]

set_false_path -from [get_ports rst] -to [all_registers]
set_false_path -from [get_ports rst] -to [all_outputs]

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay  0.20 -clock core_clk [remove_from_collection [all_inputs] [get_ports clk]]
set_input_transition 0.10 [remove_from_collection [all_inputs] [get_ports clk]]

set_load 0.010 [all_outputs]
set_output_delay 0.20 -clock core_clk [all_outputs]

group_path -name IN_TO_REG  -from [all_inputs]   -to [all_registers]
group_path -name REG_TO_OUT -from [all_registers] -to [all_outputs]
group_path -name REG_TO_REG -from [all_registers] -to [all_registers]
