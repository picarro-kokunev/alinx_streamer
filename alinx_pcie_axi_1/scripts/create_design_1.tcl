# =============================================================================
# create_design_1.tcl
#
# Rebuild design_1 block design from scratch for alinx_pcie_axi_1, including
# the memory-backed c2h_streamer (control BRAM + pattern BRAM).
#
# Usage (from alinx_pcie_axi_1/):
#   vivado -mode batch -source scripts/create_design_1.tcl
#
# Address map (XDMA M_AXI_LITE / /dev/xdma0_user):
#   0x0000_0000  control BRAM  4 KiB  CTRL/LENGTH/STATUS/BEAT_CNT/SEQ_LEN/REPEAT
#   0x0000_1000  pattern BRAM  4 KiB  host-writable sequence data
# =============================================================================

set script_dir [file normalize [file dirname [info script]]]
set proj_dir   [file normalize $script_dir/..]
set rtl_dir    [file join $proj_dir alinx_pcie_axi_1.srcs sources_1 rtl]
set bd_src_dir [file join $proj_dir alinx_pcie_axi_1.srcs sources_1 bd design_1]
set bd_gen_dir [file join $proj_dir alinx_pcie_axi_1.gen sources_1 bd design_1]
set xpr_path   [file join $proj_dir alinx_pcie_axi_1.xpr]

puts "============================================================"
puts " create_design_1.tcl"
puts " Project: $xpr_path"
puts "============================================================"

if {![file exists $xpr_path]} {
    error "Project not found: $xpr_path"
}

open_project $xpr_path

# -----------------------------------------------------------------------------
# 1) RTL sources (module-ref needs these visible / compiled)
# -----------------------------------------------------------------------------
set rtl_files [glob -nocomplain [file join $rtl_dir *.v]]
if {[llength $rtl_files] == 0} {
    error "No RTL files found in $rtl_dir"
}
add_files -norecurse $rtl_files
set_property used_in_synthesis 1  [get_files $rtl_files]
set_property used_in_simulation 1 [get_files $rtl_files]
update_compile_order -fileset sources_1

# -----------------------------------------------------------------------------
# 2) Remove existing design_1 (project + disk) so we start clean
# -----------------------------------------------------------------------------
# Close open BD if any
foreach d [get_bd_designs -quiet] {
    puts "Closing BD: $d"
    catch {close_bd_design $d}
}

# Remove BD from project
set old_bd [get_files -quiet */design_1.bd]
if {$old_bd ne ""} {
    puts "Removing existing design_1.bd from project..."
    catch {export_ip_user_files -of_objects $old_bd -no_script -reset -force -quiet}
    remove_files -fileset sources_1 $old_bd
}

# Remove auto-generated wrapper if present in sources (gen wrapper recreated later)
set old_wrap [get_files -quiet */design_1_wrapper.v]
if {$old_wrap ne ""} {
    puts "Removing existing design_1_wrapper.v from project..."
    remove_files -fileset sources_1 $old_wrap
}

# Delete on-disk BD trees
foreach d [list $bd_src_dir $bd_gen_dir] {
    if {[file exists $d]} {
        puts "Deleting $d"
        file delete -force $d
    }
}

# Reset runs that would otherwise hold stale BD products
foreach r {synth_1 impl_1} {
    if {[get_runs -quiet $r] ne ""} {
        catch {reset_run $r}
    }
}

update_compile_order -fileset sources_1

# -----------------------------------------------------------------------------
# 3) Create empty BD
# -----------------------------------------------------------------------------
puts "Creating design_1..."
create_bd_design design_1
current_bd_design design_1

# =============================================================================
# External ports
# =============================================================================
# PCIe GT
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie_7x_mgt_rtl_0

# 100 MHz PCIe refclk
set pcie_clk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_clk]
set_property CONFIG.FREQ_HZ 100000000 $pcie_clk

create_bd_port -dir I -type rst sys_rst_n
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports sys_rst_n]

create_bd_port -dir O -from 0 -to 0 LED
create_bd_port -dir O -type rst user_resetn
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports user_resetn]
create_bd_port -dir O user_lnk_up

# =============================================================================
# IP / module cells
# =============================================================================
puts "Creating IP cells..."

