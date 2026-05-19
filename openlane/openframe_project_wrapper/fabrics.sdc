# ==============================================================================
# fabrics.sdc
# Timing Constraints for FABulous eFPGA IP Integration in OpenFrame
# ==============================================================================

puts "\[INFO\]: Sourcing modular eFPGA fabric timing constraints from fabrics.sdc..."

# 1. False paths for top-level asynchronous/slow resets
puts "\[INFO\]: Sourcing fabrics.sdc - Configuring false paths for asynchronous resets and tie-offs..."
set_false_path -from [get_ports {resetb_h resetb_l por_l porb_h porb_l}]
set_false_path -from [get_ports {mask_rev[*]}]
set_false_path -from [get_ports {gpio_loopback_one[*] gpio_loopback_zero[*]}]

# 2. False paths for static pad configuration outputs
puts "\[INFO\]: Sourcing fabrics.sdc - Configuring false paths for static pad control outputs..."
set_false_path -to [get_ports {gpio_ib_mode_sel[*] gpio_vtrip_sel[*] gpio_slow_sel[*] gpio_holdover[*] gpio_analog_en[*] gpio_analog_sel[*] gpio_analog_pol[*] gpio_dm2[*] gpio_dm1[*] gpio_dm0[*]}]

# 3. False paths for all eFPGA fabric I/O pins (except system clock gpio_in[38])
puts "\[INFO\]: Sourcing fabrics.sdc - Configuring false paths for fabric I/O ports (excluding gpio_in\[38\])..."
for {set i 0} {$i < 44} {incr i} {
    if {$i != 38} {
        set_false_path -from [get_ports "gpio_in\[$i\]"]
        set_false_path -from [get_ports "gpio_in_h\[$i\]"]
        set_false_path -to [get_ports "gpio_out\[$i\]"]
        set_false_path -to [get_ports "gpio_oeb\[$i\]"]
        set_false_path -to [get_ports "gpio_inp_dis\[$i\]"]
    }
}

# 4. Max transition and capacitance relaxation constraints to disable buffer insertion (slew/cap DRC repair) on static and asynchronous nets
puts "\[INFO\]: Sourcing fabrics.sdc - Relaxing max transition and capacitance constraints on static, reset, and loopback ports..."

# Get static, reset, and loopback ports (constrained on Ports, which are standard SDC objects)
set static_ports [get_ports {
    resetb_h resetb_l por_l porb_h porb_l mask_rev[*]
    gpio_ib_mode_sel[*] gpio_vtrip_sel[*] gpio_slow_sel[*] gpio_holdover[*]
    gpio_analog_en[*] gpio_analog_sel[*] gpio_analog_pol[*] gpio_dm2[*] gpio_dm1[*] gpio_dm0[*]
    gpio_loopback_one[*] gpio_loopback_zero[*]
}]

# Set massive transition and capacitance limits so the resizer sees zero violations and inserts zero buffers,
# while keeping standard SDC compatibility (no Net or Pin objects) and leaving nets fully modifiable for antenna diode insertion!
set_max_transition 100.0 $static_ports
set_max_capacitance 100.0 $static_ports

puts "\[INFO\]: Sourcing fabrics.sdc - Relaxing max transition and capacitance constraints on fabric I/O ports..."

# Relax limits on all GPIO ports (excluding clock)
for {set i 0} {$i < 44} {incr i} {
    if {$i != 38} {
        set names [list "gpio_in\[$i\]" "gpio_in_h\[$i\]" "gpio_out\[$i\]" "gpio_oeb\[$i\]" "gpio_inp_dis\[$i\]"]
        set_max_transition 100.0 [get_ports $names]
        set_max_capacitance 100.0 [get_ports $names]
    }
}

# 5. False paths for fabric macro instances (internal blackboxes)
# Using standard -through constraints to false all paths passing through macro input/output pins.
# This resolves OpenSTA warnings where hierarchical/blackbox pins are not treated as valid -from/-to start/endpoints.
puts "\[INFO\]: Sourcing fabrics.sdc - Configuring false paths for fabric macro instances..."

set fabric_instances {
    "u_chip_core.i_classic_fabric_chipfoundry_medium"
    "u_chip_core.i_classic_fabric_chipfoundry_large"
}

if {[info commands get_cells] ne ""} {
    foreach fabric_inst $fabric_instances {
        set cell_obj [get_cells -quiet $fabric_inst]
        if {$cell_obj ne ""} {
            # Get all input pins of the fabric macro and set false paths through them
            set fabric_inputs [get_pins -quiet -of_objects $cell_obj -filter "direction == input"]
            if {$fabric_inputs ne ""} {
                set_false_path -through $fabric_inputs
                puts "\[INFO\]: Sourcing fabrics.sdc - Successfully set false path -through $fabric_inst (inputs)"
            }
            
            # Get all output pins of the fabric macro and set false paths through them
            set fabric_outputs [get_pins -quiet -of_objects $cell_obj -filter "direction == output"]
            if {$fabric_outputs ne ""} {
                set_false_path -through $fabric_outputs
                puts "\[INFO\]: Sourcing fabrics.sdc - Successfully set false path -through $fabric_inst (outputs)"
            }
        } else {
            puts "\[WARNING\]: Sourcing fabrics.sdc - Macro instance $fabric_inst not found in the current design stage."
        }
    }
}

puts "\[INFO\]: Successfully completed sourcing of fabrics.sdc!"
