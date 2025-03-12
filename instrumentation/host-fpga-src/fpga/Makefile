LIBERO_BIN   = libero

BASE_DIR = $(abspath ../)

PROJECT_NAME = smf2000
PROJECT_DIR  = $(abspath libero/)
LIBERO_PRJX  = $(PROJECT_DIR)/$(PROJECT_NAME).prjx

CREATE_PROJECT    = script/libero_create_project.tcl
LIBERO_RUN        = script/libero_run.tcl
LIBERO_EXPORT_JOB = script/libero_export_job.tcl
PROGRAM_FPGA      = script/libero_program_fpga.tcl
PROGRAMMER        = 

FP_JOB_DEVICE = fpga-device
FP_JOB_FABRIC = fpga-fabric
FP_JOB_ENVM   = fpga-envm

clean:
ifeq ($(OS),Windows_NT)
	if exist "$(PROJECT_DIR)" rd /s /q "$(PROJECT_DIR)"
else
ifndef SKIP_CLEAN_CHECK
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
endif
	-rm -rf $(PROJECT_DIR)
	-rm -rf transcript
endif

project: clean
	$(LIBERO_BIN) script:$(CREATE_PROJECT) "script_args:$(BASE_DIR) $(PROJECT_DIR) $(PROJECT_NAME)" console_mode:brief

bitstream:
	$(LIBERO_BIN) script:$(LIBERO_RUN) "script_args:$(LIBERO_PRJX) GENERATEPROGRAMMINGFILE" console_mode:brief

fpga:
	$(LIBERO_BIN) script:$(PROGRAM_FPGA) "script_args:$(LIBERO_PRJX) $(PROGRAMMER)" console_mode:brief

export-jobs:
	$(LIBERO_BIN) script:$(LIBERO_EXPORT_JOB) script_args:"$(LIBERO_PRJX) $(OUT_DIR) $(FP_JOB_DEVICE) FABRIC ENVM" console_mode:brief
	$(LIBERO_BIN) script:$(LIBERO_EXPORT_JOB) script_args:"$(LIBERO_PRJX) $(OUT_DIR) $(FP_JOB_FABRIC) FABRIC"      console_mode:brief
	$(LIBERO_BIN) script:$(LIBERO_EXPORT_JOB) script_args:"$(LIBERO_PRJX) $(OUT_DIR) $(FP_JOB_ENVM)   ENVM"        console_mode:brief
