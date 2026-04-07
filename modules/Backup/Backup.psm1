# =============================================================================
# Backup.psm1 - Backup/Restore de perfiles de usuario
# =============================================================================

function Get-TFUserProfilePaths {
    [CmdletBinding()]
    param()
    $profilesPath = "$env:SystemDrive\Users"
    $excluded = @('All Users','Default','Default User','Public','desktop.ini','DefaultAppPool')
    Get-ChildItem -Path $profilesPath -Directory | Where-Object {
        $_.Name -notin $excluded
    } | Select-Object -ExpandProperty FullName
}

function Get-TFBackupRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$BasePath)

    try { Assert-TFValidPath -Path $BasePath } catch {
        Write-TFLog "Ruta de backup invalida: $_" -Level ERROR -Component Backup
        throw
    }

    if (-not (Test-Path $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }

    $existing = Get-ChildItem -Path $BasePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "Backup_*" } |
        ForEach-Object { $_.Name -replace "Backup_","" } |
        Where-Object { $_ -match '^\d+$' } |
        Sort-Object { [int]$_ } -Descending

    $next = if ($existing) { [int]$existing[0] + 1 } else { 1 }
    $root = Join-Path $BasePath ("Backup_" + $next.ToString("00"))

    if (-not (Test-Path $root)) {
        New-Item -Path $root -ItemType Directory -Force | Out-Null
    }

    Write-TFLog "Backup root creado: $root" -Level INFO -Component Backup
    return $root
}

function Backup-TFProfileData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProfilePath,
        [Parameter(Mandatory)][string]$BackupRoot
    )

    $config = Get-TFConfig
    $folders = $config.backup.userFolders
    $threads = $config.backup.robocopyThreads
    $retries = $config.backup.robocopyRetries
    $userName = Split-Path $ProfilePath -Leaf
    $destRoot = Join-Path $BackupRoot $userName

    Write-TFLog "Iniciando backup de perfil: $userName" -Level INFO -Component Backup

    foreach ($folder in $folders) {
        $source = Join-Path $ProfilePath $folder
        $target = Join-Path $destRoot $folder
        if (Test-Path $source) {
            Write-Host " [+] RESPALDANDO $userName\$folder ..." -ForegroundColor Green
            $proc = Start-Process -FilePath 'robocopy' `
                -ArgumentList "`"$source`" `"$target`" /E /MT:$threads /R:$retries /W:1 /XJ /NFL /NDL /NJH /NJS /NC /NS /NP" `
                -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -ge 8) {
                Write-TFLog "Robocopy fallo en $userName\$folder (exit code: $($proc.ExitCode))" -Level ERROR -Component Backup
            } else {
                Write-TFLog "Respaldado: $userName\$folder (exit code: $($proc.ExitCode))" -Level INFO -Component Backup
            }
        }
    }
}

function Restore-TFProfileData {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$BackupProfilePath)

    $profileName = Split-Path $BackupProfilePath -Leaf
    $targetRoot = "$env:SystemDrive\Users\$profileName"
    if (-not (Test-Path $targetRoot)) {
        New-Item -Path $targetRoot -ItemType Directory -Force | Out-Null
    }

    Write-TFLog "Iniciando restauracion de perfil: $profileName" -Level INFO -Component Backup

    $config = Get-TFConfig
    $threads = $config.backup.robocopyThreads

    Get-ChildItem -Path $BackupProfilePath -Directory | ForEach-Object {
        $source = $_.FullName
        $dest = Join-Path $targetRoot $_.Name
        Write-Host " [+] RESTAURANDO $profileName\$($_.Name) ..." -ForegroundColor Green
        $proc = Start-Process -FilePath 'robocopy' `
            -ArgumentList "`"$source`" `"$dest`" /E /MT:$threads /R:1 /W:1 /XJ /NFL /NDL /NJH /NJS /NC /NS /NP" `
            -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ge 8) {
            Write-TFLog "Robocopy fallo restaurando $profileName\$($_.Name) (exit: $($proc.ExitCode))" -Level ERROR -Component Backup
        } else {
            Write-TFLog "Restaurado: $profileName\$($_.Name)" -Level INFO -Component Backup
        }
    }
}

