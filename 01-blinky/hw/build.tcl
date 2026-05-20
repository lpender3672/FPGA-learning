# Vivado batch build for 01-blinky.
# Run from project root:
#   vivado -mode batch -source hw/build.tcl

# Derive from directory name; hyphens → underscores (Vivado dislikes hyphens).
set proj_name   [string map {- _} [file tail [file normalize .]]]
set proj_dir    [file normalize ./build/vivado]
set part        xck26-sfvc784-2LV-c
set board       xilinx.com:kv260_som:part0:1.4

file mkdir [file normalize ./build]
file mkdir $proj_dir

create_project -force $proj_name $proj_dir -part $part
set_property board_part $board [current_project]

# Pull in custom RTL if present
set src_dir [file normalize ./hw/src]
if {[llength [glob -nocomplain -directory $src_dir *.v *.sv *.vhd]]} {
    add_files -fileset sources_1 [glob -directory $src_dir *.v *.sv *.vhd]
}

# Constraints (empty for loopback design but kept for the user to extend)
set xdc [file normalize ./hw/constraints/kv260.xdc]
if {[file exists $xdc]} {
    add_files -fileset constrs_1 $xdc
}

# Build the block design
source [file normalize ./hw/bd/design_1.tcl]

make_wrapper -files [get_files design_1.bd] -top
add_files -norecurse [glob $proj_dir/$proj_name.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v]
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Synth → impl → bitstream
launch_runs synth_1 -jobs 8
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Copy the bitstream to a stable path
set bit_src [glob $proj_dir/$proj_name.runs/impl_1/*.bit]
file copy -force $bit_src [file normalize ./build/design.bit]

puts "===== BUILD OK: build/design.bit ====="
