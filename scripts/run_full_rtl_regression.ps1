param(
    [string]$Python = $env:PYTHON,
    [string]$Iverilog = $env:IVERILOG,
    [string]$Vvp = $env:VVP
)

. (Join-Path $PSScriptRoot "rtl_regression_common.ps1")

$RepoRoot = Get-RepoRoot
Set-Location $RepoRoot

$PythonExe = Resolve-RequiredTool -Name "python" -EnvironmentVariable "PYTHON" -Override $Python
$IverilogExe = Resolve-RequiredTool -Name "iverilog" -EnvironmentVariable "IVERILOG" -Override $Iverilog
$VvpExe = Resolve-RequiredTool -Name "vvp" -EnvironmentVariable "VVP" -Override $Vvp

Write-Host "Python tool:"
& $PythonExe --version
Write-Host "Icarus tool:"
& $IverilogExe -V | Select-Object -First 1
Write-Host "VVP tool:"
& $VvpExe -V | Select-Object -First 1

function Compile-Sv {
    param(
        [string]$OutFile,
        [string[]]$Sources,
        [string[]]$Defines = @(),
        [string[]]$Includes = @("rtl\common"),
        [string]$LogPath
    )
    $args = @("-g2012")
    foreach ($define in $Defines) {
        $args += $define
    }
    foreach ($include in $Includes) {
        $args += @("-I", $include)
    }
    $args += @("-o", $OutFile)
    $args += $Sources
    Invoke-Logged -Exe $IverilogExe -Arguments $args -LogPath $LogPath | Out-Null
}

function Run-Vvp-And-Check {
    param(
        [string]$VvpFile,
        [string[]]$Arguments,
        [string]$LogPath,
        [string[]]$Patterns,
        [string]$Description
    )
    $text = Invoke-Logged -Exe $VvpExe -Arguments (@($VvpFile) + $Arguments) -LogPath $LogPath
    foreach ($pattern in $Patterns) {
        Assert-Matches -Text $text -Pattern $pattern -Description "$Description pattern '$pattern'"
    }
    return $text
}

Compile-Sv `
    -OutFile "results\rtl_phase1\tb_phase1_arith.vvp" `
    -Sources @("rtl\common\nr_ldpc_pkg.sv", "rtl\common\nr_ldpc_arith.sv", "rtl\tb\tb_phase1_arith.sv") `
    -LogPath "results\rtl_phase1\phase1_compile_portable.log"
Run-Vvp-And-Check `
    -VvpFile "results\rtl_phase1\tb_phase1_arith.vvp" `
    -Arguments @() `
    -LogPath "results\rtl_phase1\phase1_run_portable.log" `
    -Patterns @("PASS phase1 arithmetic primitives") `
    -Description "Phase 1" | Out-Null

Compile-Sv `
    -OutFile "results\rtl_phase2\tb_phase2_qc.vvp" `
    -Sources @("rtl\common\nr_ldpc_pkg.sv", "rtl\qc\nr_ldpc_qc_permute.sv", "rtl\tb\tb_phase2_qc.sv") `
    -LogPath "results\rtl_phase2\phase2_compile_portable.log"
Run-Vvp-And-Check `
    -VvpFile "results\rtl_phase2\tb_phase2_qc.vvp" `
    -Arguments @() `
    -LogPath "results\rtl_phase2\phase2_run_portable.log" `
    -Patterns @("PASS phase2 qc permutation") `
    -Description "Phase 2" | Out-Null
$qcText = Invoke-Logged `
    -Exe $PythonExe `
    -Arguments @("scripts\check_phase2_qc.py") `
    -LogPath "results\rtl_phase2\phase2_python_qc_portable.log"
Assert-Matches -Text $qcText -Pattern "PASS" -Description "Phase 2 Python QC PASS"
Assert-Matches -Text $qcText -Pattern "14208 observed SV lane rows checked" -Description "Phase 2 Python QC row count"

Compile-Sv `
    -OutFile "results\rtl_phase3\tb_phase3_c2v.vvp" `
    -Sources @("rtl\common\nr_ldpc_pkg.sv", "rtl\common\nr_ldpc_arith.sv", "rtl\check_state\nr_ldpc_c2v_reconstruct.sv", "rtl\tb\tb_phase3_c2v.sv") `
    -LogPath "results\rtl_phase3\phase3_compile_portable.log"
