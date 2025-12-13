BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Install-Clauver" {
    It "should check for PowerShell availability" {
        InModuleScope Clauver {
            Mock Get-Command { return $true }
            Mock Test-Path { return $false }

            Install-Clauver -Destination "/tmp/test-install"

            Assert-MockCalled Get-Command -Times 1 -Scope It
        }
    }

    It "should create installation directory when it doesn't exist" {
        InModuleScope Clauver {
            Mock Get-Command { return $true }
            Mock Test-Path { return $false }
            Mock New-Item { }

            Install-Clauver -Destination "/tmp/test-install"

            Assert-MockCalled New-Item -Times 1 -Scope It
        }
    }
}
