source [file join [file dirname [file normalize [info script]]] "synth_common.tcl"]
run_kernel_sweep "reconstruction" [list reconstruction_dr3 reconstruction_dr4]

