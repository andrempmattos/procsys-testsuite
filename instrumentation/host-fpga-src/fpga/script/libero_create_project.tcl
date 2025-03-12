# Creates Libero project
puts $argv

set BASE_DIR     [lindex $argv 0]
set PROJECT_DIR  [lindex $argv 1]
set PROJECT_NAME [lindex $argv 2]

new_project \
    -location $PROJECT_DIR \
    -name smf2000 \
    -project_description {Project for Trenz SMF2000 board} \
    -block_mode 0 \
    -standalone_peripheral_initialization 0 \
    -instantiate_in_smartdesign 0 \
    -ondemand_build_dh 1 \
    -use_relative_path 0 \
    -linked_files_root_dir_env {} \
    -hdl {VHDL} \
    -family {SmartFusion2} \
    -die {M2S010} \
    -package {400 VF} \
    -speed {STD} \
    -die_voltage {1.2} \
    -part_range {COM} \
    -adv_options {DSW_VCCA_VOLTAGE_RAMP_RATE:100_MS} \
    -adv_options {IO_DEFT_STD:LVCMOS 3.3V} \
    -adv_options {PLL_SUPPLY:PLL_SUPPLY_33} \
    -adv_options {RESTRICTPROBEPINS:0} \
    -adv_options {RESTRICTSPIPINS:0} \
    -adv_options {SYSTEM_CONTROLLER_SUSPEND_MODE:0} \
    -adv_options {TEMPR:COM} \
    -adv_options {VCCI_1.2_VOLTR:COM} \
    -adv_options {VCCI_1.5_VOLTR:COM} \
    -adv_options {VCCI_1.8_VOLTR:COM} \
    -adv_options {VCCI_2.5_VOLTR:COM} \
    -adv_options {VCCI_3.3_VOLTR:COM} \
    -adv_options {VOLTR:COM}

project_settings -vhdl_mode {VHDL_2008}

########################################
############## HDL SOURCES #############
########################################
## Project HDL files
create_links \
    -convert_EDN_to_HDL 0 \
    -library {work} \
    -hdl_source_folder $BASE_DIR/hdl/


## FPGA-specific HDL files
create_links \
     -convert_EDN_to_HDL 0 \
     -library {work} \
     -hdl_source_folder hdl/

########################################
########## CONFIGURE HDL CORES #########
########################################

# download IP cores
download_latest_cores

create_and_configure_core -core_vlnv {Actel:SgCore:OSC:2.0.101} -component_name {OSC_C0} -params {\
  "RCOSC_1MHZ_DRIVES_CCC:false"  \
  "RCOSC_1MHZ_DRIVES_FAB:false"  \
  "RCOSC_1MHZ_IS_USED:false"  \
  "RCOSC_25_50MHZ_DRIVES_CCC:0"  \
  "RCOSC_25_50MHZ_DRIVES_FAB:1"  \
  "RCOSC_25_50MHZ_IS_USED:1"  \
  "VOLTAGE_IS_1_2:true"  \
  "XTLOSC_DRIVES_CCC:false"  \
  "XTLOSC_DRIVES_FAB:false"  \
  "XTLOSC_FREQ:20.00"  \
  "XTLOSC_IS_USED:false"  \
  "XTLOSC_SRC:CRYSTAL"  \
}

