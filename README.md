# TechFlow Suite Pro v5.0

> Toolkit modular de soporte IT para Windows con seguridad, logging y validacion de inputs.

**Codigo:** web26-077
**Estado:** En desarrollo
**Creado:** 2026-04-07
**Basado en:** [TechFlow_Suite_Pro](https://github.com/LUISFGARCIAE/TechFlow_Suite_Pro) (MIT) por Luis Fernando Garcia Enciso

## Descripcion

TechFlow Suite Pro es un toolkit profesional de soporte IT para Windows 10/11. Automatiza tareas comunes de post-formato, mantenimiento preventivo/correctivo y troubleshooting. Esta version (v5.0) es una refactorizacion completa del script monolitico original (779 lineas) hacia una arquitectura modular con 10 submodulos, seguridad real, logging estructurado y validacion de inputs.

## Stack Tecnologico

- **Lenguaje:** PowerShell 5.1 (compatible con Windows 10/11 built-in)
- **Package Managers:** Winget (primario) + Chocolatey (fallback)
- **Compilacion:** Compatible con ps2exe para generar .exe portable

## Funcionalidades (17 opciones de menu)

| Opcion | Funcion | Modulo |
|--------|---------|--------|
| A/B | Backup y restauracion de perfiles | Backup |
| C | Gestion de drivers (export/restore/WU) | Drivers |
| D | Purga de perfil y formateo USB | DangerZone |
| E | Limpieza de archivos temporales | System |
| F/G | Herramientas externas (Chris Titus / MAS) | DangerZone |
| H | Gestor de paquetes (winget/choco) | Packages |
| I | Kit post-formato (100+ apps) | Packages |
| J | Gestion de usuarios locales | Users |
| K | Soporte tecnico (SFC/DISM, BIOS key) | Maintenance |
| L | Bypass Windows 11 (TPM/SecureBoot/RAM) | Security |
| M | Red y reparacion (reset, ping, WiFi) | Network |
| N | Mantenimiento de disco (defrag/SSD/DISM) | Maintenance |
| O | Monitor de sistema en tiempo real | System |
| P | Control de Windows Defender | Security |
| Q | Auto-Flow Express (mantenimiento 1-click) | System |

## Estructura del Proyecto

```
web26-077-tool-techflow-win-manager/
  Launch-TechFlow.cmd          # Entry point (resuelve ExecutionPolicy)
  Start-TechFlow.ps1           # Main script
  TechFlow.psd1                # Module manifest
  config/
    techflow.config.json       # Configuracion JSON
    apps-catalog.json          # Catalogo de 100+ apps
  modules/
    Core/Core.psm1             # Logger, config, validacion, UI
    Backup/Backup.psm1         # Backup/restore perfiles
    Packages/Packages.psm1     # Winget/Choco hibrido
    System/System.psm1         # Temp, monitor, auto-flow
    Security/Security.psm1     # Defender, Win11 bypass
    Network/Network.psm1       # Red, ping, WiFi, tracert
    Maintenance/Maintenance.psm1  # Disco, SFC/DISM
    Users/Users.psm1           # Usuarios locales
    Drivers/Drivers.psm1       # Drivers
    DangerZone/DangerZone.psm1 # Ops destructivas
  vendor/                      # Herramientas offline
  tests/                       # Pester tests
  legacy/                      # Script original v4.1
  logs/                        # Generado en runtime
```

## Instalacion

```bash
# Clonar repositorio
git clone https://github.com/abelardodiaz/web26-077-tool-techflow-win-manager.git
cd web26-077-tool-techflow-win-manager

# Ejecutar (requiere admin)
# Opcion 1: Doble clic en Launch-TechFlow.cmd
# Opcion 2: PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File Start-TechFlow.ps1
```

## Seguridad

- Passwords hasheadas con SHA256 + salt (nunca texto plano)
- Validacion de todos los inputs del usuario (paths, usernames, IPs, PIDs)
- No mas `Invoke-Expression` en URLs remotas
- Confirmacion PIN + password para operaciones destructivas
- Bloqueo del drive del sistema en operaciones de formato
- Dual logging para auditoria completa

## Tests

```powershell
# Requiere Pester
Invoke-Pester ./tests/
```

## Desarrollo

Ver `DEV-GUIDE.md` para instrucciones de desarrollo y convenciones del proyecto.
Ver `PLAN-ARQUITECTURA.md` para el plan completo de arquitectura (revisado por Gemini via API 900).

## Licencia

MIT (basado en proyecto original MIT)

---

*Refactorizado desde [TechFlow_Suite_Pro](https://github.com/LUISFGARCIAE/TechFlow_Suite_Pro) por Luis Fernando Garcia Enciso*
