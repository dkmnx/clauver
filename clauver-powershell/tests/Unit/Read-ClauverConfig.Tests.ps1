BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Read-ClauverConfig" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $env:USERPROFILE = $TestDir

        # Create .clauver directory
        $ClauverDir = Join-Path $TestDir ".clauver"
        New-Item -ItemType Directory -Path $ClauverDir -Force

        $configContent = @"
default_provider=minimax
minimax_base_url=https://api.minimax.io
minimax_model=MiniMax-M2
"@
        $configFile = Join-Path $ClauverDir "config"
        $configContent | Out-File -FilePath $configFile -Encoding utf8
    }

    It "Should read config file correctly" {
        $result = Read-ClauverConfig
        $result['default_provider'] | Should -Be 'minimax'
        $result['minimax_base_url'] | Should -Be 'https://api.minimax.io'
        $result['minimax_model'] | Should -Be 'MiniMax-M2'
    }

    It "Should return empty hashtable for missing config" {
        $ClauverDir = Join-Path $TestDir ".clauver"
        $configFile = Join-Path $ClauverDir "config"
        if (Test-Path $configFile) { Remove-Item $configFile -Force }

        $result = Read-ClauverConfig
        $result.Count | Should -Be 0
    }
}
