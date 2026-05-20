# Snapshot status of all three machines: Windows host, WSL sim env, KV260 board.
# Designed for an assistant to grep quickly. Each section starts with a
# clear header. Failures are reported inline; the script itself does NOT
# exit non-zero (so partial diagnostics still print).
#
# Usage:
#   .\scripts\diagnose.ps1
#   .\scripts\diagnose.ps1 -SshHost ubuntu@some-other-host

param(
    [string]$SshHost = "ubuntu@kria.tailb8a52e.ts.net"
)

$ErrorActionPreference = "Continue"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

# Pre-compute the WSL view of the repo path so we don't try to embed
# PowerShell substitutions inside `wsl -- bash -c "..."` calls (where
# the substitutions go to bash unevaluated).
function ConvertTo-WslPath {
    param([string]$WinPath)
    if ($WinPath -notmatch '^([A-Za-z]):[\\/](.*)$') { return $null }
    $drive = $matches[1].ToLower()
    $rest  = $matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
}
$wslRepoPath = ConvertTo-WslPath $repoRoot.Path

function Section($title) {
    Write-Host ""
    Write-Host "===== $title =====" -ForegroundColor Cyan
}

function Probe {
    param([string]$Label, [scriptblock]$Cmd)
    try {
        $out = & $Cmd 2>&1 | Out-String
        $out = $out.TrimEnd()
        if ($out) { Write-Host "${Label}: $out" } else { Write-Host "${Label}: (no output)" }
    } catch {
        Write-Host "${Label}: ERROR $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ---- Windows host ----
Section "Windows host"
Probe "repo"        { $repoRoot.Path }
Probe "powershell"  { $PSVersionTable.PSVersion.ToString() }
Probe "vivado"      {
    $v = Get-Command vivado -ErrorAction SilentlyContinue
    if ($v) { $v.Source } else { "NOT ON PATH (deploy.ps1 will source settings64.bat)" }
}
Probe "bootgen"     {
    $b = Get-Command bootgen -ErrorAction SilentlyContinue
    if ($b) { $b.Source } else { "NOT ON PATH (deploy.ps1 will source settings64.bat)" }
}
Probe "ssh"         { (Get-Command ssh -ErrorAction SilentlyContinue).Source }
Probe "wsl"         { (Get-Command wsl -ErrorAction SilentlyContinue).Source }

# ---- WSL sim env ----
Section "WSL"
$wslOk = (Get-Command wsl -ErrorAction SilentlyContinue) -ne $null
if (-not $wslOk) {
    Write-Host "wsl.exe not found - skipping WSL probes"
} else {
    Probe "distros"   { (((wsl -l -q) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ', ') }
    Probe "default"   { ((wsl --status) -split "`n" | Where-Object { $_ -match 'Default Distribution' } | ForEach-Object { ($_ -split ':',2)[1].Trim() }) }
    Probe "lsb"       { wsl -- bash -c "lsb_release -d 2>/dev/null | cut -f2-" }
    Probe "verilator" { wsl -- bash -c "verilator --version 2>/dev/null | head -1" }
    Probe "python"    { wsl -- bash -c "python3 --version 2>/dev/null" }

    if ($wslRepoPath) {
        $venvCheck = (wsl -- bash -c "test -x '$wslRepoPath/.venv/bin/python' && echo present || echo missing") | Out-String
        Probe "venv"   { $venvCheck.Trim() }
        if ($venvCheck.Trim() -eq "present") {
            Probe "cocotb" { wsl -- bash -c "'$wslRepoPath/.venv/bin/python' -c 'import cocotb; print(cocotb.__version__)' 2>/dev/null" }
        }
    } else {
        Write-Host "venv: cannot translate repo path to WSL"
    }
}

# ---- KV260 board ----
Section "KV260 ($SshHost)"
$sshOk = (Get-Command ssh -ErrorAction SilentlyContinue) -ne $null
if (-not $sshOk) {
    Write-Host "ssh not on PATH - skipping board probes"
} else {
    $ping = & ssh -o BatchMode=yes -o ConnectTimeout=5 $SshHost "echo up" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${SshHost}: UNREACHABLE ($ping)" -ForegroundColor Yellow
    } else {
        Probe "uptime"     { ssh $SshHost "uptime" }
        Probe "fpga state" { ssh $SshHost "cat /sys/class/fpga_manager/fpga0/state" }
        Probe "loaded app" { ssh $SshHost "sudo xmutil listapps 2>/dev/null | awk 'NR>2 && `$NF !~ /^-/ {print `$0}'" }
        Probe "pl devices" { ssh $SshHost "ls /sys/bus/platform/devices/ | grep -E 'gpio|axi|a0[0-9a-f]+' || echo '(no PL devices found)'" }
        Probe "dmesg tail" { ssh $SshHost "sudo dmesg | tail -10" }
    }
}

# ---- Repo state ----
Section "Repo"
Probe "projects"   { Get-ChildItem $repoRoot -Directory -Exclude "scripts","_template",".vscode",".venv",".verilator-build" | ForEach-Object { $_.Name } }
Probe "git branch" { git -C $repoRoot rev-parse --abbrev-ref HEAD 2>&1 }
Probe "git status" { (git -C $repoRoot status --porcelain 2>&1 | Measure-Object).Count.ToString() + " changed file(s)" }

Write-Host ""
Write-Host "===== done =====" -ForegroundColor Cyan
