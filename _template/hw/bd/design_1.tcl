# Block design skeleton: Zynq UltraScale+ PS with no PL peripherals.
# Replace the TODO section with your own IP and connections.

create_bd_design "design_1"

create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config { apply_board_preset "1" } [get_bd_cells zynq_ultra_ps_e_0]

# Disable the second AXI master so its clock isn't left dangling.
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
] [get_bd_cells zynq_ultra_ps_e_0]

# ---- TODO: add your IP cells here ----
# Example: create an AXI peripheral and connect it to the PS master:
#   create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
#   apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
#       -config { Master "/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD" \
#                 Clk_master Auto Clk_slave Auto Clk_xbar Auto } \
#       [get_bd_intf_pins axi_gpio_0/S_AXI]
#   assign_bd_address -target_address_space /zynq_ultra_ps_e_0/Data \
#       [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] -offset 0xA0000000 -range 64K

regenerate_bd_layout
save_bd_design
validate_bd_design

# ---- IP version lockfile ----
# Add an entry for every IP you instantiate (directly or via automation).
# The build fails loudly if Vivado substitutes a different rev. Bump
# versions here after intentional review + hardware re-test.
set expected_versions [dict create \
    zynq_ultra_ps_e          3.5 \
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
