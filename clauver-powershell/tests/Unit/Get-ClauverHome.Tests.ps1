BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Get-ClauverHome" {
    It "Should return USERPROFILE/.clauver path" {
        $env:USERPROFILE = "/home/TestUser"
        $result = Get-ClauverHome
        $result | Should -Be "/home/TestUser/.clauver"
    }

    It "Should handle Windows-style paths on Linux" {
        # Simulate Windows path on Linux system
        $env:USERPROFILE = "C:\Users\TestUser"
        $result = Get-ClauverHome
        # Should normalize to /home-style path or at least not error
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Be "C:/Users/TestUser/.clauver"
    }
}
