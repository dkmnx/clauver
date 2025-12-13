BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Register-ClauverTabCompletion" {
    It "should register tab completion for clauver command" {
        InModuleScope Clauver {
            Mock Register-ArgumentCompleter { }

            Register-ClauverTabCompletion

            Assert-MockCalled Register-ArgumentCompleter -Times 1 -Scope It
        }
    }

    It "should provide command completions" {
        InModuleScope Clauver {
            Mock Register-ArgumentCompleter { }

            Register-ClauverTabCompletion

            # Verify argument completer was registered
            Assert-MockCalled Register-ArgumentCompleter -Times 1 -Scope It
        }
    }
}
