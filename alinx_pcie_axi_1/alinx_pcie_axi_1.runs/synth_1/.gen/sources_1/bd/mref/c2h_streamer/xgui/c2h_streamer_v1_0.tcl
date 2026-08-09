# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ARM_ON_C2H" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DEFAULT_LEN_BYTES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "EXPORT_DEBUG" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TDATA_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.ARM_ON_C2H { PARAM_VALUE.ARM_ON_C2H } {
	# Procedure called to update ARM_ON_C2H when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ARM_ON_C2H { PARAM_VALUE.ARM_ON_C2H } {
	# Procedure called to validate ARM_ON_C2H
	return true
}

proc update_PARAM_VALUE.DEFAULT_LEN_BYTES { PARAM_VALUE.DEFAULT_LEN_BYTES } {
	# Procedure called to update DEFAULT_LEN_BYTES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEFAULT_LEN_BYTES { PARAM_VALUE.DEFAULT_LEN_BYTES } {
	# Procedure called to validate DEFAULT_LEN_BYTES
	return true
}

proc update_PARAM_VALUE.EXPORT_DEBUG { PARAM_VALUE.EXPORT_DEBUG } {
	# Procedure called to update EXPORT_DEBUG when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.EXPORT_DEBUG { PARAM_VALUE.EXPORT_DEBUG } {
	# Procedure called to validate EXPORT_DEBUG
	return true
}

proc update_PARAM_VALUE.TDATA_WIDTH { PARAM_VALUE.TDATA_WIDTH } {
	# Procedure called to update TDATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TDATA_WIDTH { PARAM_VALUE.TDATA_WIDTH } {
	# Procedure called to validate TDATA_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.TDATA_WIDTH { MODELPARAM_VALUE.TDATA_WIDTH PARAM_VALUE.TDATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TDATA_WIDTH}] ${MODELPARAM_VALUE.TDATA_WIDTH}
}

proc update_MODELPARAM_VALUE.DEFAULT_LEN_BYTES { MODELPARAM_VALUE.DEFAULT_LEN_BYTES PARAM_VALUE.DEFAULT_LEN_BYTES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEFAULT_LEN_BYTES}] ${MODELPARAM_VALUE.DEFAULT_LEN_BYTES}
}

proc update_MODELPARAM_VALUE.ARM_ON_C2H { MODELPARAM_VALUE.ARM_ON_C2H PARAM_VALUE.ARM_ON_C2H } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ARM_ON_C2H}] ${MODELPARAM_VALUE.ARM_ON_C2H}
}

proc update_MODELPARAM_VALUE.EXPORT_DEBUG { MODELPARAM_VALUE.EXPORT_DEBUG PARAM_VALUE.EXPORT_DEBUG } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.EXPORT_DEBUG}] ${MODELPARAM_VALUE.EXPORT_DEBUG}
}