Run-Vvp-And-Check `
    -VvpFile "results\rtl_phase3\tb_phase3_c2v.vvp" `
    -Arguments @() `
    -LogPath "results\rtl_phase3\phase3_run_portable.log" `
    -Patterns @("PASS phase3 compressed c2v reconstruction", "scalar_cases=32768", "vector_cases=116", "explicit_edges_checked=96") `
    -Description "Phase 3" | Out-Null

$categoryBText = Invoke-Logged `
    -Exe $PythonExe `
    -Arguments @("scripts\close_rtl_handoff_category_b.py") `
    -LogPath "results\rtl_handoff_category_b\category_b_portable.log"
Assert-Matches -Text $categoryBText -Pattern "CATEGORY B CLOSED" -Description "Category B closure"

Compile-Sv `
    -OutFile "results\rtl_phase4\tb_phase4_acc_min_update.vvp" `
    -Sources @("rtl\common\nr_ldpc_pkg.sv", "rtl\acc\nr_ldpc_acc_min_update.sv", "rtl\tb\tb_phase4_acc_min_update.sv") `
    -LogPath "results\rtl_phase4\phase4_min_compile_portable.log"
Run-Vvp-And-Check `
    -VvpFile "results\rtl_phase4\tb_phase4_acc_min_update.vvp" `
    -Arguments @() `
    -LogPath "results\rtl_phase4\phase4_min_run_portable.log" `
    -Patterns @("PASS phase4 acc min-update exhaustive", "order_independence_cases=16384") `
    -Description "Phase 4 min-update" | Out-Null

$phase4Sources = @(
    "rtl\common\nr_ldpc_pkg.sv", "rtl\common\nr_ldpc_arith.sv",
    "rtl\check_state\nr_ldpc_c2v_reconstruct.sv", "rtl\qc\nr_ldpc_qc_permute.sv",
    "rtl\acc\nr_ldpc_acc_min_update.sv", "rtl\acc\nr_ldpc_acc_context.sv",
    "rtl\acc\nr_ldpc_acc_pipeline.sv", "rtl\tb\tb_phase4_acc.sv"
)
Compile-Sv `
    -OutFile "results\rtl_phase4\tb_phase4_acc_reduced.vvp" `
    -Sources $phase4Sources `
    -Defines @("-DPHASE4_REDUCED_P=32") `
    -LogPath "results\rtl_phase4\phase4_reduced_compile_portable.log"
Run-Vvp-And-Check `
    -VvpFile "results\rtl_phase4\tb_phase4_acc_reduced.vvp" `
    -Arguments @() `
    -LogPath "results\rtl_phase4\phase4_reduced_run_portable.log" `
    -Patterns @("PASS phase4 acc pipeline", "p_lanes=32 reduced_p_sim=1") `
    -Description "Phase 4 reduced-P" | Out-Null
Compile-Sv `
    -OutFile "results\rtl_phase4\tb_phase4_acc.vvp" `
    -Sources $phase4Sources `
    -LogPath "results\rtl_phase4\phase4_p384_compile_portable.log"