function Invoke-TFBackupRestore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('BACKUP','RESTORE')]
        [string]$Mode
    )

    $config = Get-TFConfig
    $defaultBase = $config.backup.defaultBasePath

    Show-TFTitle

    if ($Mode -eq 'BACKUP') {
        Write-Host "`n BACKUP - SELECCIONE TIPO" -ForegroundColor Yellow
        Write-Host " [A] PERFIL ACTUAL" -ForegroundColor Green
        Write-Host " [B] TODOS LOS PERFILES" -ForegroundColor Green
        Write-Host " [C] EXPORTAR INVENTARIO APPS + DRIVERS" -ForegroundColor Green
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $choice = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','C','X')
        if (-not $choice -or $choice -eq 'X') { return }

        $base = Read-Host " RUTA DESTINO (ENTER para $defaultBase)"
        if (-not $base) { $base = $defaultBase }

        try { Assert-TFValidPath -Path $base } catch {
            Write-Host " [!] Ruta invalida: $_" -ForegroundColor Red
            return
        }

        $backupRoot = Get-TFBackupRoot -BasePath $base

        switch ($choice) {
            'A' {
                Backup-TFProfileData -ProfilePath $env:USERPROFILE -BackupRoot $backupRoot
                Write-Host "`n [OK] Backup completado en: $backupRoot" -ForegroundColor Green
            }
            'B' {
                $profiles = Get-TFUserProfilePaths
                foreach ($p in $profiles) { Backup-TFProfileData -ProfilePath $p -BackupRoot $backupRoot }
                Write-Host "`n [OK] Todos los perfiles respaldados en: $backupRoot" -ForegroundColor Green
            }
            'C' {
                if (-not (Test-Path $backupRoot)) { New-Item -Path $backupRoot -ItemType Directory -Force | Out-Null }
                $appsFile = Join-Path $backupRoot "InstalledApps_$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
                $driversPath = Join-Path $backupRoot "Drivers"

                Write-Host " [+] Exportando lista de programas..." -ForegroundColor Green
                try {
                    Get-Package | Sort-Object Name | Format-Table -AutoSize | Out-String |
                        ForEach-Object { [System.IO.File]::WriteAllText($appsFile, $_, [System.Text.Encoding]::UTF8) }
                } catch {
                    Write-TFLog "Error exportando apps: $_" -Level ERROR -Component Backup
                }

                Write-Host " [+] Exportando drivers..." -ForegroundColor Green
                try {
                    if (-not (Test-Path $driversPath)) { New-Item -Path $driversPath -ItemType Directory -Force | Out-Null }
                    Export-WindowsDriver -Online -Destination $driversPath | Out-Null
                } catch {
                    Write-TFLog "Error exportando drivers: $_" -Level ERROR -Component Backup
                }

                Write-Host "`n [OK] Inventario creado en: $backupRoot" -ForegroundColor Green
                Write-TFLog "Inventario exportado a: $backupRoot" -Level INFO -Component Backup
            }
        }
        Read-Host " ENTER para continuar"
        return
    }

    # RESTORE
    Write-Host "`n RESTAURAR - SELECCIONE TIPO" -ForegroundColor Yellow
    Write-Host " [A] LISTAR BACKUPS DISPONIBLES" -ForegroundColor Green
    Write-Host " [B] ESPECIFICAR RUTA MANUAL" -ForegroundColor Green
    Write-Host " [C] RESTAURAR ULTIMO BACKUP" -ForegroundColor Green
    Write-Host " [X] VOLVER" -ForegroundColor Red

    $choice = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','C','X')
    if (-not $choice -or $choice -eq 'X') { return }

    $backupRoot = $null

    switch ($choice) {
        'A' {
            if (-not (Test-Path $defaultBase)) {
                Write-Host " [!] No hay backups en $defaultBase" -ForegroundColor Red; return
            }
            $backups = Get-ChildItem -Path $defaultBase -Directory | Where-Object { $_.Name -like "Backup_*" } | Sort-Object CreationTime -Descending
            if (-not $backups) { Write-Host " [!] No se encontraron backups" -ForegroundColor Red; return }

            Write-Host "`n BACKUPS DISPONIBLES:" -ForegroundColor Green
            for ($i = 0; $i -lt $backups.Count; $i++) {
                Write-Host " [$($i+1)] $($backups[$i].Name) - $($backups[$i].CreationTime)"
            }
            $sel = Read-Host " Seleccione numero"
            if ($sel -match '^\d+$' -and [int]$sel -le $backups.Count -and [int]$sel -ge 1) {
                $backupRoot = $backups[[int]$sel - 1].FullName
            } else {
                Write-Host " [!] Seleccion invalida" -ForegroundColor Red; return
            }
        }
        'B' {
            $manualPath = Read-Host " Ruta completa al backup"
            try {
                Assert-TFValidPath -Path $manualPath -MustExist
                $backupRoot = $manualPath
            } catch {
                Write-Host " [!] $_" -ForegroundColor Red; return
            }
        }
        'C' {
            if (-not (Test-Path $defaultBase)) {
                Write-Host " [!] No hay backups en $defaultBase" -ForegroundColor Red; return
            }
            $latest = Get-ChildItem -Path $defaultBase -Directory | Where-Object { $_.Name -like "Backup_*" } | Sort-Object CreationTime -Descending | Select-Object -First 1
            if (-not $latest) { Write-Host " [!] No se encontraron backups" -ForegroundColor Red; return }
            $backupRoot = $latest.FullName
            Write-Host " [+] Usando ultimo backup: $($latest.Name)" -ForegroundColor Green
        }
    }

    if (-not $backupRoot) { return }

    $profiles = Get-ChildItem -Path $backupRoot -Directory -ErrorAction SilentlyContinue
    if (-not $profiles) { Write-Host " [!] No hay perfiles en el backup" -ForegroundColor Red; return }

    Write-Host "`n PERFILES EN BACKUP:" -ForegroundColor Green
    $profiles | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Cyan }

    $sel = Read-Host " Nombre de perfil (ENTER para todos, X para volver)"
    if ($sel -and $sel.ToUpper() -eq 'X') { return }

    if (-not $sel) {
        foreach ($p in $profiles) { Restore-TFProfileData -BackupProfilePath $p.FullName }
        Write-Host "`n [OK] Todos los perfiles restaurados" -ForegroundColor Green
    } else {
        $found = $profiles | Where-Object { $_.Name -ieq $sel }
        if ($found) {
            Restore-TFProfileData -BackupProfilePath $found.FullName
            Write-Host "`n [OK] Perfil $sel restaurado" -ForegroundColor Green
        } else {
            Write-Host " [!] Perfil no encontrado" -ForegroundColor Red
        }
    }
    Read-Host " ENTER para continuar"
}

Export-ModuleMember -Function @(
    'Invoke-TFBackupRestore'
)
