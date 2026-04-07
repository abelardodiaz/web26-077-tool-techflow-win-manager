# =============================================================================
# DangerZone.psm1 - Purge, format, scripts externos
# =============================================================================

function Invoke-TFPurgeAndFormat {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n OPERACION CRITICA" -ForegroundColor Red
        Write-Host " [A] PURGAR PERFIL (eliminar contenido de carpetas de usuario)"
        Write-Host " [B] FORMATEAR USB"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $o = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','X')
        if (-not $o -or $o -eq 'X') { break }

        if (-not (Confirm-TFDangerousAction -Reason "Operacion critica: $(if ($o -eq 'A') {'Purgar perfil'} else {'Formatear USB'})")) { continue }

        switch ($o) {
            'A' {
                Write-TFLog "Purga de perfil iniciada" -Level WARN -Component DangerZone
                $config = Get-TFConfig
                $folders = $config.backup.userFolders
                foreach ($folder in $folders) {
                    $path = Join-Path $env:USERPROFILE $folder
                    if (Test-Path $path) {
                        try {
                            Remove-Item "$path\*" -Recurse -Force -ErrorAction Stop
                            Write-TFLog "Purgado: $path" -Level INFO -Component DangerZone
                        } catch {
                            Write-TFLog "Error purgando $path : $_" -Level ERROR -Component DangerZone
                        }
                    }
                }
                Write-Host " [OK] Perfil purgado" -ForegroundColor Green
                Read-Host " ENTER"
            }
            'B' {
                $letter = Read-Host " Letra de unidad USB"
                try {
                    $validated = Assert-TFValidDriveLetter -Letter $letter
                    Write-Host " [+] Formateando $validated`:..." -ForegroundColor Yellow
                    Format-Volume -DriveLetter $validated -FileSystem NTFS -Force
                    Write-Host " [OK] Formato completado" -ForegroundColor Green
                    Write-TFLog "USB formateado: $validated`:" -Level WARN -Component DangerZone
                } catch {
                    Write-Host " [!] $_" -ForegroundColor Red
                    Write-TFLog "Error formateando: $_" -Level ERROR -Component DangerZone
                }
                Read-Host " ENTER"
            }
        }
    }
}

function Invoke-TFExternalTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ChrisTitusWinUtil','MASActivation')]
        [string]$ToolName
    )

    $urls = @{
        'ChrisTitusWinUtil' = 'https://christitus.com/win'
        'MASActivation'     = 'https://get.activated.win'
    }
    $url = $urls[$ToolName]

    Write-TFLog "Solicitud de herramienta externa: $ToolName ($url)" -Level WARN -Component DangerZone

    # Verificar internet
    if (-not $Global:TFState.InternetAvailable) {
        Write-Host " [!] Sin conexion a internet" -ForegroundColor Red

        # Buscar en vendor/
        $vendorPath = Join-Path $PSScriptRoot "..\..\vendor\$ToolName.ps1"
        $vendorPath = [System.IO.Path]::GetFullPath($vendorPath)
        if (Test-Path $vendorPath) {
            Write-Host " [+] Encontrado en vendor/ (modo offline)" -ForegroundColor Yellow
            if (-not (Confirm-TFDangerousAction -Reason "Ejecutar $ToolName desde vendor/")) { return }
            try {
                & $vendorPath
                Write-TFLog "Ejecutado desde vendor: $ToolName" -Level INFO -Component DangerZone
            } catch {
                Write-TFLog "Error ejecutando desde vendor: $_" -Level ERROR -Component DangerZone
            }
        } else {
            Write-Host " [!] No disponible offline. Coloque el script en vendor/$ToolName.ps1" -ForegroundColor Red
        }
        return
    }

    Show-TFTitle
    Write-Host "`n [!] ADVERTENCIA: Esto descargara y ejecutara codigo externo de:" -ForegroundColor Red
    Write-Host "     $url" -ForegroundColor Yellow
    Write-Host "     TechFlow no controla el contenido de este script." -ForegroundColor Red
    Write-Host ""

    if (-not (Confirm-TFDangerousAction -Reason "Ejecutar script externo: $ToolName")) { return }

    $tempFile = Join-Path $env:TEMP "tf_external_$(Get-Random).ps1"
    try {
        Write-Host " [+] Descargando..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing

        if ((Test-Path $tempFile) -and (Get-Item $tempFile).Length -gt 0) {
            $hash = (Get-FileHash $tempFile -Algorithm SHA256).Hash
            Write-TFLog "Script externo descargado. SHA256: $hash | URL: $url" -Level INFO -Component DangerZone
            Write-Host " [+] SHA256: $hash" -ForegroundColor Gray
            Write-Host " [+] Ejecutando..." -ForegroundColor Green
            & $tempFile
        } else {
            Write-Host " [!] Error: archivo descargado vacio" -ForegroundColor Red
            Write-TFLog "Script externo vacio despues de descarga: $url" -Level ERROR -Component DangerZone
        }
    } catch {
        Write-Host " [!] Error: $_" -ForegroundColor Red
        Write-TFLog "Error ejecutando herramienta externa: $_" -Level ERROR -Component DangerZone
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function @(
    'Invoke-TFPurgeAndFormat',
    'Invoke-TFExternalTool'
)
