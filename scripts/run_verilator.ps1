param(
    [string]$OssCadSuite = $env:OSS_CAD_SUITE,
    [string]$Verilator = $env:VERILATOR
)

. (Join-Path $PSScriptRoot "rtl_regression_common.ps1")

$RepoRoot = Get-RepoRoot
Set-Location $RepoRoot
Initialize-OssCadSuite -OssCadSuite $OssCadSuite

$VerilatorExe = Resolve-AnyRequiredTool `
    -Names @("verilator_bin.exe", "verilator") `
    -EnvironmentVariable "VERILATOR" `
    -Override $Verilator

Write-Host "Verilator tool:"
& $VerilatorExe --version

$args = @(
    "--lint-only",
    "-Wall",
    "-Wno-fatal",
    "--top-module", "nr_ldpc_decoder_core",
    "-Irtl/common",
    "-Irtl/acc",
    "-Irtl/check_state",
    "-Irtl/control",
    "-Irtl/core",
    "-Irtl/qc",
    "-Irtl/rec",
    "-Irtl/storage",
    "-Irtl/syndrome"
) + (Get-ProductionCoreSources)

$text = Invoke-Logged `
    -Exe $VerilatorExe `
    -Arguments $args `
    -LogPath "results\free_tool_validation\verilator_lint.log"

Write-Host "PASS Verilator lint/elaboration completed"
