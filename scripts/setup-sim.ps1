# Thin wrapper: invokes scripts/setup-sim.sh inside WSL. Cocotb 2.x dropped
# xsim, and Verilator on Windows is a MinGW nightmare, so sim runs in WSL.
#
# Usage:
#   .\scripts\setup-sim.ps1
#   .\scripts\setup-sim.ps1 -Distro Ubuntu

param(
    [string]$Distro = ""
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    throw "wsl.exe not found. Install WSL with: wsl --install -d Ubuntu"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# Detect a leftover Windows venv from earlier Icarus attempts.
$winVenv = Join-Path $repoRoot ".venv\Scripts"
if (Test-Path $winVenv) {
    Write-Warning ".venv is a Windows-built venv from an earlier run."
    Write-Warning "Delete it before continuing:  Remove-Item -Recurse -Force .\.venv"
    throw "Refusing to mix Windows and Linux venvs at the same path."
}

# Translate C:\foo\bar -> /mnt/c/foo/bar. PowerShell mangles backslashes
# when passing args to wsl.exe, so we do the translation here instead of
# shelling out to `wslpath`.
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

Write-Host "==> running scripts/setup-sim.sh inside WSL at $wslPath" -ForegroundColor Cyan
$wslArgs = @()
if ($Distro) { $wslArgs += @("-d", $Distro) }
$wslArgs += @("--cd", $wslPath, "--", "bash", "scripts/setup-sim.sh")
& wsl @wslArgs
if ($LASTEXITCODE -ne 0) { throw "WSL setup failed (exit $LASTEXITCODE)" }
