# Block design: Zynq UltraScale+ PS + AXI GPIO (loopback).
# Sourced from build.tcl after create_project.

create_bd_design "design_1"

# Zynq UltraScale+ Processing System, preset for KV260
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config { apply_board_preset "1" } [get_bd_cells zynq_ultra_ps_e_0]

# Disable the second AXI master (HPM1_FPD) so its clock isn't left dangling.
# The KV260 board preset turns it on by default but we only use HPM0_FPD.
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
] [get_bd_cells zynq_ultra_ps_e_0]

# AXI GPIO — 32-bit output channel, looped back to the input channel
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
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

# ---- IP version lockfile ----
# Vivado happily substitutes newer IP revs without warning. Enforce the
# exact versions this design was validated against, including indirect
# cells inserted by apply_bd_automation. To bump after a deliberate
# review: change the version here and re-test the loopback on hardware.
set expected_versions [dict create \
    zynq_ultra_ps_e          3.5 \
    axi_gpio                 2.0 \
    axi_interconnect         2.1 \
    axi_dwidth_converter     2.1 \
    axi_protocol_converter   2.1 \
    proc_sys_reset           5.0 \
]

set mismatches {}
foreach cell [get_bd_cells -hierarchical] {
    set vlnv [get_property VLNV $cell]
    if {[regexp {xilinx\.com:ip:([^:]+):(.+)} $vlnv -> ip_name ip_version]} {
        if {[dict exists $expected_versions $ip_name]} {
            set expected [dict get $expected_versions $ip_name]
            if {$ip_version ne $expected} {
                lappend mismatches "  $ip_name: expected $expected, got $ip_version  (cell: $cell)"
            }
        }
    }
}
if {[llength $mismatches] > 0} {
    puts "===== IP VERSION DRIFT DETECTED ====="
    foreach m $mismatches { puts $m }
    error "Pinned IP versions in bd/design_1.tcl do not match what Vivado generated. Review changes and update the lockfile after re-testing."
}
puts "===== IP versions all match lockfile ====="
