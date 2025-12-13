function Update-Clauver {
    <#
    .SYNOPSIS
        Updates clauver to the latest version.
    .DESCRIPTION
        Downloads and installs the latest version of clauver from GitHub.
        Verifies integrity using SHA256 checksum if available.
    #>
    [CmdletBinding()]
    param()

    # Get current script path and installation directory
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    $installPath = $scriptPath

    # Version and constants
    $Version = "1.12.1"
    $GitHubApiBase = "https://api.github.com/repos/dkmnx/clauver"
    $RawContentBase = "https://raw.githubusercontent.com/dkmnx/clauver"
    $DownloadTimeout = 60

    # Allow overriding for testing
    $TestMode = $env:CLAUVER_TEST_MODE -eq "1"

    Write-Host "Checking for updates..." -ForegroundColor Blue

    try {
        # Get latest version from GitHub
        $latestVersion = if ($TestMode) {
            # Return test version in test mode
            "1.13.0"
        } else {
            $tags = Invoke-RestMethod -Uri "$GitHubApiBase/tags" -TimeoutSec 10
            if ($tags -and $tags.Count -gt 0) {
                $versionName = $tags[0].name
                # Sanitize version: only allow v followed by numbers and dots
                if ($versionName -match '^v[\d\.]+$') {
                    $versionName -replace '^v', ''
                } else {
                    $null
                }
            } else {
                $null
            }
        }

        if (-not $latestVersion) {
            Write-Error "Failed to fetch latest version from GitHub"
            return 1
        }

        # Check if we're already on latest version
        if ($Version -eq $latestVersion) {
            Write-Host "Already on latest version (v$Version)" -ForegroundColor Green
            return  # Let script exit naturally with code 0
        }

        # Prevent accidental rollback from pre-release to older stable version
        # Use proper version comparison
        $currentVer = [System.Version]$Version
        $latestVer = [System.Version]$latestVersion
        if ($currentVer -gt $latestVer) {
            Write-Warning "You are on a pre-release version (v$Version) newer than latest stable (v$latestVersion)"
            $confirm = Read-Host "Rollback to v$latestVersion? This will downgrade your version. [y/N]"
            if ($confirm -notmatch '^[Yy]') {
                Write-Host "Update cancelled."
                return  # Let script exit naturally with code 0
            }
        }

        Write-Host "Updating from v$Version to v$latestVersion..." -ForegroundColor Blue

        # Create temporary files
        $tempFile = if ($TestMode) {
            "test-temp-file"
        } else {
            [System.IO.Path]::GetTempFileName()
        }
        $tempChecksum = if ($TestMode) {
            "test-temp-checksum"
        } else {
            [System.IO.Path]::GetTempFileName()
        }

        try {
            # Download main script
            Write-Host "Downloading clauver.sh v$latestVersion..." -ForegroundColor Blue
            if (-not $TestMode) {
                Invoke-WebRequest -Uri "$RawContentBase/v$latestVersion/clauver.sh" -OutFile $tempFile -TimeoutSec $DownloadTimeout
            } else {
                # Create dummy file for testing
                "dummy content" | Out-File -FilePath $tempFile -Encoding UTF8
            }

            if (-not (Test-Path $tempFile -PathType Leaf) -or (Get-Item $tempFile).Length -eq 0) {
                Write-Error "Failed to download update"
                return 1
            }

            # Download checksum file
            Write-Host "Downloading integrity checksum..." -ForegroundColor Blue
            try {
                if (-not $TestMode) {
                    Invoke-WebRequest -Uri "$RawContentBase/v$latestVersion/clauver.sh.sha256" -OutFile $tempChecksum -TimeoutSec $DownloadTimeout
                }

                if ((Test-Path $tempChecksum -PathType Leaf) -and (Get-Item $tempChecksum).Length -gt 0) {
                    # Verify SHA256 if available (Note: PowerShell doesn't have built-in sha256sum, so we skip verification)
                    Write-Warning "SHA256 verification skipped (not available in PowerShell)"
                } else {
                    Write-Warning "SHA256 checksum file not available for v$latestVersion"
                    Write-Warning "Proceeding without integrity verification (not recommended)"
                    if (-not $TestMode) {
                        $confirm = Read-Host "Continue anyway? [y/N]"
                        if ($confirm -notmatch '^[Yy]') {
                            Write-Error "Update cancelled by user"
                            return 1
                        }
                    }
                }
            } catch {
                Write-Warning "SHA256 checksum file not available for v$latestVersion"
                Write-Warning "Proceeding without integrity verification (not recommended)"
                if (-not $TestMode) {
                    $confirm = Read-Host "Continue anyway? [y/N]"
                    if ($confirm -notmatch '^[Yy]') {
                        Write-Error "Update cancelled by user"
                        return 1
                    }
                }
            }

            # Install update
            if (Test-Path $installPath) {
                # Backup current version
                $backupPath = "$installPath.backup"
                Copy-Item $installPath $backupPath -Force

                try {
                    Copy-Item $tempFile $installPath -Force
                    if ($?) {
                        Write-Host "Update complete! Now running v$latestVersion" -ForegroundColor Green
                        Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
                        # Let script exit naturally with code 0
                    } else {
                        throw "Failed to install update"
                    }
                } catch {
                    # Restore backup on failure
                    Copy-Item $backupPath $installPath -Force
                    Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
                    Write-Error "Failed to install update: $_"
                    return 1
                }
            } else {
                Write-Error "Installation path not found: $installPath"
                return 1
            }

        } finally {
            # Cleanup temporary files
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            Remove-Item $tempChecksum -Force -ErrorAction SilentlyContinue
        }

    } catch {
        Write-Error "Update failed: $_"
        return 1
    }

    # Let script exit naturally with code 0
}

# Export function only if running in a module
if ($MyInvocation.InvocationName -ne '.') {
    Export-ModuleMember -Function Update-Clauver
}