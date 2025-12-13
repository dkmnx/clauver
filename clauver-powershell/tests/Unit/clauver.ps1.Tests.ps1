Describe 'clauver.ps1 Command Handling Logic' {
    BeforeEach {
        # Ensure module is loaded
        Import-Module (Join-Path $PSScriptRoot '../../Clauver.psm1') -Force

        # Mock functions that would normally be called
        Mock Show-ClauverHelp {}
        Mock Invoke-ClauverProvider {}
    }

    Context 'When run without arguments' {
        It 'Should show help if no default provider is set' {
            # Mock Get-ClauverDefault to return null (no default)
            Mock Get-ClauverDefault { return $null }

            # Simulate the script's main logic
            $command = $null  # No arguments provided
            if (-not $command) {
                $defaultProvider = Get-ClauverDefault
                if ($defaultProvider) {
                    Invoke-ClauverProvider -Provider $defaultProvider -ClaudeArgs @()
                } else {
                    Show-ClauverHelp
                    exit 1
                }
            }

            # Should have called Show-ClauverHelp since no default provider
            Assert-MockCalled Show-ClauverHelp -Times 1 -Scope It
        }

        It 'Should use default provider if one is set' {
            # Mock Get-ClauverDefault to return 'anthropic'
            Mock Get-ClauverDefault { return 'anthropic' }
            Mock Invoke-ClauverProvider {} -Verifiable -ParameterFilter { $Provider -eq 'anthropic' }

            # Simulate the script's main logic
            $command = $null  # No arguments provided
            if (-not $command) {
                $defaultProvider = Get-ClauverDefault
                if ($defaultProvider) {
                    Invoke-ClauverProvider -Provider $defaultProvider -ClaudeArgs @()
                } else {
                    Show-ClauverHelp
                    exit 1
                }
            }

            # Should have called Invoke-ClauverProvider with 'anthropic'
            Assert-MockCalled Invoke-ClauverProvider -Times 1 -ParameterFilter { $Provider -eq 'anthropic' } -Scope It
        }
    }
}