function Get-LatestVersion {
    <#
    .SYNOPSIS
        Gets the latest version of clauver from GitHub API.
    .DESCRIPTION
        Fetches the latest release tag from GitHub API and returns the version number.
        Matches the bash implementation behavior exactly.
    #>
    [CmdletBinding()]
    param()

    try {
        # Only show log message if not being captured (when stdout is a terminal)
        if ($Host.UI.RawUI) {
            Write-Host "Checking for updates..." -ForegroundColor Blue
        }

        # GitHub API call matching bash implementation
        $apiUrl = "$script:GitHubApiBase/tags"

        # Use timeout values matching bash implementation
        $connectTimeout = $script:PerformanceDefaults.network_connect_timeout
        $maxTime = $script:PerformanceDefaults.network_max_time

        $response = Invoke-RestMethod -Uri $apiUrl -TimeoutSec $maxTime

        if ($response -and $response.Count -gt 0) {
            $version = $response[0].name

            # Sanitize version - only allow v followed by numbers and dots
            if ($version -match '^v[\d\.]+$') {
                return $version -replace '^v', ''
            }
        }
    } catch {
        Write-Debug "Failed to fetch latest version: $_"
    }

    return $null
}