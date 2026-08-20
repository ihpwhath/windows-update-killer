<div align="center">

# 🛡️ Windows Update Killer

**一键彻底禁用 Windows 自动更新 | One-click to permanently disable Windows Update**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue)](https://github.com/ihpwhath/windows-update-killer)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://github.com/ihpwhath/windows-update-killer)

> 不是把更新时间推迟到 2124 年，是真正禁掉它。  
> Not just delaying updates to year 2124 — actually killing them.

</div>

---

## 🤖 AI Agent Skill — 说句话，让 AI 帮你搞定

**装上这个 Skill，你只需要跟 AI 说一句话，它会自动帮你禁用或恢复 Windows 更新。**  
Install this as an **Antigravity agent skill** — just describe what you want, the AI handles everything.

### 安装方法 | Installation

把 `.agents/` 文件夹复制到你的任意项目根目录：  
Copy the `.agents/` folder into your project root:

```powershell
git clone https://github.com/ihpwhath/windows-update-killer.git
Copy-Item -Recurse windows-update-killer\.agents\ .\
```

目录结构如下 | Directory structure:

```
your-project/
└── .agents/
    └── skills/
        └── windows-update-killer/
            ├── SKILL.md
            └── scripts/
                └── Disable-WindowsUpdate.ps1
```

### 装好之后，直接跟 AI 说 | Just talk to your agent

| 你说 / You say | AI 做什么 / Agent does |
|----------------|------------------------|
| 帮我禁用 Windows 更新 | 运行四层禁用，彻底关掉自动更新 |
| 关掉 Windows 自动更新 | 同上 |
| 恢复 Windows 更新 | 一键恢复所有更新服务 |
| disable Windows Update | Runs 4-layer disable mode |
| kill / stop Windows updates | Runs 4-layer disable mode |
| restore / enable Windows Update | Restores all update services |

> AI 会自动请求 UAC 管理员权限，执行完后汇报结果，全程不用你动手。  
> The agent auto-requests UAC admin rights, runs the script, and reports back — zero manual steps.

---

## 🇨🇳 中文说明

### 解决了什么问题？

Windows 自带的"暂停更新"最多只能推迟 35 天，网上流传的"推迟到 2124 年"方案也只是治标不治本。本工具通过**四层拦截**彻底禁止 Windows 自动更新：

| 层级 | 方式 | 说明 |
|------|------|------|
| 第一层 | 服务禁用 | `wuauserv` / `UsoSvc` 设为 `Disabled` |
| 第二层 | 注册表强制写入 | `WaaSMedicSvc`（自愈守护进程）`Start=4`，防止它自动恢复其他更新服务 |
| 第三层 | 组策略注册表 | `NoAutoUpdate=1` / `DisableWindowsUpdateAccess=1` |
| 第四层 | 计划任务禁用 | 禁用 WindowsUpdate / UpdateOrchestrator / WaaSMedic 全部计划任务 |

### ✅ 不影响 Microsoft Store 下载

以下服务**完全不动**，应用商店下载、安装照常：

- `dosvc` — Delivery Optimization（应用商店下载加速）
- `InstallService` — Microsoft Store Install Service
- `StorSvc` / `AppXSvc` / `ClipSVC`

### 📂 文件说明

| 文件 | 用途 |
|------|------|
| `RunAsAdmin.bat` | **双击运行** → 自动请求管理员权限 → 禁用更新 |
| `RestoreWindowsUpdate.bat` | **双击运行** → 恢复所有 Windows 更新服务 |
| `Disable-WindowsUpdate.ps1` | 核心脚本，支持 `-Restore` 参数 |

### 🚀 使用方法

**禁用更新（推荐）：**
```
双击 RunAsAdmin.bat → UAC 弹窗点「是」→ 等待完成
```

**恢复更新：**
```
双击 RestoreWindowsUpdate.bat → UAC 弹窗点「是」→ 等待完成
```

**命令行方式：**
```powershell
# 禁用
powershell -ExecutionPolicy Bypass -File Disable-WindowsUpdate.ps1

# 恢复
powershell -ExecutionPolicy Bypass -File Disable-WindowsUpdate.ps1 -Restore
```

### ⚠️ 注意事项

- 必须以**管理员身份**运行
- `WaaSMedicSvc` 是微软的受保护服务。若注册表修改失败，脚本会提示，可**重启进入安全模式**后再次运行
- 禁用后 Windows 不会再自动安装安全补丁，需自行评估风险
- 随时可通过 `RestoreWindowsUpdate.bat` 一键恢复

---

## 🇬🇧 English Guide

### What does this do?

Windows' built-in "Pause Updates" only lasts 35 days. The popular "delay to year 2124" trick is just a workaround. This tool uses **4 layers of protection** to truly kill Windows Update:

| Layer | Method | Details |
|-------|--------|---------|
| Layer 1 | Service disable | `wuauserv` / `UsoSvc` set to `Disabled` |
| Layer 2 | Registry force-write | `WaaSMedicSvc` (self-healing guardian) `Start=4` — prevents it from re-enabling other update services |
| Layer 3 | Group policy registry | `NoAutoUpdate=1` / `DisableWindowsUpdateAccess=1` |
| Layer 4 | Scheduled task disable | All WindowsUpdate / UpdateOrchestrator / WaaSMedic tasks disabled |

### ✅ Microsoft Store downloads are unaffected

These services are **never touched**:

- `dosvc` — Delivery Optimization (used by Store)
- `InstallService` — Microsoft Store Install Service
- `StorSvc` / `AppXSvc` / `ClipSVC`

### 📂 Files

| File | Purpose |
|------|---------|
| `RunAsAdmin.bat` | **Double-click** → auto-requests admin rights → disables updates |
| `RestoreWindowsUpdate.bat` | **Double-click** → restores all Windows Update services |
| `Disable-WindowsUpdate.ps1` | Core script, supports `-Restore` flag |

### 🚀 Usage

**Disable updates (recommended):**
```
Double-click RunAsAdmin.bat → click "Yes" on UAC prompt → done
```

**Restore updates:**
```
Double-click RestoreWindowsUpdate.bat → click "Yes" on UAC prompt → done
```

**Command line:**
```powershell
# Disable
powershell -ExecutionPolicy Bypass -File Disable-WindowsUpdate.ps1

# Restore
powershell -ExecutionPolicy Bypass -File Disable-WindowsUpdate.ps1 -Restore
```

### ⚠️ Notes

- Must be run as **Administrator**
- `WaaSMedicSvc` is a protected Windows service. If registry write fails, the script will warn you — reboot into **Safe Mode** and run again for full effect
- Disabling updates means no automatic security patches — assess the risk yourself
- Restore anytime with `RestoreWindowsUpdate.bat`

---

## 📄 License

MIT — free to use, modify, and distribute.

---

<div align="center">

**如果这个工具在你最关键的时刻帮你挡住了强制更新重启，给个 ⭐ 吧**  
**If this saved you from a 3-hour Windows update at the worst possible moment, give it a ⭐**

</div>