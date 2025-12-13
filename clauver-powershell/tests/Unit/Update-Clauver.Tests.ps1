BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe 'Update-Clauver' {
    Context 'When checking for updates' {
        It 'Should detect newer version available' {
            InModuleScope Clauver {
                # Arrange
                Mock Get-LatestVersion { return "1.13.0" }
                Mock Write-Host { } -Verifiable

                # Act
                $result = Update-Clauver -CheckOnly

                # Assert
                $result.Success | Should -Be $true
                $result.NewerVersionAvailable | Should -Be $true
                $result.CurrentVersion | Should -Be "1.12.1"
                $result.LatestVersion | Should -Be "1.13.0"
                Should -Invoke Write-Host -ParameterFilter {
                    $Object -eq "Current version: v1.12.1"
                }
            }
        }

        It 'Should detect no updates needed' {
            InModuleScope Clauver {
                # Arrange
                Mock Get-LatestVersion { return "1.12.1" }
                Mock Write-Host { } -Verifiable

                # Act
                $result = Update-Clauver -CheckOnly

                # Assert
                $result.Success | Should -Be $true
                $result.NewerVersionAvailable | Should -Be $false
                $result.CurrentVersion | Should -Be "1.12.1"
                $result.LatestVersion | Should -Be "1.12.1"
            }
        }

        It 'Should handle pre-release version newer than latest stable' {
            InModuleScope Clauver {
                # Arrange
                Mock Get-LatestVersion { return "1.10.0" }
                Mock Write-Host { } -Verifiable
                Mock Write-Warn { } -Verifiable

                # Act
                $result = Update-Clauver -CheckOnly

                # Assert
                $result.Success | Should -Be $true
                $result.NewerVersionAvailable | Should -Be $false
                $result.IsPreRelease | Should -Be $true
                Should -Invoke Write-Warn -Times 1 -Exactly
            }
        }

        It 'Should handle version check failure' {
            InModuleScope Clauver {
                # Arrange
                Mock Get-LatestVersion { return $null }

                # Act
                $result = Update-Clauver -CheckOnly

                # Assert
                $result.Success | Should -Be $false
                $result.Error | Should -Be "Version check failed"
            }
        }
    }

    Context 'Version comparison edge cases' {
        It 'Should handle version comparison with pre-release tags' {
            InModuleScope Clauver {
                # Test Compare-ClauverVersions directly
                $result = Compare-ClauverVersions -Current "1.12.1-beta" -Latest "1.12.1"
                $result | Should -Be $false  # Pre-release is considered newer
            }
        }

        It 'Should handle version comparison with different number of components' {
            InModuleScope Clauver {
                # Test Compare-ClauverVersions directly
                $result = Compare-ClauverVersions -Current "1.12" -Latest "1.12.1"
                $result | Should -Be $true  # 1.12 < 1.12.1
            }
        }

        It 'Should handle version comparison with complex versions' {
            InModuleScope Clauver {
                # Test Compare-ClauverVersions directly
                $result = Compare-ClauverVersions -Current "1.12.1-alpha" -Latest "1.12.1-beta"
                $result | Should -Be $true  # alpha < beta
            }
        }

        It 'Should handle version comparison with equal versions' {
            InModuleScope Clauver {
                # Test Compare-ClauverVersions directly
                $result = Compare-ClauverVersions -Current "1.12.1" -Latest "1.12.1"
                $result | Should -Be $false  # Equal versions
            }
        }
    }

    Context 'When python3 is not available' {
        It 'Should return null when python3 is not found' {
            InModuleScope Clauver {
                # Arrange
                Mock Get-Command { return $null } -ParameterFilter { $Name -eq "python3" }
                Mock Write-ClauverError { } -Verifiable

                # Act
                $result = Get-LatestVersion

                # Assert
                $result | Should -Be $null
                Should -Invoke Write-ClauverError -ParameterFilter {
                    $Message -like "*python3 command not found*"
                }
            }
        }
    }

    Context 'When downloading fails' {
        BeforeEach {
            InModuleScope Clauver {
                Mock Get-LatestVersion { return "1.13.0" }
                Mock Get-Command {
                    return @{
                        Source = "/test/path/clauver"
                    }
                } -ParameterFilter { $Name -eq "clauver" }
                Mock Test-Path { return $true } -ParameterFilter { $Path -eq "/test/path" }
                Mock Out-File { }
                Mock Remove-Item { }
            }
        }

        It 'Should handle download failure gracefully' {
            InModuleScope Clauver {
                # Arrange
                Mock Invoke-WebRequest { throw "Network error" } -ParameterFilter {
                    $Uri -like "*clauver.sh*"
                }
                Mock Write-ClauverError { }

                # Act
                $result = Update-Clauver -Force

                # Assert
                $result.Success | Should -Be $false
                $result.Error | Should -BeLike "*Download failed*"
            }
        }

        It 'Should handle SHA256 verification failure' {
            InModuleScope Clauver {
                # Arrange
                $tempFile = New-TemporaryFile
                "test content" | Out-File $tempFile
                Mock Invoke-WebRequest {
                    if ($Uri -like "*clauver.sh*") {
                        # Return the temp file
                        return $tempFile
                    } elseif ($Uri -like "*sha256*") {
                        # Return invalid checksum
                        "invalidhash  clauver.sh" | Out-File (New-TemporaryFile)
                        return
                    }
                }
                Mock Write-ClauverError { }
                Mock Get-Content { return "invalidhash" }

                # Act
                $result = Update-Clauver -Force

                # Assert
                $result.Success | Should -Be $false
                $result.Error | Should -Be "SHA256 verification failed"

                # Cleanup
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            }
        }
    }

    Context 'When installing update' {
        BeforeEach {
            InModuleScope Clauver {
                Mock Get-LatestVersion { return "1.13.0" }
                Mock Get-Command {
                    return @{
                        Source = "/test/path/clauver"
                    }
                } -ParameterFilter { $Name -eq "clauver" }
                Mock Test-Path { return $true } -ParameterFilter { $Path -eq "/test/path" }
                Mock Out-File { }
                Mock Copy-Item { }
                Mock Remove-Item { }
                Mock Get-FileHash {
                    return @{
                        Hash = "testhash"
                    }
                }
                Mock Get-Content {
                    if ($Path -like "*sha256*") {
                        return "testhash  clauver.sh"
                    }
                }
            }
        }

        It 'Should backup current version before update' {
            InModuleScope Clauver {
                # Arrange
                $tempFile = New-TemporaryFile
                "test content" | Out-File $tempFile
                Mock Invoke-WebRequest { return $tempFile }
                Mock $PSCmdlet.ShouldProcess { return $true }

                # Act
                $result = Perform-ClauverUpdate -LatestVersion "1.13.0"

                # Assert
                Should -Invoke Copy-Item -Times 2 -Exactly  # Once for backup, once for install
                $result.Success | Should -Be $true

                # Cleanup
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            }
        }

        It 'Should restore backup on installation failure' {
            InModuleScope Clauver {
                # Arrange
                $tempFile = New-TemporaryFile
                "test content" | Out-File $tempFile
                Mock Invoke-WebRequest { return $tempFile }
                Mock Copy-Item {
                    if ($Destination -like "*backup*") {
                        return
                    } else {
                        throw "Installation failed"
                    }
                }
                Mock $PSCmdlet.ShouldProcess { return $true }
                Mock Write-ClauverError { }

                # Act
                $result = Perform-ClauverUpdate -LatestVersion "1.13.0"

                # Assert
                $result.Success | Should -Be $false
                $result.Error | Should -Be "Installation failed"

                # Cleanup
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            }
        }
    }
}

