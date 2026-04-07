# =============================================================================
# Drivers.psm1 - Driver backup/restore/update
# =============================================================================

function Invoke-TFDriverManagement {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n GESTION DE DRIVERS PRO" -ForegroundColor Cyan
        Write-Host " [A] Exportar drivers (backup)"
        Write-Host " [B] Re-instalar desde backup"
        Write-Host " [C] Buscar en Windows Update (oficiales)"
        Write-Host " [D] Ver dispositivos sin driver"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $o = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','C','D','X')
        if (-not $o -or $o -eq 'X') { break }

        Write-TFLog "Drivers opcion: $o" -Level INFO -Component Drivers

        switch ($o) {
            'A' {
                $p = Join-Path $PSScriptRoot "..\..\Drivers_$env:COMPUTERNAME"
                $p = [System.IO.Path]::GetFullPath($p)
                if (-not (Test-Path $p)) { New-Item $p -ItemType Directory -Force | Out-Null }
                Write-Host " [+] Exportando drivers... (puede tardar)" -ForegroundColor Cyan
                try {
                    Export-WindowsDriver -Online -Destination $p
                    Write-Host " [OK] Backup creado en: $p" -ForegroundColor Green
                    Write-TFLog "Drivers exportados a: $p" -Level INFO -Component Drivers
                } catch {
                    Write-Host " [!] Error: $_" -ForegroundColor Red
                    Write-TFLog "Error exportando drivers: $_" -Level ERROR -Component Drivers
                }
                Read-Host " ENTER"
            }
            'B' {
                $path = Join-Path $PSScriptRoot "..\..\Drivers_$env:COMPUTERNAME"
                $path = [System.IO.Path]::GetFullPath($path)
                if (Test-Path $path) {
                    Write-Host " [+] Re-instalando drivers..." -ForegroundColor Green
                    try {
                        Get-ChildItem "$path\*.inf" -Recurse | ForEach-Object {
                            pnputil /add-driver $_.FullName /install
                        }
                        Write-TFLog "Drivers reinstalados desde: $path" -Level INFO -Component Drivers
                    } catch {
                        Write-TFLog "Error reinstalando drivers: $_" -Level ERROR -Component Drivers
                    }
                    Read-Host " ENTER"
                } else {
                    Write-Host " [!] No se encontro carpeta de backup" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
            'C' {
                if (-not $Global:TFState.InternetAvailable) {
                    Write-Host " [!] Sin conexion a internet" -ForegroundColor Red
                    Read-Host " ENTER"
                    continue
                }

                Write-Host " [+] Configurando entorno..." -ForegroundColor Gray
                try {
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

                    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                        Write-Host " [+] Instalando NuGet..." -ForegroundColor Gray
                        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false | Out-Null
                    }

                    if (-not (Get-Module -ListAvailable PSWindowsUpdate)) {
                        Write-Host " [+] Instalando PSWindowsUpdate..." -ForegroundColor Gray
                        Install-Module PSWindowsUpdate -Force -Confirm:$false -Scope CurrentUser | Out-Null
                    }

                    Import-Module PSWindowsUpdate
                    Write-Host " [+] Buscando drivers certificados..." -ForegroundColor Cyan
                    Get-WindowsUpdate -Category "Drivers" -Install -AcceptAll -IgnoreReboot
                    Write-TFLog "Drivers actualizados via Windows Update" -Level INFO -Component Drivers
                } catch {
                    Write-Host " [!] Error: $_" -ForegroundColor Red
                    Write-TFLog "Error buscando drivers en WU: $_" -Level ERROR -Component Drivers
                }
                Read-Host " ENTER"
            }
            'D' {
                Write-Host "`n Dispositivos con errores o sin driver:" -ForegroundColor Yellow
                try {
                    $missing = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
                    if ($missing) {
                        $missing | Select-Object Name, Status, DeviceID | Format-Table -AutoSize
                    } else {
                        Write-Host " [OK] Todo OK - no se detectaron problemas" -ForegroundColor Green
                    }
                } catch {
                    Write-Host " [!] Error: $_" -ForegroundColor Red
                }
                Read-Host " ENTER"
            }
        }
    }
}

Export-ModuleMember -Function @('Invoke-TFDriverManagement')
