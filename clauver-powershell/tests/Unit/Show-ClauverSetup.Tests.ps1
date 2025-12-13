BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Show-ClauverSetup" {
    BeforeEach {
        Mock Set-ClauverConfig { }
        Mock Write-Host { } -ModuleName Clauver
        Mock Write-ClauverSuccess { } -ModuleName Clauver
        Mock Write-ClauverWarn { } -ModuleName Clauver
        Mock Write-ClauverError { } -ModuleName Clauver
        Mock Read-Host { } -ModuleName Clauver
    }

    It "Should display ASCII art banner" {
        Show-ClauverSetup

        # Verify Write-Host was called with the banner (at least once)
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -match "CLAUVER"
        }
    }

    It "Should show welcome message" {
        Show-ClauverSetup

        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "Welcome to Clauver Setup!"
        }
    }

    It "Should display all menu options" {
        Show-ClauverSetup

        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  1) Use Native Anthropic (free - uses your existing Claude subscription)"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  2) Configure Z.AI (GLM models - requires API key)"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  3) Configure MiniMax (MiniMax-M2 - requires API key)"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  4) Configure Kimi (Moonshot AI - requires API key)"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  5) Configure DeepSeek (DeepSeek Chat - requires API key)"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  6) Add a custom provider"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  7) Skip (I'll configure later)"
        }
    }

    It "Should prompt user for choice" {
        Show-ClauverSetup

        Should -Invoke Read-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Prompt -eq "Choose [1-7]"
        }
    }

    It "Should handle choice 1 - Native Anthropic" {
        Mock Read-Host { return "1" } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Write-ClauverSuccess -ModuleName Clauver -Times 1 -ParameterFilter {
            $Message -eq "Native Anthropic is ready to use!"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "Next steps:"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -match "clauver anthropic"
        }
    }

    It "Should handle choice 2 - Configure Z.AI" {
        Mock Read-Host { return "2" } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Set-ClauverConfig -Times 1 -ParameterFilter {
            $Provider -eq "zai"
        }
    }

    It "Should handle choice 3 - Configure MiniMax" {
        Mock Read-Host { return "3" } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Set-ClauverConfig -Times 1 -ParameterFilter {
            $Provider -eq "minimax"
        }
    }

    It "Should handle choice 4 - Configure Kimi" {
        Mock Read-Host { return "4" } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Set-ClauverConfig -Times 1 -ParameterFilter {
            $Provider -eq "kimi"
        }
    }

    It "Should handle choice 5 - Configure DeepSeek" {
        Mock Read-Host { return "5" } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Set-ClauverConfig -Times 1 -ParameterFilter {
            $Provider -eq "deepseek"
        }
    }

    It "Should handle choice 6 - Custom provider" {
        Mock Read-Host { return "6" } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Set-ClauverConfig -Times 1 -ParameterFilter {
            $Provider -eq "custom"
        }
    }

    It "Should handle choice 7 - Skip" {
        Mock Read-Host { return "7" } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Write-ClauverWarn -ModuleName Clauver -Times 1 -ParameterFilter {
            $Message -eq "Setup skipped."
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -match "clauver setup"
        }
    }

    It "Should handle invalid choice" {
        Mock Read-Host { return "invalid" } -ModuleName Clauver
        Mock exit { } -ModuleName Clauver

        { Show-ClauverSetup } | Should -Throw

        Should -Invoke Write-ClauverError -ModuleName Clauver -Times 1 -ParameterFilter {
            $Message -eq "Invalid choice. Run 'clauver setup' again to retry."
        }
    }

    It "Should always show post-setup information" {
        Mock Read-Host { return "1" } -ModuleName Clauver
        Mock exit { } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "Setup complete!"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "Quick reference:"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "Start using Claude:"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -match "clauver anthropic"
        }
    }

    It "Should display all quick reference commands" {
        Mock Read-Host { return "1" } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  clauver setup        # Run this wizard again"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  clauver list         # See all providers"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  clauver status       # Check configuration"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  clauver help         # View all commands"
        }
    }

    It "Should display start using Claude section" {
        Mock Read-Host { return "1" } -ModuleName Clauver

        Show-ClauverSetup

        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  clauver anthropic    # Use Native Anthropic"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq "  clauver <provider>   # Use any configured provider"
        }
        Should -Invoke Write-Host -ModuleName Clauver -Times 1 -ParameterFilter {
            $Object -eq '  claude "your prompt" # Use current provider'
        }
    }
}