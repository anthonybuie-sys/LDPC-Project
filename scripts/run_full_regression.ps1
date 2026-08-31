param(
    [string]$Python = $env:PYTHON,
    [string]$Iverilog = $env:IVERILOG,
    [string]$Vvp = $env:VVP
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "run_python_regression.ps1") -Python $Python
if ($LASTEXITCODE -ne 0) {
    throw "Python regression failed."
}

& (Join-Path $PSScriptRoot "run_full_rtl_regression.ps1") -Python $Python -Iverilog $Iverilog -Vvp $Vvp
if ($LASTEXITCODE -ne 0) {
    throw "RTL regression failed."
}

Write-Host "PASS full Python and RTL regression"
