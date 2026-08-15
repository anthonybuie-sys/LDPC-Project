source [file join [file dirname [file normalize [info script]]] "synth_common.tcl"]
run_kernel_sweep "forwarding" [list forward_mux_wrapper app_lut8_wrapper]