# --- XDMA: AXI-Stream, Gen2 x2, 64-bit @ 125 MHz, AXI-Lite master ---
create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.2 xdma_0
set_property -dict [list \
    CONFIG.mode_selection              {Basic} \
    CONFIG.pcie_blk_locn               {X0Y0} \
    CONFIG.pl_link_cap_max_link_width  {X2} \
    CONFIG.pl_link_cap_max_link_speed  {5.0_GT/s} \
    CONFIG.ref_clk_freq                {100_MHz} \
    CONFIG.axi_data_width              {64_bit} \
    CONFIG.axisten_freq                {125} \
    CONFIG.xdma_axi_intf_mm            {AXI_Stream} \
    CONFIG.xdma_rnum_chnl              {1} \
    CONFIG.xdma_wnum_chnl              {1} \
    CONFIG.axilite_master_en           {true} \
    CONFIG.axilite_master_size         {1} \
    CONFIG.axilite_master_scale        {Megabytes} \
    CONFIG.pf0_device_id               {7022} \
    CONFIG.vendor_id                   {10EE} \
    CONFIG.xdma_num_usr_irq            {1} \
] [get_bd_cells xdma_0]

# --- Diff clock buffer for PCIe refclk ---
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf
set_property CONFIG.C_BUF_TYPE {IBUFDSGTE} [get_bd_cells util_ds_buf]

# --- AXI interconnect: 1 SI -> 2 MI (control BRAM + pattern BRAM) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_MI {2} \
] [get_bd_cells axi_interconnect_0]

# --- Control AXI BRAM controller (single-port; frees BRAM Port B for streamer) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_1
set_property CONFIG.SINGLE_PORT_BRAM {1} [get_bd_cells axi_bram_ctrl_1]

# --- Control BRAM: True Dual Port, 32-bit both ports ---
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_1
set_property -dict [list \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Enable_B {Use_ENB_Pin} \
    CONFIG.Use_RSTB_Pin {true} \
    CONFIG.Port_B_Clock {100} \
    CONFIG.Port_B_Write_Rate {50} \
    CONFIG.Port_B_Enable_Rate {100} \
] [get_bd_cells blk_mem_gen_1]

# --- Pattern AXI BRAM controller (host write port) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_2
set_property CONFIG.SINGLE_PORT_BRAM {1} [get_bd_cells axi_bram_ctrl_2]

# --- Pattern BRAM: Port A 32-bit (host), Port B 64-bit (streamer), 4 KiB ---
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_2
set_property -dict [list \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Write_Depth_A {1024} \
    CONFIG.Read_Width_A {32} \
    CONFIG.Enable_A {Use_ENA_Pin} \
    CONFIG.Enable_B {Use_ENB_Pin} \
    CONFIG.Use_Byte_Write_Enable {true} \
    CONFIG.Byte_Size {8} \
    CONFIG.Write_Width_B {64} \
    CONFIG.Read_Width_B {64} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {true} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {true} \
    CONFIG.Use_RSTB_Pin {true} \
    CONFIG.Port_B_Clock {100} \
    CONFIG.Port_B_Write_Rate {0} \
    CONFIG.Port_B_Enable_Rate {100} \
    CONFIG.Operating_Mode_A {WRITE_FIRST} \
    CONFIG.Operating_Mode_B {READ_FIRST} \
] [get_bd_cells blk_mem_gen_2]

# --- c2h_streamer (module reference) ---
puts "Creating c2h_streamer_0 module reference..."
create_bd_cell -type module -reference c2h_streamer c2h_streamer_0

# --- AXIS register slice between streamer and XDMA C2H ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_0
set_property -dict [list \
    CONFIG.TDATA_NUM_BYTES {8} \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.HAS_TLAST {1} \
] [get_bd_cells axis_register_slice_0]

# --- H2C discard sink ---
create_bd_cell -type module -reference h2c_axis_sink h2c_axis_sink_0

