# =============================================================================
# System.psm1 - Temp cleanup, monitor, auto-flow
# =============================================================================

function Invoke-TFTempCleanup {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n OPTIMIZACION DE ARCHIVOS TEMPORALES" -ForegroundColor Cyan
        Write-Host " [A] LIMPIEZA PROFUNDA (todo)"
        Write-Host " [B] Solo temporales de usuario"
        Write-Host " [C] Solo temporales del sistema"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $o = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','C','X')
        if (-not $o -or $o -eq 'X') { break }

        $targets = switch ($o) {
            'A' { @($env:TEMP, "C:\Windows\Temp") }
            'B' { @($env:TEMP) }
            'C' { @("C:\Windows\Temp") }
        }

        Write-TFLog "Limpieza de temporales: opcion $o" -Level INFO -Component System
        $cleaned = 0; $failed = 0

        foreach ($target in $targets) {
            if (Test-Path $target) {
                Get-ChildItem -Path $target -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop
                        $cleaned++
                    } catch {
                        $failed++
                        Write-TFLog "No se pudo eliminar: $($_.FullName)" -Level DEBUG -Component System
                    }
                }
            }
        }

        Write-Host "`n [OK] Limpieza completada: $cleaned eliminados, $failed bloqueados" -ForegroundColor Green
        Write-TFLog "Limpieza temp: $cleaned eliminados, $failed bloqueados" -Level INFO -Component System
        Start-Sleep -Seconds 1
    }
}

function Show-TFSystemMonitor {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n MONITOR DE SISTEMA" -ForegroundColor Cyan

        try {
            $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
            $mem = Get-CimInstance Win32_OperatingSystem | Select-Object `
                @{Name="Free";Expression={"{0:N2}" -f ($_.FreePhysicalMemory / 1MB)}},
                @{Name="Total";Expression={"{0:N2}" -f ($_.TotalVisibleMemorySize / 1MB)}}

            Write-Host " CPU: $cpu %" -ForegroundColor Green
            Write-Host " RAM LIBRE: $($mem.Free) GB / $($mem.Total) GB" -ForegroundColor Green
        } catch {
            Write-Host " [!] Error leyendo metricas: $_" -ForegroundColor Red
        }

        Write-Host "`n TOP 10 PROCESOS (por RAM):" -ForegroundColor Yellow
        Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 | ForEach-Object {
            $memMB = "{0:N2}" -f ($_.WorkingSet / 1MB)
            $name = if ($_.ProcessName.Length -gt 25) { $_.ProcessName.Substring(0,22) + "..." } else { $_.ProcessName }
            Write-Host " [ID: $($_.Id.ToString().PadRight(6))]  $($name.PadRight(25)) | $memMB MB"
        }

        Write-Host "`n [K] KILL proceso  [R] Refrescar  [X] Volver" -ForegroundColor Cyan
        $action = Read-TFChoice -Prompt " Opcion" -ValidChoices @('K','R','X')
        if (-not $action -or $action -eq 'X') { break }
        if ($action -eq 'R') { continue }
        if ($action -eq 'K') {
            $target = Read-Host " Nombre o ID del proceso"
            if ($target) {
                try {
                    $validated = Assert-TFValidProcessTarget -Target $target
                    if ($validated -match '^\d+$') {
                        Stop-Process -Id $validated -Force -ErrorAction Stop
                    } else {
                        Stop-Process -Name $validated -Force -ErrorAction Stop
                    }
                    Write-Host " [OK] Proceso finalizado" -ForegroundColor Green
                    Write-TFLog "Proceso terminado: $target" -Level INFO -Component System
                } catch {
                    Write-Host " [!] Error: $_" -ForegroundColor Red
                    Write-TFLog "Error terminando proceso $target : $_" -Level ERROR -Component System
                }
                Start-Sleep -Seconds 2
            }
        }
    }
}

function Invoke-TFAutoMaintenance {
    [CmdletBinding()]
    param()

    Show-TFTitle
    Write-Host "`n AUTO-FLOW EXPRESS" -ForegroundColor Yellow
    Write-Host " 1. Eliminar bloatware"
    Write-Host " 2. Limpiar temporales"
    Write-Host " 3. Instalar Chrome, 7-Zip, VLC"
    Write-Host "`n [ENTER] Comenzar  [X] Volver" -ForegroundColor Cyan

    $decision = $null
    while ($true) {
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            $char = $key.Character.ToString().ToUpper()
            if ($char -eq "X") { $decision = "SALIR"; break }
            if ([int]$key.Character -eq 13) { $decision = "INICIAR"; break }
        }
        Start-Sleep -Milliseconds 100
    }

    if ($decision -eq "SALIR") {
        Write-Host "`n [X] Cancelado" -ForegroundColor Yellow
        return
    }

    Write-TFLog "Auto-Flow Express iniciado" -Level INFO -Component System

    $checkAbort = {
        if ($Host.UI.RawUI.KeyAvailable) {
            $k = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($k.Character -eq 'x' -or $k.Character -eq 'X') {
                Write-Host "`n [XXX] DETENIDO POR EL USUARIO" -ForegroundColor Red
                Write-TFLog "Auto-Flow abortado por usuario" -Level WARN -Component System
                return $true
            }
        }
        return $false
    }

    # Paso 1: Bloatware
    Write-Host "`n [+] Paso 1/3: Eliminando Bloatware..." -ForegroundColor Cyan
    $config = Get-TFConfig
    foreach ($b in $config.bloatware) {
        if (& $checkAbort) { return }
        try { Get-AppxPackage $b -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue } catch {}
    }

    # Paso 2: Temporales
    if (& $checkAbort) { return }
    Write-Host " [+] Paso 2/3: Limpiando temporales..." -ForegroundColor Cyan
    @("$env:TEMP\*", "C:\Windows\Temp\*") | ForEach-Object {
        if (& $checkAbort) { return }
        Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Paso 3: Apps esenciales
    if (& $checkAbort) { return }
    Write-Host " [+] Paso 3/3: Instalando apps esenciales..." -ForegroundColor Cyan
    $basico = @(
        @{Name="Chrome"; ID="Google.Chrome"},
        @{Name="7-Zip"; ID="7zip.7zip"},
        @{Name="VLC Player"; ID="VideoLAN.VLC"}
    )
    foreach ($app in $basico) {
        if (& $checkAbort) { return }
        Invoke-TFSmartInstall -AppID $app.ID -AppName $app.Name | Out-Null
    }

    Write-Host "`n [OK] AUTO-FLOW FINALIZADO" -ForegroundColor Green
    Write-TFLog "Auto-Flow Express completado" -Level INFO -Component System
    Read-Host " ENTER para volver"
}

Export-ModuleMember -Function @(
    'Invoke-TFTempCleanup',
    'Show-TFSystemMonitor',
    'Invoke-TFAutoMaintenance'
)
