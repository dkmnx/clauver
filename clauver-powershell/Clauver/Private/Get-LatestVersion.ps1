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

        # Security: Verify python3 exists before using it (matching bash implementation)
        $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
        if (-not $pythonCmd) {
            Write-ClauverError "python3 command not found. Please install Python 3."
            return $null
        }

        # GitHub API call matching bash implementation
        $apiUrl = "$script:GitHubApiBase/tags"

        # Use timeout values matching bash implementation
        $connectTimeout = $script:PerformanceDefaults.network_connect_timeout
        $maxTime = $script:PerformanceDefaults.network_max_time

        # Create temporary file for version output
        $tempOutput = New-TemporaryFile

        try {
            # Build Python script matching bash implementation exactly
            $pythonScript = @"
import sys, json, re
try:
    data = json.load(sys.stdin)
    if data and len(data) > 0:
        version = data[0].get('name', '')
        # Sanitize version: allow v followed by numbers and dots, optionally with pre-release tags
        if re.match(r'^v[\d\.]+(?:-[a-zA-Z0-9\.]+)?$', version):
            print(version.lstrip('v'))
except (json.JSONDecodeError, IndexError, KeyError) as e:
    sys.stderr.write(f"Error parsing version: {e}")
    sys.exit(1)
"@

            # Run curl with background job for progress indicator (matching bash)
            $curlJob = Start-Job -ScriptBlock {
                param($Url, $ConnectTimeout, $MaxTime)
                try {
                    $result = curl.exe -s --connect-timeout $ConnectTimeout --max-time $MaxTime $Url 2>$null
                    return $result
                } catch {
                    return $null
                }
            } -ArgumentList $apiUrl, $connectTimeout, $maxTime

            # Show progress for the network request
            if ($Host.UI.RawUI) {
                $progressParams = @{
                    Activity = "Checking GitHub API"
                    Status = "Fetching latest version..."
                    PercentComplete = 0
                }
                Write-Progress @progressParams
            }

            # Wait for job with timeout
            $jobCompleted = Wait-Job -Job $curlJob -Timeout $maxTime

            if ($Host.UI.RawUI) {
                Write-Progress -Activity "Checking GitHub API" -Completed
            }

            if (-not $jobCompleted) {
                Remove-Job $curlJob -Force
                Write-ClauverError "Failed to fetch latest version: timeout"
                return $null
            }

            $apiResponse = Receive-Job $curlJob
            Remove-Job $curlJob

            if (-not $apiResponse) {
                Write-ClauverError "Failed to fetch latest version: no response from GitHub API"
                return $null
            }

            # Process response through Python script
            $pythonCmd = $pythonCmd.Source
            $apiResponse | & $pythonCmd -c $pythonScript 2>$null | Set-Content $tempOutput -Encoding UTF8

            # Check Python exit code
            if ($LASTEXITCODE -ne 0) {
                $errorOutput = Get-Content $tempOutput -ErrorAction SilentlyContinue
                Write-ClauverError "Failed to parse version response: $errorOutput"
                return $null
            }

            # Read and validate version
            $version = (Get-Content $tempOutput -Encoding UTF8).Trim()

            if ($version) {
                # Additional validation: ensure version format is valid
                if ($version -match '^\d+(?:\.\d+)*(?:-[a-zA-Z0-9\.]+)?$') {
                    return $version
                } else {
                    Write-ClauverError "Invalid version format received: $version"
                }
            }
        } finally {
            if (Test-Path $tempOutput) {
                Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-ClauverError "Failed to fetch latest version: $($_.Exception.Message)"
        return $null
    }

    return $null
}