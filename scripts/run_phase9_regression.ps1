param(
    [string]$Iverilog = $env:IVERILOG,
    [string]$Vvp = $env:VVP
)

. (Join-Path $PSScriptRoot "rtl_regression_common.ps1")

$RepoRoot = Get-RepoRoot
Set-Location $RepoRoot

$IverilogExe = Resolve-RequiredTool -Name "iverilog" -EnvironmentVariable "IVERILOG" -Override $Iverilog
$VvpExe = Resolve-RequiredTool -Name "vvp" -EnvironmentVariable "VVP" -Override $Vvp

Write-Host "Icarus tool:"
& $IverilogExe -V | Select-Object -First 1
Write-Host "VVP tool:"
& $VvpExe -V | Select-Object -First 1

New-Item -ItemType Directory -Force -Path "results\rtl_phase9" | Out-Null
$phase9Vvp = "results\rtl_phase9\tb_phase9_decoder_core.vvp"
$compileArgs = @(
    "-g2012",
    "-I", "rtl\common",
    "-I", "rtl\syndrome",
    "-I", "rtl\control",
    "-o", $phase9Vvp
) + (Get-Phase9Sources)

Invoke-Logged `
    -Exe $IverilogExe `
    -Arguments $compileArgs `
    -LogPath "results\rtl_phase9\phase9_compile_portable.log" | Out-Null

$allText = ""
foreach ($case in 1..14) {
    Write-Host "Phase 9 selected case $case"
    $caseText = Invoke-Logged `
        -Exe $VvpExe `
        -Arguments @($phase9Vvp, "+phase9_case=$case") `
        -LogPath "results\rtl_phase9\phase9_case_$case.log"
    Assert-Matches -Text $caseText -Pattern "PASS phase9 decoder core controller" -Description "Phase 9 case $case PASS"
    $allText += "`n$caseText"
}

Assert-Matches -Text $allText -Pattern "pc0_sequence=0/74/148" -Description "three-iteration PC0 sequence"
Assert-Matches -Text $allText -Pattern "terminal_done=221" -Description "three-iteration terminal done"
Assert-Matches -Text $allText -Pattern "generation_advances=2" -Description "three-iteration generation advances"
Assert-Matches -Text $allText -Pattern "epochs=0/1/2" -Description "three-iteration epochs"
Assert-Matches -Text $allText -Pattern "acc_issues=120 rec_issues=120 acc_edges=228 rec_edges=228" -Description "three-iteration ACC/REC counts"
Assert-Matches -Text $allText -Pattern "decoder_schedule_cycles=71 syndrome_completion_cycle=72 syndrome_decision_cycle=73 controller_retry_pc0_to_pc0=74" -Description "Phase 9 71/72/73/74 timing"

Write-Host "PASS Phase 9 selected-case regression including three-iteration ping-pong"
