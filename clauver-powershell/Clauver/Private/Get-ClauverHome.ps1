function Get-ClauverHome {
    # Normalize path separators for cross-platform compatibility
    $homePath = $env:USERPROFILE -replace '\\', '/'
    # Use string concatenation to avoid Join-Path issues with Windows drive letters on Linux
    return "$homePath/.clauver"
}
