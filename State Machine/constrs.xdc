
####################################################################################
# Generated by Vivado 2024.1 built on 'Wed May 22 18:36:09 MDT 2024' by 'xbuild'
# Command Used: write_xdc -force /uio/hume/student-u50/filipmar/Documents/in3160_obliger/assignments-main/O08/constrs.xdc
####################################################################################


####################################################################################
# Constraints from file : 'constraints.xdc'
####################################################################################

set_property IOSTANDARD LVCMOS33 [get_ports c]
set_property IOSTANDARD LVCMOS33 [get_ports dir_out]
set_property IOSTANDARD LVCMOS33 [get_ports en_out]
set_property IOSTANDARD LVCMOS33 [get_ports mclk]
set_property IOSTANDARD LVCMOS33 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports sa]
set_property IOSTANDARD LVCMOS33 [get_ports sb]
set_property IOSTANDARD LVCMOS33 [get_ports {abcdefg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {abcdefg[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {abcdefg[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {abcdefg[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {abcdefg[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {abcdefg[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {abcdefg[0]}]
set_property PACKAGE_PIN AA4 [get_ports {abcdefg[3]}]
set_property PACKAGE_PIN V4 [get_ports c]
set_property PACKAGE_PIN W12 [get_ports dir_out]
set_property PACKAGE_PIN W11 [get_ports en_out]
set_property PACKAGE_PIN Y9 [get_ports mclk]
set_property PACKAGE_PIN R18 [get_ports reset]
set_property PACKAGE_PIN V10 [get_ports sa]
set_property PACKAGE_PIN W8 [get_ports sb]

create_clock -period 10.000 -name clock -waveform {0.000 5.000} [get_ports mclk]

set_property PACKAGE_PIN Y4 [get_ports {abcdefg[4]}]
set_property PACKAGE_PIN AB6 [get_ports {abcdefg[5]}]
set_property PACKAGE_PIN AB7 [get_ports {abcdefg[6]}]
set_property PACKAGE_PIN V7 [get_ports {abcdefg[2]}]
set_property PACKAGE_PIN W7 [get_ports {abcdefg[1]}]
set_property PACKAGE_PIN V5 [get_ports {abcdefg[0]}]

# Vivado Generated miscellaneous constraints 

#revert back to original instance
current_instance -quiet
