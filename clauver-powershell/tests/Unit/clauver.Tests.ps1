BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
    $scriptDir = Split-Path -Parent $PSCommandPath
    $parentDir = Split-Path -Parent $scriptDir
    $grandparentDir = Split-Path -Parent $parentDir
    $scriptPath = Join-Path $grandparentDir "clauver.ps1"
}

Describe "clauver entry point" {
    It "Should route setup command" {
        Mock Initialize-Clauver { }

        & $scriptPath setup

        Assert-MockCalled Initialize-Clauver -Times 1
    }

    It "Should route config command" {
        Mock Set-ClauverConfig { }

        & $scriptPath config minimax

        Assert-MockCalled Set-ClauverConfig -Times 1 -ParameterFilter { $Name -eq "minimax" }
    }

    It "Should route help command" {
        Mock Show-ClauverHelp { }

        & $scriptPath help

        Assert-MockCalled Show-ClauverHelp -Times 1
    }

    It "Should route list command" {
        Mock Get-ClauverProviderList { return @() }

        & $scriptPath list

        Assert-MockCalled Get-ClauverProviderList -Times 1
    }

    It "Should route status command" {
        Mock Get-ClauverStatus { }

        & $scriptPath status

        Assert-MockCalled Get-ClauverStatus -Times 1
    }

    It "Should route test command" {
        Mock Test-ClauverProvider { }

        & $scriptPath test minimax

        Assert-MockCalled Test-ClauverProvider -Times 1 -ParameterFilter { $Name -eq "minimax" }
    }

    It "Should route version command" {
        Mock Get-ClauverVersion { }

        & $scriptPath version

        Assert-MockCalled Get-ClauverVersion -Times 1
    }

    It "Should route default command with provider name" {
        Mock Set-ClauverDefault { }

        & $scriptPath default minimax

        Assert-MockCalled Set-ClauverDefault -Times 1 -ParameterFilter { $Name -eq "minimax" }
    }

    It "Should route migrate command" {
        Mock Invoke-ClauverMigrate { }

        & $scriptPath migrate

        Assert-MockCalled Invoke-ClauverMigrate -Times 1
    }

    It "Should route provider shortcut commands" {
        Mock Invoke-ClauverProvider { }

        & $scriptPath minimax

        Assert-MockCalled Invoke-ClauverProvider -Times 1 -ParameterFilter { $Name -eq "minimax" }
    }
}