Describe 'Get-LatestVersion' {
    Context 'When GitHub API returns invalid response' {
        It 'Should handle empty response' {
            InModuleScope Clauver {
                # Arrange
                Mock Get-Command { return $true } -ParameterFilter { $Name -eq "python3" }
                Mock Start-Job {
                    return @{
                        State = 'Completed'
                    }
                }
                Mock Receive-Job { return $null }
                Mock Remove-Job { }
                Mock Write-ClauverError { }

                # Act
                $result = Get-LatestVersion

                # Assert
                $result | Should -Be $null
                Should -Invoke Write-ClauverError -ParameterFilter {
                    $Message -like "*no response from GitHub API*"
                }
            }
        }

        It 'Should handle invalid JSON response' {
            InModuleScope Clauver {
                # Arrange
                Mock Get-Command { return $true } -ParameterFilter { $Name -eq "python3" }
                Mock Start-Job {
                    return @{
                        State = 'Completed'
                    }
                }
                Mock Receive-Job { return "invalid json" }
                Mock Remove-Job { }
                Mock Write-ClauverError { }

                # Act
                $result = Get-LatestVersion

                # Assert
                $result | Should -Be $null
            }
        }

        It 'Should handle malformed version tags' {
            InModuleScope Clauver {
                # Arrange
                Mock Get-Command { return $true } -ParameterFilter { $Name -eq "python3" }
                Mock Start-Job {
                    return @{
                        State = 'Completed'
                    }
                }
                Mock Receive-Job { return '[{"name": "invalid-tag"}]' }
                Mock Remove-Job { }
                Mock Write-ClauverError { }

                # Act
                $result = Get-LatestVersion

                # Assert
                $result | Should -Be $null
            }
        }

        It 'Should handle pre-release version tags correctly' {
            InModuleScope Clauver {
                # Arrange
                Mock Get-Command { return $true } -ParameterFilter { $Name -eq "python3" }
                Mock Start-Job {
                    return @{
                        State = 'Completed'
                    }
                }
                Mock Receive-Job { return '[{"name": "v1.13.0-beta"}]' }
                Mock Remove-Job { }
                Mock New-TemporaryFile {
                    $temp = [System.IO.Path]::GetTempFileName()
                    return $temp
                }
                Mock Set-Content { }
                Mock Get-Content { return "1.13.0-beta" }

                # Act
                $result = Get-LatestVersion

                # Assert
                $result | Should -Be "1.13.0-beta"
            }
        }
    }
}