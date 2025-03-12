# 50 MHz clock
create_clock -name {clk12} -period 83.333 [ get_nets { clk12_i } ]
create_clock -name {clk50} -period 40 [ get_nets { fccc_clk_w } ]

# set_multicycle_path -setup 2 -from [ get_pins { harv_soc_u/harv_u/*alu*/* } ] -to [ get_pins { harv_soc_u/harv_u/* } ]
