$ClauverColors = @{
    Info = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Banner = 'Magenta'
}

function Write-ClauverLog {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor $ClauverColors.Info
}

function Write-ClauverSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $ClauverColors.Success
}

function Write-ClauverWarn {
    param([string]$Message)
    Write-Host "! $Message" -ForegroundColor $ClauverColors.Warning
}

function Write-ClauverError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $ClauverColors.Error
}

function Show-ClauverBanner {
    param([string]$Provider)
    
    $version = "1.12.1"
    $bannerColor = $ClauverColors.Banner
    
    Write-Host ""
    Write-Host -ForegroundColor $bannerColor "  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗"
    Write-Host -ForegroundColor $bannerColor " ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗"
    Write-Host -ForegroundColor $bannerColor " ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝"
    Write-Host -ForegroundColor $bannerColor " ██║     ██║     ██╔══██║██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗"
    Write-Host -ForegroundColor $bannerColor " ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║"
    Write-Host -ForegroundColor $bannerColor "  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝"
    Write-Host -ForegroundColor $bannerColor "  v$version - $Provider"
    Write-Host ""
}

Export-ModuleMember -Function Write-ClauverLog, Write-ClauverSuccess, Write-ClauverWarn, Write-ClauverError, Show-ClauverBanner
