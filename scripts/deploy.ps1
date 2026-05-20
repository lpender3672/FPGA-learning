# Build, package, scp and xmutil loadapp for one project in this repo.
# Auto-sources Xilinx settings64.bat so it runs from a plain PowerShell.
#
# Usage:
#   .\scripts\deploy.ps1 -Project 01-blinky
#   .\scripts\deploy.ps1 -Project 01-blinky -SkipBuild
#   .\scripts\deploy.ps1 -Project 02-counter -AppName custom-name

param(
    [Parameter(Mandatory=$true)][string]$Project,
    [switch]$SkipBuild,
    [string]$AppName,
    [string]$SshHost = "ubuntu@kria.tailb8a52e.ts.net",
    [string]$XilinxRoot = "C:\AMDDesignTools\2025.2"
)

$ErrorActionPreference = "Stop"

# Machine-parseable last-line marker for assistants / scripts:
#   [result] deploy ok                | success
#   [result] deploy fail: <reason>    | any throw
trap {
    Write-Host "[result] deploy fail: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$repoRoot    = Resolve-Path (Join-Path $PSScriptRoot "..")
$projectDir  = Join-Path $repoRoot $Project
if (-not (Test-Path $projectDir)) { throw "Project not found: $projectDir" }
if (-not $AppName) { $AppName = $Project }

$buildDir = Join-Path $projectDir "build"
$pkgDir   = Join-Path $buildDir "pkg"

# 0. Source Xilinx env into this session if vivado isn't already on PATH.
function Import-XilinxEnv {
    param([string]$BatPath)
    if (-not (Test-Path $BatPath)) { throw "Settings batch not found: $BatPath" }
    $marker = "===XILINX-ENV==="
    $out = cmd /c "`"$BatPath`" >nul 2>&1 && echo $marker && set"
    $past = $false
    foreach ($line in $out) {
        if (-not $past) { if ($line -eq $marker) { $past = $true }; continue }
        if ($line -match "^([^=]+)=(.*)$") {
            Set-Item -Path "Env:$($matches[1])" -Value $matches[2] -ErrorAction SilentlyContinue
        }
    }
}

if (-not (Get-Command vivado -ErrorAction SilentlyContinue)) {
    Write-Host "==> sourcing Xilinx env from $XilinxRoot" -ForegroundColor Cyan
    Import-XilinxEnv (Join-Path $XilinxRoot "Vivado\settings64.bat")
    Import-XilinxEnv (Join-Path $XilinxRoot "Vitis\settings64.bat")
}

foreach ($tool in @("vivado", "bootgen")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool not on PATH after sourcing settings64.bat. Check -XilinxRoot."
    }
}

# All paths in build.tcl are relative to the project dir.
Set-Location $projectDir

# 1. Vivado build
if (-not $SkipBuild) {
    Write-Host "==> [$Project] Vivado build" -ForegroundColor Cyan
    & vivado -mode batch -source (Join-Path $projectDir "hw\build.tcl")
    if ($LASTEXITCODE -ne 0) { throw "Vivado build failed" }
}

$bitPath = Join-Path $buildDir "design.bit"
if (-not (Test-Path $bitPath)) {
    throw "$bitPath not found. Run without -SkipBuild first."
}

# 2. .bit -> .bit.bin (bootgen)
Write-Host "==> [$Project] bootgen" -ForegroundColor Cyan
Push-Location $buildDir
& bootgen -arch zynqmp -process_bitstream bin -image (Join-Path $projectDir "firmware\design.bif") -w
Pop-Location

# 3. Assemble package directory (dtc runs on the board, not here)
Write-Host "==> [$Project] packaging" -ForegroundColor Cyan
if (Test-Path $pkgDir) { Remove-Item -Recurse -Force $pkgDir }
New-Item -ItemType Directory -Path $pkgDir | Out-Null
Copy-Item (Join-Path $buildDir "design.bit.bin")     (Join-Path $pkgDir "$AppName.bit.bin")
Copy-Item (Join-Path $projectDir "firmware\shell.json") $pkgDir

# Rewrite the dts firmware-name to match the deployed .bit.bin. Source dts
# can use any placeholder (or its own project name); the on-board dtbo MUST
# reference "<AppName>.bit.bin" or xmutil's FPGA-manager bind step fails
# with "Load Error: -1".
$dtsSrc = Get-Content (Join-Path $projectDir "firmware\pl.dts") -Raw
$dtsOut = [regex]::Replace($dtsSrc, 'firmware-name\s*=\s*"[^"]*"', "firmware-name = `"$AppName.bit.bin`"")
Set-Content -Path (Join-Path $pkgDir "$AppName.dts") -Value $dtsOut -Encoding ASCII

# 4. Ship to board, compile dtbo there, install, and load
Write-Host "==> [$Project] deploy to $SshHost" -ForegroundColor Cyan
& ssh $SshHost "rm -rf /tmp/$AppName"
& scp -r $pkgDir "${SshHost}:/tmp/$AppName"
if ($LASTEXITCODE -ne 0) { throw "scp failed" }

$remoteScript = @'
set -e
cd /tmp/__APP__
if ! command -v dtc >/dev/null; then
    sudo apt-get update && sudo apt-get install -y device-tree-compiler
fi
dtc -@ -I dts -O dtb -o __APP__.dtbo __APP__.dts
rm -f __APP__.dts
sudo rm -rf /lib/firmware/xilinx/__APP__
sudo mv /tmp/__APP__ /lib/firmware/xilinx/__APP__
sudo xmutil unloadapp >/dev/null 2>&1 || true
sudo xmutil loadapp __APP__
sudo xmutil listapps
'@
$remoteScript = $remoteScript.Replace("__APP__", $AppName)

& ssh $SshHost $remoteScript
if ($LASTEXITCODE -ne 0) { throw "remote load failed" }

# 5. Ship the test script
$testScript = Join-Path $projectDir "sw\test.sh"
if (Test-Path $testScript) {
    & scp $testScript "${SshHost}:~/test.sh"
    & ssh $SshHost "chmod +x ~/test.sh"
}

Write-Host "==> [$Project] done. Run: ssh $SshHost ./test.sh" -ForegroundColor Green
Write-Host "[result] deploy ok"
