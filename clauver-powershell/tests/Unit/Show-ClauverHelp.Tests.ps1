BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Show-ClauverHelp" {
    It "should display help information" {
        InModuleScope Clauver {
            Mock Write-Host { }

            Show-ClauverHelp

            Assert-MockCalled Write-Host -Times 1 -Scope It
        }
    }

    It "should mention setup command" {
        InModuleScope Clauver {
            Mock Write-Host { }

            Show-ClauverHelp

            Assert-MockCalled Write-Host -Times 1 -Scope It -ParameterFilter {
                $Object -like "*setup*"
            }
        }
    }
}
