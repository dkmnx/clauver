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

        # Check if key already exists
        if (Test-Path $ageKeyPath) {
            return @{ Success = $true }
        }

        # Check if age command is available - specific error message
        $ageCommand = Get-Command age -ErrorAction SilentlyContinue
        $ageKeygenCommand = Get-Command age-keygen -ErrorAction SilentlyContinue

        if (-not $ageCommand -or -not $ageKeygenCommand) {
            if (-not $ageCommand) {
                Write-ClauverError "age command not found. Please install 'age' package."
            }
            if (-not $ageKeygenCommand) {
                Write-ClauverError "age-keygen command not found. Please install 'age' package."
            }
            Write-Host ""
            Write-Host "Installation instructions:" -ForegroundColor Yellow
            Write-Host "  • Debian/Ubuntu: sudo apt install age" -ForegroundColor White
            Write-Host "  • Fedora/RHEL:   sudo dnf install age" -ForegroundColor White
            Write-Host "  • Arch Linux:    sudo pacman -S age" -ForegroundColor White
            Write-Host "  • macOS:         brew install age" -ForegroundColor White
            Write-Host "  • From source:   https://github.com/FiloSottile/age" -ForegroundColor White
            return @{
                Success = $false
                Error = "age command-line tools not found"
            }
        }

        # Ensure the clauver home directory exists
        if (-not (Test-Path $clauverHome)) {
            try {
                New-Item -Path $clauverHome -ItemType Directory -Force | Out-Null
            }
            catch {
                Write-ClauverError "Failed to create clauver home directory: $clauverHome"
                return @{
                    Success = $false
                    Error = "Failed to create directory: $_"
                }
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

            # Clean up any partially created file
            if (Test-Path $ageKeyPath) {
                Remove-Item -Path $ageKeyPath -Force -ErrorAction SilentlyContinue
            }

            return @{
                Success = $false
                Error = "Age key generation failed with exit code $($process.ExitCode)"
            }
        }

        # Verify the key was created successfully
        if (-not (Test-Path $ageKeyPath)) {
            Write-ClauverError "Age key file was not created at expected location: $ageKeyPath"
            return @{
                Success = $false
                Error = "Age key file not created"
            }
        }

        # Check if the key file has content
        if ((Get-Item $ageKeyPath).Length -eq 0) {
            Write-ClauverError "Age key file is empty: $ageKeyPath"
            Remove-Item -Path $ageKeyPath -Force -ErrorAction SilentlyContinue
            return @{
                Success = $false
                Error = "Age key file is empty"
            }
        }

        # Set secure permissions (cross-platform)
        if (-not (Set-SecureFilePermissions -Path $ageKeyPath)) {
            Write-ClauverWarn "Failed to set secure permissions on age key file. Please set them manually."
        }

        Write-ClauverSuccess "Age encryption key generated at $(Sanitize-ClauverPath $ageKeyPath)"
        Write-Host ""
        Write-ClauverWarn "IMPORTANT: Back up your age key! Without this key, you cannot decrypt your secrets."

        return @{ Success = $true }
    }
    catch {
        Write-ClauverError "Error ensuring age key: $_"

        # Clean up any partially created file on error
        if (Test-Path $ageKeyPath -ErrorAction SilentlyContinue) {
            Remove-Item -Path $ageKeyPath -Force -ErrorAction SilentlyContinue
        }

        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}