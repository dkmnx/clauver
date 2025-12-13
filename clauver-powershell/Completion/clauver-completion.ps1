#!/usr/bin/env pwsh
# Clauver PowerShell Tab Completion Installation Script

<#
.SYNOPSIS
    Install Clauver tab completion for PowerShell

.DESCRIPTION
    This script installs PowerShell tab completion for the clauver command.
    It registers the completion for the current session and adds it to your PowerShell profile
    for persistence across sessions.

.EXAMPLE
    . ./clauver-completion.ps1
    Installs tab completion and adds to profile

.NOTES
    Requires PowerShell 7+
    Run this script from the Completion directory
#>

param(
    [Parameter()]
    [switch]$NoProfileUpdate
)

try {
    Write-Host "`n=== Clauver Tab Completion Installation ===`n" -ForegroundColor Cyan

    # Get module path
    $scriptDir = Split-Path -Parent $PSCommandPath
    $modulePath = Join-Path $scriptDir ".." "Clauver.psm1"

    if (-not (Test-Path $modulePath)) {
        throw "Clauver module not found at: $modulePath"
    }

    Write-Host "Loading Clauver module..." -ForegroundColor Yellow
    Import-Module $modulePath -Force

    # Register completion for current session
    Write-Host "Registering tab completion..." -ForegroundColor Yellow
    Register-ClauverTabCompletion

    # Add to PowerShell profile for persistence
    if (-not $NoProfileUpdate) {
        $profilePath = $PROFILE.CurrentUserCurrentHost
        $moduleResolvedPath = Resolve-Path $modulePath
        $completionLines = @(
            ""
            "# Clauver tab completion"
            "if (Test-Path '$moduleResolvedPath') {"
            "    Import-Module '$moduleResolvedPath' -Force -ErrorAction SilentlyContinue"
            "    Register-ClauverTabCompletion -ErrorAction SilentlyContinue"
            "}"
        )

        # Create profile if it doesn't exist
        if (-not (Test-Path $profilePath)) {
            Write-Host "Creating PowerShell profile: $profilePath" -ForegroundColor Yellow
            New-Item -Path $profilePath -ItemType File -Force | Out-Null
        }

        # Check if already added
        $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($profileContent -and $profileContent -match "Clauver tab completion") {
            Write-Host "Tab completion already exists in PowerShell profile" -ForegroundColor Green
        } else {
            Add-Content -Path $profilePath -Value ($completionLines -join "`n")
            Write-Host "Added tab completion to PowerShell profile:" -ForegroundColor Green
            Write-Host "  $profilePath"
        }
    }

    # Test completion
    Write-Host "`n=== Testing Tab Completion ===`n" -ForegroundColor Cyan
    Write-Host "Tab completion is now active! Test with:" -ForegroundColor Green
    Write-Host "  clauver <TAB>           # Show main commands" -ForegroundColor White
    Write-Host "  clauver config <TAB>    # Show providers for config" -ForegroundColor White
    Write-Host "  clauver test <TAB>      # Show providers for test" -ForegroundColor White
    Write-Host "  clauver default <TAB>   # Show providers for default" -ForegroundColor White

    if (-not $NoProfileUpdate) {
        Write-Host "`nRestart PowerShell to ensure tab completion persists across sessions." -ForegroundColor Yellow
    }

} catch {
    Write-Error "Failed to install tab completion: $_"
    Write-Error "Exception: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n✓ Clauver tab completion installed successfully!" -ForegroundColor Green