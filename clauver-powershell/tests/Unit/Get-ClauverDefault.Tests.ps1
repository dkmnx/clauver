BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Get-ClauverDefault" {
    It "should return null when no default is set" {
        InModuleScope Clauver {
            Mock Read-ClauverConfig { return @{} }

            $result = Get-ClauverDefault

            $result | Should -BeNullOrEmpty
        }
    }

    It "should return default provider name when set" {
        InModuleScope Clauver {
            Mock Read-ClauverConfig { return @{ default_provider = "minimax" } }

            $result = Get-ClauverDefault

            $result | Should -Be "minimax"
        }
    }
}
