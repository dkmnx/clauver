function Ensure-AgeKey {
    <#
    .SYNOPSIS
    Ensures the age encryption key exists for encrypting secrets.

    .DESCRIPTION
    Creates an age encryption key if one doesn't exist already.
    This is required for encrypting secrets with age encryption.

    .RETURNS
    Hashtable with Success boolean and optional Error message.
    #>
    [CmdletBinding()]
    param()

    try {
        $clauverHome = Get-ClauverHome
        $ageKeyPath = Join-Path $clauverHome "age.key"

        if (Test-Path $ageKeyPath) {
            return @{ Success = $true }
        }

        # Check if age command is available
        if (-not (Get-Command age -ErrorAction SilentlyContinue)) {
            Write-ClauverError "age command not found. Please install 'age' package."
            Write-Host ""
            Write-Host "Installation instructions:" -ForegroundColor Yellow
            Write-Host "  • Debian/Ubuntu: sudo apt install age" -ForegroundColor White
            Write-Host "  • Fedora/RHEL:   sudo dnf install age" -ForegroundColor White
            Write-Host "  • Arch Linux:    sudo pacman -S age" -ForegroundColor White
            Write-Host "  • macOS:         brew install age" -ForegroundColor White
            Write-Host "  • From source:   https://github.com/FiloSottile/age" -ForegroundColor White
            return @{
                Success = $false
                Error = "age command not found"
            }
        }

        # Generate age key
        Write-ClauverLog "Generating age encryption key..."

        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "age-keygen"
        $processInfo.Arguments = "-o", $ageKeyPath
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        $process.WaitForExit()

        if ($process.ExitCode -ne 0) {
            $errorOutput = $process.StandardError.ReadToEnd()
            Write-ClauverError "Failed to generate age key: $errorOutput"
            return @{
                Success = $false
                Error = "Failed to generate age key"
            }
        }

        # Set secure permissions
        chmod 600 $ageKeyPath

        Write-ClauverSuccess "Age encryption key generated at $(Sanitize-ClauverPath $ageKeyPath)"
        Write-Host ""
        Write-ClauverWarn "IMPORTANT: Back up your age key! Without this key, you cannot decrypt your secrets."

        return @{ Success = $true }
    }
    catch {
        Write-ClauverError "Error ensuring age key: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}