function Update-Clauver {
    <#
    .SYNOPSIS
        Updates clauver to the latest version with version checking.
    .DESCRIPTION
        Downloads and installs the latest version of clauver from GitHub.
        Supports -CheckOnly switch for version checking only.
        Matches bash implementation behavior exactly.
    .PARAMETER CheckOnly
        If specified, only checks for updates without performing them.
    .PARAMETER Force
        If specified, bypasses confirmation prompts.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$CheckOnly,
        [switch]$Force
    )

    try {
        Write-Host "Current version: v$script:ClauverVersion"

        $latestVersion = Get-LatestVersion
        if (-not $latestVersion) {
            Write-ClauverError "Could not determine latest version"
            return @{
                Success = $false
                Error = "Version check failed"
            }
        }

        if ($script:ClauverVersion -eq $latestVersion) {
            Write-Success "You are on the latest version"
            return @{
                Success = $true
                CurrentVersion = $script:ClauverVersion
                LatestVersion = $latestVersion
                NewerVersionAvailable = $false
            }
        }

        # Version comparison logic matching bash sort -V behavior
        $needsUpdate = Compare-ClauverVersions -Current $script:ClauverVersion -Latest $latestVersion

        if ($needsUpdate) {
            Write-Warn "Update available: v$latestVersion"
            Write-Host "Run 'clauver update' to upgrade"

            if ($CheckOnly) {
                return @{
                    Success = $true
                    CurrentVersion = $script:ClauverVersion
                    LatestVersion = $latestVersion
                    NewerVersionAvailable = $true
                }
            }
        } else {
            Write-Warn "You are on a pre-release version (v$script:ClauverVersion) newer than latest stable (v$latestVersion)"

            if (-not $CheckOnly -and -not $Force) {
                $confirm = Read-Host "Rollback to v$latestVersion? This will downgrade your version. [y/N]"
                if ($confirm -notmatch '^[Yy]') {
                    Write-Host "Update cancelled."
                    return @{
                        Success = $true
                        CurrentVersion = $script:ClauverVersion
                        LatestVersion = $latestVersion
                        NewerVersionAvailable = $false
                        IsPreRelease = $true
                        Cancelled = $true
                    }
                }
            }
        }

        # If CheckOnly, return here without performing update
        if ($CheckOnly) {
            return @{
                Success = $true
                CurrentVersion = $script:ClauverVersion
                LatestVersion = $latestVersion
                NewerVersionAvailable = $needsUpdate
                IsPreRelease = (-not $needsUpdate)
            }
        }

        # Perform the actual update
        return Perform-ClauverUpdate -LatestVersion $latestVersion

    } catch {
        Write-ClauverError "Update failed: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Perform-ClauverUpdate {
    <#
    .SYNOPSIS
        Performs the actual download and update of clauver.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$LatestVersion
    )

    # Find clauver installation path
    $installPath = Get-Command clauver -ErrorAction SilentlyContinue
    if (-not $installPath) {
        Write-ClauverError "Clauver installation not found in PATH"
        return @{
            Success = $false
            Error = "Installation not found"
        }
    }
    $installPath = $installPath.Source

    # Check write permissions
    $installDir = Split-Path $installPath -Parent
    if (-not (Test-Path $installDir -PathType Container)) {
        Write-ClauverError "Installation directory not found: $installDir"
        return @{
            Success = $false
            Error = "Installation directory not found"
        }
    }

    # Test write permission by creating a temp file
    $testFile = Join-Path $installDir ".clauver_test_write_$(Get-Random)"
    try {
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item $testFile -Force
    } catch {
        Write-ClauverError "No write permission to $installDir. Try with elevated privileges."
        return @{
            Success = $false
            Error = "No write permission"
        }
    }

    Write-Host "Updating from v$script:ClauverVersion to v$LatestVersion..." -ForegroundColor Blue

    # Create temporary files
    $tempFile = New-TemporaryFile
    $tempChecksum = New-TemporaryFile

    try {
        # Security: Download both script and checksum file
        Write-Log "Starting download process..."

        # Download main script
        $downloadUrl = "$script:RawContentBase/v$LatestVersion/clauver.sh"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -TimeoutSec $script:DownloadTimeout

        if (-not (Test-Path $tempFile -PathType Leaf) -or (Get-Item $tempFile).Length -eq 0) {
            Write-ClauverError "Failed to download update"
            return @{
                Success = $false
                Error = "Download failed"
            }
        }

        # Download checksum file
        $checksumUrl = "$script:RawContentBase/v$LatestVersion/clauver.sh.sha256"
        try {
            Invoke-WebRequest -Uri $checksumUrl -OutFile $tempChecksum -TimeoutSec $script:PerformanceDefaults.network_max_time

            if ((Test-Path $tempChecksum -PathType Leaf) -and (Get-Item $tempChecksum).Length -gt 0) {
                # Verify SHA256 if available
                $expectedHash = (Get-Content $tempChecksum -Raw).Trim().Split()[0]
                $actualHash = (Get-FileHash $tempFile -Algorithm SHA256).Hash

                if ($actualHash -ne $expectedHash) {
                    Write-ClauverError "SHA256 mismatch! File may be corrupted or tampered."
                    Write-ClauverError "Expected: $expectedHash"
                    Write-ClauverError "Got:      $actualHash"
                    return @{
                        Success = $false
                        Error = "SHA256 verification failed"
                    }
                }
                Write-Success "SHA256 verification passed"
            } else {
                Write-Warning "SHA256 checksum file not available for v$LatestVersion"
                Write-Warning "Proceeding without integrity verification (not recommended)"

                if (-not $Force) {
                    $confirm = Read-Host "Continue anyway? [y/N]"
                    if ($confirm -notmatch '^[Yy]') {
                        Write-ClauverError "Update cancelled by user"
                        return @{
                            Success = $false
                            Error = "Cancelled by user"
                        }
                    }
                }
            }
        } catch {
            Write-Warning "SHA256 checksum file not available for v$LatestVersion"
            Write-Warning "Proceeding without integrity verification (not recommended)"

            if (-not $Force) {
                $confirm = Read-Host "Continue anyway? [y/N]"
                if ($confirm -notmatch '^[Yy]') {
                    Write-ClauverError "Update cancelled by user"
                    return @{
                        Success = $false
                        Error = "Cancelled by user"
                    }
                }
            }
        }

        # Install verified update
        if ($PSCmdlet.ShouldProcess($installPath, "Update clauver from v$script:ClauverVersion to v$LatestVersion")) {
            # Backup current version
            $backupPath = "$installPath.backup"
            Copy-Item $installPath $backupPath -Force

            try {
                Copy-Item $tempFile $installPath -Force
                if ($?) {
                    Write-Success "Update complete! Now running v$LatestVersion"
                    Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
                    return @{
                        Success = $true
                        CurrentVersion = $script:ClauverVersion
                        LatestVersion = $LatestVersion
                        Updated = $true
                    }
                } else {
                    throw "Failed to install update"
                }
            } catch {
                # Restore backup on failure
                Copy-Item $backupPath $installPath -Force
                Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
                Write-ClauverError "Failed to install update: $_"
                return @{
                    Success = $false
                    Error = "Installation failed"
                }
            }
        }

    } finally {
        # Cleanup temporary files
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        Remove-Item $tempChecksum -Force -ErrorAction SilentlyContinue
    }
}

# Export function only if running in a module
if ($MyInvocation.InvocationName -ne '.') {
    Export-ModuleMember -Function Update-Clauver
}