# Programs the FPGA

set PROJECT [lindex $argv 0]
if { $::argc > 2 } {
    set PROGRAMMER_ID [lindex $argv 1]
} else {
    set PROGRAMMER_ID ""
}

open_project -file $PROJECT

if { $PROGRAMMER_ID ne "" } {
    select_programmer -programmer_id $PROGRAMMER_ID
}

update_and_run_tool -name {PROGRAMDEVICE}
