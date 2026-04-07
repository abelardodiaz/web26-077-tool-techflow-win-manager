# =============================================================================
# Start-TechFlow.ps1 - Entry Point
# TechFlow Suite Pro v5.0 - Modular Edition
# =============================================================================

$ErrorActionPreference = 'Stop'

# Transcript para capturar output de binarios nativos (dism, sfc, etc.)
$transcriptDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $transcriptDir)) { New-Item -Path $transcriptDir -ItemType Directory -Force | Out-Null }
$transcriptFile = Join-Path $transcriptDir "transcript_$(Get-Date -Format 'yyyyMMdd').txt"
Start-Transcript -Path $transcriptFile -Append -Force | Out-Null

# Importar modulo principal (carga Core + todos los submodulos via NestedModules)
try {
    Import-Module (Join-Path $PSScriptRoot 'TechFlow.psd1') -Force -ErrorAction Stop
} catch {
    Write-Host " [!] Error cargando modulos: $_" -ForegroundColor Red
    Write-Host " Verifique que la estructura de carpetas este completa." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    exit 1
}

# Inicializar logging
Initialize-TFLog -LogDir (Join-Path $PSScriptRoot 'logs')
Write-TFLog "TechFlow Suite Pro v5.0 iniciado" -Level INFO -Component Main

# Verificar privilegios de administrador
if (-not (Test-TFAdminPrivilege)) {
    Stop-Transcript | Out-Null
    exit 1
}

# Pre-flight check
$state = Get-TFSystemState

# Cargar config
$config = Get-TFConfig

# Primera ejecucion: pedir password
if (-not $config.security.masterPasswordHash) {
    Write-Host ""
    Write-Host " --- PRIMERA EJECUCION ---" -ForegroundColor Yellow
    Write-Host " Configure una password maestra para operaciones criticas." -ForegroundColor Yellow
    Write-Host ""
    Set-TFMasterPassword
}

# Menu toggle
$Global:MenuHorizontal = $config.ui.horizontalMenu

# Menu principal
$menuOptions = [ordered]@{
    'A' = 'RESPALDO'
    'B' = 'RESTAURAR'
    'C' = 'DRIVERS'
    'D' = 'PURGA Y FORMATEO'
    'E' = 'LIMPIEZA TEMP'
    'F' = 'CHRIS TITUS WINUTIL'
    'G' = 'MAS ACTIVATION'
    'H' = 'GESTOR PAQUETES'
    'I' = 'KIT POST-FORMATO'
    'J' = 'GESTION USUARIOS'
    'K' = 'SOPORTE TECNICO'
    'L' = 'BYPASS WIN 11'
    'M' = 'RED Y REPARACION'
    'N' = 'MANTENIM. DISCO'
    'O' = 'MONITOR EN VIVO'
    'P' = 'CONTROL DEFENDER'
    'Q' = 'AUTO-FLOW EXPRESS'
    'S' = 'CAMBIAR PASSWORD'
    'V' = 'CAMBIAR VISTA'
    'X' = 'SALIR'
}

$validKeys = @($menuOptions.Keys)

# Main loop
while ($true) {
    Show-TFTitle

    if ($Global:MenuHorizontal) {
        Show-TFMenu -Options $menuOptions -Title "MENU PRINCIPAL" -Horizontal
    } else {
        Show-TFMenu -Options $menuOptions -Title "MENU PRINCIPAL"
    }

    $choice = Read-TFChoice -Prompt " Opcion" -ValidChoices $validKeys

    if (-not $choice) { continue }

    Write-TFLog "Usuario selecciono: $choice ($($menuOptions[$choice]))" -Level INFO -Component Main

    switch ($choice) {
        'A' { Invoke-TFBackupRestore -Mode BACKUP }
        'B' { Invoke-TFBackupRestore -Mode RESTORE }
        'C' { Invoke-TFDriverManagement }
        'D' { Invoke-TFPurgeAndFormat }
        'E' { Invoke-TFTempCleanup }
        'F' { Invoke-TFExternalTool -ToolName ChrisTitusWinUtil }
        'G' { Invoke-TFExternalTool -ToolName MASActivation }
        'H' { Invoke-TFPackageManager }
        'I' { Invoke-TFAppCatalog }
        'J' { Invoke-TFUserManagement }
        'K' { Invoke-TFTechSupport }
        'L' { Invoke-TFWin11Bypass }
        'M' { Invoke-TFNetworkTools }
        'N' { Invoke-TFDiskMaintenance }
        'O' { Show-TFSystemMonitor }
        'P' { Invoke-TFDefenderControl }
        'Q' { Invoke-TFAutoMaintenance }
        'S' { Set-TFMasterPassword }
        'V' {
            $Global:MenuHorizontal = -not $Global:MenuHorizontal
            Write-TFLog "Vista cambiada a: $(if ($Global:MenuHorizontal) {'Horizontal'} else {'Vertical'})" -Level INFO -Component Main
        }
        'X' {
            Write-TFLog "TechFlow Suite Pro cerrado por el usuario" -Level INFO -Component Main
            Stop-Transcript | Out-Null
            exit 0
        }
    }

    Write-Host ""
    Write-Host " Presione ENTER para continuar..." -ForegroundColor Gray
    Read-Host | Out-Null
}
