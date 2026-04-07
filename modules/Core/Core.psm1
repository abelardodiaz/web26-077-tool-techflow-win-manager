# =============================================================================
# Core.psm1 - Fundacion: Logger, Config, Validacion, UI, Pre-Flight
# TechFlow Suite Pro v5.0
# =============================================================================

$Script:TFLogPath = $null
$Script:TFConfigCache = $null
$Script:SALT = "TechFlow_Salt_077x!"

# -----------------------------------------------------------------------------
# LOGGING
# -----------------------------------------------------------------------------
function Write-TFLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO',

        [string]$Component = 'Core'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $levelPad = $Level.PadRight(5)
    $compPad = $Component.PadRight(12)
    $line = "[$timestamp] [$levelPad] [$compPad] $Message"

    # Escribir a archivo con StreamWriter (UTF8, append)
    if ($Script:TFLogPath) {
        try {
            $dir = Split-Path $Script:TFLogPath -Parent
            if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
            $sw = New-Object System.IO.StreamWriter($Script:TFLogPath, $true, [System.Text.Encoding]::UTF8)
            $sw.WriteLine($line)
            $sw.Close()
        } catch {
            # Silenciar error de log para no romper el flujo
        }
    }

    # Escribir a consola con color
    $color = switch ($Level) {
        'INFO'  { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
}

function Initialize-TFLog {
    [CmdletBinding()]
    param(
        [string]$LogDir
    )

    if (-not $LogDir) {
        $LogDir = Join-Path $PSScriptRoot '..\..\logs'
    }
    $LogDir = [System.IO.Path]::GetFullPath($LogDir)

    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }

    $date = Get-Date -Format 'yyyyMMdd'
    $Script:TFLogPath = Join-Path $LogDir "techflow_$date.log"

    # Rotacion: eliminar logs viejos
    $config = Get-TFConfig
    $retention = 30
    if ($config -and $config.logging -and $config.logging.retentionDays) {
        $retention = $config.logging.retentionDays
    }
    $cutoff = (Get-Date).AddDays(-$retention)
    Get-ChildItem -Path $LogDir -Filter 'techflow_*.log' -ErrorAction SilentlyContinue | Where-Object {
        $_.LastWriteTime -lt $cutoff
    } | Remove-Item -Force -ErrorAction SilentlyContinue

    Write-TFLog "Log inicializado: $Script:TFLogPath" -Level INFO -Component Core
}

# -----------------------------------------------------------------------------
# CONFIGURACION
# -----------------------------------------------------------------------------
function Get-TFConfig {
    [CmdletBinding()]
    param()

    $configPath = Join-Path $PSScriptRoot '..\..\config\techflow.config.json'
    $configPath = [System.IO.Path]::GetFullPath($configPath)

    if (-not (Test-Path $configPath)) {
        Write-TFLog "Config no encontrada, creando defaults: $configPath" -Level WARN -Component Core
        $defaults = @{
            version = "5.0"
            security = @{
                masterPasswordHash = ""
                salt = $Script:SALT
                requirePasswordForDangerousOps = $true
                trustedUrls = @(
                    "https://christitus.com/win",
                    "https://get.activated.win",
                    "https://community.chocolatey.org/install.ps1"
                )
            }
            backup = @{
                defaultBasePath = "C:\Backups"
                userFolders = @("Desktop","Documents","Pictures","Videos","Music","Downloads","Favorites","Contacts","Saved Games","AppData\Roaming")
                robocopyThreads = 16
                robocopyRetries = 1
            }
            logging = @{
                enabled = $true
                level = "INFO"
                retentionDays = 30
            }
            ui = @{
                horizontalMenu = $true
                colorPrimary = "Green"
                colorAlert = "Yellow"
                colorDanger = "Red"
                colorMenu = "Cyan"
            }
            bloatware = @("*CandyCrush*","*Disney*","*Netflix*","*TikTok*","*Instagram*")
        }
        $json = $defaults | ConvertTo-Json -Depth 10
        $dir = Split-Path $configPath -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        [System.IO.File]::WriteAllText($configPath, $json, [System.Text.Encoding]::UTF8)
    }

    try {
        $raw = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
        $Script:TFConfigCache = $raw | ConvertFrom-Json
    } catch {
        Write-TFLog "Error leyendo config: $_" -Level ERROR -Component Core
        $Script:TFConfigCache = $null
    }

    return $Script:TFConfigCache
}

