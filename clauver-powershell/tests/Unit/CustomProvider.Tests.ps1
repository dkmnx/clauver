Describe 'Custom Provider Support' {
    BeforeEach {
        # Setup test environment
        $TestDrive = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $TestHome = Join-Path $TestDrive "clauver-test-$(Get-Random)"
        $env:CLAUVER_HOME = $TestHome
        New-Item -ItemType Directory -Path $TestHome -Force | Out-Null

        # Import the module
        $modulePath = Join-Path $PSScriptRoot ".." ".." "Clauver.psm1"
        Import-Module $modulePath -Force
    }

    AfterEach {
        # Cleanup test environment
        if ($TestHome -and (Test-Path $TestHome)) {
            Remove-Item $TestHome -Recurse -Force
        }
        Remove-Module Clauver -ErrorAction SilentlyContinue
    }

    Context 'When detecting custom providers' {
        It 'Should detect custom provider and use it' {
            # Arrange: Setup custom provider config
            $configPath = Join-Path $TestHome "config"
            "custom_myprovider_api_key=sk-test-12345" | Out-File -FilePath $configPath -Encoding UTF8
            "custom_myprovider_base_url=https://api.myprovider.com" | Out-File -FilePath $configPath -Encoding UTF8 -Append

            # Mock within module scope
            InModuleScope "Clauver" {
                # Mock Switch-ToCustom to capture the call
                Mock Switch-ToCustom {} -Verifiable -ParameterFilter {
                    $ProviderName -eq "myprovider" -and $ClaudeArgs -contains "test prompt"
                }

                # Mock the final claude call to prevent actual execution
                Mock "claude" {} -Verifiable
            }

            # Act: Call clauver with custom provider
            & (Join-Path $PSScriptRoot ".." ".." "clauver.ps1") "myprovider" "test prompt"

            # Assert: Verify custom provider was detected and used
            InModuleScope "Clauver" {
                Assert-MockCalled Switch-ToCustom -Times 1 -Exactly
                Assert-MockCalled "claude" -Times 1 -Exactly
            }
        }

        It 'Should fall back to default provider when custom provider not found' {
            # Arrange: Set default provider
            $configPath = Join-Path $TestHome "config"
            "default_provider=zai" | Out-File -FilePath $configPath -Encoding UTF8

            # Mock Invoke-ClauverProvider to capture the call
            Mock Invoke-ClauverProvider {
                param($Provider, $ClaudeArgs)
                return @{ Provider = $Provider; Args = $ClaudeArgs }
            } -Verifiable

            # Act: Call clauver with unknown provider
            $result = & (Join-Path $PSScriptRoot ".." ".." "clauver.ps1") "unknownprovider" "test prompt"

            # Assert: Should use default provider instead
            Assert-MockCalled Invoke-ClauverProvider -Times 1 -ParameterFilter {
                $Provider -eq "zai" -and $ClaudeArgs -contains "unknownprovider" -and $ClaudeArgs -contains "test prompt"
            }
        }

        It 'Should show error when neither custom nor default provider found' {
            # Mock within module scope
            InModuleScope "Clauver" {
                # Mock Show-ClauverHelp
                Mock Show-ClauverHelp {} -Verifiable

                # Mock Write-Host to capture the error output
                Mock Write-Host {} -Verifiable -ParameterFilter { $ForegroundColor -eq "Red" }
            }

            # Act: Call clauver with unknown provider
            try {
                & (Join-Path $PSScriptRoot ".." ".." "clauver.ps1") "unknownprovider"
            } catch {
                # Expected to exit with error
            }

            # Assert: Should show error and help
            InModuleScope "Clauver" {
                Assert-MockCalled Write-Host -Times 1 -Exactly -ParameterFilter { $ForegroundColor -eq "Red" }
                Assert-MockCalled Show-ClauverHelp -Times 1 -Exactly
            }
        }
    }

    Context 'When configuring custom providers' {
        It 'Should validate custom provider name' {
            # Test invalid names
            $invalidNames = @("anthropic", "zai", "minimax", "kimi", "deepseek", "custom", "", "test provider", "test@provider")

            foreach ($name in $invalidNames) {
                $result = Test-ProviderName -ProviderName $name
                $result | Should -Be $false
            }

            # Test valid names
            $validNames = @("myprovider", "test-provider", "test_provider", "provider123", "MyProvider")

            foreach ($name in $validNames) {
                $result = Test-ProviderName -ProviderName $name
                $result | Should -Be $true
            }
        }

        It 'Should validate custom provider configuration' {
            # Arrange: Mock Read-ClauverInput and Read-ClauverSecureInput
            Mock Read-ClauverInput { return "testprovider" } -ParameterFilter { $Prompt -like "*name*" }
            Mock Read-ClauverInput { return "https://api.testprovider.com" } -ParameterFilter { $Prompt -like "*URL*" }
            Mock Read-ClauverSecureInput { return "sk-test-1234567890abcdef" } -ParameterFilter { $Prompt -like "*Key*" }
            Mock Read-ClauverInput { return $null } -ParameterFilter { $Prompt -like "*model*" }
            Mock Write-ClauverConfig {} -Verifiable

            # Act
            Set-CustomProviderConfig

            # Assert
            Assert-MockCalled Write-ClauverConfig -Times 1 -ParameterFilter {
                $Config.ContainsKey("custom_testprovider_api_key") -and
                $Config.ContainsKey("custom_testprovider_base_url")
            }
        }

        It 'Should reject invalid custom provider configuration' {
            # Arrange: Mock invalid inputs
            Mock Read-ClauverInput { return "anthropic" } -ParameterFilter { $Prompt -like "*name*" }
            Mock Write-ClauverError {} -Verifiable

            # Act & Assert
            Set-CustomProviderConfig
            # Note: The function exits, so we check if the error was written
            Assert-MockCalled Write-ClauverError -Times 1
        }
    }

    Context 'When using custom providers' {
        It 'Should load custom provider configuration correctly' {
            # Arrange: Setup custom provider in config
            $configPath = Join-Path $TestHome "config"
            @"
custom_testprovider_api_key=sk-test-1234567890abcdef
custom_testprovider_base_url=https://api.testprovider.com
custom_testprovider_model=test-model-v1
"@ | Out-File -FilePath $configPath -Encoding UTF8

            # Mock Switch-ToCustom to verify it gets called correctly
            Mock Switch-ToCustom {} -Verifiable

            # Act
            Invoke-ClauverProvider -Provider "testprovider" -ClaudeArgs @("test")

            # Assert
            Assert-MockCalled Switch-ToCustom -Times 1 -Exactly -ParameterFilter {
                $ProviderName -eq "testprovider" -and $ClaudeArgs -contains "test"
            }
        }

        It 'Should handle custom provider without optional model' {
            # Arrange: Setup custom provider without model
            $configPath = Join-Path $TestHome "config"
            @"
custom_simpleprovider_api_key=sk-test-1234567890abcdef
custom_simpleprovider_base_url=https://api.simpleprovider.com
"@ | Out-File -FilePath $configPath -Encoding UTF8

            # Mock Switch-ToCustom to verify it gets called correctly
            Mock Switch-ToCustom {} -Verifiable

            # Act
            Invoke-ClauverProvider -Provider "simpleprovider" -ClaudeArgs @("test")

            # Assert
            Assert-MockCalled Switch-ToCustom -Times 1 -Exactly -ParameterFilter {
                $ProviderName -eq "simpleprovider" -and $ClaudeArgs -contains "test"
            }
        }
    }
}