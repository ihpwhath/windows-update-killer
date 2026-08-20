---
name: windows-update-killer
description: >-
  Disable or re-enable Windows Update services on the current machine.
  Use this skill when the user says things like "disable Windows Update",
  "turn off Windows Update", "stop Windows updates", "kill Windows update",
  "enable Windows Update", "restore Windows Update", or "turn updates back on".
  The skill runs a PowerShell script (requires admin elevation) that:
    - Stops and disables wuauserv, UsoSvc, WaaSMedicSvc
    - Writes group policy registry keys to block auto-update
    - Disables all related scheduled tasks
    - Does NOT touch Microsoft Store download services (dosvc, InstallService, etc.)
  Supports both DISABLE and RESTORE modes.
---

# Windows Update Killer Skill

Use this skill to **disable** or **restore** Windows Update on the user's machine.

## When to Activate

| User says | Action |
|-----------|--------|
| "禁用/关闭/停止 Windows 更新" | Disable mode |
| "disable / kill / stop Windows Update" | Disable mode |
| "恢复/开启 Windows 更新" | Restore mode |
| "enable / restore Windows Update" | Restore mode |

## Prerequisites

- Windows 10 or Windows 11
- The script must be run as **Administrator** (the launcher `.bat` handles UAC automatically)
- PowerShell 5.1+

---

## Step-by-Step Instructions

### Mode A — Disable Windows Update

1. **Determine the script path.**  
   The PowerShell script is bundled with this skill at:
   ```
   .agents/skills/windows-update-killer/scripts/Disable-WindowsUpdate.ps1
   ```
   Resolve its absolute path before running.

2. **Run the script as Administrator.**  
   Use this command (PowerShell will prompt UAC if not already elevated):
   ```powershell
   Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"<ABSOLUTE_PATH_TO_SCRIPT>`"" -Wait
   ```
   Replace `<ABSOLUTE_PATH_TO_SCRIPT>` with the resolved absolute path.

3. **Verify success.**  
   After the script exits, check service states:
   ```powershell
   Get-Service wuauserv, UsoSvc | Select-Object Name, Status, StartType
   ```
   Expected: `Status=Stopped`, `StartType=Disabled` for both.

4. **Report to the user.**  
   Confirm which services were disabled and note that Microsoft Store is unaffected.
   If `WaaSMedicSvc` registry write failed (script will print `[!]`), advise the user
   to reboot into Safe Mode and run again.

---

### Mode B — Restore Windows Update

1. **Determine the script path** (same as above).

2. **Run the script with `-Restore` flag as Administrator:**
   ```powershell
   Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"<ABSOLUTE_PATH_TO_SCRIPT>`" -Restore" -Wait
   ```

3. **Verify success.**
   ```powershell
   Get-Service wuauserv, UsoSvc | Select-Object Name, Status, StartType
   ```
   Expected: `StartType=Automatic`.

4. **Report to the user.**  
   Confirm services are restored and advise a reboot for full effect.

---

## What the Script Does (Reference)

### Disable Mode — 4 Layers of Protection

| Layer | Action |
|-------|--------|
| 1 | `wuauserv` + `UsoSvc` → `Stop-Service` + `Set-Service -StartupType Disabled` |
| 2 | `WaaSMedicSvc` registry `Start=4` (force-disabled via ACL/TakeOwnership/reg.exe fallback) |
| 3 | Group policy keys: `NoAutoUpdate=1`, `DisableWindowsUpdateAccess=1`, `AUOptions=1` |
| 4 | Scheduled tasks disabled: `Scheduled Start`, `sih`, `sihboot`, `Reboot`, `Schedule Scan`, `PerformRemediation` |

### Restore Mode

Reverses all of the above: sets `StartupType=Automatic`, `WaaSMedicSvc Start=3`,
removes policy registry keys, re-enables scheduled tasks.

### Services Preserved (Microsoft Store Safe)

`dosvc`, `InstallService`, `StorSvc`, `AppXSvc`, `ClipSVC` — never modified.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ScriptRequiresElevation` error | Must run as Administrator; use the `-Verb RunAs` approach above |
| `WaaSMedicSvc registry change failed` | Reboot into Safe Mode → run again; in Safe Mode the service doesn't load |
| Updates re-enable after reboot | WaaSMedicSvc may have restored them; run in Safe Mode for permanent fix |
| Microsoft Store not downloading | Check `dosvc` and `InstallService` are still running (`Get-Service dosvc`) |

---

## Script Reference

Full source: [Disable-WindowsUpdate.ps1](./scripts/Disable-WindowsUpdate.ps1)