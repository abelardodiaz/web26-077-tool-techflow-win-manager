# =============================================================================
# Network.psm1 - Red, ping, WiFi, tracert, speedtest
# =============================================================================

function Invoke-TFNetworkTools {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n RED Y REPARACION" -ForegroundColor Cyan
        Write-Host " [A] Resetear red              [F] Traza de ruta (tracert)"
        Write-Host " [B] Reparar Windows Update    [G] Test velocidad (fast.com)"
        Write-Host " [C] Ver IP                    [E] Ver claves WiFi"
        Write-Host " [D] Ping monitor"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $m = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','C','D','E','F','G','X')
        if (-not $m -or $m -eq 'X') { break }

        Write-TFLog "Red herramienta: $m" -Level INFO -Component Network

        switch ($m) {
            'A' {
                Write-Host "`n [+] Reseteando red..." -ForegroundColor Green
                try {
                    netsh winsock reset
                    netsh int ip reset
                    ipconfig /flushdns
                    Write-TFLog "Red reseteada (winsock + ip + dns)" -Level INFO -Component Network
                } catch {
                    Write-TFLog "Error reseteando red: $_" -Level ERROR -Component Network
                }
                Read-Host " OK"
            }
            'B' {
                Write-Host "`n [+] Reparando Windows Update..." -ForegroundColor Green
                try {
                    "wuauserv","bits" | ForEach-Object { Stop-Service $_ -Force -ErrorAction SilentlyContinue }
                    Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
                    "wuauserv","bits" | ForEach-Object { Start-Service $_ -ErrorAction SilentlyContinue }
                    Write-TFLog "Windows Update reparado" -Level INFO -Component Network
                } catch {
                    Write-TFLog "Error reparando WU: $_" -Level ERROR -Component Network
                }
                Read-Host " OK"
            }
            'C' {
                Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -notmatch "Loopback" | Format-Table
                Read-Host " ENTER"
            }
            'D' {
                $target = Read-Host " IP o dominio (ENTER para 8.8.8.8)"
                if (-not $target) { $target = "8.8.8.8" }
                try {
                    $validated = Assert-TFValidHostname -Hostname $target
                    Write-TFLog "Ping monitor iniciado: $validated" -Level INFO -Component Network
                    while ($true) {
                        Test-Connection $validated -Count 1
                        if ([console]::KeyAvailable) { break }
                        Start-Sleep -Seconds 1
                    }
                } catch {
                    Write-Host " [!] $_" -ForegroundColor Red
                }
            }
            'E' {
                Show-TFTitle
                Write-Host "`n CLAVES WIFI GUARDADAS" -ForegroundColor Green
                try {
                    $profiles = netsh wlan show profiles | Select-String "\:(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
                    foreach ($name in $profiles) {
                        $passLine = (netsh wlan show profile name="$name" key=clear) | Select-String "Contenido de la clave|Key Content"
                        if ($passLine) {
                            $pass = $passLine.ToString().Split(":")[1].Trim()
                            Write-Host " RED: $name | CLAVE: $pass" -ForegroundColor Green
                        }
                    }
                } catch {
                    Write-Host " [!] Error obteniendo claves: $_" -ForegroundColor Red
                }
                Read-Host "`n ENTER"
            }
            'F' {
                $target = Read-Host " Dominio"
                try {
                    $validated = Assert-TFValidHostname -Hostname $target
                    tracert $validated
                } catch {
                    Write-Host " [!] $_" -ForegroundColor Red
                }
                Read-Host " ENTER"
            }
            'G' {
                Start-Process "https://fast.com"
                Read-Host " OK"
            }
        }
    }
}

Export-ModuleMember -Function @('Invoke-TFNetworkTools')
