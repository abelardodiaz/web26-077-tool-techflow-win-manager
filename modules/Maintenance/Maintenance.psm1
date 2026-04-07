# =============================================================================
# Maintenance.psm1 - Disco, SFC/DISM, BIOS key, time sync
# =============================================================================

function Invoke-TFTechSupport {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n SOPORTE TECNICO PRO" -ForegroundColor Cyan
        Write-Host " [A] Salud de disco"
        Write-Host " [B] Reparar sistema (SFC + DISM)"
        Write-Host " [C] Clave BIOS/OEM"
        Write-Host " [D] Sincronizar hora"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $s = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','C','D','X')
        if (-not $s -or $s -eq 'X') { break }

        Write-TFLog "Soporte tecnico opcion: $s" -Level INFO -Component Maintenance

        switch ($s) {
            'A' {
                try { Get-PhysicalDisk | Format-Table } catch { Write-Host " [!] Error: $_" -ForegroundColor Red }
                Read-Host " ENTER"
            }
            'B' {
                Write-Host "`n [+] Ejecutando SFC..." -ForegroundColor Green
                sfc /scannow
                Write-Host "`n [+] Ejecutando DISM..." -ForegroundColor Green
                dism /online /cleanup-image /restorehealth
                Write-TFLog "Reparacion SFC+DISM ejecutada" -Level INFO -Component Maintenance
                Read-Host " OK"
            }
            'C' {
                try {
                    $key = (Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey
                    if ($key) {
                        Write-Host "`n Clave OEM: $key" -ForegroundColor Green
                    } else {
                        Write-Host " [!] No se encontro clave OEM" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host " [!] Error: $_" -ForegroundColor Red
                }
                Read-Host " OK"
            }
            'D' {
                try {
                    net stop w32time 2>&1 | Out-Null
                    w32tm /config /syncfromflags:manual /manualpeerlist:"time.windows.com" 2>&1 | Out-Null
                    net start w32time 2>&1 | Out-Null
                    $syncResult = w32tm /resync 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "`n [OK] Sincronizacion exitosa" -ForegroundColor Green
                        w32tm /query /source | ForEach-Object { Write-Host " > $_" }
                        w32tm /query /status | ForEach-Object { Write-Host " > $_" }
                        Write-TFLog "Hora sincronizada correctamente" -Level INFO -Component Maintenance
                    } else {
                        Write-Host "`n [!] Error al sincronizar:" -ForegroundColor Red
                        $syncResult | ForEach-Object { Write-Host " > $_" }
                        Write-TFLog "Error sincronizando hora" -Level ERROR -Component Maintenance
                    }
                } catch {
                    Write-Host " [!] Error: $_" -ForegroundColor Red
                }
                Read-Host " OK"
            }
        }
    }
}

function Invoke-TFDiskMaintenance {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n MANTENIMIENTO DE DISCOS" -ForegroundColor Cyan
        Write-Host " [A] Desfragmentar HDD"
        Write-Host " [B] Optimizar SSD"
        Write-Host " [C] Limpieza DISM"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $o = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','C','X')
        if (-not $o -or $o -eq 'X') { break }

        Write-TFLog "Mantenimiento disco opcion: $o" -Level INFO -Component Maintenance

        switch ($o) {
            'A' {
                Write-Host "`n [+] Desfragmentando C:..." -ForegroundColor Green
                defrag C: /O
                Write-TFLog "Desfragmentacion completada" -Level INFO -Component Maintenance
                Read-Host " OK"
            }
            'B' {
                Write-Host "`n [+] Optimizando SSD (TRIM)..." -ForegroundColor Green
                try {
                    Optimize-Volume -DriveLetter C -ReTrim -Verbose
                    Write-TFLog "SSD optimizado (TRIM)" -Level INFO -Component Maintenance
                } catch {
                    Write-Host " [!] Error: $_" -ForegroundColor Red
                    Write-TFLog "Error optimizando SSD: $_" -Level ERROR -Component Maintenance
                }
                Read-Host " OK"
            }
            'C' {
                Write-Host "`n [+] Limpieza DISM..." -ForegroundColor Green
                dism /online /Cleanup-Image /StartComponentCleanup
                Write-TFLog "DISM cleanup completado" -Level INFO -Component Maintenance
                Read-Host " OK"
            }
        }
    }
}

Export-ModuleMember -Function @(
    'Invoke-TFTechSupport',
    'Invoke-TFDiskMaintenance'
)
