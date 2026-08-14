# DEPRECATED: incremental patch failed on locked/stale BD IPs.
# Use the from-scratch builder instead:
#
#   vivado -mode batch -source scripts/create_design_1.tcl
#
source [file join [file dirname [info script]] create_design_1.tcl]
