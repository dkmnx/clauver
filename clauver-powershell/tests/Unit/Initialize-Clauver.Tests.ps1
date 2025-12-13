BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Initialize-Clauver" {
    It "Should create clauver directory structure" {
        $TestDir = Join-Path $TestDrive "test-clauver"
        Initialize-Clauver -HomePath $TestDir

        $configDir = Join-Path $TestDir ".clauver"
        $configDir | Should -Exist

        $ageKeyPath = Join-Path $configDir "age.key"
        $ageKeyPath | Should -Exist
    }
}
