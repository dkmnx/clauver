BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Update-Clauver Unit Tests" {
    BeforeEach {
        InModuleScope Clauver {
            # Set test mode environment variable
            $env:CLAUVER_TEST_MODE = "1"

            # Mock external dependencies
            Mock Invoke-RestMethod { }
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Write-Error { }
            Mock Read-Host { return "y" }
            Mock Test-Path { return $true }
            Mock Get-Item { return @{ Length = 1000 } }
            Mock Copy-Item { return $true }
            Mock Remove-Item { }
            Mock Invoke-WebRequest { }
        }
    }

    Context "When checking for updates" {
        It "Should not update if already on latest version" {
            InModuleScope Clauver {
                # Arrange
                Mock Invoke-RestMethod { return @(@{ name = "v1.12.1" }) }

                # Act
                $result = Update-Clauver

                # Assert
                $result | Should -Be 0
                Should -Invoke Write-Host -ParameterFilter {
                    $Object -eq "Already on latest version (v1.12.1)" -and
                    $ForegroundColor -eq [ConsoleColor]::Green
                }
            }
        }

        It "Should warn about pre-release rollback" {
            InModuleScope Clauver {
                # Arrange
                Mock Invoke-RestMethod { return @(@{ name = "v1.10.0" }) }
                Mock Read-Host { return "n" } -ParameterFilter { $Prompt -like "*rollback*" }

                # Act
                $result = Update-Clauver

                # Assert
                $result | Should -Be 0
                Should -Invoke Write-Warning -ParameterFilter {
                    $_ -like "*pre-release version*"
                }
                Should -Invoke Write-Host -ParameterFilter {
                    $Object -eq "Update cancelled."
                }
            }
        }
    }

    Context "When downloading updates" {
        BeforeEach {
            Mock Invoke-RestMethod { return @(@{ name = "v1.13.0" }) }
        }

        It "Should fail if download fails" {
            # Arrange
            Mock Test-Path { return $false }

            # Act
            $result = Update-Clauver

            # Assert
            $result | Should -Be 1
            Should -Invoke Write-Error -ParameterFilter {
                $_ -eq "Failed to download update"
            }
        }

        It "Should warn if checksum not available" {
            # Arrange
            Mock Test-Path -ParameterFilter { $Path -like "*checksum*" } { return $false }
            Mock Test-Path -ParameterFilter { $Path -notlike "*checksum*" } { return $true }

            # Act
            $result = Update-Clauver

            # Assert
            Should -Invoke Write-Warning -ParameterFilter {
                $_ -like "*SHA256 checksum file not available*"
            }
        }
    }

    Context "When installing updates" {
        BeforeEach {
            InModuleScope Clauver {
                Mock Invoke-RestMethod { return @(@{ name = "v1.13.0" }) }
                Mock Test-Path -ParameterFilter { $Path -like "*checksum*" } { return $false }
                Mock Test-Path -ParameterFilter { $Path -notlike "*checksum*" } { return $true }
            }
        }

        It "Should successfully update" {
            InModuleScope Clauver {
                # Act
                $result = Update-Clauver

                # Assert
                $result | Should -Be 0
                Should -Invoke Write-Host -ParameterFilter {
                    $Object -eq "Update complete! Now running v1.13.0" -and
                    $ForegroundColor -eq [ConsoleColor]::Green
                }
            }
        }

        It "Should restore backup on failure" {
            InModuleScope Clauver {
                # Arrange
                Mock Copy-Item -ParameterFilter { $Destination -like "*.backup" } { return $true }
                Mock Copy-Item -ParameterFilter { $Destination -notlike "*.backup" } { throw "Install failed" }

                # Act
                $result = Update-Clauver

                # Assert
                $result | Should -Be 1
                Should -Invoke Write-Error -ParameterFilter {
                    $_ -like "*Failed to install update*"
                }
                # Should restore backup
                Should -Invoke Copy-Item -ParameterFilter {
                    $Destination -eq $installPath
                } -Times 2
            }
        }
    }

    Context "Error handling" {
        It "Should handle GitHub API failure" {
            InModuleScope Clauver {
                # Arrange
                Mock Invoke-RestMethod { throw "API Error" }

                # Act
                $result = Update-Clauver

                # Assert
                $result | Should -Be 1
                Should -Invoke Write-Error -ParameterFilter {
                    $_ -like "*Failed to fetch latest version*"
                }
            }
        }

        It "Should handle missing installation path" {
            InModuleScope Clauver {
                # Arrange
                Mock Invoke-RestMethod { return @(@{ name = "v1.13.0" }) }
                Mock Test-Path { return $false }

                # Act
                $result = Update-Clauver

                # Assert
                $result | Should -Be 1
                Should -Invoke Write-Error -ParameterFilter {
                    $_ -like "*Installation path not found*"
                }
            }
        }
    }
}
