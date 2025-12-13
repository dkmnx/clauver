am(
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

# Copy module files - files are in the same directory as this installer script
$sourceDir = $PSScriptRoot
Copy-Item -Path (Join-Path $sourceDir "Clauver.psm1") -Destination $Destination -Force
Copy-Item -Path (Join-Path $sourceDir "clauver.ps1") -Destination $Destination -Force
Copy-Item -Path (Join-Path $sourceDir "Clauver") -Destination $Destination -Recurse -Force

# Make clauver.ps1 executable (PowerShell equivalent for Windows)
$clauverScript = Join-Path $Destination "clauver.ps1"
if (Test-Path $clauverScript) {
    # Remove readonly attribute if present
    $file = Get-Item $clauverScript
    $file.IsReadOnly = $false
}

Write-Host "SUCCESS: Clauver installed successfully to $Destination" -ForegroundColor Green

# Check if destination is in PATH
$inPath = $env:PATH -split ';' | ForEach-Object { $_.TrimEnd('\') } | Where-Object { $_ -eq $Destination.TrimEnd('\') }

if (-not $inPath) {
    Write-Host ""
    Write-Host "ACTION REQUIRED: Add '$Destination' to your PATH." -ForegroundColor Yellow
    Write-Host "To use 'clauver', you need to add the installation directory to your PATH."
    Write-Host ""
    Write-Host "PowerShell command:" -ForegroundColor Yellow
    Write-Host "    [Environment]::SetEnvironmentVariable('PATH', [Environment]::GetEnvironmentVariable('PATH', 'User') + ';$Destination', 'User')"
    Write-Host ""
    Write-Host "After adding to PATH, restart your terminal or run:" -ForegroundColor Yellow
    Write-Host "    `$env:PATH += ';$Destination'" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host ""
Write-Host "What's next?" -ForegroundColor Cyan -BackgroundColor Black
Write-Host " 1. Quick start:"
Write-Host "    clauver setup              # Interactive setup wizard"
Write-Host ""
Write-Host " 2. Configure a provider:"
Write-Host "    clauver config zai"
Write-Host "    clauver config minimax"
Write-Host "    clauver config kimi"
Write-Host "    clauver config anthropic"
Write-Host ""
Write-Host " 3. Set a default provider (optional):"
Write-Host "    clauver default zai        # Set Z.AI as default"
Write-Host "    clauver default            # Show current default"
Write-Host ""
Write-Host " 4. Use a provider:"
Write-Host "    clauver zai                # Use specific provider"
Write-Host "    clauver minimax"
Write-Host "    clauver anthropic"
Write-Host "    clauver `"your prompt`"      # Use default provider"
Write-Host ""
Write-Host " 5. For all commands:"
Write-Host "    clauver help"
Write-Host ""
Write-Host "Auto-completion enabled!" -ForegroundColor Yellow
Write-Host "  Try: clauver <TAB> to see available commands"
