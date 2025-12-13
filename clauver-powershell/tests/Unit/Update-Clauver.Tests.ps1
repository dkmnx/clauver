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
}