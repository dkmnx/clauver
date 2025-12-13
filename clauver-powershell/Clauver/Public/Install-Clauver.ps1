function Install-Clauver {
    param(
        [string]$Destination = "$env:USERPROFILE\clauver"
    )

    Write-Host "Installing Clauver to $Destination..." -ForegroundColor Cyan

    # Check if PowerShell is available
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host "PowerShell (pwsh) is required but not installed." -ForegroundColor Red
        exit 1
    }

    # Create installation directory
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    Write-Host "Installation completed successfully!" -ForegroundColor Green
}
