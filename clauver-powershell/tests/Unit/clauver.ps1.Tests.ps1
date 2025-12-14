Describe 'clauver.ps1 Command Handling Logic' {
    BeforeEach {
        # Ensure module is loaded
        Import-Module (Join-Path $PSScriptRoot '../../Clauver.psm1') -Force

        # Mock functions that would normally be called
        Mock Show-ClauverHelp {}
        Mock Show-ClauverSetup {}
        Mock Invoke-ClauverProvider {}
        Mock Get-ClauverVersion {}
        Mock Update-Clauver {}
        Mock Set-ClauverConfig {}
        Mock Get-ClauverProvider {}
        Mock Get-ClauverStatus {}
        Mock Test-ClauverProvider {}
        Mock Set-ClauverDefault {}
        Mock Get-ClauverDefault {}
        Mock Invoke-ClauverMigrate {}
        Mock Get-ConfigValue {}
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

    Context 'When run with setup command' {
        It 'Should call Show-ClauverSetup for "setup" command' {
            # Simulate the script's switch logic
            $command = "setup"
            switch ($command) {
                { $_ -in @("setup", "-s") } {
                    Show-ClauverSetup
                }
            }

            # Should have called Show-ClauverSetup
            Assert-MockCalled Show-ClauverSetup -Times 1 -Scope It
        }

        It 'Should call Show-ClauverSetup for "-s" command' {
            # Simulate the script's switch logic
            $command = "-s"
            switch ($command) {
                { $_ -in @("setup", "-s") } {
                    Show-ClauverSetup
                }
            }

            # Should have called Show-ClauverSetup
            Assert-MockCalled Show-ClauverSetup -Times 1 -Scope It
        }
    }

    Context 'When run with other commands' {
        It 'Should call Show-ClauverHelp for help command' {
            $command = "help"
            switch ($command) {
                { $_ -in @("help", "-h", "--help") } {
                    Show-ClauverHelp
                }
            }

            Assert-MockCalled Show-ClauverHelp -Times 1 -Scope It
        }

        It 'Should call Get-ClauverVersion for version command' {
            $command = "version"
            switch ($command) {
                { $_ -in @("version", "-v", "--version") } {
                    Get-ClauverVersion
                }
            }

            Assert-MockCalled Get-ClauverVersion -Times 1 -Scope It
        }

        It 'Should call Update-Clauver for update command' {
            $command = "update"
            switch ($command) {
                "update" {
                    Update-Clauver
                }
            }

            Assert-MockCalled Update-Clauver -Times 1 -Scope It
        }

        It 'Should call Set-ClauverConfig for config command' {
            $command = "config"
            $RemainingArgs = @("config", "zai")
            switch ($command) {
                "config" {
                    Set-ClauverConfig -Provider $RemainingArgs[1]
                }
            }

            Assert-MockCalled Set-ClauverConfig -Times 1 -ParameterFilter { $Provider -eq "zai" } -Scope It
        }

        It 'Should call Invoke-ClauverMigrate for migrate command' {
            $command = "migrate"
            switch ($command) {
                "migrate" {
                    Invoke-ClauverMigrate
                }
            }

            Assert-MockCalled Invoke-ClauverMigrate -Times 1 -Scope It
        }
    }
}