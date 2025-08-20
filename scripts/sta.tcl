# scripts/sta.tcl
# -------- Static Timing Analysis for systolic_array --------

set design  "systolic_array"
set netlist "build/systolic_array_synth.v"
set sdc     "constr/top.sdc"
set lib_tt  $::env(LIB_TT)
# --- Load technology and cell LEFs (Sky130 HD)
read_lef /home/skanda/.volare/volare/sky130/versions/bdc9412b3e468c102d01b7cf6337be06ec6e9c9a/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef

# --- Safety checks (use quotes instead of [ERROR])
if {![file exists $netlist]} { puts stderr "ERROR: Netlist not found: $netlist"; exit 1 }
if {![file exists $sdc]}     { puts stderr "ERROR: SDC not found: $sdc";       exit 1 }
if {![file exists $lib_tt]}  { puts stderr "ERROR: Liberty not found: $lib_tt"; exit 1 }

# Ensure output dir exists
file mkdir build
file mkdir build/reports

# --- Load timing library & design
read_liberty $lib_tt
read_verilog $netlist
link_design $design

# --- Constraints
read_sdc $sdc


# --- Setup/hold reports
report_worst_slack
report_tns

report_checks -path_delay max -fields {slew cap input_pins nets} -digits 3 > build/reports/sta_max.rpt
report_checks -path_delay min -fields {slew cap input_pins nets} -digits 3 > build/reports/sta_min.rpt

report_checks -path_delay max -summary > build/reports/sta_summary_max.rpt
report_checks -path_delay min -summary > build/reports/sta_summary_min.rpt
