param(
    [string]$OssCadSuite = $env:OSS_CAD_SUITE,
    [string]$Yosys = $env:YOSYS
)

. (Join-Path $PSScriptRoot "rtl_regression_common.ps1")

$RepoRoot = Get-RepoRoot
Set-Location $RepoRoot
Initialize-OssCadSuite -OssCadSuite $OssCadSuite

$YosysExe = Resolve-RequiredTool -Name "yosys" -EnvironmentVariable "YOSYS" -Override $Yosys
Write-Host "Yosys tool:"
& $YosysExe -V

New-Item -ItemType Directory -Force -Path "results\free_tool_validation" | Out-Null
$sources = (Get-ProductionCoreSources) -join " "
$script = "read_slang --std latest --unroll-limit 20000 --top nr_ldpc_decoder_core $sources; hierarchy -top nr_ldpc_decoder_core; proc; opt; check; stat; tee -o results/free_tool_validation/yosys_generic_stat.txt stat"

Invoke-Logged `
    -Exe $YosysExe `
    -Arguments @("-l", "results\free_tool_validation\yosys_generic.log", "-p", $script) `
    -LogPath "results\free_tool_validation\yosys_generic_console.log" | Out-Null

$log = Get-Content "results\free_tool_validation\yosys_generic.log" -Raw
Assert-Matches -Text $log -Pattern "Build succeeded: 0 errors, 0 warnings" -Description "Yosys/slang clean build"
Assert-Matches -Text $log -Pattern "Found and reported 0 problems" -Description "Yosys check clean"

$stat = Get-Content "results\free_tool_validation\yosys_generic_stat.txt" -Raw
Assert-Matches -Text $stat -Pattern "38 memories" -Description "generic memory count"
Assert-Matches -Text $stat -Pattern "3023808 memory bits" -Description "generic memory bits"

Write-Host "PASS Yosys generic synthesis"
