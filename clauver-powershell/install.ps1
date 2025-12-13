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

# Copy module files
$sourceDir = Split-Path -Parent $PSScriptRoot
Copy-Item -Path (Join-Path $sourceDir "Clauver.psm1") -Destination $Destination -Force
Copy-Item -Path (Join-Path $sourceDir "clauver.ps1") -Destination $Destination -Force
Copy-Item -Path (Join-Path $sourceDir "Clauver") -Destination $Destination -Recurse -Force

# Make clauver.ps1 executable
chmod +x (Join-Path $Destination "clauver.ps1") 2>$null

Write-Host "✓ Clauver installed successfully to $Destination" -ForegroundColor Green
Write-Host "Add '$Destination' to your PATH to use clauver from anywhere." -ForegroundColor Yellow
