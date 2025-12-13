# NOTE: Write-Host is intentionally used in this module instead of Write-Output
# because Clauver is a CLI tool and Write-Host provides the best user experience
# for direct console output with colors. The PSAvoidUsingWriteHost warning is
# suppressed in PSScriptAnalyzerSettings.psd1 for this reason.

$ClauverColors = @{
    Info    = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error   = 'Red'
    Banner  = 'Magenta'
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

# Aliases for shorter function names (matching bash implementation)
New-Alias -Name Write-Log -Value Write-ClauverLog
New-Alias -Name Write-Success -Value Write-ClauverSuccess
New-Alias -Name Write-Warn -Value Write-ClauverWarn
New-Alias -Name ui_success -Value Write-ClauverSuccess
New-Alias -Name ui_warn -Value Write-ClauverWarn
New-Alias -Name ui_error -Value Write-ClauverError
New-Alias -Name ui_log -Value Write-ClauverLog

