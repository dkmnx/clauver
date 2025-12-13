BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Set-ClauverConfig" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-config-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $env:USERPROFILE = $TestDir

        # Generate test age key
        age-keygen -o (Join-Path $TestDir "age.key") 2>$null
    }

    It "Should configure provider with API key" {
        InModuleScope Clauver {
            Mock Read-ClauverInput { return "https://api.minimax.io" } -ParameterFilter { $Prompt -match "base url" }
            Mock Read-ClauverInput { return "MiniMax-M2" } -ParameterFilter { $Prompt -match "model" }
            Mock Read-ClauverSecureInput { return "test-api-key" }
            Mock Invoke-AgeEncrypt { }
            Mock Write-ClauverSuccess { }

            Set-ClauverConfig -Name "minimax"

            $config = Read-ClauverConfig
            $config['minimax_type'] | Should -Be 'minimax'
            $config['minimax_base_url'] | Should -Be 'https://api.minimax.io'
            $config['minimax_model'] | Should -Be 'MiniMax-M2'
        }
    }
}
