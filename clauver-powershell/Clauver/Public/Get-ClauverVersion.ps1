function Get-ClauverVersion {
    <#
    .SYNOPSIS
        Displays the current version of clauver and checks for updates.
    .DESCRIPTION
        Matches the bash implementation behavior exactly:
        - Shows current version
        - Checks for latest version from GitHub
        - Compares versions and shows status
        - Has colored output matching bash UI functions
    #>
    [CmdletBinding()]
    param()

    # Show current version
    Write-Host "Current version: v$script:ClauverVersion" -ForegroundColor Cyan

    # Try to get latest version
    $latestVersion = Get-LatestVersion

    if ($latestVersion) {
        if ($script:ClauverVersion -eq $latestVersion) {
            Write-Host "✓ You are on the latest version" -ForegroundColor Green
        } elseif (Compare-ClauverVersions -Current $script:ClauverVersion -Latest $latestVersion) {
            Write-Host "! Update available: v$latestVersion" -ForegroundColor Yellow
            Write-Host "Run 'clauver update' to upgrade" -ForegroundColor Yellow
        } else {
            Write-Host "! You are on a pre-release version (v$script:ClauverVersion) newer than latest stable (v$latestVersion)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "! Could not check for updates" -ForegroundColor Yellow
    }
}

