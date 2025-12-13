BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Get-ClauverHome" {
    It "Should return USERPROFILE/.clauver path" {
        $env:USERPROFILE = "/home/TestUser"
        $result = Get-ClauverHome
        $result | Should -Be "/home/TestUser/.clauver"
    }
}
