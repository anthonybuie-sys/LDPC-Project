$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Resolve-RequiredTool {
    param(
        [string]$Name,
        [string]$EnvironmentVariable = "",
        [string]$Override = ""
    )

    $candidate = $Override
    if ([string]::IsNullOrWhiteSpace($candidate) -and
            -not [string]::IsNullOrWhiteSpace($EnvironmentVariable)) {
        $candidate = [Environment]::GetEnvironmentVariable($EnvironmentVariable)
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = $Name
    }

    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        $hint = if ([string]::IsNullOrWhiteSpace($EnvironmentVariable)) {
            "Pass a tool path explicitly or add $Name to PATH."
        } else {
            "Set `$env:$EnvironmentVariable, pass a tool path explicitly, or add $Name to PATH."
        }
        throw "Required tool '$Name' was not found. $hint"
    }
    return $cmd.Source
}

function Resolve-AnyRequiredTool {
    param(
        [string[]]$Names,
        [string]$EnvironmentVariable = "",
        [string]$Override = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return Resolve-RequiredTool -Name $Names[0] -EnvironmentVariable "" -Override $Override
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentVariable)) {
        $envValue = [Environment]::GetEnvironmentVariable($EnvironmentVariable)
        if (-not [string]::IsNullOrWhiteSpace($envValue)) {
            return Resolve-RequiredTool -Name $Names[0] -EnvironmentVariable "" -Override $envValue
        }
    }

    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            return $cmd.Source
        }
    }
    throw "Required tool was not found. Tried: $($Names -join ', ')."
}

function Initialize-OssCadSuite {
    param([string]$OssCadSuite = "")

    if ([string]::IsNullOrWhiteSpace($OssCadSuite)) {
        $OssCadSuite = $env:OSS_CAD_SUITE
    }
    if ([string]::IsNullOrWhiteSpace($OssCadSuite)) {
        return
    }

    $envScript = Join-Path $OssCadSuite "environment.ps1"
    if (-not (Test-Path $envScript)) {
        throw "OSS CAD Suite environment script not found: $envScript"
    }
    . $envScript

    $verilatorRoot = Join-Path $OssCadSuite "share\verilator"
    if ((Test-Path $verilatorRoot) -and [string]::IsNullOrWhiteSpace($env:VERILATOR_ROOT)) {
        $env:VERILATOR_ROOT = $verilatorRoot
    }
}

function Invoke-Logged {
    param(
        [string]$Exe,
        [string[]]$Arguments,
        [string]$LogPath
    )

    $logDir = Split-Path $LogPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }

    Write-Host "RUN $Exe $($Arguments -join ' ')"
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Exe @Arguments 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $oldErrorAction
    }
    $text = ($output | Out-String).TrimEnd()
    if (-not [string]::IsNullOrEmpty($text)) {
        $text | Tee-Object -FilePath $LogPath
    } else {
        "" | Set-Content -Path $LogPath
    }
    if ($exitCode -ne 0) {
        throw "Command failed with exit code $exitCode. See $LogPath"
    }
    return $text
}

function Assert-Matches {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Description
    )

    if ($Text -notmatch $Pattern) {
        throw "Missing expected result: $Description. Pattern: $Pattern"
    }
}

function Get-Phase9Sources {
    return @(
        "rtl\common\nr_ldpc_pkg.sv",
        "rtl\syndrome\nr_ldpc_syndrome_profile_bg1_first4.sv",
        "rtl\control\nr_ldpc_controller_profile_bg1_first4.sv",
        "rtl\common\nr_ldpc_arith.sv",
        "rtl\check_state\nr_ldpc_c2v_reconstruct.sv",
        "rtl\acc\nr_ldpc_acc_min_update.sv",
        "rtl\acc\nr_ldpc_acc_context.sv",
        "rtl\acc\nr_ldpc_acc_pipeline.sv",
        "rtl\rec\nr_ldpc_rec_pipeline.sv",
        "rtl\qc\nr_ldpc_qc_permute.sv",
        "rtl\storage\nr_ldpc_q_scratch.sv",
        "rtl\storage\nr_ldpc_check_state_store.sv",
        "rtl\core\nr_ldpc_acc_rec_datapath.sv",
        "rtl\storage\nr_ldpc_app_memory.sv",
        "rtl\storage\nr_ldpc_forward_cache.sv",
        "rtl\core\nr_ldpc_app_forward_datapath.sv",
        "rtl\control\nr_ldpc_iteration_decide.sv",
        "rtl\syndrome\nr_ldpc_syndrome_engine.sv",
        "rtl\core\nr_ldpc_syndrome_datapath.sv",
        "rtl\control\nr_ldpc_schedule_controller.sv",
        "rtl\core\nr_ldpc_decoder_core.sv",
        "rtl\tb\tb_phase9_decoder_core.sv"
    )
}

function Get-ProductionCoreSources {
    return @(
        "rtl\common\nr_ldpc_pkg.sv",
        "rtl\syndrome\nr_ldpc_syndrome_profile_bg1_first4.sv",
        "rtl\control\nr_ldpc_controller_profile_bg1_first4.sv",
        "rtl\common\nr_ldpc_arith.sv",
        "rtl\check_state\nr_ldpc_c2v_reconstruct.sv",
        "rtl\acc\nr_ldpc_acc_min_update.sv",
        "rtl\acc\nr_ldpc_acc_context.sv",
        "rtl\acc\nr_ldpc_acc_pipeline.sv",
        "rtl\rec\nr_ldpc_rec_pipeline.sv",
        "rtl\qc\nr_ldpc_qc_permute.sv",
        "rtl\storage\nr_ldpc_q_scratch.sv",
        "rtl\storage\nr_ldpc_check_state_store.sv",
        "rtl\storage\nr_ldpc_app_memory.sv",
        "rtl\storage\nr_ldpc_forward_cache.sv",
        "rtl\control\nr_ldpc_iteration_decide.sv",
        "rtl\control\nr_ldpc_schedule_controller.sv",
        "rtl\syndrome\nr_ldpc_syndrome_engine.sv",
        "rtl\core\nr_ldpc_acc_rec_datapath.sv",
        "rtl\core\nr_ldpc_app_forward_datapath.sv",
        "rtl\core\nr_ldpc_syndrome_datapath.sv",
        "rtl\core\nr_ldpc_decoder_core.sv"
    )
}
