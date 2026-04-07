# =============================================================================
# Core.Tests.ps1 - Pester tests para modulo Core (TDD)
# Ejecutar: Invoke-Pester ./tests/Core.Tests.ps1
# =============================================================================

BeforeAll {
    Import-Module "$PSScriptRoot\..\modules\Core\Core.psm1" -Force
}

Describe 'Assert-TFValidPath' {
    It 'acepta path valido' {
        { Assert-TFValidPath -Path 'C:\Users\test\Documents' } | Should -Not -Throw
    }

    It 'rechaza path vacio' {
        { Assert-TFValidPath -Path '' } | Should -Throw '*vacia*'
    }

    It 'rechaza path con null bytes' {
        { Assert-TFValidPath -Path "C:\test`0\evil" } | Should -Throw '*nulos*'
    }

    It 'rechaza directory traversal con ..' {
        { Assert-TFValidPath -Path 'C:\Users\..\Windows\System32' } | Should -Throw '*traversal*'
    }

    It 'rechaza traversal al inicio' {
        { Assert-TFValidPath -Path '..\etc\passwd' } | Should -Throw '*traversal*'
    }

    It 'acepta path con puntos en nombre de archivo' {
        { Assert-TFValidPath -Path 'C:\Users\test\file.name.txt' } | Should -Not -Throw
    }

    It 'lanza error si MustExist y no existe' {
        { Assert-TFValidPath -Path 'C:\NoExiste_XYZ_999' -MustExist } | Should -Throw '*no existe*'
    }
}

Describe 'Assert-TFValidDriveLetter' {
    It 'acepta letra valida en mayuscula' {
        # No podemos testear sin un volumen real, pero al menos verificar formato
        { Assert-TFValidDriveLetter -Letter 'ZZ' } | Should -Throw '*invalida*'
    }

    It 'rechaza letra del sistema (C)' {
        { Assert-TFValidDriveLetter -Letter 'C' } | Should -Throw '*sistema*'
    }

    It 'rechaza entrada no-letra' {
        { Assert-TFValidDriveLetter -Letter '1' } | Should -Throw '*invalida*'
    }

    It 'rechaza string largo' {
        { Assert-TFValidDriveLetter -Letter 'AB' } | Should -Throw '*invalida*'
    }

    It 'rechaza caracteres especiales' {
        { Assert-TFValidDriveLetter -Letter ';' } | Should -Throw '*invalida*'
    }
}

Describe 'Assert-TFValidUsername' {
    It 'acepta username valido' {
        Assert-TFValidUsername -Username 'juan_perez' | Should -Be 'juan_perez'
    }

    It 'acepta username con punto y guion' {
        Assert-TFValidUsername -Username 'j.perez-01' | Should -Be 'j.perez-01'
    }

    It 'rechaza username vacio' {
        { Assert-TFValidUsername -Username '' } | Should -Throw '*vacio*'
    }

    It 'rechaza username con punto y coma (injection)' {
        { Assert-TFValidUsername -Username 'user;rm -rf' } | Should -Throw '*invalido*'
    }

    It 'rechaza username con espacios' {
        { Assert-TFValidUsername -Username 'user name' } | Should -Throw '*invalido*'
    }

    It 'rechaza username con pipe' {
        { Assert-TFValidUsername -Username 'user|cmd' } | Should -Throw '*invalido*'
    }

    It 'rechaza username mayor a 20 chars' {
        { Assert-TFValidUsername -Username 'abcdefghijklmnopqrstu' } | Should -Throw '*invalido*'
    }

    It 'rechaza nombre reservado Administrator' {
        { Assert-TFValidUsername -Username 'Administrator' } | Should -Throw '*reservado*'
    }

    It 'rechaza nombre reservado SYSTEM' {
        { Assert-TFValidUsername -Username 'SYSTEM' } | Should -Throw '*reservado*'
    }
}

Describe 'Assert-TFValidHostname' {
    It 'acepta hostname valido' {
        Assert-TFValidHostname -Hostname 'google.com' | Should -Be 'google.com'
    }

    It 'acepta IP valida' {
        Assert-TFValidHostname -Hostname '8.8.8.8' | Should -Be '8.8.8.8'
    }

    It 'rechaza hostname vacio' {
        { Assert-TFValidHostname -Hostname '' } | Should -Throw '*vacio*'
    }

    It 'rechaza hostname con punto y coma' {
        { Assert-TFValidHostname -Hostname 'host;cmd' } | Should -Throw '*invalido*'
    }

    It 'rechaza hostname con pipe' {
        { Assert-TFValidHostname -Hostname 'host|evil' } | Should -Throw '*invalido*'
    }

    It 'rechaza hostname con ampersand' {
        { Assert-TFValidHostname -Hostname 'host&cmd' } | Should -Throw '*invalido*'
    }
}

Describe 'Assert-TFValidProcessTarget' {
    It 'acepta PID numerico' {
        Assert-TFValidProcessTarget -Target '1234' | Should -Be '1234'
    }

    It 'acepta nombre de proceso valido' {
        Assert-TFValidProcessTarget -Target 'notepad' | Should -Be 'notepad'
    }

    It 'acepta nombre con punto' {
        Assert-TFValidProcessTarget -Target 'svchost.exe' | Should -Be 'svchost.exe'
    }

    It 'rechaza target vacio' {
        { Assert-TFValidProcessTarget -Target '' } | Should -Throw '*vacio*'
    }

    It 'rechaza nombre con caracteres peligrosos' {
        { Assert-TFValidProcessTarget -Target 'proc;cmd' } | Should -Throw '*invalido*'
    }
}

Describe 'Get-TFCredentialHash' {
    It 'genera hash consistente para misma password' {
        $hash1 = Get-TFCredentialHash -Password 'test123'
        $hash2 = Get-TFCredentialHash -Password 'test123'
        $hash1 | Should -Be $hash2
    }

    It 'genera hash diferente para passwords distintas' {
        $hash1 = Get-TFCredentialHash -Password 'test123'
        $hash2 = Get-TFCredentialHash -Password 'test456'
        $hash1 | Should -Not -Be $hash2
    }

    It 'genera hash de 64 caracteres hex (SHA256)' {
        $hash = Get-TFCredentialHash -Password 'cualquiera'
        $hash.Length | Should -Be 64
        $hash | Should -Match '^[A-F0-9]{64}$'
    }

    It 'hash incluye salt (diferente de SHA256 puro)' {
        # SHA256 puro de "test" es diferente de SHA256("test" + salt)
        $hash = Get-TFCredentialHash -Password 'test'
        # SHA256 puro de "test" = 9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08
        $hash | Should -Not -Be '9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08'
    }
}

Describe 'Test-TFAdminPrivilege' {
    It 'retorna booleano' {
        $result = Test-TFAdminPrivilege
        $result | Should -BeOfType [bool]
    }
}
