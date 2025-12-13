function Get-ClauverHome {
    # Cross-platform: Use USERPROFILE on Windows, HOME on Linux/Unix
    $homePath = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }

    # Normalize path separators for cross-platform compatibility
    $homePath = $homePath -replace '\\', '/'

    # Use string concatenation to avoid Join-Path issues with Windows drive letters on Linux
    return "$homePath/.clauver"
}

