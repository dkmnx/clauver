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

Export-ModuleMember -Function Write-ClauverLog, Write-ClauverSuccess, Write-ClauverWarn, Write-ClauverError
