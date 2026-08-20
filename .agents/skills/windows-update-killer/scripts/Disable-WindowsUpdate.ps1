#Requires -RunAsAdministrator
param([switch]$Restore)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step { param($msg) Write-Host "  [*] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  [X] $msg" -ForegroundColor Red }

$ServicesToDisable = @(
    @{ Name = 'wuauserv';     Display = 'Windows Update' },
    @{ Name = 'UsoSvc';       Display = 'Update Orchestrator Service' },
    @{ Name = 'WaaSMedicSvc'; Display = 'Windows Update Medic Service' }
)
$ServicesToKeep = @('dosvc','InstallService','StorSvc','AppXSvc','ClipSVC')

if ($Restore) {
    Write-Host "`n  Restoring Windows Update services...`n" -ForegroundColor Magenta
    foreach ($svc in $ServicesToDisable) {
        try {
            Set-Service   -Name $svc.Name -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
            Write-OK "Restored: $($svc.Name)"
        } catch { Write-Warn "Could not restore $($svc.Name): $_" }
    }
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            'SYSTEM\CurrentControlSet\Services\WaaSMedicSvc', $true)
        if ($key) { $key.SetValue('Start', 3, [Microsoft.Win32.RegistryValueKind]::DWord); $key.Close() }
        Write-OK "WaaSMedicSvc registry restored (Start=3)"
    } catch { Write-Warn "Registry restore failed: $_" }
    $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    if (Test-Path $policyPath) {
        Remove-Item -Path $policyPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "Group policy registry cleared"
    }
    $tasks = @(
        @{Path='\Microsoft\Windows\WindowsUpdate\';      Name='Scheduled Start'},
        @{Path='\Microsoft\Windows\UpdateOrchestrator\'; Name='Schedule Scan'},
        @{Path='\Microsoft\Windows\WaaSMedic\';          Name='PerformRemediation'}
    )
    foreach ($t in $tasks) {
        try { Enable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -EA SilentlyContinue | Out-Null; Write-OK "Task enabled: $($t.Name)" } catch {}
    }
    Write-Host "`n  Done. Please reboot.`n" -ForegroundColor Green
    return
}

Write-Host "`n  Disabling Windows Update services`n" -ForegroundColor Magenta

# Step 1: Force-disable WaaSMedicSvc via registry
Write-Host "[Step 1] Force-disable WaaSMedicSvc (self-healing guardian)" -ForegroundColor Yellow
$medicOK = $false
$regPath = 'SYSTEM\CurrentControlSet\Services\WaaSMedicSvc'
# Try A: direct write
try {
    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($regPath, $true)
    if ($k) { $k.SetValue('Start', 4, [Microsoft.Win32.RegistryValueKind]::DWord); $k.Close(); Write-OK "Direct write Start=4"; $medicOK = $true }
} catch { Write-Warn "Direct write failed, trying TakeOwnership..." }
# Try B: take ownership then write
if (-not $medicOK) {
    try {
        $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            $regPath,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::TakeOwnership)
        $acl = $k.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
        $acl.SetOwner([System.Security.Principal.NTAccount]'Administrators')
        $k.SetAccessControl($acl)
        $acl2 = $k.GetAccessControl()
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            [System.Security.Principal.NTAccount]'Administrators',
            [System.Security.AccessControl.RegistryRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow)
        $acl2.SetAccessRule($rule)
        $k.SetAccessControl($acl2)
        $k.Close()
        $k2 = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($regPath, $true)
        $k2.SetValue('Start', 4, [Microsoft.Win32.RegistryValueKind]::DWord)
        $k2.Close()
        Write-OK "TakeOwnership write Start=4"
        $medicOK = $true
    } catch { Write-Warn "TakeOwnership failed: $_" }
}
# Try C: reg.exe
if (-not $medicOK) {
    try {
        & reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-OK "reg.exe write Start=4"; $medicOK = $true }
        else { Write-Fail "reg.exe failed" }
    } catch { Write-Fail "reg.exe exception: $_" }
}
try { Stop-Service -Name 'WaaSMedicSvc' -Force -EA SilentlyContinue; Write-OK "WaaSMedicSvc stopped" } catch { Write-Warn "Could not stop WaaSMedicSvc" }

