# Re-integrate samples_generator_0 with proper BRAM_PORTB bus interface.
#
# Root cause of disconnected bram_portb_* pins:
#   Vivado inferred the module without a grouped BRAM_PORTB interface, leaving
#   individual ports that cannot connect to blk_mem_gen_1/BRAM_PORTB.
#
# Fix: X_INTERFACE attributes in samples_generator.v + delete/recreate BD cell.
#
# Usage (from alinx_pcie_axi_1/):
#   vivado -mode batch -source scripts/add_samples_generator.tcl

set proj_dir [file normalize [file dirname [info script]]/..]
cd $proj_dir

set rtl_file [file normalize $proj_dir/alinx_pcie_axi_1.srcs/sources_1/new/samples_generator.v]

open_project alinx_pcie_axi_1.xpr

set rtl [get_files -quiet [file tail $rtl_file]]
if {$rtl eq ""} {
    add_files -norecurse $rtl_file
}
set_property used_in_synthesis true [get_files $rtl_file]
set_property used_in_simulation true [get_files $rtl_file]
update_compile_order -fileset sources_1

# Force re-inference from RTL (delete stale per-pin component.xml if needed)
set mref_xml [file normalize $proj_dir/alinx_pcie_axi_1.gen/sources_1/bd/mref/samples_generator/component.xml]
if {[file exists $mref_xml]} {
  file delete -force $mref_xml
}

open_bd_design [get_files design_1.bd]

# Remove broken instance (discrete bram_portb_* ports, no BRAM_PORTB bus)
set sg [get_bd_cells -quiet samples_generator_0]
if {$sg ne ""} {
  delete_bd_objs $sg
}

# Remove stale H2C_1 loopback if present
set loop_net [get_bd_intf_nets -quiet xdma_0_M_AXIS_H2C_1]
if {$loop_net ne ""} {
  delete_bd_objs $loop_net
}

# Re-create from RTL (picks up X_INTERFACE attributes -> BRAM_PORTB + M_AXIS)
create_bd_cell -type module -reference samples_generator samples_generator_0

# Verify grouped interfaces exist
if {[get_bd_intf_pins -quiet samples_generator_0/BRAM_PORTB] eq ""} {
  error "samples_generator_0/BRAM_PORTB not found. Check X_INTERFACE attributes in samples_generator.v"
}
if {[get_bd_intf_pins -quiet samples_generator_0/M_AXIS] eq ""} {
  error "samples_generator_0/M_AXIS not found. Check X_INTERFACE attributes in samples_generator.v"
}

# BRAM port B: samples_generator (master) -> blk_mem_gen (slave)
set bram_net [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins blk_mem_gen_1/BRAM_PORTB]]
if {$bram_net ne ""} {
  delete_bd_objs $bram_net
}
connect_bd_intf_net \
  [get_bd_intf_pins samples_generator_0/BRAM_PORTB] \
  [get_bd_intf_pins blk_mem_gen_1/BRAM_PORTB]

# AXI-Stream: samples_generator -> XDMA C2H channel 1
set axis_net [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins xdma_0/S_AXIS_C2H_1]]
if {$axis_net ne ""} {
  delete_bd_objs $axis_net
}
connect_bd_intf_net \
  [get_bd_intf_pins samples_generator_0/M_AXIS] \
  [get_bd_intf_pins xdma_0/S_AXIS_C2H_1]

# Clock / reset
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins samples_generator_0/aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins samples_generator_0/aresetn]

validate_bd_design
save_bd_design

set bd_file [get_files design_1.bd]
generate_target all $bd_file
export_ip_user_files -of_objects $bd_file -no_script -sync -force -quiet

save_project
close_project

puts "OK: samples_generator_0 connected (BRAM_PORTB + M_AXIS)"