foreach ($case in @(3, 6, 7, 8, 9)) {
    $patterns = @("PASS phase4 acc pipeline", "phase4_case=$case", "p_lanes=384 reduced_p_sim=0")
    if ($case -eq 9) {
        $patterns += @("high_rate_acc_issue_cycles=40 high_rate_active_edges=76")
    }
    Run-Vvp-And-Check `
        -VvpFile "results\rtl_phase4\tb_phase4_acc.vvp" `
        -Arguments @("+phase4_case=$case") `
        -LogPath "results\rtl_phase4\phase4_case_$case.log" `
        -Patterns $patterns `
        -Description "Phase 4 case $case" | Out-Null
}

$phase5Sources = @(
    "rtl\common\nr_ldpc_pkg.sv", "rtl\common\nr_ldpc_arith.sv",
    "rtl\qc\nr_ldpc_qc_permute.sv", "rtl\check_state\nr_ldpc_c2v_reconstruct.sv",
    "rtl\rec\nr_ldpc_rec_pipeline.sv", "rtl\tb\tb_phase5_rec.sv"
)
Compile-Sv `
    -OutFile "results\rtl_phase5\tb_phase5_rec_reduced.vvp" `
    -Sources $phase5Sources `
    -Defines @("-DPHASE5_REDUCED_P=32") `
    -LogPath "results\rtl_phase5\phase5_reduced_compile_portable.log"
Run-Vvp-And-Check `
    -VvpFile "results\rtl_phase5\tb_phase5_rec_reduced.vvp" `
    -Arguments @() `
    -LogPath "results\rtl_phase5\phase5_reduced_run_portable.log" `
    -Patterns @("PASS phase5 rec pipeline", "p_lanes=32 reduced_p_sim=1", "directed_cases=21") `
    -Description "Phase 5 reduced-P" | Out-Null
Compile-Sv `
    -OutFile "results\rtl_phase5\tb_phase5_rec.vvp" `
    -Sources $phase5Sources `
    -LogPath "results\rtl_phase5\phase5_p384_compile_portable.log"
foreach ($case in @(0, 1, 2, 3)) {
    $patterns = @("PASS phase5 rec pipeline", "phase5_case=$case", "p_lanes=384 reduced_p_sim=0")
    if ($case -eq 0) {
        $patterns += @("directed_cases=21 alignment_cases=1 high_rate_rec_issue_cycles=40 high_rate_active_edges=76")
    }
    if ($case -eq 3) {
        $patterns += @("high_rate_rec_issue_cycles=40 high_rate_active_edges=76")
    }
    Run-Vvp-And-Check `
        -VvpFile "results\rtl_phase5\tb_phase5_rec.vvp" `
        -Arguments @("+phase5_case=$case") `
        -LogPath "results\rtl_phase5\phase5_case_$case.log" `
        -Patterns $patterns `
        -Description "Phase 5 case $case" | Out-Null
}

$phase6Sources = @(
    "rtl\common\nr_ldpc_pkg.sv", "rtl\common\nr_ldpc_arith.sv",
    "rtl\check_state\nr_ldpc_c2v_reconstruct.sv", "rtl\qc\nr_ldpc_qc_permute.sv",
    "rtl\acc\nr_ldpc_acc_min_update.sv", "rtl\acc\nr_ldpc_acc_context.sv",
    "rtl\acc\nr_ldpc_acc_pipeline.sv", "rtl\rec\nr_ldpc_rec_pipeline.sv",
    "rtl\storage\nr_ldpc_q_scratch.sv", "rtl\storage\nr_ldpc_check_state_store.sv",
    "rtl\core\nr_ldpc_acc_rec_datapath.sv", "rtl\tb\tb_phase6_acc_rec_storage.sv"
)
Compile-Sv `
    -OutFile "results\rtl_phase6\tb_phase6_acc_rec_storage.vvp" `
    -Sources $phase6Sources `
    -LogPath "results\rtl_phase6\phase6_compile_portable.log"
Run-Vvp-And-Check `
    -VvpFile "results\rtl_phase6\tb_phase6_acc_rec_storage.vvp" `
    -Arguments @() `
    -LogPath "results\rtl_phase6\phase6_run_portable.log" `
    -Patterns @("PASS phase6 acc rec storage", "directed_cases=20", "selected_numeric_checks=60", "distinct_payload_checks=50", "close_boundary_checks=4", "decoder_cycles=71") `
    -Description "Phase 6" | Out-Null

