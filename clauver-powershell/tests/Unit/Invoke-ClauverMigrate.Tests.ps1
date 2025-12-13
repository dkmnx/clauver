BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe 'Invoke-ClauverMigrate' {
    Context 'When checking migration status' {
        It 'Should detect already encrypted secrets' {
            InModuleScope Clauver {
                Mock Test-Path {
                    param($Path)
                    if ($Path -like "*.age") { return $true }
                    return $false
                }
                Mock Get-ClauverHome { return "/test/clauver" }
                Mock Write-ClauverSuccess { }
                Mock Write-Host { }
                Mock Sanitize-ClauverPath { param($p) return $p }

                $result = Invoke-ClauverMigrate -CheckOnly

                $result.AlreadyEncrypted | Should -Be $true
                $result.NeedsMigration | Should -Be $false
            }
        }

        It 'Should detect plaintext secrets needing migration' {
            InModuleScope Clauver {
                Mock Test-Path {
                    param($Path)
                    # Return $true only for secrets.env (plaintext file)
                    if ($Path -like "*secrets.env" -and $Path -notlike "*.age") { return $true }
                    return $false
                }
                Mock Get-ClauverHome { return "/test/clauver" }
                Mock Write-ClauverLog { }
                Mock Write-Host { }
                Mock Sanitize-ClauverPath { param($p) return $p }

                $result = Invoke-ClauverMigrate -CheckOnly

                $result.AlreadyEncrypted | Should -Be $false
                $result.NeedsMigration | Should -Be $true
            }
        }

        It 'Should detect no secrets found' {
            InModuleScope Clauver {
                Mock Test-Path { return $false }
                Mock Get-ClauverHome { return "/test/clauver" }
                Mock Write-ClauverWarn { }
                Mock Write-Host { }
                Mock Sanitize-ClauverPath { param($p) return $p }

                $result = Invoke-ClauverMigrate -CheckOnly

                $result.AlreadyEncrypted | Should -Be $false
                $result.NeedsMigration | Should -Be $false
                $result.NoSecretsFound | Should -Be $true
            }
        }
    }

    Context 'When performing migration' {
        It 'Should migrate plaintext to encrypted' {
            InModuleScope Clauver {
                Mock Test-Path {
                    param($Path)
                    # Return $true only for secrets.env (plaintext file)
                    if ($Path -like "*secrets.env" -and $Path -notlike "*.age") { return $true }
                    return $false
                }
                Mock Get-ClauverHome { return "/test/clauver" }
                Mock Write-ClauverLog { }
                Mock Write-Host { }
                Mock Sanitize-ClauverPath { param($p) return $p }
                Mock Ensure-AgeKey { return @{ Success = $true } }
                Mock Perform-Migration { return @{ Success = $true } }

                $result = Invoke-ClauverMigrate

                $result.Success | Should -Be $true
                Assert-MockCalled Ensure-AgeKey -Times 1 -Scope It
                Assert-MockCalled Perform-Migration -Times 1 -Scope It
            }
        }

        It 'Should handle age key failure' {
            InModuleScope Clauver {
                Mock Test-Path {
                    param($Path)
                    # Return $true only for secrets.env (plaintext file)
                    if ($Path -like "*secrets.env" -and $Path -notlike "*.age") { return $true }
                    return $false
                }
                Mock Get-ClauverHome { return "/test/clauver" }
                Mock Write-ClauverLog { }
                Mock Write-ClauverError { }
                Mock Sanitize-ClauverPath { param($p) return $p }
                Mock Ensure-AgeKey { return @{ Success = $false } }

                $result = Invoke-ClauverMigrate

                $result.Success | Should -Be $false
                $result.Error | Should -Be "Age key creation failed"
            }
        }
    }
}