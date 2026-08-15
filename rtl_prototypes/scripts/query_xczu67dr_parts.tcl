set matches [get_parts -quiet *xczu67dr*]
puts "Vivado version: [version -short]"
puts "XCZU67DR part matches:"
foreach part $matches {
  puts $part
}

set broad [get_parts -quiet *zu67dr*]
puts "ZU67DR part matches:"
foreach part $broad {
  puts $part
}

set exact [get_parts -quiet *zu67dr*fsve1156*-2*]
puts "Exact XCZU67DR FSVE1156 -2 candidates:"
foreach part $exact {
  puts $part
}

if {[llength $exact] == 0} {
  puts "ERROR: No installed Vivado part matched *zu67dr*fsve1156*-2*."
  exit 2
}
