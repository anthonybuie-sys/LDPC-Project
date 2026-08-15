$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$OutDir = Join-Path $Root "results\rtl_prototypes\sim"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Iverilog = (Get-Command iverilog -ErrorAction Stop).Source
$Vvp = (Get-Command vvp -ErrorAction Stop).Source

function Invoke-Sim {
    param(
        [string]$Name,
        [string[]]$Sources
    )
    $Output = Join-Path $OutDir "$Name.vvp"
    & $Iverilog -g2012 -Wall -o $Output @Sources
    & $Vvp $Output
}

Invoke-Sim -Name "reconstruction_tb" -Sources @(
    (Join-Path $Root "rtl_prototypes\reconstruction\reconstruction_dr3.sv"),
    (Join-Path $Root "rtl_prototypes\reconstruction\reconstruction_dr4.sv"),
    (Join-Path $Root "rtl_prototypes\tb\tb_reconstruction.sv")
)

Invoke-Sim -Name "accumulation_tb" -Sources @(
    (Join-Path $Root "rtl_prototypes\accumulation\accumulation_da3.sv"),
    (Join-Path $Root "rtl_prototypes\accumulation\accumulation_da4.sv"),
    (Join-Path $Root "rtl_prototypes\tb\tb_accumulation.sv")
)

Invoke-Sim -Name "forwarding_app_tb" -Sources @(
    (Join-Path $Root "rtl_prototypes\forwarding\forward_cache_8.sv"),
    (Join-Path $Root "rtl_prototypes\forwarding\forward_mux_wrapper.sv"),
    (Join-Path $Root "rtl_prototypes\app_memory\app_lut8_model.sv"),
    (Join-Path $Root "rtl_prototypes\tb\tb_forwarding_app.sv")
)

Write-Host "All RTL prototype simulations passed."

