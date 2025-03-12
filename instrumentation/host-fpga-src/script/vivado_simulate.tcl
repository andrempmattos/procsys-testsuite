set BASE_DIR [lindex $argv 0]
set WORK_DIR [lindex $argv 1]
if {$argc == 4} {
    set DUMP_ALL [lindex $argv 3]
} else {
    set DUMP_ALL 0
}

set WORK_DIR "$WORK_DIR"

# create project
create_project -force sim-project $WORK_DIR/xilinx -part xc7z020clg484-1

# add all files from HDL folders
add_files $BASE_DIR/hdl/

# add simulation files
add_files -fileset sim_1 $BASE_DIR/sim/

# set VHDL 2008 to all files
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

# update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# set top entity as top
set_property top top [current_fileset]
# set testbench entity as top
set_property top top_tb [get_filesets sim_1]

# set simulation parameters
set_property generic "WORK_DIR=$WORK_DIR" [get_filesets sim_1]

# set maximum simulation time
set_property -name {xsim.simulate.runtime} -value {60s} -objects [get_filesets sim_1]

# configure dump to wdb file for all signals
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

# start simulation
launch_simulation

exit
