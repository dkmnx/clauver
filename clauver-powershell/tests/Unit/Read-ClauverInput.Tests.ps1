BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Read-ClauverInput" {
    It "Should read input with default value" {
        InModuleScope Clauver {
            Mock Read-Host { return "" }

            $result = Read-ClauverInput -Prompt "Enter value" -Default "default"

            $result | Should -Be "default"
        }
    }

    It "Should read input without default" {
        InModuleScope Clauver {
            Mock Read-Host { return "user input" }

            $result = Read-ClauverInput -Prompt "Enter value"

            $result | Should -Be "user input"
        }
    }
}
