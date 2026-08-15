source [file join [file dirname [file normalize [info script]]] "synth_common.tcl"]
run_kernel_sweep "combined" [list da3_dr3_datapath da4_dr4_datapath]