Write-Host ""

# Step 2: Stop and disable wuauserv + UsoSvc
Write-Host "[Step 2] Stop and disable Windows Update services" -ForegroundColor Yellow
foreach ($svc in $ServicesToDisable | Where-Object { $_.Name -ne 'WaaSMedicSvc' }) {
    Write-Step "$($svc.Display) ($($svc.Name))"
    try {
        $s = Get-Service -Name $svc.Name -EA SilentlyContinue
        if (-not $s) { Write-Warn "Service not found, skipped"; continue }
        Stop-Service -Name $svc.Name -Force -EA SilentlyContinue
        Set-Service  -Name $svc.Name -StartupType Disabled
        Write-OK "Stopped + Disabled"
    } catch { Write-Fail "$_" }
}
Write-Host ""

# Step 3: Group policy registry
Write-Host "[Step 3] Write group policy registry (block auto-update)" -ForegroundColor Yellow
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$au  = "$pol\AU"
foreach ($p in @($pol,$au)) { if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null } }
Set-ItemProperty -Path $au  -Name 'NoAutoUpdate'                  -Value 1 -Type DWord -Force
Set-ItemProperty -Path $au  -Name 'AUOptions'                     -Value 1 -Type DWord -Force
Set-ItemProperty -Path $au  -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1 -Type DWord -Force
Set-ItemProperty -Path $pol -Name 'DisableWindowsUpdateAccess'    -Value 1 -Type DWord -Force
Set-ItemProperty -Path $pol -Name 'DisableOSUpgrade'              -Value 1 -Type DWord -Force
Write-OK "Policy registry written"
Write-Host ""

# Step 4: Disable scheduled tasks
Write-Host "[Step 4] Disable Windows Update scheduled tasks" -ForegroundColor Yellow
$tasks = @(
    @{Path='\Microsoft\Windows\WindowsUpdate\';      Name='Scheduled Start'},
    @{Path='\Microsoft\Windows\WindowsUpdate\';      Name='sih'},
    @{Path='\Microsoft\Windows\WindowsUpdate\';      Name='sihboot'},
    @{Path='\Microsoft\Windows\UpdateOrchestrator\'; Name='Reboot'},
    @{Path='\Microsoft\Windows\UpdateOrchestrator\'; Name='Schedule Scan'},
    @{Path='\Microsoft\Windows\UpdateOrchestrator\'; Name='Schedule Scan Static Task'},
    @{Path='\Microsoft\Windows\UpdateOrchestrator\'; Name='USO_UxBroker'},
    @{Path='\Microsoft\Windows\WaaSMedic\';          Name='PerformRemediation'}
)
foreach ($t in $tasks) {
    try {
        $task = Get-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -EA SilentlyContinue
        if ($task) { Disable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -EA SilentlyContinue | Out-Null; Write-OK "Disabled: $($t.Name)" }
    } catch { Write-Warn "Skipped: $($t.Name)" }
}
Write-Host ""

# Step 5: Verify Store services untouched
Write-Host "[Step 5] Verify Microsoft Store services (should be unaffected)" -ForegroundColor Yellow
foreach ($name in $ServicesToKeep) {
    $s = Get-Service -Name $name -EA SilentlyContinue
    if ($s) {
        $wmi = Get-WmiObject Win32_Service -Filter "Name='$name'" -EA SilentlyContinue
        Write-OK "$name  Status=$($s.Status)  StartMode=$($wmi.StartMode)"
    }
}
Write-Host ""
Write-Host "  All done!" -ForegroundColor Magenta
Write-Host "  Disabled: wuauserv, UsoSvc, WaaSMedicSvc + policy registry + scheduled tasks" -ForegroundColor Gray
Write-Host "  Kept:     dosvc, InstallService, StorSvc, AppXSvc, ClipSVC" -ForegroundColor Gray
if (-not $medicOK) {
    Write-Host ""
    Write-Warn "WaaSMedicSvc registry change may have failed."
    Write-Warn "For full effect, reboot into Safe Mode and run again."
}
Write-Host ""
Write-Host "  To restore: .\Disable-WindowsUpdate.ps1 -Restore" -ForegroundColor Cyan