function Save-TFConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )

    $configPath = Join-Path $PSScriptRoot '..\..\config\techflow.config.json'
    $configPath = [System.IO.Path]::GetFullPath($configPath)

    try {
        $json = $Config | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($configPath, $json, [System.Text.Encoding]::UTF8)
        $Script:TFConfigCache = $Config
        Write-TFLog "Config guardada" -Level INFO -Component Core
    } catch {
        Write-TFLog "Error guardando config: $_" -Level ERROR -Component Core
        throw
    }
}

# -----------------------------------------------------------------------------
# PRE-FLIGHT CHECK
# -----------------------------------------------------------------------------
function Get-TFSystemState {
    [CmdletBinding()]
    param()

    Write-TFLog "Ejecutando pre-flight check..." -Level INFO -Component Core

    $osVersion = [System.Environment]::OSVersion.Version
    $isWin11 = $osVersion.Build -ge 22000

    # Internet
    $internet = $false
    try {
        $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
        $internet = $ping
    } catch {
        $internet = $false
    }

    # Winget
    $winget = $false
    try {
        $null = Get-Command winget -ErrorAction Stop
        $winget = $true
    } catch {
        $winget = $false
    }

    # Chocolatey
    $choco = $false
    try {
        $null = Get-Command choco -ErrorAction Stop
        $choco = $true
    } catch {
        $choco = $false
    }

    # USB detection
    $scriptRoot = $PSScriptRoot
    if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $isUSB = $false
    if ($scriptRoot) {
        $driveLetter = (Split-Path $scriptRoot -Qualifier) -replace ':',''
        try {
            $driveType = (Get-Volume -DriveLetter $driveLetter -ErrorAction Stop).DriveType
            $isUSB = $driveType -eq 'Removable'
        } catch {
            $isUSB = $false
        }
    }

    $state = [PSCustomObject]@{
        WindowsVersion    = "$($osVersion.Major).$($osVersion.Minor).$($osVersion.Build)"
        IsWindows11       = $isWin11
        InternetAvailable = $internet
        WingetAvailable   = $winget
        ChocoAvailable    = $choco
        IsUSBExecution    = $isUSB
        SystemDrive       = $env:SystemDrive -replace ':',''
        PSVersion         = "$($PSVersionTable.PSVersion)"
    }

    $Global:TFState = $state

    Write-TFLog "Windows: $($state.WindowsVersion) | Win11: $($state.IsWindows11) | Internet: $($state.InternetAvailable) | Winget: $($state.WingetAvailable) | Choco: $($state.ChocoAvailable) | USB: $($state.IsUSBExecution)" -Level INFO -Component Core

    return $state
}

# -----------------------------------------------------------------------------
# SEGURIDAD Y CREDENCIALES
# -----------------------------------------------------------------------------
function Test-TFAdminPrivilege {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-TFLog "Se requieren privilegios de administrador" -Level ERROR -Component Core
        Write-Host "`n [!] ERROR: Ejecute como Administrador" -ForegroundColor Red
        Write-Host "     Haga clic derecho -> Ejecutar como administrador`n" -ForegroundColor Yellow
    }

    return $isAdmin
}

function Get-TFCredentialHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Password
    )

    $salted = $Password + $Script:SALT
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($salted)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash($bytes)
    $sha.Dispose()

    return [BitConverter]::ToString($hash) -replace '-',''
}

function Test-TFCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Password
    )

    $config = Get-TFConfig
    if (-not $config -or -not $config.security.masterPasswordHash) {
        return $true  # Sin password configurada, permitir
    }

    $hash = Get-TFCredentialHash -Password $Password
    return $hash -eq $config.security.masterPasswordHash
}

