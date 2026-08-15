set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set results_root [file join $repo_root "results" "rtl_prototypes" "vivado"]
file mkdir $results_root

proc select_target_part {} {
  set candidates [get_parts -quiet *zu67dr*fsve1156*-2*]
  if {[llength $candidates] == 0} {
    puts "ERROR: No installed Vivado part matched *zu67dr*fsve1156*-2*."
    puts "Query the local Vivado database and update the target filter only with a real installed part."
    exit 2
  }
  set part [lindex $candidates 0]
  puts "Selected Vivado part: $part"
  return $part
}

proc common_sources {repo_root} {
  set files [list]
  foreach pattern [list \
    "rtl_prototypes/common/*.sv" \
    "rtl_prototypes/reconstruction/*.sv" \
    "rtl_prototypes/accumulation/*.sv" \
    "rtl_prototypes/forwarding/*.sv" \
    "rtl_prototypes/app_memory/*.sv" \
    "rtl_prototypes/combined/*.sv"] {
    foreach file [glob -nocomplain [file join $repo_root $pattern]] {
      lappend files $file
    }
  }
  return $files
}

proc run_one_kernel {group top clock_mhz} {
  global repo_root results_root
  set part [select_target_part]
  set period_ns [expr {1000.0 / $clock_mhz}]
  set run_dir [file join $results_root $group $top "${clock_mhz}MHz"]
  file mkdir $run_dir

  create_project -force "${top}_${clock_mhz}MHz" $run_dir -part $part
  set_property target_language SystemVerilog [current_project]
  read_verilog -sv [common_sources $repo_root]
  synth_design -top $top -part $part -flatten_hierarchy rebuilt
  create_clock -period $period_ns -name clk [get_ports clk]
  opt_design
  place_design
  phys_opt_design
  route_design

  report_utilization -file [file join $run_dir utilization.rpt]
  report_timing_summary -file [file join $run_dir timing_summary.rpt]
  report_timing -max_paths 20 -file [file join $run_dir worst_paths.rpt]
  report_high_fanout_nets -file [file join $run_dir high_fanout.rpt]
  if {[llength [info commands report_design_analysis]] > 0} {
    report_design_analysis -congestion -file [file join $run_dir congestion.rpt]
  }
  write_checkpoint -force [file join $run_dir routed.dcp]
  close_project
}

proc run_kernel_sweep {group tops} {
  foreach top $tops {
    foreach clock_mhz {200 250 280 300 320 350} {
      puts "Running $group $top at ${clock_mhz}MHz"
      run_one_kernel $group $top $clock_mhz
    }
  }
}

