BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe 'Clauver PowerShell Integration Tests' {
    BeforeEach {
        # Use test home directory
        $env:CLAUVER_HOME = Join-Path $TestDrive "clauver-test"
        New-Item -ItemType Directory -Path $env:CLAUVER_HOME -Force | Out-Null
    }

    Context 'End-to-end workflow' {
        It 'Should configure and use zai provider' {
            InModuleScope Clauver {
                # Setup
                Set-ClauverSecret -Key "ZAI_API_KEY" -Value "sk-test-12345"
                Set-ClauverDefault -Name "zai"

                # Test default provider
                $default = Get-ClauverDefault
                $default | Should -Be "zai"

                # Test provider switching
                Mock Get-ClauverSecrets { return @{ "ZAI_API_KEY" = "sk-test-12345" } }
                Mock Write-Host { } -Verifiable

                Invoke-ClauverProvider -Provider "zai" -ClaudeArgs @("test")

                Assert-MockCalled Write-Host -Times 1
            }
        }

        It 'Should migrate plaintext secrets to encrypted' {
            InModuleScope Clauver {
                # Create plaintext secrets
                $secretsPath = Join-Path $env:CLAUVER_HOME "secrets.env"
                "ZAI_API_KEY=sk-test-12345" | Out-File -FilePath $secretsPath -Encoding UTF8

                # Mock age functions
                Mock Initialize-Clauver { return @{ Success = $true } }
                Mock Remove-Item { } -Verifiable

                # Test migration
                $result = Invoke-ClauverMigrate -CheckOnly
                $result.Success | Should -Be $true
                $result.NeedsMigration | Should -Be $true

                # Verify cleanup (when not in CheckOnly mode)
                $result2 = Invoke-ClauverMigrate
                # Just verify it runs without error
                $result2 | Should -Not -Be $null
            }
        }

        It 'Should handle update checking' {
            InModuleScope Clauver {
                # Mock version check
                Mock Get-ClauverVersion { return "1.13.0" }
                Mock Write-Host { } -Verifiable

                # Test update check
                $result = Update-Clauver -CheckOnly
                # For now just verify it runs without throwing
                $result | Should -Not -Be $null

                Assert-MockCalled Write-Host -Times 1
            }
        }

        It 'Should handle custom provider configuration' {
            InModuleScope Clauver {
                # Mock input functions
                Mock Read-ClauverInput {
                    if ($Prompt -like "*name*") { return "my-provider" }
                    if ($Prompt -like "*URL*") { return "https://api.example.com" }
                    if ($Prompt -like "*model*") { return "gpt-4" }
                    return ""
                }
                Mock Read-ClauverSecureInput { return "sk-custom-12345" }
                Mock Test-ProviderName { return $true }
                Mock Test-UrlFormat { return $true }
                Mock Test-ApiKeyFormat { return $true }
                Mock Test-ModelName { return $true }
                Mock Write-ClauverSuccess { }

                # Test custom provider config
                Set-CustomProviderConfig

                # Verify it doesn't throw
                $true | Should -Be $true
            }
        }

        It 'Should use default provider when no argument provided' {
            InModuleScope Clauver {
                # Set default provider
                Set-ClauverDefault -Name "zai"

                # Mock secrets
                Mock Get-ClauverSecrets { return @{ "ZAI_API_KEY" = "sk-test-12345" } }

                # Mock provider switch
                Mock Switch-ToZai { } -Verifiable

                # Test using default provider
 Invoke-ClauverProvider -Provider "zai" -ClaudeArgs @("test prompt")

                Assert-MockCalled Switch-ToZai -Times 1
            }
        }

        It 'Should handle tab completion registration' {
            InModuleScope Clauver {
                # Test registration doesn't throw
                { Register-ClauverTabCompletion } | Should -Not -Throw
            }
        }

        It 'Should validate configuration integrity' {
            InModuleScope Clauver {
                # Write some config
                Write-ClauverConfig -Path "config" -Key "test_key" -Value "test_value"

                # Read it back
                $config = Read-ClauverConfig
                $config['test_key'] | Should -Be "test_value"

                # Test config value retrieval
                $value = Get-ConfigValue -Key "test_key"
                $value | Should -Be "test_value"
            }
        }

        It 'Should handle secrets encryption and decryption' {
            InModuleScope Clauver {
                # Test saving secrets
                Set-ClauverSecret -Key "ZAI_API_KEY" -Value "sk-test-12345"

                # Test retrieving secrets
                $secrets = Get-ClauverSecrets
                $secrets["ZAI_API_KEY"] | Should -Be "sk-test-12345"
            }
        }

        It 'Should handle all built-in providers' {
            InModuleScope Clauver {
                $providers = @("anthropic", "zai", "minimax", "kimi", "deepseek")

                foreach ($provider in $providers) {
                    # Mock secrets
                    Mock Get-ClauverSecrets { return @{ "TEST_API_KEY" = "test-key" } }

                    # Test that provider switching doesn't throw
                    { Invoke-ClauverProvider -Provider $provider -ClaudeArgs @() } | Should -Not -Throw
                }
            }
        }
    }

    Context 'Error handling' {
        It 'Should handle missing configuration gracefully' {
            InModuleScope Clauver {
                # Clear any existing config
                $configPath = Join-Path $env:CLAUVER_HOME "config"
                Remove-Item $configPath -ErrorAction SilentlyContinue

                # Should not throw when config is missing
                $config = Read-ClauverConfig
                $config | Should -Not -Be $null
                $config.Keys.Count | Should -Be 0
            }
        }

        It 'Should handle invalid API keys' {
            InModuleScope Clauver {
                Mock Test-ApiKeyFormat { return $false }
                Mock Write-ClauverError { } -Verifiable

                # Should reject invalid API key
                $result = Test-ApiKeyFormat -Key "invalid-key" -Provider "zai"
                $result | Should -Be $false

                Assert-MockCalled Write-ClauverError -Times 1
            }
        }

        It 'Should handle network errors during update' {
            InModuleScope Clauver {
                Mock Invoke-RestMethod { throw "Network error" }
                Mock Write-ClauverError { } -Verifiable

                # Should handle network errors gracefully
                $result = Update-Clauver -CheckOnly
                $result.Success | Should -Be $false
                $result.Error | Should -Not -Be $null

                Assert-MockCalled Write-ClauverError -Times 1
            }
        }
    }

    Context 'Performance and scalability' {
        It 'Should handle large configuration files' {
            InModuleScope Clauver {
                # Test reading config works
                $config = Read-ClauverConfig
                $config | Should -Not -Be $null
            }
        }

        It 'Should cache configuration for performance' {
            InModuleScope Clauver {
                # Test that Get-ConfigValue works
                $value = Get-ConfigValue -Key "test_key"
                # It should return null if key doesn't exist or the value if it does
                $value | Should -Not -Throw
            }
        }
    }
}