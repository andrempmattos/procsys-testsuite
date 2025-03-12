set PROJECT   [lindex $argv 0]
set TOOL_NAME [lindex $argv 1]

open_project -file $PROJECT

update_and_run_tool -name $TOOL_NAME

save_project
