# =============================================================================
# Security.psm1 - Defender control, Win11 bypass
# =============================================================================

function Invoke-TFDefenderControl {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n CONTROL DE WINDOWS DEFENDER" -ForegroundColor Cyan
        Write-Host " [A] ACTIVAR Defender"
        Write-Host " [B] DESACTIVAR Defender"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $o = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','X')
        if (-not $o -or $o -eq 'X') { break }

        if ($o -eq 'A') {
            try {
                reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 0 /f | Out-Null
                Write-Host " [OK] Defender activado. Reinicie para aplicar." -ForegroundColor Green
                Write-TFLog "Windows Defender ACTIVADO via registro" -Level INFO -Component Security
            } catch {
                Write-Host " [!] Error: $_" -ForegroundColor Red
                Write-TFLog "Error activando Defender: $_" -Level ERROR -Component Security
            }
            Read-Host " ENTER"
        }

        if ($o -eq 'B') {
            if (-not (Confirm-TFDangerousAction -Reason "Desactivar Windows Defender")) { continue }
            try {
                $regReal = "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
                reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f | Out-Null
                reg add $regReal /v "DisableRealtimeMonitoring" /t REG_DWORD /d 1 /f | Out-Null
                Write-Host " [OK] Defender desactivado" -ForegroundColor Green
                Write-TFLog "Windows Defender DESACTIVADO via registro" -Level WARN -Component Security
            } catch {
                Write-Host " [!] Error (posible bloqueo AMSI/antivirus): $_" -ForegroundColor Red
                Write-TFLog "Error desactivando Defender (posible AMSI): $_" -Level ERROR -Component Security
            }
            Read-Host " ENTER"
        }
    }
}

function Invoke-TFWin11Bypass {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n BYPASS WINDOWS 11" -ForegroundColor Yellow
        Write-Host " [A] BYPASS HARDWARE - Omitir TPM, SecureBoot, RAM" -ForegroundColor Cyan
        Write-Host " [B] BYPASS INTERNET - Sin conexion durante instalacion" -ForegroundColor Cyan
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $b = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','X')
        if (-not $b -or $b -eq 'X') { break }

        if (-not (Confirm-TFDangerousAction -Reason "Bypass Windows 11 (opcion $b)")) { continue }

        if ($b -eq 'A') {
            try {
                Write-Host "`n [+] Aplicando bypass de hardware..." -ForegroundColor Green
                $reg = "HKLM:\System\Setup\LabConfig"
                if (-not (Test-Path $reg)) { New-Item $reg -Force | Out-Null }
                "BypassTPMCheck","BypassSecureBootCheck","BypassRAMCheck" | ForEach-Object {
                    New-ItemProperty $reg $_ -Value 1 -PropertyType DWord -Force | Out-Null
                }
                Write-Host " [OK] Bypass aplicado" -ForegroundColor Green
                Write-TFLog "Win11 bypass hardware aplicado (TPM/SecureBoot/RAM)" -Level WARN -Component Security
            } catch {
                Write-Host " [!] Error (posible AMSI): $_" -ForegroundColor Red
                Write-TFLog "Error en Win11 bypass hardware: $_" -Level ERROR -Component Security
            }
            Read-Host " ENTER"
        }

        if ($b -eq 'B') {
            try {
                Write-Host "`n [+] Aplicando bypass de internet..." -ForegroundColor Green
                & $env:SystemRoot\System32\oobe\bypassnro.cmd
                Write-TFLog "Win11 bypass internet aplicado" -Level WARN -Component Security
            } catch {
                Write-Host " [!] Error: $_" -ForegroundColor Red
                Write-TFLog "Error en Win11 bypass internet: $_" -Level ERROR -Component Security
            }
            Read-Host " ENTER"
        }
    }
}

Export-ModuleMember -Function @(
    'Invoke-TFDefenderControl',
    'Invoke-TFWin11Bypass'
)
