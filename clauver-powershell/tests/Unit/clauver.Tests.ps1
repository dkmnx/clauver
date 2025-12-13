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

    It "Should route list command" {
        Mock Get-ClauverProviderList { return @() }

        & $scriptPath list

        Assert-MockCalled Get-ClauverProviderList -Times 1
    }

    It "Should show error for unknown command" {
        $result = & $scriptPath unknowncommand 2>&1
        $result | Should -Match "Unknown command"
    }
}
