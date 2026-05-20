# Thin wrapper: invokes scripts/sim.sh inside WSL.
#
# Usage:
#   .\scripts\sim.ps1 -Project 01-blinky
#   .\scripts\sim.ps1 -Project 01-blinky -Distro Ubuntu

param(
    [Parameter(Mandatory=$true)][string]$Project,
    [string]$Distro = ""
)

$ErrorActionPreference = "Stop"

# Machine-parseable last-line marker for assistants / scripts:
#   [result] sim ok                | all tests passed
#   [result] sim fail: <reason>    | any failure
trap {
    Write-Host "[result] sim fail: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    throw "wsl.exe not found. Install WSL with: wsl --install -d Ubuntu"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function ConvertTo-WslPath {
    param([string]$WinPath)
    if ($WinPath -notmatch '^([A-Za-z]):[\\/](.*)$') {
        throw "Cannot translate $WinPath to a WSL path"
    }
    $drive = $matches[1].ToLower()
    $rest  = $matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
}
$wslPath = ConvertTo-WslPath $repoRoot

$wslArgs = @()
if ($Distro) { $wslArgs += @("-d", $Distro) }
$wslArgs += @("--cd", $wslPath, "--", "bash", "scripts/sim.sh", "-p", $Project)
& wsl @wslArgs
if ($LASTEXITCODE -ne 0) { throw "Simulation failed (exit $LASTEXITCODE)" }
Write-Host "[result] sim ok"
