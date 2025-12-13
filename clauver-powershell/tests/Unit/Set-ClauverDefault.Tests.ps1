BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Set-ClauverDefault" {
    It "should call Write-ClauverConfig with default_provider" {
        InModuleScope Clauver {
            Mock Read-ClauverConfig { return @{} }
            Mock Write-ClauverConfig { }

            Set-ClauverDefault -Name "minimax"

            Assert-MockCalled Write-ClauverConfig -Times 1 -Scope It
            Assert-MockCalled Read-ClauverConfig -Times 1 -Scope It
        }
    }
}
