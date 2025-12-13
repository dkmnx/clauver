function Get-ClauverHome {
    # Check for test mode first
    if ($env:CLAUVER_TEST_MODE -eq "1") {
        # In test mode, use only the provided CLAUVER_HOME
        if (-not $env:CLAUVER_HOME) {
            throw "CLAUVER_HOME must be set in test mode"
        }
        return $env:CLAUVER_HOME
    }

    # Normal mode - allow fallback to home directory
    if ($env:CLAUVER_HOME) {
        return $env:CLAUVER_HOME
    }

    # Cross-platform: Use USERPROFILE on Windows, HOME on Linux/Unix
    $homePath = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }

    # Normalize path separators for cross-platform compatibility
    $homePath = $homePath -replace '\\', '/'

    # Use string concatenation to avoid Join-Path issues with Windows drive letters on Linux
    return "$homePath/.clauver"
}

