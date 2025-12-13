BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Read-ClauverInput" {
    It "Should read input with default value" {
        InModuleScope Clauver {
            Mock Read-Host { return "" }

            $result = Read-ClauverInput -Prompt "Enter value" -Default "default"

            Assert-MockCalled Read-Host -Times 1 -ParameterFilter {
                $Prompt -eq "Enter value [default]"
            }
            $result | Should -Be "default"
        }
    }

    It "Should read input without default" {
        InModuleScope Clauver {
            Mock Read-Host { return "user input" }

            $result = Read-ClauverInput -Prompt "Enter value"

            Assert-MockCalled Read-Host -Times 1 -ParameterFilter {
                $Prompt -eq "Enter value"
            }
            $result | Should -Be "user input"
        }
    }
}
