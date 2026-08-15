source [file join [file dirname [file normalize [info script]]] "synth_common.tcl"]
run_kernel_sweep "accumulation" [list accumulation_da3 accumulation_da4]