# --- Debug / status glue ---
create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_1
set_property -dict [list \
    CONFIG.C_MON_TYPE {MIX} \
    CONFIG.C_NUM_MONITOR_SLOTS {2} \
    CONFIG.C_NUM_OF_PROBES {3} \
    CONFIG.C_SLOT {1} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:aximm_rtl:1.0} \
    CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
    CONFIG.C_DATA_DEPTH {8192} \
    CONFIG.C_ADV_TRIGGER {true} \
] [get_bd_cells system_ila_1]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property -dict [list \
    CONFIG.NUM_PORTS {6} \
    CONFIG.IN0_WIDTH {32} \
    CONFIG.IN1_WIDTH {1} \
    CONFIG.IN2_WIDTH {1} \
    CONFIG.IN3_WIDTH {1} \
    CONFIG.IN4_WIDTH {4} \
    CONFIG.IN5_WIDTH {2} \
] [get_bd_cells xlconcat_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1
set_property -dict [list \
    CONFIG.CONST_WIDTH {1} \
    CONFIG.CONST_VAL {0} \
] [get_bd_cells xlconstant_1]

create_bd_cell -type ip -vlnv xilinx.com:ip:c_counter_binary:12.0 c_counter_binary_0
set_property CONFIG.Output_Width {26} [get_bd_cells c_counter_binary_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0
set_property -dict [list \
    CONFIG.DIN_WIDTH {26} \
    CONFIG.DIN_FROM {25} \
    CONFIG.DIN_TO {25} \
] [get_bd_cells xlslice_0]

# =============================================================================
# Interface connections
# =============================================================================
puts "Connecting interfaces..."

# PCIe
connect_bd_intf_net [get_bd_intf_ports pcie_7x_mgt_rtl_0] [get_bd_intf_pins xdma_0/pcie_mgt]
connect_bd_intf_net [get_bd_intf_ports pcie_clk]          [get_bd_intf_pins util_ds_buf/CLK_IN_D]

# AXI-Lite: XDMA -> interconnect -> BRAM controllers (+ ILA monitor)
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI_LITE] \
    [get_bd_intf_pins axi_interconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] \
    [get_bd_intf_pins axi_bram_ctrl_1/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] \
    [get_bd_intf_pins axi_bram_ctrl_2/S_AXI]

# Control BRAM: Port A = host, Port B = streamer regs
connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTA] \
    [get_bd_intf_pins blk_mem_gen_1/BRAM_PORTA]
connect_bd_intf_net [get_bd_intf_pins c2h_streamer_0/BRAM_PORTB] \
    [get_bd_intf_pins blk_mem_gen_1/BRAM_PORTB]

# Pattern BRAM: Port A = host, Port B = streamer data
connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_2/BRAM_PORTA] \
    [get_bd_intf_pins blk_mem_gen_2/BRAM_PORTA]
connect_bd_intf_net [get_bd_intf_pins c2h_streamer_0/PATTERN_BRAM] \
    [get_bd_intf_pins blk_mem_gen_2/BRAM_PORTB]

# AXI-Stream C2H path: streamer -> slice -> XDMA
connect_bd_intf_net [get_bd_intf_pins c2h_streamer_0/M_AXIS] \
    [get_bd_intf_pins axis_register_slice_0/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins axis_register_slice_0/M_AXIS] \
    [get_bd_intf_pins xdma_0/S_AXIS_C2H_0]

# H2C discard
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXIS_H2C_0] \
    [get_bd_intf_pins h2c_axis_sink_0/S_AXIS]

# ILA monitors
connect_bd_intf_net [get_bd_intf_pins system_ila_1/SLOT_0_AXI] \
    [get_bd_intf_pins xdma_0/M_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins system_ila_1/SLOT_1_AXIS] \
    [get_bd_intf_pins axis_register_slice_0/M_AXIS]

# =============================================================================
# Scalar nets (clock / reset / debug / status)
# =============================================================================
puts "Connecting clocks, resets, and debug..."

connect_bd_net [get_bd_ports sys_rst_n]          [get_bd_pins xdma_0/sys_rst_n]
connect_bd_net [get_bd_pins util_ds_buf/IBUF_OUT] [get_bd_pins xdma_0/sys_clk]

# axi_aclk fanout
connect_bd_net [get_bd_pins xdma_0/axi_aclk] \
    [get_bd_pins axi_interconnect_0/ACLK] \
    [get_bd_pins axi_interconnect_0/S00_ACLK] \
    [get_bd_pins axi_interconnect_0/M00_ACLK] \
    [get_bd_pins axi_interconnect_0/M01_ACLK] \
    [get_bd_pins axi_bram_ctrl_1/s_axi_aclk] \
    [get_bd_pins axi_bram_ctrl_2/s_axi_aclk] \
    [get_bd_pins c2h_streamer_0/aclk] \
    [get_bd_pins h2c_axis_sink_0/aclk] \
    [get_bd_pins axis_register_slice_0/aclk] \
    [get_bd_pins system_ila_1/clk] \
    [get_bd_pins c_counter_binary_0/CLK]

