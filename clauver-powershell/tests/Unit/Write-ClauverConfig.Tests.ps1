BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Write-ClauverConfig" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-write-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $env:USERPROFILE = $TestDir
    }

    It "Should write config file correctly" {
        $config = @{
            'default_provider' = 'minimax'
            'minimax_base_url' = 'https://api.minimax.io'
        }

        Write-ClauverConfig -Config $config

        $configPath = Join-Path $TestDir ".clauver/config"
        $configPath | Should -Exist

        $content = Get-Content $configPath -Raw
        $content | Should -Match 'default_provider=minimax'
        $content | Should -Match 'minimax_base_url=https://api.minimax.io'
    }
}
