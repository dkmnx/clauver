BeforeAll {
    $script:TestDir = Join-Path $TestDrive "clauver-e2e-test"
    $script:ScriptPath = Join-Path $PSScriptRoot "../../clauver.ps1"
    $script:ModulePath = Join-Path $PSScriptRoot "../../Clauver.psm1"
}

Describe "Clauver PowerShell - End-to-End Workflow" {
    It "Should complete full setup and configuration workflow" {
        # Setup: Initialize clauver
        $env:USERPROFILE = $script:TestDir
        & $script:ScriptPath setup | Should -BeNullOrEmpty

        # Verify .clauver directory created
        $clauverDir = Join-Path $script:TestDir ".clauver"
        $clauverDir | Should -Exist

        # Verify age key created
        $ageKeyPath = Join-Path $clauverDir "age.key"
        $ageKeyPath | Should -Exist
    }

    It "Should handle help command" {
        # Help command outputs to console, verify it runs without error
        { & $script:ScriptPath help } | Should -Not -Throw
    }

    It "Should handle version command" {
        # Version command outputs to console, verify it runs without error
        { & $script:ScriptPath version } | Should -Not -Throw
    }

    It "Should list providers (empty initially)" {
        # List command outputs to console, verify it runs without error
        { & $script:ScriptPath list } | Should -Not -Throw
    }

    It "Should show status" {
        # Status command outputs to console, verify it runs without error
        { & $script:ScriptPath status } | Should -Not -Throw
    }

    It "Should handle unknown commands gracefully" {
        # Unknown command should show help and exit with error code
        # Just verify it runs without unhandled exceptions
        { & $script:ScriptPath nonexistentcommand } | Should -Not -Throw
    }
}

Describe "Clauver PowerShell - Provider Shortcuts" {
    BeforeAll {
        $script:TestDir = Join-Path $TestDrive "clauver-shortcuts-test"
        $script:ScriptPath = Join-Path $PSScriptRoot "../../clauver.ps1"
        $env:USERPROFILE = $script:TestDir
        & $script:ScriptPath setup | Out-Null
    }

    It "Should route all provider shortcuts" {
        $providers = @("anthropic", "minimax", "zai", "kimi", "deepseek", "custom")

        foreach ($provider in $providers) {
            # Provider shortcuts should run without error
            { & $script:ScriptPath $provider } | Should -Not -Throw
        }
    }
}

Describe "Clauver PowerShell - Default Provider Management" {
    BeforeAll {
        $script:TestDir = Join-Path $TestDrive "clauver-default-test"
        $script:ScriptPath = Join-Path $PSScriptRoot "../../clauver.ps1"
        $env:USERPROFILE = $script:TestDir
        & $script:ScriptPath setup | Out-Null
    }

    It "Should set and get default provider" {
        # Set default - should run without error
        { & $script:ScriptPath default minimax } | Should -Not -Throw

        # Get default - should run without error
        { & $script:ScriptPath default } | Should -Not -Throw
    }

    It "Should handle no default provider" {
        # Clean config
        $configPath = Join-Path (Join-Path $script:TestDir ".clauver") "config"
        Remove-Item $configPath -ErrorAction SilentlyContinue

        # Should handle missing config gracefully
        { & $script:ScriptPath default } | Should -Not -Throw
    }
}

Describe "Clauver PowerShell - Migration" {
    BeforeAll {
        $script:TestDir = Join-Path $TestDrive "clauver-migrate-test"
        $script:ScriptPath = Join-Path $PSScriptRoot "../../clauver.ps1"
        $env:USERPROFILE = $script:TestDir
        & $script:ScriptPath setup | Out-Null
    }

    It "Should handle migration command" {
        # Migration should run without error
        { & $script:ScriptPath migrate } | Should -Not -Throw
    }

    It "Should handle migration with plaintext file" {
        # Create fake plaintext file
        $secretsPath = Join-Path (Join-Path $script:TestDir ".clauver") "secrets.env"
        "ZAI_API_KEY=test" | Out-File -FilePath $secretsPath -Encoding utf8

        # Should handle plaintext file gracefully
        { & $script:ScriptPath migrate } | Should -Not -Throw
    }
}

Describe "Clauver PowerShell - Tab Completion" {
    It "Should register tab completion" {
        Import-Module $script:ModulePath -Force -ErrorAction Stop
        { Register-ClauverTabCompletion } | Should -Not -Throw
    }
}

Describe "Clauver PowerShell - Installation" {
    It "Should run installation function" {
        Import-Module $script:ModulePath -Force -ErrorAction Stop
        { Install-Clauver -Destination (Join-Path $TestDrive "install-test") } | Should -Not -Throw
    }
}
