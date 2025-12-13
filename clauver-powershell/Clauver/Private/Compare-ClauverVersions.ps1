function Compare-ClauverVersions {
    <#
    .SYNOPSIS
        Compares two version strings following bash sort -V behavior.
    .DESCRIPTION
        Returns true if Current version is less than Latest version (needs update).
        Returns false if Current version is greater or equal (no update needed).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Current,

        [Parameter(Mandatory=$true)]
        [string]$Latest
    )

    try {
        # Split versions into integer components
        $currentParts = $Current -split '\.' | ForEach-Object {
            if ($_ -match '^\d+$') { [int]$_ } else { 0 }
        }
        $latestParts = $Latest -split '\.' | ForEach-Object {
            if ($_ -match '^\d+$') { [int]$_ } else { 0 }
        }

        $maxLength = [Math]::Max($currentParts.Length, $latestParts.Length)

        for ($i = 0; $i -lt $maxLength; $i++) {
            $currentVal = if ($i -lt $currentParts.Length) { $currentParts[$i] } else { 0 }
            $latestVal = if ($i -lt $latestParts.Length) { $latestParts[$i] } else { 0 }

            if ($currentVal -lt $latestVal) {
                return $true  # Need update
            } elseif ($currentVal -gt $latestVal) {
                return $false # Current is newer
            }
        }

        return $false # Same version
    } catch {
        Write-Debug "Version comparison failed: $_"
        return $false
    }
}