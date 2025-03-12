set PROJECT    [lindex $argv 0]
set OUT_DIR    [lindex $argv 1]
set OUT_JOB    [lindex $argv 2]
set COMPONENTS [expr { ($argc == 5) ? "[lindex $argv 3] [lindex $argv 4]" : "[lindex $argv 3]" }]

open_project -file $PROJECT

export_prog_job \
    -export_dir $OUT_DIR \
    -job_file_name $OUT_JOB \
    -bitstream_file_type {TRUSTED_FACILITY} \
    -bitstream_file_components $COMPONENTS \
    -design_bitstream_format PPD
