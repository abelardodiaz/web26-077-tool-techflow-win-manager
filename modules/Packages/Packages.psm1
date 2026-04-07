# =============================================================================
# Packages.psm1 - Instalacion hibrida winget/choco, catalogo de apps
# =============================================================================

function Invoke-TFSmartInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppID,
        [Parameter(Mandatory)][string]$AppName
    )

    Write-Host "`n [!] INSTALANDO: $AppName..." -ForegroundColor Cyan
    Write-TFLog "Instalando: $AppName (ID: $AppID)" -Level INFO -Component Packages

    # Intentar winget primero si esta disponible
    if ($Global:TFState.WingetAvailable) {
        try {
            $proc = Start-Process -FilePath 'winget' `
                -ArgumentList "install --id $AppID --exact --accept-package-agreements --accept-source-agreements --silent" `
                -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -eq 0) {
                Write-TFLog "Instalado via winget: $AppName" -Level INFO -Component Packages
                return "OK"
            }
        } catch {
            Write-TFLog "Error winget para $AppName : $_" -Level WARN -Component Packages
        }
        Write-Host " [!] WINGET FALLO. Intentando Chocolatey..." -ForegroundColor Yellow
    } else {
        Write-TFLog "Winget no disponible, usando Chocolatey directo" -Level INFO -Component Packages
    }

    # Fallback a Chocolatey
    if ($Global:TFState.ChocoAvailable) {
        $shortName = $AppID.Split('.')[-1].ToLower()
        try {
            $proc = Start-Process -FilePath 'choco' `
                -ArgumentList "install $shortName -y --no-progress" `
                -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -eq 0) {
                Write-TFLog "Instalado via choco: $AppName ($shortName)" -Level INFO -Component Packages
                return "OK"
            }
        } catch {
            Write-TFLog "Error choco para $AppName : $_" -Level ERROR -Component Packages
        }
    } else {
        Write-Host " [!] Chocolatey no disponible" -ForegroundColor Red
        Write-TFLog "Ni winget ni choco disponibles para: $AppName" -Level ERROR -Component Packages
    }

    return "ERROR"
}

function Invoke-TFAppCatalog {
    [CmdletBinding()]
    param()

    # Cargar catalogo desde JSON
    $catalogPath = Join-Path $PSScriptRoot '..\..\config\apps-catalog.json'
    $catalogPath = [System.IO.Path]::GetFullPath($catalogPath)

    if (-not (Test-Path $catalogPath)) {
        Write-Host " [!] Catalogo no encontrado: $catalogPath" -ForegroundColor Red
        Write-TFLog "apps-catalog.json no encontrado" -Level ERROR -Component Packages
        return
    }

    $raw = [System.IO.File]::ReadAllText($catalogPath, [System.Text.Encoding]::UTF8)
    $catalog = $raw | ConvertFrom-Json

    $config = Get-TFConfig

    while ($true) {
        Show-TFTitle
        Write-Host "`n KIT POST FORMATO - INSTALACION INTELIGENTE" -ForegroundColor Green
        Write-Host " [0] LIMPIEZA DE BLOATWARE"
        Write-Host " [1] PERFIL BASICO (Chrome, 7Zip, VLC, AnyDesk, Zoom)"
        Write-Host " [2] PERFIL GAMING (Steam, Discord, VLC, DirectX)"
        Write-Host " [3] SELECCION MANUAL (Listado Completo)"
        Write-Host " [4] ACTUALIZAR TODO EL SOFTWARE"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $opt = Read-TFChoice -Prompt " Opcion" -ValidChoices @('0','1','2','3','4','X')
        if (-not $opt -or $opt -eq 'X') { break }

        Write-TFLog "Kit Post Formato opcion: $opt" -Level INFO -Component Packages

        if ($opt -eq '0') {
            Write-Host "`n [!] Eliminando Bloatware..." -ForegroundColor Yellow
            $bloatList = $config.bloatware
            foreach ($b in $bloatList) {
                try {
                    Get-AppxPackage $b -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
                    Write-TFLog "Bloatware removido: $b" -Level INFO -Component Packages
                } catch {
                    Write-TFLog "Error removiendo bloatware $b : $_" -Level DEBUG -Component Packages
                }
            }
            Write-Host " [OK] Limpieza completada" -ForegroundColor Green
            Read-Host " ENTER"
            continue
        }

        if ($opt -eq '4') {
            if ($Global:TFState.WingetAvailable) {
                Write-Host "`n Actualizando via winget..." -ForegroundColor Green
                winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
            } else {
                Write-Host " [!] Winget no disponible" -ForegroundColor Red
            }
            Read-Host " ENTER"
            continue
        }

        $selection = @()
        $apps = @{}
        foreach ($prop in $catalog.apps.PSObject.Properties) {
            $apps[$prop.Name] = $prop.Value
        }

        if ($opt -eq '1') {
            $selection = @($catalog.profiles.basico)
        } elseif ($opt -eq '2') {
            $selection = @($catalog.profiles.gaming)
        } elseif ($opt -eq '3') {
            Show-TFTitle
            Write-Host "`n LISTADO MAESTRO" -ForegroundColor Cyan
            $sortedKeys = $apps.Keys | Sort-Object { [int]$_ }
            for ($i = 0; $i -lt $sortedKeys.Count; $i += 3) {
                $row = ""
                for ($j = 0; $j -lt 3; $j++) {
                    if (($i + $j) -lt $sortedKeys.Count) {
                        $key = $sortedKeys[$i + $j]
                        $row += "[$($key.PadLeft(3))] $($apps[$key].name.PadRight(18)) "
                    }
                }
                Write-Host " $row"
            }
            $manual = Read-Host "`n Numeros separados por coma (X cancelar)"
            if ($manual.ToUpper() -eq 'X') { continue }
            $selection = $manual.Split(",").Trim()
        }

        if ($selection.Count -gt 0) {
            $results = @()
            foreach ($item in $selection) {
                if ($apps.ContainsKey($item)) {
                    $res = Invoke-TFSmartInstall -AppID $apps[$item].id -AppName $apps[$item].name
                    $results += "[ $res ] $($apps[$item].name)"
                }
            }
            Show-TFTitle
            Write-Host "`n RESUMEN DE INSTALACION:" -ForegroundColor Yellow
            $results | ForEach-Object { Write-Host " $_" }
            Read-Host "`n ENTER para continuar"
        }
    }
}

