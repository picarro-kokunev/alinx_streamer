# Add c2h_streamer (pattern source + BRAM control) to design_1 block design.
#
# Usage:
#   vivado -mode batch -source scripts/add_c2h_streamer.tcl
#
# Or from Vivado Tcl console:
#   source scripts/add_c2h_streamer.tcl

set script_dir [file normalize [file dirname [info script]]]
set proj_dir   [file normalize $script_dir/..]
set rtl_dir    [file join $proj_dir alinx_pcie_axi_1.srcs sources_1 rtl]
set bd_path    [file join $proj_dir alinx_pcie_axi_1.srcs sources_1 bd design_1 design_1.bd]

puts "Project dir: $proj_dir"
puts "BD path:     $bd_path"

open_project [file join $proj_dir alinx_pcie_axi_1.xpr]

# Add RTL sources
set rtl_files [glob -nocomplain [file join $rtl_dir *.v]]
if {[llength $rtl_files] == 0} {
    error "No RTL files found in $rtl_dir"
}
add_files -norecurse $rtl_files
set_property used_in_synthesis 1 [get_files $rtl_files]
set_property used_in_simulation 1 [get_files $rtl_files]
update_compile_order -fileset sources_1

open_bd_design $bd_path

# --- Remove H2C→C2H loopback nets (if present) ---
foreach pair {
    {xdma_0/M_AXIS_H2C_0 xdma_0/S_AXIS_C2H_0}
    {xdma_0/M_AXIS_H2C_1 xdma_0/S_AXIS_C2H_1}
} {
    lassign $pair h2c c2h
    set intf_net [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins $h2c]]
    if {$intf_net ne ""} {
        puts "Deleting loopback net: $intf_net"
        delete_bd_objs $intf_net
    }
}

# --- Switch BRAM controller to single-port (free port B for streamer) ---
set bram_ctrl [get_bd_cells axi_bram_ctrl_1]
if {$bram_ctrl ne ""} {
    catch {upgrade_ip [get_ips design_1_axi_bram_ctrl_1_0]}
    set_property -dict [list CONFIG.SINGLE_PORT_BRAM {1}] $bram_ctrl
}

# Disconnect axi_bram_ctrl BRAM_PORTB if connected
set portb_net [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTB]]
if {$portb_net ne ""} {
    puts "Disconnecting axi_bram_ctrl_1/BRAM_PORTB"
    delete_bd_objs $portb_net
}

# --- Add module cells (skip if already present) ---
if {[get_bd_cells -quiet c2h_streamer_0] eq ""} {
    create_bd_cell -type module -reference c2h_streamer c2h_streamer_0
}
# Explicit CTRL start only (matches host mem/pattern: C2H open, then arm).
set_property -dict [list CONFIG.ARM_ON_C2H {0}] [get_bd_cells c2h_streamer_0]
if {[get_bd_cells -quiet h2c_axis_sink_0] eq ""} {
    create_bd_cell -type module -reference h2c_axis_sink h2c_axis_sink_0
}
if {[get_bd_cells -quiet h2c_axis_sink_1] eq ""} {
    create_bd_cell -type module -reference h2c_axis_sink h2c_axis_sink_1
}

# --- AXI-Stream: c2h_streamer → XDMA C2H channel 0 ---
if {[get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins c2h_streamer_0/M_AXIS]] eq ""} {
    connect_bd_intf_net [get_bd_intf_pins c2h_streamer_0/M_AXIS] [get_bd_intf_pins xdma_0/S_AXIS_C2H_0]
}

# --- H2C discard sinks ---
if {[get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins h2c_axis_sink_0/S_AXIS]] eq ""} {
    connect_bd_intf_net [get_bd_intf_pins h2c_axis_sink_0/S_AXIS] [get_bd_intf_pins xdma_0/M_AXIS_H2C_0]
}
if {[get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins h2c_axis_sink_1/S_AXIS]] eq ""} {
    connect_bd_intf_net [get_bd_intf_pins h2c_axis_sink_1/S_AXIS] [get_bd_intf_pins xdma_0/M_AXIS_H2C_1]
}

# --- BRAM port B: streamer ↔ blk_mem_gen ---
if {[get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins c2h_streamer_0/BRAM_PORTB]] eq ""} {
    connect_bd_intf_net [get_bd_intf_pins c2h_streamer_0/BRAM_PORTB] [get_bd_intf_pins blk_mem_gen_1/BRAM_PORTB]
}

# --- Clock / reset ---
connect_bd_net -quiet [get_bd_pins xdma_0/axi_aclk] [get_bd_pins c2h_streamer_0/aclk] \
    [get_bd_pins h2c_axis_sink_0/aclk] [get_bd_pins h2c_axis_sink_1/aclk]
connect_bd_net -quiet [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins c2h_streamer_0/aresetn] \
    [get_bd_pins h2c_axis_sink_0/aresetn] [get_bd_pins h2c_axis_sink_1/aresetn]

regenerate_bd_layout
validate_bd_design
save_bd_design

puts "Done. Re-run synthesis and implementation to build the updated bitstream."
