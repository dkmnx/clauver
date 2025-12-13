BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Invoke-ClauverMigrate" {
    It "should check for plaintext secrets file" {
        InModuleScope Clauver {
            Mock Test-Path { return $false }
            Mock Write-ClauverLog { }

            Invoke-ClauverMigrate

            Assert-MockCalled Test-Path -Times 1 -Scope It
        }
    }

    It "should handle when no plaintext file exists" {
        InModuleScope Clauver {
            Mock Test-Path { return $false }
            Mock Write-ClauverSuccess { }

            Invoke-ClauverMigrate

            Assert-MockCalled Write-ClauverSuccess -Times 1 -Scope It -ParameterFilter { $Message -like "*already encrypted*" }
        }
    }
}
