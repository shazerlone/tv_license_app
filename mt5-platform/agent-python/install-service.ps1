# Installs the MT5 Agent as a Windows service using NSSM.
# Run in an elevated PowerShell.  Prereqs: Python 3.11+, NSSM (https://nssm.cc).
#
#   .\install-service.ps1 -InstallDir "C:\mt5agent"

param(
    [string]$InstallDir = "C:\mt5agent",
    [string]$ServiceName = "MT5Agent",
    [string]$PythonExe = "C:\Python311\python.exe",
    [string]$NssmExe = "C:\nssm\nssm.exe"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Preparing $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\logs" | Out-Null

# Copy agent sources next to this script into the install dir.
Copy-Item "$PSScriptRoot\*.py"   $InstallDir -Force
Copy-Item "$PSScriptRoot\requirements.txt" $InstallDir -Force
if (-not (Test-Path "$InstallDir\config.yaml")) {
    Copy-Item "$PSScriptRoot\config.example.yaml" "$InstallDir\config.yaml"
    Write-Warning "Edit $InstallDir\config.yaml with your API URL + agent token before starting."
}

Write-Host "==> Installing Python dependencies"
& $PythonExe -m pip install --upgrade pip | Out-Null
& $PythonExe -m pip install -r "$InstallDir\requirements.txt"

# Lock down config.yaml so only SYSTEM + Administrators can read it (it holds the token).
Write-Host "==> Hardening config.yaml ACL"
icacls "$InstallDir\config.yaml" /inheritance:r /grant:r "SYSTEM:(R)" "Administrators:(R)" | Out-Null

Write-Host "==> Registering service '$ServiceName'"
& $NssmExe install $ServiceName $PythonExe "$InstallDir\agent.py" "--config" "$InstallDir\config.yaml"
& $NssmExe set $ServiceName AppDirectory $InstallDir
& $NssmExe set $ServiceName AppStdout "$InstallDir\logs\service.out.log"
& $NssmExe set $ServiceName AppStderr "$InstallDir\logs\service.err.log"
& $NssmExe set $ServiceName AppRotateFiles 1
& $NssmExe set $ServiceName AppRotateBytes 10485760
& $NssmExe set $ServiceName Start SERVICE_AUTO_START
# Auto-restart on crash, throttled.
& $NssmExe set $ServiceName AppExit Default Restart
& $NssmExe set $ServiceName AppRestartDelay 5000

Write-Host "==> Starting service"
& $NssmExe start $ServiceName

Write-Host "Done. Manage with: nssm status/stop/restart $ServiceName"
