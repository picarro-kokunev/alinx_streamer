set proj_dir [file normalize [file dirname [info script]]/..]
cd $proj_dir
open_project alinx_pcie_axi_1.xpr
open_bd_design [get_files design_1.bd]

puts "=== validate_bd_design ==="
validate_bd_design
puts "RESULT: VALIDATION PASSED"

foreach pin {BRAM_PORTB M_AXIS} {
    set p [get_bd_intf_pins -quiet samples_generator_0/$pin]
    if {$p eq ""} {
        puts "MISSING: samples_generator_0/$pin"
    } else {
        set net [get_bd_intf_nets -quiet -of_objects $p]
        puts "samples_generator_0/$pin connected via: $net"
    }
}

save_bd_design
close_project