function Invoke-TFPackageManager {
    [CmdletBinding()]
    param()

    while ($true) {
        Show-TFTitle
        Write-Host "`n GESTION DE PAQUETES (WINGET & CHOCOLATEY)" -ForegroundColor Cyan
        Write-Host " [A] WINGET: Actualizar todo        [D] CHOCO: Instalar Chocolatey"
        Write-Host " [B] WINGET: Listar disponibles     [E] CHOCO: Actualizar todo"
        Write-Host " [C] WINGET: Reparar cliente        [F] CHOCO: Buscar paquete"
        Write-Host " [G] Instalar por nombre (auto-search)"
        Write-Host " [X] VOLVER" -ForegroundColor Red

        $o = Read-TFChoice -Prompt " Opcion" -ValidChoices @('A','B','C','D','E','F','G','X')
        if (-not $o -or $o -eq 'X') { break }

        Write-TFLog "Gestor de paquetes opcion: $o" -Level INFO -Component Packages

        switch ($o) {
            'A' {
                if (-not $Global:TFState.WingetAvailable) { Write-Host " [!] Winget no disponible" -ForegroundColor Red; break }
                Write-Host "`n Actualizando via winget..." -ForegroundColor Green
                winget upgrade --all --accept-package-agreements --accept-source-agreements
                Read-Host " ENTER"
            }
            'B' {
                if (-not $Global:TFState.WingetAvailable) { Write-Host " [!] Winget no disponible" -ForegroundColor Red; break }
                winget upgrade
                Read-Host " ENTER"
            }
            'C' {
                Write-Host "`n Re-instalando cliente winget..." -ForegroundColor Yellow
                try {
                    $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
                    $dest = Join-Path $env:TEMP "winget.msixbundle"
                    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
                    Add-AppxPackage -Path $dest
                    Remove-Item $dest -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK] Cliente actualizado" -ForegroundColor Green
                    Write-TFLog "Winget client reinstalado" -Level INFO -Component Packages
                } catch {
                    Write-Host " [!] Error: $_" -ForegroundColor Red
                    Write-TFLog "Error reinstalando winget: $_" -Level ERROR -Component Packages
                }
                Read-Host " ENTER"
            }
            'D' {
                Write-Host "`n Instalando Chocolatey..." -ForegroundColor Yellow
                try {
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                    $installerPath = Join-Path $env:TEMP "choco_install.ps1"
                    Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $installerPath -UseBasicParsing
                    if ((Test-Path $installerPath) -and (Get-Item $installerPath).Length -gt 0) {
                        $hash = (Get-FileHash $installerPath -Algorithm SHA256).Hash
                        Write-TFLog "Chocolatey installer SHA256: $hash" -Level INFO -Component Packages
                        & $installerPath
                        Write-Host " [OK] Chocolatey instalado" -ForegroundColor Green
                    } else {
                        Write-Host " [!] Error descargando instalador" -ForegroundColor Red
                    }
                    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Host " [!] Error: $_" -ForegroundColor Red
                    Write-TFLog "Error instalando Chocolatey: $_" -Level ERROR -Component Packages
                }
                Read-Host " ENTER"
            }
            'E' {
                if (-not $Global:TFState.ChocoAvailable) { Write-Host " [!] Chocolatey no instalado" -ForegroundColor Red; Read-Host " ENTER"; break }
                choco upgrade all -y
                Read-Host " ENTER"
            }
            'F' {
                $p = Read-Host " Nombre del programa"
                if ($p -and $p -match '^[a-zA-Z0-9\-\._ ]+$') {
                    choco search $p
                } else {
                    Write-Host " [!] Nombre invalido" -ForegroundColor Red
                }
                Read-Host " ENTER"
            }
            'G' {
                $app = (Read-Host " Nombre de la app").Trim()
                if ($app -and $app -match '^[a-zA-Z0-9\-\._ ]+$') {
                    Invoke-TFSmartInstall -AppID $app -AppName $app
                } else {
                    Write-Host " [!] Nombre invalido" -ForegroundColor Red
                }
                Read-Host " ENTER"
            }
        }
    }
}

Export-ModuleMember -Function @(
    'Invoke-TFSmartInstall',
    'Invoke-TFAppCatalog',
    'Invoke-TFPackageManager'
)
