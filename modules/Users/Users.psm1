# =============================================================================
# Users.psm1 - Gestion de usuarios locales
# =============================================================================

function Invoke-TFUserManagement {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n GESTION DE USUARIOS" -ForegroundColor Cyan
        Write-Host " [A] Listar usuarios"
        Write-Host " [B] Crear admin local"
        Write-Host " [C] Eliminar usuario"
        Write-Host " [D] Activar super admin"
        Write-Host " [F] Cambiar password"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $u = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','C','D','F','X')
        if (-not $u -or $u -eq 'X') { break }

        Write-TFLog "Gestion usuarios opcion: $u" -Level INFO -Component Users

        switch ($u) {
            'A' {
                net user
                Read-Host " ENTER"
            }
            'B' {
                $n = Read-Host " Nombre de usuario"
                try {
                    $validated = Assert-TFValidUsername -Username $n
                    if (-not (Confirm-TFDangerousAction -Reason "Crear admin local: $validated")) { continue }

                    $pass = Read-Host -AsSecureString " Password para $validated"
                    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass)
                    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

                    net user "$validated" "$plain" /add
                    net localgroup administrators "$validated" /add
                    Write-Host " [OK] Usuario $validated creado como admin" -ForegroundColor Green
                    Write-TFLog "Usuario admin creado: $validated" -Level INFO -Component Users
                } catch {
                    Write-Host " [!] $_" -ForegroundColor Red
                    Write-TFLog "Error creando usuario: $_" -Level ERROR -Component Users
                }
                Read-Host " ENTER"
            }
            'C' {
                $n = Read-Host " Nombre de usuario a eliminar"
                try {
                    $validated = Assert-TFValidUsername -Username $n

                    # Prevenir eliminar usuario actual
                    if ($validated -ieq $env:USERNAME) {
                        Write-Host " [!] No puede eliminar el usuario actual" -ForegroundColor Red
                        Read-Host " ENTER"
                        continue
                    }

                    if (-not (Confirm-TFDangerousAction -Reason "Eliminar usuario: $validated")) { continue }
                    net user "$validated" /delete
                    Write-Host " [OK] Usuario $validated eliminado" -ForegroundColor Green
                    Write-TFLog "Usuario eliminado: $validated" -Level WARN -Component Users
                } catch {
                    Write-Host " [!] $_" -ForegroundColor Red
                }
                Read-Host " ENTER"
            }
            'D' {
                if (-not (Confirm-TFDangerousAction -Reason "Activar cuenta super administrador")) { continue }
                net user administrator /active:yes
                Write-Host " [OK] Super admin activado" -ForegroundColor Green
                Write-TFLog "Super admin activado" -Level WARN -Component Users
                Read-Host " ENTER"
            }
            'F' {
                $n = Read-Host " Usuario"
                try {
                    $validated = Assert-TFValidUsername -Username $n
                    $pass = Read-Host -AsSecureString " Nueva password"
                    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass)
                    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

                    if ($validated -and $plain) {
                        net user "$validated" "$plain"
                        Write-Host " [OK] Password cambiada" -ForegroundColor Green
                        Write-TFLog "Password cambiada para: $validated" -Level INFO -Component Users
                    }
                } catch {
                    Write-Host " [!] $_" -ForegroundColor Red
                }
                Read-Host " ENTER"
            }
        }
    }
}

Export-ModuleMember -Function @('Invoke-TFUserManagement')
