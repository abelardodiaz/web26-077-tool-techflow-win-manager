@{
    RootModule        = ''
    ModuleVersion     = '5.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'TechFlow Team'
    Description       = 'TechFlow Suite Pro - Windows IT Support Toolkit'
    PowerShellVersion = '5.1'

    NestedModules     = @(
        'modules\Core\Core.psm1',
        'modules\Backup\Backup.psm1',
        'modules\Packages\Packages.psm1',
        'modules\System\System.psm1',
        'modules\Security\Security.psm1',
        'modules\Network\Network.psm1',
        'modules\Maintenance\Maintenance.psm1',
        'modules\Users\Users.psm1',
        'modules\Drivers\Drivers.psm1',
        'modules\DangerZone\DangerZone.psm1'
    )

    FunctionsToExport = @(
        # Core
        'Write-TFLog','Initialize-TFLog','Get-TFConfig','Save-TFConfig',
        'Get-TFSystemState','Test-TFAdminPrivilege',
        'Get-TFCredentialHash','Test-TFCredential','Set-TFMasterPassword',
        'Confirm-TFDangerousAction',
        'Assert-TFValidPath','Assert-TFValidDriveLetter','Assert-TFValidUsername',
        'Assert-TFValidHostname','Assert-TFValidProcessTarget',
        'Show-TFTitle','Show-TFMenu','Read-TFChoice',
        # Backup
        'Invoke-TFBackupRestore',
        # Packages
        'Invoke-TFSmartInstall','Invoke-TFAppCatalog','Invoke-TFPackageManager',
        # System
        'Invoke-TFTempCleanup','Show-TFSystemMonitor','Invoke-TFAutoMaintenance',
        # Security
        'Invoke-TFDefenderControl','Invoke-TFWin11Bypass',
        # Network
        'Invoke-TFNetworkTools',
        # Maintenance
        'Invoke-TFDiskMaintenance','Invoke-TFTechSupport',
        # Users
        'Invoke-TFUserManagement',
        # Drivers
        'Invoke-TFDriverManagement',
        # DangerZone
        'Invoke-TFPurgeAndFormat','Invoke-TFExternalTool'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
}
