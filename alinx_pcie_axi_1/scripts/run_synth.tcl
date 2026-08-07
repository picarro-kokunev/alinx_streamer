open_project alinx_pcie_axi_1.xpr
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
puts "Synthesis status: [get_property STATUS [get_runs synth_1]]"
