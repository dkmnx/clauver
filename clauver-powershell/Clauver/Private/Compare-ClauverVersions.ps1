function Compare-ClauverVersions {
    <#
    .SYNOPSIS
        Compares two version strings following bash sort -V behavior.
    .DESCRIPTION
        Returns true if Current version is less than Latest version (needs update).
        Returns false if Current version is greater or equal (no update needed).

        This function replicates the exact behavior of bash's `sort -V` command:
        - Versions are split into numeric segments
        - Missing segments are treated as 0
        - Numeric comparison is used for numeric segments
        - Handles pre-release versions (e.g., 1.12.1-beta)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Current,

        [Parameter(Mandatory=$true)]
        [string]$Latest
    )

    try {
        # Function to parse version into components (matching sort -V behavior)
        function Parse-Version {
            param([string]$Version)

            # Split version into numeric and non-numeric parts
            # This handles versions like "1.12.1" and "1.12.1-beta"
            $parts = @()
            $current = ""
            $isNumeric = $false

            for ($i = 0; $i -lt $Version.Length; $i++) {
                $char = $Version[$i]
                $charIsNumeric = $char -match '\d'

                if ($i -eq 0) {
                    $isNumeric = $charIsNumeric
                    $current = $char
                } elseif ($charIsNumeric -eq $isNumeric) {
                    $current += $char
                } else {
                    # Switch between numeric and non-numeric
                    if ($current) {
                        if ($isNumeric) {
                            $parts += [int]$current
                        } else {
                            $parts += $current.ToLower()
                        }
                    }
                    $current = $char
                    $isNumeric = $charIsNumeric
                }
            }

            # Add the last part
            if ($current) {
                if ($isNumeric) {
                    $parts += [int]$current
                } else {
                    $parts += $current.ToLower()
                }
            }

            return $parts
        }

        # Parse both versions
        $currentParts = Parse-Version -Version $Current
        $latestParts = Parse-Version -Version $Latest

        # Compare parts element by element
        $maxLength = [Math]::Max($currentParts.Length, $latestParts.Length)

        for ($i = 0; $i -lt $maxLength; $i++) {
            # Get current parts or default
            $currentVal = if ($i -lt $currentParts.Length) {
                $currentParts[$i]
            } else {
                # Missing trailing parts are treated as 0 for numeric
                0
            }

            # Get latest parts or default
            $latestVal = if ($i -lt $latestParts.Length) {
                $latestParts[$i]
            } else {
                # Missing trailing parts are treated as 0 for numeric
                0
            }

            # Compare based on type
            if ($currentVal -is [int] -and $latestVal -is [int]) {
                # Numeric comparison
                if ($currentVal -lt $latestVal) {
                    return $true  # Current is older, need update
                } elseif ($currentVal -gt $latestVal) {
                    return $false # Current is newer
                }
            } elseif ($currentVal -is [string] -and $latestVal -is [string]) {
                # String comparison
                $compareResult = [string]::Compare($currentVal, $latestVal, $true)
                if ($compareResult -lt 0) {
                    return $true  # Current is older, need update
                } elseif ($compareResult -gt 0) {
                    return $false # Current is newer
                }
            } else {
                # Mixed types: numeric strings come before alphanumeric in sort -V
                if ($currentVal -is [int]) {
                    # Numeric before string: Current is "newer"
                    return $false
                } else {
                    # String before numeric: Current is "older"
                    return $true
                }
            }
        }

        # All parts equal, no update needed
        return $false

    } catch {
        Write-Debug "Version comparison failed: $_"
        # On error, assume no update needed for safety
        return $false
    }
}