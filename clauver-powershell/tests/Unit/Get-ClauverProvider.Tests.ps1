BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Get-ClauverProvider" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-list-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $script:ClauverHome = $TestDir
    }

    It "Should list configured providers" {
        Mock -CommandName Read-ClauverConfig -ModuleName Clauver -MockWith { return @{
            'minimax_type' = 'minimax'
            'zai_type' = 'zai'
        }}

        $result = Get-ClauverProvider
        $result | Should -Contain "minimax"
        $result | Should -Contain "zai"
    }

    It "Should return empty list when no providers configured" {
        Mock -CommandName Read-ClauverConfig -ModuleName Clauver -MockWith { return @{} }

        $result = Get-ClauverProvider
        $result.Count | Should -Be 0
    }
}
