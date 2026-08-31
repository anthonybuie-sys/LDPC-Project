param(
    [string]$Python = $env:PYTHON
)

. (Join-Path $PSScriptRoot "rtl_regression_common.ps1")

$RepoRoot = Get-RepoRoot
Set-Location $RepoRoot

$PythonExe = Resolve-RequiredTool -Name "python" -EnvironmentVariable "PYTHON" -Override $Python
Write-Host "Python tool:"
& $PythonExe --version

$text = Invoke-Logged `
    -Exe $PythonExe `
    -Arguments @("tests\run_tests.py") `
    -LogPath "results\final\python_regression.log"

Assert-Matches -Text $text -Pattern "76 passed" -Description "full Python regression 76 passed"
Write-Host "PASS full Python regression: 76 passed"
