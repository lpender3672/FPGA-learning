# Block design: Zynq UltraScale+ PS + AXI GPIO (loopback).
# Sourced from build.tcl after create_project.

create_bd_design "design_1"

# Zynq UltraScale+ Processing System, preset for KV260
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:* zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config { apply_board_preset "1" } [get_bd_cells zynq_ultra_ps_e_0]

# Disable the second AXI master (HPM1_FPD) so its clock isn't left dangling.
# The KV260 board preset turns it on by default but we only use HPM0_FPD.
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
] [get_bd_cells zynq_ultra_ps_e_0]

# AXI GPIO — 32-bit output channel, looped back to the input channel
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:* axi_gpio_0
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH  {32} \
    CONFIG.C_GPIO2_WIDTH {32} \
    CONFIG.C_IS_DUAL     {1}  \
    CONFIG.C_ALL_INPUTS_2 {1} \
    CONFIG.C_ALL_OUTPUTS  {1} \
] [get_bd_cells axi_gpio_0]

# Loopback: GPIO out -> GPIO2 in
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins axi_gpio_0/gpio2_io_i]

# Auto-connect AXI-Lite + clocks + resets
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { Master "/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD" \
              Clk_master    "Auto" \
              Clk_slave     "Auto" \
              Clk_xbar      "Auto" } \
    [get_bd_intf_pins axi_gpio_0/S_AXI]

# Pin the GPIO at a stable base address (matches pl.dts)
assign_bd_address -target_address_space /zynq_ultra_ps_e_0/Data \
    [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] -offset 0xA0000000 -range 64K

regenerate_bd_layout
save_bd_design
validate_bd_design