# axi_aresetn fanout
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] \
    [get_bd_pins axi_interconnect_0/ARESETN] \
    [get_bd_pins axi_interconnect_0/S00_ARESETN] \
    [get_bd_pins axi_interconnect_0/M00_ARESETN] \
    [get_bd_pins axi_interconnect_0/M01_ARESETN] \
    [get_bd_pins axi_bram_ctrl_1/s_axi_aresetn] \
    [get_bd_pins axi_bram_ctrl_2/s_axi_aresetn] \
    [get_bd_pins c2h_streamer_0/aresetn] \
    [get_bd_pins h2c_axis_sink_0/aresetn] \
    [get_bd_pins axis_register_slice_0/aresetn] \
    [get_bd_pins system_ila_1/resetn] \
    [get_bd_ports user_resetn]

connect_bd_net [get_bd_pins xdma_0/user_lnk_up] [get_bd_ports user_lnk_up]
connect_bd_net [get_bd_pins xlconstant_1/dout] [get_bd_pins xdma_0/usr_irq_req]

# LED blink from free-running counter
connect_bd_net [get_bd_pins c_counter_binary_0/Q] [get_bd_pins xlslice_0/Din]
connect_bd_net [get_bd_pins xlslice_0/Dout]       [get_bd_ports LED]

# Debug concat -> ILA probe0; length/seed -> probe1/probe2
connect_bd_net [get_bd_pins c2h_streamer_0/dbg_beat_count]   [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins c2h_streamer_0/dbg_start]        [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins c2h_streamer_0/dbg_busy]         [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins c2h_streamer_0/dbg_done]         [get_bd_pins xlconcat_0/In3]
connect_bd_net [get_bd_pins c2h_streamer_0/dbg_ctrl_state]   [get_bd_pins xlconcat_0/In4]
connect_bd_net [get_bd_pins c2h_streamer_0/dbg_src_state]    [get_bd_pins xlconcat_0/In5]
connect_bd_net [get_bd_pins xlconcat_0/dout]                 [get_bd_pins system_ila_1/probe0]
connect_bd_net [get_bd_pins c2h_streamer_0/dbg_length_bytes] [get_bd_pins system_ila_1/probe1]
connect_bd_net [get_bd_pins c2h_streamer_0/dbg_seed]         [get_bd_pins system_ila_1/probe2]

# =============================================================================
# Address map
# =============================================================================
puts "Assigning addresses..."
assign_bd_address -offset 0x00000000 -range 4K \
    -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] \
    [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0]

assign_bd_address -offset 0x00001000 -range 4K \
    -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] \
    [get_bd_addr_segs axi_bram_ctrl_2/S_AXI/Mem0]

# =============================================================================
# Validate / save / wrapper
# =============================================================================
puts "Validating BD..."
regenerate_bd_layout
validate_bd_design
save_bd_design

puts "Generating BD output products..."
generate_target all [get_files [file join $bd_src_dir design_1.bd]]
catch {export_ip_user_files -of_objects [get_files [file join $bd_src_dir design_1.bd]] -no_script -sync -force -quiet}

puts "Creating HDL wrapper..."
set wrap_result [make_wrapper -files [get_files [file join $bd_src_dir design_1.bd]] -top]
# make_wrapper returns path(s); add and set top
set wrap_file [lindex [get_files -quiet */design_1_wrapper.v] 0]
if {$wrap_file eq ""} {
    # Newly generated under .gen
    set wrap_candidates [glob -nocomplain \
        [file join $bd_gen_dir hdl design_1_wrapper.v] \
        [file join $bd_src_dir hdl design_1_wrapper.v]]
    if {[llength $wrap_candidates] == 0} {
        error "design_1_wrapper.v was not created (make_wrapper returned: $wrap_result)"
    }
    add_files -norecurse [lindex $wrap_candidates 0]
    set wrap_file [lindex $wrap_candidates 0]
}
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "============================================================"
puts " design_1 created successfully."
puts "   Control BRAM @ 0x0000 (4 KiB)"
puts "   Pattern BRAM @ 0x1000 (4 KiB)"
puts "   Top: design_1_wrapper"
puts " Next: run synthesis / implementation."
puts "============================================================"
