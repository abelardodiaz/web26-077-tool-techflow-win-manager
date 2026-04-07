# Plan: TechFlow Suite Pro — Clonar, Modularizar, Securizar

**Fecha:** 2026-04-07
**Revisado por:** Gemini 3.1 Pro (ticket #925 API 900)
**Repo origen:** [LUISFGARCIAE/TechFlow_Suite_Pro](https://github.com/LUISFGARCIAE/TechFlow_Suite_Pro) (MIT)

## Contexto

El repo origen es un toolkit de soporte IT para Windows: un script monolitico de 779 lineas PowerShell con 17 opciones de menu. Tiene funcionalidad solida pero problemas criticos: password en texto plano, ejecucion remota sin verificacion (`Invoke-Expression` en URLs), cero logging, cero manejo de errores, input sin validar, y 140 lineas de logica inline sin funciones.

El objetivo es clonarlo y reconstruirlo como un proyecto modular, seguro y con logging estructurado, manteniendo toda la funcionalidad existente.

---

## Estructura de Carpetas

```
TechFlowSuitePro/
|-- Launch-TechFlow.cmd              # Wrapper .cmd (resuelve ExecutionPolicy en USB)
|-- Start-TechFlow.ps1               # Entry point PS (~60 lineas)
|-- TechFlow.psd1                    # Module manifest (carga modulos via NestedModules)
|-- config/
|   |-- techflow.config.json         # Config JSON (reemplaza suite_config.dat)
|   |-- apps-catalog.json            # Catalogo de 100+ apps (extraido del hardcode)
|-- modules/
|   |-- Core/Core.psm1               # Logger, config, validacion, UI helpers, pre-flight
|   |-- Backup/Backup.psm1           # Backup/restore de perfiles
|   |-- Packages/Packages.psm1       # Instalacion hibrida winget/choco
|   |-- System/System.psm1           # Temp cleanup, monitor, auto-flow
|   |-- Security/Security.psm1       # Defender, Win11 bypass, credenciales
|   |-- Network/Network.psm1         # Red, ping, WiFi, tracert
|   |-- Maintenance/Maintenance.psm1 # Disco, SFC/DISM, BIOS key
|   |-- Users/Users.psm1             # Gestion de usuarios locales
|   |-- Drivers/Drivers.psm1         # Drivers backup/restore/update
|   |-- DangerZone/DangerZone.psm1   # Purge, format, scripts externos
|-- vendor/                           # Herramientas de terceros incluidas offline
|-- logs/                             # Creado en runtime
|-- tests/                            # Pester tests
|   |-- Core.Tests.ps1               # TDD — se escriben en Fase 1 junto con Core
```

### Decisiones de arquitectura

- **`Launch-TechFlow.cmd`** como wrapper para resolver ExecutionPolicy al ejecutar desde USB
- **`NestedModules` en `.psd1`** en vez de un loader `.psm1` manual (forma nativa de PowerShell)
- **`vendor/`** para herramientas de terceros pre-descargadas (modo offline)
- **Tests en Fase 1 (TDD)** para Core — si el Core falla, todo colapsa

---

## Orden de Implementacion

### Fase 1: Fundacion + Tests del Core (TDD)

1. **Clonar repo** y crear estructura de carpetas
2. **`Launch-TechFlow.cmd`** — wrapper que resuelve ExecutionPolicy:
   ```cmd
   @echo off
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-TechFlow.ps1"
   pause
   ```
3. **`config/techflow.config.json`** — config por defecto con hash+salt de password, paths, colores, logging settings
4. **`modules/Core/Core.psm1`** (~220 lineas) — funciones base:
   - `Write-TFLog` — log a archivo con formato `[timestamp] [LEVEL] [Component] mensaje`, rotacion por dias
   - `Get-TFConfig` — carga JSON con `[System.IO.File]::ReadAllText()`, crea defaults si no existe
   - `Save-TFConfig` — escribe JSON con `[System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)` (nunca Out-File)
   - `Test-TFAdminPrivilege` — verifica ejecucion como admin
   - `Get-TFSystemState` — **PRE-FLIGHT CHECK**: detecta version Windows, internet disponible, winget instalado, choco instalado. Guarda en `$Global:TFState` (read-only)
   - `Confirm-TFDangerousAction` — PIN random + password hash+salt para ops destructivas
   - `Get-TFCredentialHash` — SHA256 con salt estatico: `SHA256(password + salt)`
   - `Test-TFCredential` — compara hash+salt contra config
   - `Assert-TFValidPath` — valida paths (sin traversal, sin null bytes)
   - `Assert-TFValidDriveLetter` — solo A-Z, rechaza drive del sistema
   - `Assert-TFValidUsername` — regex `^[a-zA-Z0-9_\-\.]{1,20}$`
   - `Show-TFTitle` — banner ASCII
   - `Show-TFMenu` / `Read-TFChoice` — menu generalizado con validacion
5. **`tests/Core.Tests.ps1`** — Pester tests escritos EN PARALELO con Core (TDD):
   - Tests para cada Assert-TF* (paths con `..`, usernames con `;`, drive letters invalidos)
   - Tests para Get-TFCredentialHash (hash+salt correcto)
   - Tests para Get-TFSystemState (mock de estados)
6. **`TechFlow.psd1`** — manifest con `PowerShellVersion = '5.1'` y `NestedModules` cargando todos los submodulos
7. **`Start-TechFlow.ps1`** — entry point: `Start-Transcript`, importa modulo, pre-flight, main loop con switch delegando a modulos

### Fase 2: Modulos de datos (sin operaciones destructivas)

8. **`modules/Backup/Backup.psm1`** (~180 lineas) — `Get-TFUserProfilePaths`, `Get-TFBackupRoot`, `Backup-TFProfileData`, `Restore-TFProfileData`, `Invoke-TFBackupRestore`
   - Robocopy via `Start-Process -Wait -PassThru`, error solo si `$process.ExitCode -ge 8` (codigos 0-7 son exito)
   - Validar paths con `Assert-TFValidPath`
   - Logging de cada operacion
9. **`modules/Packages/Packages.psm1`** (~200 lineas) — `Invoke-TFSmartInstall`, `Invoke-TFAppCatalog`, `Invoke-TFPackageManager`
   - Catalogo desde JSON
   - Choco install seguro (descargar a archivo, no iex)
   - Consultar `$Global:TFState.WingetAvailable` antes de intentar winget — si no existe, ir directo a choco
10. **`config/apps-catalog.json`** — 100+ apps con id/nombre/categoria + perfiles predefinidos + lista bloatware

### Fase 3: Modulos de sistema

11. **`modules/System/System.psm1`** (~150 lineas) — `Invoke-TFTempCleanup`, `Show-TFSystemMonitor`, `Invoke-TFAutoMaintenance`
    - try/catch por archivo en cleanup, validar PID/nombre antes de kill
12. **`modules/Drivers/Drivers.psm1`** (~80 lineas) — `Invoke-TFDriverManagement`
    - try/catch en Export-WindowsDriver, install seguro de PSWindowsUpdate
13. **`modules/Network/Network.psm1`** (~100 lineas) — `Invoke-TFNetworkTools` con subfunciones (reset, ping, WiFi, tracert, speedtest)
    - Validar hostname/IP con regex, rechazar metacaracteres shell
    - Consultar `$Global:TFState.InternetAvailable` para operaciones que requieren red
14. **`modules/Maintenance/Maintenance.psm1`** (~100 lineas) — `Invoke-TFDiskMaintenance`, `Get-TFDiskHealth`, `Invoke-TFSystemRepair`, `Get-TFBIOSKey`, `Sync-TFSystemTime`

### Fase 4: Modulos de alto riesgo (maxima seguridad)

15. **`modules/Users/Users.psm1`** (~80 lineas) — `Invoke-TFUserManagement`
    - Validar username, `Read-Host -AsSecureString` para passwords, confirmar antes de crear/eliminar, prevenir eliminar usuario actual
16. **`modules/Security/Security.psm1`** (~120 lineas) — `Invoke-TFDefenderControl`, `Invoke-TFWin11Bypass`
    - Confirmar antes de desactivar Defender, log de cambios en registro
    - **NOTA AMSI**: funciones de Defender/Bypass pueden disparar antivirus corporativos — manejar con try/catch + mensaje claro
17. **`modules/DangerZone/DangerZone.psm1`** (~80 lineas) — `Invoke-TFPurgeAndFormat`, `Invoke-TFExternalTool`
    - Descargar scripts a archivo temporal, log SHA256, advertencia + confirmacion, ejecutar con `&` no `iex`
    - No hardcodear hash esperado — solo loguear para auditoria (scripts externos cambian con cada update)
    - Validar drive letter, bloquear drive del sistema
    - Opcion de usar `vendor/` para herramientas pre-descargadas (modo offline)

### Fase 5: Polish y tests adicionales

18. Tests basicos para modulos restantes (al menos validacion de inputs y error paths)
19. Actualizar **`DEV-GUIDE.md`** con comandos, arquitectura y convenciones

---

## Fixes de Seguridad Criticos

| Problema | Fix |
|---|---|
| Password "ADMIN2026" en texto plano | SHA256 con salt estatico en JSON config |
| `Invoke-Expression` en URLs remotas | Descargar a archivo, log SHA256 (no validar hash rigido), advertir, confirmar, ejecutar con `&` |
| `iex` para instalar Chocolatey | Descargar .ps1 a temp, verificar existencia, ejecutar con `&` |
| `Format-Volume` sin validar drive letter | `Assert-TFValidDriveLetter` + bloquear drive del sistema |
| `net user` sin validar username | `Assert-TFValidUsername` regex |
| Paths de usuario sin validar | `Assert-TFValidPath` en todo input de paths |
| Kill de proceso sin validar | Regex: PID numerico o nombre alfanumerico |
| Password visible al cambiar | `Read-Host -AsSecureString` |
| `-ErrorAction SilentlyContinue` en todos lados | Try/catch con logging especifico |
| ExecutionPolicy bloquea en USB | Wrapper `Launch-TechFlow.cmd` con `-ExecutionPolicy Bypass` |
| AMSI bloquea modulos de seguridad | Try/catch + mensaje claro si antivirus interviene |
| Winget no existe en Win10 LTSC/Server | Pre-flight check `Get-TFSystemState`, fallback directo a choco |

---

## Logging

- **Dual logging**: `Start-Transcript` (captura TODO incluyendo output de binarios nativos como dism/sfc) + `Write-TFLog` (logging estructurado de negocio)
- Archivo: `logs/techflow_YYYYMMDD.log` + `logs/transcript_YYYYMMDD.txt`
- Formato Write-TFLog: `[2026-04-07 14:32:01] [INFO ] [Backup] Respaldo iniciado - perfil: Juan`
- Niveles: INFO (green), WARN (yellow), ERROR (red), DEBUG (gray)
- Rotacion: eliminar logs con mas de 30 dias (configurable)
- Se loguea: entrada a funciones, operaciones exitosas/fallidas, choices del usuario, ops destructivas, descargas externas con SHA256

---

## Encoding (critico para PS 5.1)

- **NUNCA usar `Out-File`** para JSON o config — usar `[System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)`
- **Leer con** `[System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)`
- `Write-TFLog` debe usar `[System.IO.StreamWriter]` con UTF8 para append
- Sin emojis en scripts (problemas de encoding en Windows PowerShell)

---

## Pre-Flight Check: Get-TFSystemState

Ejecuta al inicio y guarda en `$Global:TFState` (read-only):

```
WindowsVersion    : 10.0.19045 (Win10 22H2)
IsWindows11       : $false
InternetAvailable : $true
WingetAvailable   : $true
ChocoAvailable    : $false
IsUSBExecution    : $true
SystemDrive       : C
PSVersion         : 5.1.19041.4412
```

Los modulos consultan `$Global:TFState` en vez de hacer checks individuales.

---

## Restricciones Tecnicas

- PowerShell 5.1 (Windows 10/11 built-in) — nada de sintaxis PS7 (`?.`, `??`, ternarios)
- Portable desde USB — todo relativo a `$PSScriptRoot`, sin instalar en `$env:PSModulePath`
- Encoding UTF8 via APIs .NET (nunca Out-File para datos criticos)
- Idioma de interfaz: espanol
- Carga de modulos via `NestedModules` en `.psd1` (no dot-source manual)

---

## Mapa de Funciones: Original -> Refactorizado

| Menu | Funcion Original | Modulo Nuevo | Funcion Nueva |
|------|-----------------|--------------|---------------|
| A | `Invoke-Engine "BACKUP"` | Backup | `Invoke-TFBackupRestore -Mode BACKUP` |
| B | `Invoke-Engine "RESTORE"` | Backup | `Invoke-TFBackupRestore -Mode RESTORE` |
| C | `Invoke-DriverManagement` | Drivers | `Invoke-TFDriverManagement` |
| D | Inline (purge/format) | DangerZone | `Invoke-TFPurgeAndFormat` |
| E | `Invoke-TempOptimizer` | System | `Invoke-TFTempCleanup` |
| F | Inline (Chris Titus iex) | DangerZone | `Invoke-TFExternalTool -Tool ChrisTitusWinUtil` |
| G | Inline (MAS iex) | DangerZone | `Invoke-TFExternalTool -Tool MASActivation` |
| H | `Invoke-WingetMenu` | Packages | `Invoke-TFPackageManager` |
| I | `Invoke-KitPostFormat` | Packages | `Invoke-TFAppCatalog` |
| J | Inline (users) | Users | `Invoke-TFUserManagement` |
| K | Inline (tech support) | Maintenance | `Invoke-TFTechSupport` |
| L | Inline (Win11 bypass) | Security | `Invoke-TFWin11Bypass` |
| M | Inline (network) | Network | `Invoke-TFNetworkTools` |
| N | Inline (disk maint) | Maintenance | `Invoke-TFDiskMaintenance` |
| O | `Show-LiveMonitor` | System | `Show-TFSystemMonitor` |
| P | `Invoke-DefenderControl` | Security | `Invoke-TFDefenderControl` |
| Q | `Invoke-AutoFlow` | System | `Invoke-TFAutoMaintenance` |
| S | Inline (change pass) | Core | `Set-TFMasterPassword` |
| V | Inline (toggle menu) | Core | Toggle `$Global:MenuHorizontal` |

---

## Verificacion

1. **Ejecutar `Launch-TechFlow.cmd` desde USB** — debe abrir PS con bypass y mostrar menu completo
2. **Pre-flight check** — debe detectar correctamente Windows version, winget, internet
3. **Probar cada opcion** del menu A-Q verificando que funciona igual que el original
4. **Verificar logs** — cada operacion debe generar entrada en `logs/techflow_YYYYMMDD.log` Y en transcript
5. **Probar validaciones** — inputs invalidos (paths con `..`, usernames con `; rm -rf`, drive letters invalidos) deben ser rechazados
6. **Probar config** — borrar `techflow.config.json`, ejecutar, debe recrearse con defaults
7. **Probar seguridad** — ops destructivas (D, F, G, P) deben pedir confirmacion PIN + password
8. **Probar sin winget** — debe hacer fallback a choco sin errores
9. **Probar AMSI** — Security.psm1 debe manejar bloqueo de antivirus gracefully
10. **Ejecutar Pester tests** — `Invoke-Pester ./tests/`