$phase7Sources = @(
    "rtl\common\nr_ldpc_pkg.sv", "rtl\common\nr_ldpc_arith.sv",
    "rtl\check_state\nr_ldpc_c2v_reconstruct.sv", "rtl\qc\nr_ldpc_qc_permute.sv",
    "rtl\acc\nr_ldpc_acc_min_update.sv", "rtl\acc\nr_ldpc_acc_context.sv",
    "rtl\acc\nr_ldpc_acc_pipeline.sv", "rtl\rec\nr_ldpc_rec_pipeline.sv",
    "rtl\storage\nr_ldpc_q_scratch.sv", "rtl\storage\nr_ldpc_check_state_store.sv",
    "rtl\core\nr_ldpc_acc_rec_datapath.sv", "rtl\storage\nr_ldpc_app_memory.sv",
    "rtl\storage\nr_ldpc_forward_cache.sv", "rtl\core\nr_ldpc_app_forward_datapath.sv",
    "rtl\tb\tb_phase7_app_forward.sv"
)
Compile-Sv `
    -OutFile "results\rtl_phase7\tb_phase7_app_forward.vvp" `
    -Sources $phase7Sources `
    -LogPath "results\rtl_phase7\phase7_compile_portable.log"
foreach ($case in 1..6) {
    $patterns = @("PASS phase7 app forward integration", "phase7_case=$case")
    if ($case -eq 4) {
        $patterns += @("numerical_dependency_checks=32")
    }
    if ($case -eq 5 -or $case -eq 6) {
        $patterns += @("forward_allocations=50 forwarded_reads=27 normal_reads=49 max_live_forward_entries=8", "same_bank_collisions=4 decoder_cycles=71")
    }
    Run-Vvp-And-Check `
        -VvpFile "results\rtl_phase7\tb_phase7_app_forward.vvp" `
        -Arguments @("+phase7_case=$case") `
        -LogPath "results\rtl_phase7\phase7_case_$case.log" `
        -Patterns $patterns `
        -Description "Phase 7 case $case" | Out-Null
}

$phase8Sources = @(
    "rtl\common\nr_ldpc_pkg.sv", "rtl\syndrome\nr_ldpc_syndrome_profile_bg1_first4.sv",
    "rtl\common\nr_ldpc_arith.sv", "rtl\check_state\nr_ldpc_c2v_reconstruct.sv",
    "rtl\qc\nr_ldpc_qc_permute.sv", "rtl\acc\nr_ldpc_acc_min_update.sv",
    "rtl\acc\nr_ldpc_acc_context.sv", "rtl\acc\nr_ldpc_acc_pipeline.sv",
    "rtl\rec\nr_ldpc_rec_pipeline.sv", "rtl\storage\nr_ldpc_q_scratch.sv",
    "rtl\storage\nr_ldpc_check_state_store.sv", "rtl\core\nr_ldpc_acc_rec_datapath.sv",
    "rtl\storage\nr_ldpc_app_memory.sv", "rtl\storage\nr_ldpc_forward_cache.sv",
    "rtl\core\nr_ldpc_app_forward_datapath.sv", "rtl\control\nr_ldpc_iteration_decide.sv",
    "rtl\syndrome\nr_ldpc_syndrome_engine.sv", "rtl\core\nr_ldpc_syndrome_datapath.sv",
    "rtl\tb\tb_phase8_syndrome.sv"
)
Compile-Sv `
    -OutFile "results\rtl_phase8\tb_phase8_syndrome.vvp" `
    -Sources $phase8Sources `
    -LogPath "results\rtl_phase8\phase8_compile_portable.log"
Run-Vvp-And-Check `
    -VvpFile "results\rtl_phase8\tb_phase8_syndrome.vvp" `
    -Arguments @() `
    -LogPath "results\rtl_phase8\phase8_run_portable.log" `
    -Patterns @("PASS phase8 streaming syndrome", "syndrome_completion_cycle=72", "syndrome_tail=1", "effective_boundary=72", "mixed_final_hard_bits ones=5383 zeros=4601") `
    -Description "Phase 8" | Out-Null

& (Join-Path $PSScriptRoot "run_phase9_regression.ps1") -Iverilog $IverilogExe -Vvp $VvpExe
if ($LASTEXITCODE -ne 0) {
    throw "Phase 9 selected-case script failed."
}

Write-Host "PASS full RTL regression wrapper"
