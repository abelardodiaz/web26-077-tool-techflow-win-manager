# Changelog

Todos los cambios notables de este proyecto seran documentados aqui.

El formato esta basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

## [5.0.0] - 2026-04-07

### Agregado
- Arquitectura modular completa: 10 submodulos PowerShell independientes
- `Launch-TechFlow.cmd` wrapper para resolver ExecutionPolicy en USB
- `TechFlow.psd1` manifest con NestedModules (carga nativa de PS)
- `modules/Core/Core.psm1` - fundacion: logger, config, validacion, credenciales, pre-flight, UI
- `modules/Backup/Backup.psm1` - backup/restore de perfiles con robocopy
- `modules/Packages/Packages.psm1` - instalacion hibrida winget/choco con catalogo JSON
- `modules/System/System.psm1` - limpieza temp, monitor de sistema, auto-flow express
- `modules/Security/Security.psm1` - control Defender, bypass Windows 11
- `modules/Network/Network.psm1` - reset red, ping, WiFi keys, tracert, speedtest
- `modules/Maintenance/Maintenance.psm1` - SFC/DISM, disco, BIOS key, sync hora
- `modules/Users/Users.psm1` - CRUD de usuarios locales con validacion
- `modules/Drivers/Drivers.psm1` - export/restore/update de drivers
- `modules/DangerZone/DangerZone.psm1` - operaciones destructivas con confirmacion
- `config/techflow.config.json` - configuracion JSON centralizada
- `config/apps-catalog.json` - catalogo de 100+ apps (extraido de hardcode a JSON)
- `tests/Core.Tests.ps1` - 30+ tests Pester para funciones de validacion
- `PLAN-ARQUITECTURA.md` - plan completo revisado por Gemini (API 900 ticket #925)
- Carpeta `vendor/` para herramientas offline
- Carpeta `legacy/` con script original v4.1

### Seguridad
- Passwords hasheadas con SHA256 + salt (reemplaza texto plano)
- Validacion de inputs en todo: paths, usernames, drive letters, hostnames, PIDs
- Eliminado `Invoke-Expression` en URLs remotas (ahora descarga + hash SHA256 + confirmacion + `&`)
- `Confirm-TFDangerousAction` con PIN aleatorio + master password para ops destructivas
- `Assert-TFValidDriveLetter` bloquea drive del sistema en formateos
- `Assert-TFValidUsername` previene injection en `net user`
- `Read-Host -AsSecureString` para todas las passwords

### Cambiado
- De script monolitico (779 lineas) a arquitectura modular (2,272 lineas en 10 modulos)
- Config de `suite_config.dat` (texto plano) a `techflow.config.json` (JSON estructurado)
- Encoding via `[System.IO.File]::WriteAllText` con UTF8 (nunca Out-File para datos criticos)
- Carga de modulos via `NestedModules` en `.psd1` (no dot-source manual)
- Robocopy con `Start-Process -Wait -PassThru` y validacion de exit codes (0-7=ok, 8+=error)
- Chocolatey install: descarga a archivo temporal, no `iex` directo

### Agregado (Logging)
- Dual logging: `Start-Transcript` (binarios nativos) + `Write-TFLog` (estructurado)
- Formato: `[timestamp] [LEVEL] [Component] mensaje`
- Rotacion automatica de logs (30 dias configurable)
- Log de todas las operaciones destructivas, descargas externas con SHA256

### Agregado (Pre-Flight)
- `Get-TFSystemState` detecta al inicio: Windows version, internet, winget, choco, USB
- `$Global:TFState` consultado por todos los modulos (sin checks repetidos)
- Fallback automatico winget -> choco cuando winget no esta disponible

---

## Guia de Categorias

- **Agregado**: Nuevas funcionalidades
- **Cambiado**: Cambios en funcionalidades existentes
- **Deprecated**: Funcionalidades que seran removidas
- **Removido**: Funcionalidades eliminadas
- **Arreglado**: Correcciones de bugs
- **Seguridad**: Correcciones de vulnerabilidades