function Set-TFMasterPassword {
    [CmdletBinding()]
    param()

    $config = Get-TFConfig

    # Si ya hay password, verificar la actual
    if ($config.security.masterPasswordHash) {
        $current = Read-Host -AsSecureString " Password actual"
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($current)
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

        if (-not (Test-TFCredential -Password $plain)) {
            Write-Host " [!] Password incorrecta" -ForegroundColor Red
            Write-TFLog "Intento fallido de cambio de password" -Level WARN -Component Security
            return
        }
    }

    $new1 = Read-Host -AsSecureString " Nueva password"
    $new2 = Read-Host -AsSecureString " Confirmar password"

    $bstr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($new1)
    $plain1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)

    $bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($new2)
    $plain2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)

    if ($plain1 -ne $plain2) {
        Write-Host " [!] Las passwords no coinciden" -ForegroundColor Red
        return
    }

    if ($plain1.Length -lt 4) {
        Write-Host " [!] Password debe tener al menos 4 caracteres" -ForegroundColor Red
        return
    }

    $config.security.masterPasswordHash = Get-TFCredentialHash -Password $plain1
    Save-TFConfig -Config $config
    Write-Host " [OK] Password actualizada" -ForegroundColor Green
    Write-TFLog "Master password actualizada" -Level INFO -Component Security
}

function Confirm-TFDangerousAction {
    [CmdletBinding()]
    param(
        [string]$Reason = "operacion peligrosa"
    )

    Write-TFLog "Confirmacion requerida: $Reason" -Level WARN -Component Security

    $config = Get-TFConfig

    # Verificar master password si esta configurada
    if ($config.security.requirePasswordForDangerousOps -and $config.security.masterPasswordHash) {
        $pass = Read-Host -AsSecureString " Password maestra"
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass)
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

        if (-not (Test-TFCredential -Password $plain)) {
            Write-Host " [!] Password incorrecta" -ForegroundColor Red
            Write-TFLog "Confirmacion RECHAZADA (password incorrecta): $Reason" -Level WARN -Component Security
            return $false
        }
    }

    # PIN de confirmacion
    $pin = Get-Random -Minimum 1000 -Maximum 9999
    Write-Host " [!] CONFIRMAR: $Reason" -ForegroundColor Yellow
    Write-Host " Ingrese PIN: $pin" -ForegroundColor Cyan
    $input_pin = Read-Host " PIN"

    if ($input_pin -ne $pin.ToString()) {
        Write-Host " [!] PIN incorrecto" -ForegroundColor Red
        Write-TFLog "Confirmacion RECHAZADA (PIN incorrecto): $Reason" -Level WARN -Component Security
        return $false
    }

    Write-TFLog "Confirmacion ACEPTADA: $Reason" -Level INFO -Component Security
    return $true
}

# -----------------------------------------------------------------------------
# VALIDACION DE INPUTS
# -----------------------------------------------------------------------------
function Assert-TFValidPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$MustExist
    )

    # Null o vacio
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Ruta no puede estar vacia"
    }

    # Null bytes
    if ($Path.Contains("`0")) {
        throw "Ruta contiene caracteres nulos"
    }

    # Directory traversal
    $normalized = $Path -replace '\\','/'
    if ($normalized -match '(^|/)\.\.(/|$)') {
        throw "Ruta contiene directory traversal (..)"
    }

    # Caracteres invalidos (excepto : y \ que son validos en Windows paths)
    $invalidChars = [System.IO.Path]::GetInvalidPathChars()
    foreach ($c in $invalidChars) {
        if ($Path.Contains($c)) {
            throw "Ruta contiene caracteres invalidos"
        }
    }

    # Verificar existencia si se requiere
    if ($MustExist -and -not (Test-Path $Path)) {
        throw "Ruta no existe: $Path"
    }

    return $Path
}

function Assert-TFValidDriveLetter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Letter
    )

    $Letter = $Letter.Trim().ToUpper()

    if ($Letter.Length -ne 1 -or $Letter -notmatch '^[A-Z]$') {
        throw "Letra de unidad invalida: '$Letter'. Debe ser una letra A-Z"
    }

    # Bloquear drive del sistema
    $sysDrive = ($env:SystemDrive -replace ':','').ToUpper()
    if ($Letter -eq $sysDrive) {
        throw "No se puede operar sobre la unidad del sistema ($sysDrive`:)"
    }

    # Verificar que el volumen existe
    try {
        $null = Get-Volume -DriveLetter $Letter -ErrorAction Stop
    } catch {
        throw "Volumen no encontrado: $Letter`:"
    }

    return $Letter
}