create_and_configure_core -core_vlnv {Actel:SgCore:FCCC:2.0.201} -component_name {FCCC_C0} -params {\
  "ADVANCED_TAB_CHANGED:false"  \
  "CLK0_IS_USED:true"  \
  "CLK0_PAD_IS_USED:false"  \
  "CLK1_IS_USED:false"  \
  "CLK1_PAD_IS_USED:false"  \
  "CLK2_IS_USED:false"  \
  "CLK2_PAD_IS_USED:false"  \
  "CLK3_IS_USED:false"  \
  "CLK3_PAD_IS_USED:false"  \
  "DYN_CONF_IS_USED:false"  \
  "GL0_BP_IN_0_FREQ:100"  \
  "GL0_BP_IN_0_SRC:IO_HARDWIRED_0"  \
  "GL0_BP_IN_1_FREQ:100"  \
  "GL0_BP_IN_1_SRC:IO_HARDWIRED_0"  \
  "GL0_FREQUENCY_LOCKED:false"  \
  "GL0_IN_0_SRC:PLL"  \
  "GL0_IN_1_SRC:UNUSED"  \
  "GL0_IS_INVERTED:false"  \
  "GL0_IS_USED:true"  \
  "GL0_OUT_0_FREQ:50"  \
  "GL0_OUT_1_FREQ:50"  \
  "GL0_OUT_IS_GATED:false"  \
  "GL0_PLL_IN_0_PHASE:0"  \
  "GL0_PLL_IN_1_PHASE:0"  \
  "GL1_BP_IN_0_FREQ:100"  \
  "GL1_BP_IN_0_SRC:IO_HARDWIRED_0"  \
  "GL1_BP_IN_1_FREQ:100"  \
  "GL1_BP_IN_1_SRC:IO_HARDWIRED_0"  \
  "GL1_FREQUENCY_LOCKED:false"  \
  "GL1_IN_0_SRC:PLL"  \
  "GL1_IN_1_SRC:UNUSED"  \
  "GL1_IS_INVERTED:false"  \
  "GL1_IS_USED:false"  \
  "GL1_OUT_0_FREQ:100"  \
  "GL1_OUT_1_FREQ:50"  \
  "GL1_OUT_IS_GATED:false"  \
  "GL1_PLL_IN_0_PHASE:0"  \
  "GL1_PLL_IN_1_PHASE:0"  \
  "GL2_BP_IN_0_FREQ:100"  \
  "GL2_BP_IN_0_SRC:IO_HARDWIRED_0"  \
  "GL2_BP_IN_1_FREQ:100"  \
  "GL2_BP_IN_1_SRC:IO_HARDWIRED_0"  \
  "GL2_FREQUENCY_LOCKED:false"  \
  "GL2_IN_0_SRC:PLL"  \
  "GL2_IN_1_SRC:UNUSED"  \
  "GL2_IS_INVERTED:false"  \
  "GL2_IS_USED:false"  \
  "GL2_OUT_0_FREQ:100"  \
  "GL2_OUT_1_FREQ:50"  \
  "GL2_OUT_IS_GATED:false"  \
  "GL2_PLL_IN_0_PHASE:0"  \
  "GL2_PLL_IN_1_PHASE:0"  \
  "GL3_BP_IN_0_FREQ:100"  \
  "GL3_BP_IN_0_SRC:IO_HARDWIRED_0"  \
  "GL3_BP_IN_1_FREQ:100"  \
  "GL3_BP_IN_1_SRC:IO_HARDWIRED_0"  \
  "GL3_FREQUENCY_LOCKED:false"  \
  "GL3_IN_0_SRC:PLL"  \
  "GL3_IN_1_SRC:UNUSED"  \
  "GL3_IS_INVERTED:false"  \
  "GL3_IS_USED:false"  \
  "GL3_OUT_0_FREQ:100"  \
  "GL3_OUT_1_FREQ:50"  \
  "GL3_OUT_IS_GATED:false"  \
  "GL3_PLL_IN_0_PHASE:0"  \
  "GL3_PLL_IN_1_PHASE:0"  \
  "GPD0_IS_USED:false"  \
  "GPD0_NOPIPE_RSTSYNC:true"  \
  "GPD0_SYNC_STYLE:G3STYLE_AND_NO_LOCK_RSTSYNC"  \
  "GPD1_IS_USED:false"  \
  "GPD1_NOPIPE_RSTSYNC:true"  \
  "GPD1_SYNC_STYLE:G3STYLE_AND_NO_LOCK_RSTSYNC"  \
  "GPD2_IS_USED:false"  \
  "GPD2_NOPIPE_RSTSYNC:true"  \
  "GPD2_SYNC_STYLE:G3STYLE_AND_NO_LOCK_RSTSYNC"  \
  "GPD3_IS_USED:false"  \
  "GPD3_NOPIPE_RSTSYNC:true"  \
  "GPD3_SYNC_STYLE:G3STYLE_AND_NO_LOCK_RSTSYNC"  \
  "GPD_EXPOSE_RESETS:false"  \
  "GPD_SYNC_STYLE:G3STYLE_AND_LOCK_RSTSYNC"  \
  "INIT:0000007F90000045174000318C6318C1F18C61F00404040401805"  \
  "IO_HARDWIRED_0_IS_DIFF:false"  \
  "IO_HARDWIRED_1_IS_DIFF:false"  \
  "IO_HARDWIRED_2_IS_DIFF:false"  \
  "IO_HARDWIRED_3_IS_DIFF:false"  \
  "MODE_10V:false"  \
  "NGMUX0_HOLD_IS_USED:false"  \
  "NGMUX0_IS_USED:false"  \
  "NGMUX1_HOLD_IS_USED:false"  \
  "NGMUX1_IS_USED:false"  \
  "NGMUX2_HOLD_IS_USED:false"  \
  "NGMUX2_IS_USED:false"  \
  "NGMUX3_HOLD_IS_USED:false"  \
  "NGMUX3_IS_USED:false"  \
  "NGMUX_EXPOSE_HOLD:false"  \
  "PLL_DELAY:0"  \
  "PLL_EXPOSE_BYPASS:false"  \
  "PLL_EXPOSE_RESETS:false"  \
  "PLL_EXT_FB_GL:EXT_FB_GL0"  \
  "PLL_FB_SRC:CCC_INTERNAL"  \
  "PLL_IN_FREQ:12"  \
  "PLL_IN_SRC:CORE_0"  \
  "PLL_IS_USED:true"  \
  "PLL_LOCK_IND:1024"  \
  "PLL_LOCK_WND:32000"  \
  "PLL_SSM_DEPTH:0.5"  \
  "PLL_SSM_ENABLE:false"  \
  "PLL_SSM_FREQ:40"  \
  "PLL_SUPPLY_VOLTAGE:25_V"  \
  "PLL_VCO_TARGET:700"  \
  "RCOSC_1MHZ_IS_USED:false"  \
  "RCOSC_25_50MHZ_IS_USED:false"  \
  "VCOFREQUENCY:800.000"  \
  "XTLOSC_IS_USED:false"  \
  "Y0_IS_USED:false"  \
  "Y1_IS_USED:false"  \
  "Y2_IS_USED:false"  \
  "Y3_IS_USED:false"  \
}

################################
############ FINISH ############
################################

build_design_hierarchy

set_root -module {top_smf2000::work}
generate_component -component_name {OSC_C0}
generate_component -component_name {FCCC_C0}

create_links \
  -convert_EDN_to_HDL 0 \
  -io_pdc {constraints/smf2000-io.pdc}
create_links \
  -convert_EDN_to_HDL 0 \
  -sdc {constraints/smf2000-timing.sdc}

organize_tool_files \
    -tool {SYNTHESIZE} \
    -file {constraints/smf2000-timing.sdc} \
    -module {top_smf2000::work} \
    -input_type {constraint}

organize_tool_files \
    -tool {PLACEROUTE} \
    -file {constraints/smf2000-timing.sdc} \
    -file {constraints/smf2000-io.pdc} \
    -module {top_smf2000::work} \
    -input_type {constraint}

organize_tool_files \
    -tool {VERIFYTIMING} \
    -file {constraints/smf2000-timing.sdc} \
    -module {top_smf2000::work} \
    -input_type {constraint}

save_project
exit