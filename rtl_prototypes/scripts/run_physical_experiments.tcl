set repo_root {C:/Users/18324/Verilog Project/LDPC Decoder}
set results_root [file join $repo_root "results" "rtl_prototypes" "vivado"]
set target_part "xczu67dr-fsve1156-2-i"
set clock_mhz_list {200 250 280 300 320 350}

file mkdir $results_root

proc add_tclstore_package_dirs {dir} {
  if {[file exists [file join $dir "pkgIndex.tcl"]]} {
    if {[lsearch -exact $::auto_path $dir] == -1} {
      lappend ::auto_path $dir
    }
  }
  foreach child [glob -nocomplain -directory $dir *] {
    if {[file isdirectory $child]} {
      add_tclstore_package_dirs $child
    }
  }
}

add_tclstore_package_dirs {C:/Xilinx/2025.1/Vivado/data/XilinxTclStore/support}
add_tclstore_package_dirs {C:/Xilinx/2025.1/Vivado/data/XilinxTclStore/tclapp}
if {[catch {package require ::tclapp::support::appinit 1.2} appinit_err]} {
  puts "WARNING: Could not preload TclStore appinit package: $appinit_err"
} else {
  puts "Preloaded TclStore appinit package."
}
if {[catch {package require ::tclapp::xilinx::xsim} xsim_err]} {
  puts "WARNING: Could not preload TclStore xsim package: $xsim_err"
} else {
  puts "Preloaded TclStore xsim package."
}

set part_matches [get_parts -quiet $target_part]
if {[llength $part_matches] == 0} {
  puts "ERROR: Required exact Vivado part is not installed: $target_part"
  exit 2
}
puts "Selected exact Vivado part: $target_part"

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

proc csv_escape {value} {
  set text [string map {"\"" "\"\""} $value]
  return "\"$text\""
}

proc write_status_header {path} {
  set fh [open $path w]
  puts $fh "group,variant,top,clock_mhz,period_ns,part,generics,status,wns_ns,critical_delay_ns,startpoint,endpoint,run_dir"
  close $fh
}

proc append_status {path row} {
  set fh [open $path a]
  set fields [list \
    [dict get $row group] \
    [dict get $row variant] \
    [dict get $row top] \
    [dict get $row clock_mhz] \
    [dict get $row period_ns] \
    [dict get $row part] \
    [dict get $row generics] \
    [dict get $row status] \
    [dict get $row wns_ns] \
    [dict get $row critical_delay_ns] \
    [dict get $row startpoint] \
    [dict get $row endpoint] \
    [dict get $row run_dir]]
  set escaped [list]
  foreach field $fields {
    lappend escaped [csv_escape $field]
  }
  puts $fh [join $escaped ","]
  close $fh
}

proc run_one_physical {exp clock_mhz summary_csv} {
  global repo_root results_root target_part
  set group [dict get $exp group]
  set variant [dict get $exp variant]
  set top [dict get $exp top]
  set generics [dict get $exp generics]
  set period_ns [expr {1000.0 / $clock_mhz}]
  set run_dir [file join $results_root $group $variant "${clock_mhz}MHz"]
  file mkdir $run_dir

  puts "Running $group $variant ($top) at ${clock_mhz} MHz"
  puts "Run directory: $run_dir"

  set status "ok"
  set wns_ns "N/A"
  set critical_delay_ns "N/A"
  set startpoint "N/A"
  set endpoint "N/A"
  set fail_file [file join $run_dir "failure.txt"]
  if {[file exists $fail_file]} {
    file delete -force $fail_file
  }

  if {[catch {
    read_verilog -sv [common_sources $repo_root]

    set synth_cmd [list synth_design -top $top -part $target_part -mode out_of_context -flatten_hierarchy rebuilt]
    foreach generic $generics {
      lappend synth_cmd -generic $generic
    }
    eval $synth_cmd

    create_clock -period $period_ns -name clk [get_ports clk]
    opt_design
    place_design
    phys_opt_design
    route_design

    report_utilization -file [file join $run_dir "utilization.rpt"]
    report_timing_summary -delay_type max -report_unconstrained -file [file join $run_dir "timing_summary.rpt"]
    report_timing -delay_type max -max_paths 20 -file [file join $run_dir "worst_paths.rpt"]
    report_route_status -file [file join $run_dir "route_status.rpt"]
    report_high_fanout_nets -file [file join $run_dir "high_fanout.rpt"]
    if {[llength [info commands report_design_analysis]] > 0} {
      report_design_analysis -congestion -file [file join $run_dir "congestion.rpt"]
    }
    write_checkpoint -force [file join $run_dir "routed.dcp"]

    set paths [get_timing_paths -delay_type max -max_paths 1 -quiet]
    if {[llength $paths] > 0} {
      set path [lindex $paths 0]
      set wns_ns [get_property SLACK $path]
      set critical_delay_ns [expr {$period_ns - $wns_ns}]
      set startpoint [get_property STARTPOINT_PIN $path]
      set endpoint [get_property ENDPOINT_PIN $path]
      if {$wns_ns < 0} {
        set status "timing_fail"
      }
    }
  } err opts]} {
    set status "tool_fail"
    set fh [open $fail_file w]
    puts $fh $err
    puts $fh [dict get $opts -errorinfo]
    close $fh
    puts "ERROR: $group $variant ${clock_mhz}MHz failed: $err"
  }

  if {[llength [current_design -quiet]] > 0} {
    close_design
  }

  append_status $summary_csv [dict create \
    group $group \
    variant $variant \
    top $top \
    clock_mhz $clock_mhz \
    period_ns [format %.6f $period_ns] \
    part $target_part \
    generics [join $generics " "] \
    status $status \
    wns_ns $wns_ns \
    critical_delay_ns $critical_delay_ns \
    startpoint $startpoint \
    endpoint $endpoint \
    run_dir $run_dir]

  if {$status eq "tool_fail"} {
    exit 3
  }
}

set experiments [list \
  [dict create group "reconstruction" variant "DR3" top "reconstruction_dr3" generics [list]] \
  [dict create group "reconstruction" variant "DR4" top "reconstruction_dr4" generics [list]] \
  [dict create group "accumulation" variant "DA3" top "accumulation_da3" generics [list]] \
  [dict create group "accumulation" variant "DA4" top "accumulation_da4" generics [list]] \
  [dict create group "forwarding" variant "NF4" top "forward_mux_wrapper" generics [list "NF=4"]] \
  [dict create group "forwarding" variant "NF8" top "forward_mux_wrapper" generics [list "NF=8"]] \
  [dict create group "app_lut8" variant "8banks" top "app_lut8_wrapper" generics [list]] \
  [dict create group "combined" variant "DA3_DR3_NF8" top "da3_dr3_datapath" generics [list "NF=8"]] \
  [dict create group "combined" variant "DA4_DR4_NF8" top "da4_dr4_datapath" generics [list "NF=8"]]]

set summary_csv [file join $results_root "physical_run_status.csv"]
write_status_header $summary_csv

foreach exp $experiments {
  foreach clock_mhz $clock_mhz_list {
    run_one_physical $exp $clock_mhz $summary_csv
  }
}

puts "Physical experiment sweep completed. Summary: $summary_csv"
