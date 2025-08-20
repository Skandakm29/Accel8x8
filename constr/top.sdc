# ===== SDC for systolic_array (Sky130) =====

# ---- Clock ----
create_clock -name core_clk -period 10.000 [get_ports clk]

# Optional clock quality margins
set_clock_uncertainty 0.10 [get_clocks core_clk]
set_clock_transition 0.10 [get_clocks core_clk]

# ---- Asynchronous reset ----
set_false_path -from [get_ports rst] -to [all_registers]
set_false_path -from [get_ports rst] -to [all_outputs]

# ---- Input interface modeling ----
set_input_delay 0.20 -clock core_clk [remove_from_collection [all_inputs] [get_ports clk]]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [remove_from_collection [all_inputs] [get_ports clk]]
set_input_transition 0.10 [remove_from_collection [all_inputs] [get_ports clk]]

# ---- Output interface modeling ----
set_load 0.010 [all_outputs]
set_output_delay 0.20 -clock core_clk [all_outputs]

# ---- Path groups ----
group_path -name IN_TO_REG  -from [all_inputs]    -to [all_registers]
group_path -name REG_TO_OUT -from [all_registers] -to [all_outputs]
group_path -name REG_TO_REG -from [all_registers] -to [all_registers]
