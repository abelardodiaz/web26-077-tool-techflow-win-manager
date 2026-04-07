# DEV-GUIDE.md

Development guide and conventions for this repository.

## Project

TechFlow Suite Pro v5.0 - Modular Windows IT Support Toolkit. Refactored from a monolithic 779-line PowerShell script into a modular architecture with security, logging, and input validation.

## Build & Run

```bash
# Run from USB or local (resolves ExecutionPolicy automatically)
./Launch-TechFlow.cmd

# Run directly in PowerShell (requires admin + bypass)
powershell -NoProfile -ExecutionPolicy Bypass -File Start-TechFlow.ps1

# Run Pester tests
Invoke-Pester ./tests/
```

## Architecture

- **Entry**: `Launch-TechFlow.cmd` -> `Start-TechFlow.ps1` -> imports `TechFlow.psd1`
- **Module loading**: `TechFlow.psd1` uses `NestedModules` to load all submodules (no manual dot-sourcing)
- **Core dependency**: All modules depend on `modules/Core/Core.psm1` (loaded first)
- **Config**: `config/techflow.config.json` (JSON, read/written via .NET APIs for UTF-8 safety)
- **App catalog**: `config/apps-catalog.json` (100+ apps with winget IDs, profiles, bloatware list)
- **Logging**: Dual - `Start-Transcript` (captures native binary output) + `Write-TFLog` (structured business logging)
- **Pre-flight**: `Get-TFSystemState` runs at startup, stores results in `$Global:TFState` (Windows version, internet, winget, choco availability)

### Modules

| Module | Functions | Purpose |
|--------|-----------|---------|
| Core | Write-TFLog, Get-TFConfig, Assert-TF*, Confirm-TFDangerousAction | Foundation: logging, config, validation, UI, security |
| Backup | Invoke-TFBackupRestore | Profile backup/restore with robocopy |
| Packages | Invoke-TFSmartInstall, Invoke-TFAppCatalog, Invoke-TFPackageManager | Hybrid winget/choco installation |
| System | Invoke-TFTempCleanup, Show-TFSystemMonitor, Invoke-TFAutoMaintenance | Temp files, process monitor, auto-flow |
| Security | Invoke-TFDefenderControl, Invoke-TFWin11Bypass | Defender registry, Win11 bypass |
| Network | Invoke-TFNetworkTools | Reset, ping, WiFi keys, tracert |
| Maintenance | Invoke-TFTechSupport, Invoke-TFDiskMaintenance | SFC/DISM, disk ops, BIOS key |
| Users | Invoke-TFUserManagement | Local account CRUD |
| Drivers | Invoke-TFDriverManagement | Export/restore/update drivers |
| DangerZone | Invoke-TFPurgeAndFormat, Invoke-TFExternalTool | Destructive ops, external scripts |

## Key Conventions

- PowerShell 5.1 only (no PS7 syntax: `?.`, `??`, ternary)
- All file I/O uses `[System.IO.File]::WriteAllText/ReadAllText` with UTF8 encoding (never `Out-File` for config/JSON)
- All user input validated through `Assert-TF*` functions before use
- Destructive operations require `Confirm-TFDangerousAction` (PIN + master password)
- Passwords hashed with SHA256 + salt (never plaintext)
- External script execution: download to temp file, log SHA256, confirm, execute with `&` (never `Invoke-Expression`)
- No emojis in scripts (encoding issues on Windows PowerShell)
- Everything relative to `$PSScriptRoot` for USB portability
