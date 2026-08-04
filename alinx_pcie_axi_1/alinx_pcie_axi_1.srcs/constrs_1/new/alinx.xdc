##############################################################################
set_property PACKAGE_PIN L16 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PULLTYPE PULLUP [get_ports sys_rst_n]

#############SPI Configurate Setting##################
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

############# LEDs ##################
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} [get_ports {LED[0]}]
#set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports {LED[1]}]
#set_property -dict { PACKAGE_PIN K14 IOSTANDARD LVCMOS33 } [get_ports {LED[2]}]
#set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports {LED[3]}]
###############################################################################
set_property -dict { PACKAGE_PIN K14 IOSTANDARD LVCMOS33 } [get_ports {user_resetn}]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports {user_lnk_up}]

set_false_path -from [get_ports sys_rst_n]
###############################################################################
set_property -dict {PACKAGE_PIN F10} [get_ports pcie_clk_clk_p]
create_clock -period 10.000 -name pcie_clk [get_ports pcie_clk_clk_p]


set_property IOSTANDARD LVCMOS33 [get_ports user_resetn]