function Assert-TFValidUsername {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username
    )

    if ([string]::IsNullOrWhiteSpace($Username)) {
        throw "Nombre de usuario no puede estar vacio"
    }

    if ($Username -notmatch '^[a-zA-Z0-9_\-\.]{1,20}$') {
        throw "Nombre de usuario invalido: '$Username'. Solo letras, numeros, _, -, . (max 20 chars)"
    }

    # Nombres reservados
    $reserved = @('Administrator','SYSTEM','LocalService','NetworkService','DefaultAccount','WDAGUtilityAccount','Guest')
    if ($reserved -contains $Username) {
        throw "Nombre de usuario reservado: '$Username'"
    }

    return $Username
}

function Assert-TFValidHostname {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hostname
    )

    if ([string]::IsNullOrWhiteSpace($Hostname)) {
        throw "Hostname no puede estar vacio"
    }

    # Solo alfanumerico, puntos, guiones (hostname o IP)
    if ($Hostname -notmatch '^[a-zA-Z0-9\.\-]+$') {
        throw "Hostname invalido: '$Hostname'. Solo letras, numeros, puntos y guiones"
    }

    return $Hostname
}

function Assert-TFValidProcessTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
        throw "Proceso no puede estar vacio"
    }

    # PID numerico o nombre alfanumerico
    if ($Target -match '^\d+$') {
        return $Target  # PID valido
    }

    if ($Target -notmatch '^[a-zA-Z0-9_\-\.]+$') {
        throw "Nombre de proceso invalido: '$Target'. Solo letras, numeros, _, -, ."
    }

    return $Target
}

# -----------------------------------------------------------------------------
# UI HELPERS
# -----------------------------------------------------------------------------
function Show-TFTitle {
    [CmdletBinding()]
    param()

    Clear-Host
    $border = "=" * 60
    Write-Host ""
    Write-Host " $border" -ForegroundColor Green
    Write-Host "   TECHFLOW SUITE PRO v5.0" -ForegroundColor Green
    Write-Host "   Windows Manager Tool - Modular Edition" -ForegroundColor Green
    Write-Host " $border" -ForegroundColor Green
    Write-Host ""
}

function Show-TFMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Options,

        [string]$Title = "MENU PRINCIPAL",

        [switch]$Horizontal
    )

    Write-Host " --- $Title ---" -ForegroundColor Cyan
    Write-Host ""

    if ($Horizontal) {
        $line = ""
        foreach ($key in ($Options.Keys | Sort-Object)) {
            $line += " [$key] $($Options[$key])  "
            if ($line.Length -gt 80) {
                Write-Host $line -ForegroundColor Cyan
                $line = ""
            }
        }
        if ($line) { Write-Host $line -ForegroundColor Cyan }
    } else {
        foreach ($key in ($Options.Keys | Sort-Object)) {
            Write-Host "  [$key] $($Options[$key])" -ForegroundColor Cyan
        }
    }
    Write-Host ""
}

function Read-TFChoice {
    [CmdletBinding()]
    param(
        [string]$Prompt = " Opcion",

        [string[]]$ValidChoices
    )

    $choice = (Read-Host $Prompt).Trim().ToUpper()

    if ($ValidChoices -and $choice -notin $ValidChoices) {
        Write-Host " [!] Opcion invalida: $choice" -ForegroundColor Yellow
        return $null
    }

    return $choice
}

# -----------------------------------------------------------------------------
# EXPORTS
# -----------------------------------------------------------------------------
Export-ModuleMember -Function @(
    'Write-TFLog',
    'Initialize-TFLog',
    'Get-TFConfig',
    'Save-TFConfig',
    'Get-TFSystemState',
    'Test-TFAdminPrivilege',
    'Get-TFCredentialHash',
    'Test-TFCredential',
    'Set-TFMasterPassword',
    'Confirm-TFDangerousAction',
    'Assert-TFValidPath',
    'Assert-TFValidDriveLetter',
    'Assert-TFValidUsername',
    'Assert-TFValidHostname',
    'Assert-TFValidProcessTarget',
    'Show-TFTitle',
    'Show-TFMenu',
    'Read-TFChoice'
)
