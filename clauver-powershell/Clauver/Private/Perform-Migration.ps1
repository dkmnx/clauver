function Perform-Migration {
    <#
    .SYNOPSIS
    Performs the actual migration from plaintext secrets to encrypted format.

    .DESCRIPTION
    Sources the plaintext secrets into environment variables (like bash),
    then encrypts them using age and removes the plaintext file.

    .PARAMETER PlaintextPath
    Path to the plaintext secrets.env file.

    .PARAMETER EncryptedPath
    Path where the encrypted secrets.env.age file should be created.

    .RETURNS
    Hashtable with Success boolean and optional Error message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlaintextPath,

        [Parameter(Mandatory = $true)]
        [string]$EncryptedPath
    )

    try {
        # Load existing plaintext secrets into environment variables (matching bash behavior)
        Write-ClauverLog "Loading plaintext secrets..."
        Import-ClauverSecrets -SecretsPath $PlaintextPath

        # Read all lines from plaintext file to prepare for encryption
        $secretsContent = Get-Content -Path $PlaintextPath -Raw -Encoding UTF8

        if ([string]::IsNullOrWhiteSpace($secretsContent)) {
            return @{
                Success = $false
                Error = "Plaintext secrets file is empty"
            }
        }

        # Prepare secrets data for encryption (matching bash save_secrets behavior)
        $secretsData = @()
        $lines = $secretsContent -split "`n"

        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -and -not $line.StartsWith('#')) {
                # Only include lines that look like environment variables
                if ($line -match '^[A-Z_][A-Z0-9_]*=.*$') {
                    $secretsData += $line
                }
            }
        }

        if ($secretsData.Count -eq 0) {
            return @{
                Success = $false
                Error = "No valid secrets found in plaintext file"
            }
        }

        $secretsText = $secretsData -join "`n"

        # Encrypt directly from memory
        Write-ClauverLog "Encrypting secrets..."

        $ageKeyPath = Get-ClauverAgeKey
        if (-not $ageKeyPath) {
            return @{
                Success = $false
                Error = "Age key not found"
            }
        }

        # Create process for age encryption
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "age"
        $processInfo.Arguments = "-e", "-i", $ageKeyPath, "-o", $EncryptedPath
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardInput = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        # Write the secrets to stdin
        $process.StandardInput.Write($secretsText)
        $process.StandardInput.Close()

        # Wait for completion with progress indicator
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $spinner = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
        $spinnerIndex = 0

        while (-not $process.WaitForExit(100)) {
            $spinnerChar = $spinner[$spinnerIndex % $spinner.Length]
            Write-Host "`r$spinnerChar Encrypting secrets file..." -NoNewline -ForegroundColor Cyan
            $spinnerIndex++
        }

        $process.WaitForExit()
        $stopwatch.Stop()

        # Clear the progress line
        Write-Host "`r✓ Encrypting secrets completed" -ForegroundColor Green

        if ($process.ExitCode -ne 0) {
            $errorOutput = $process.StandardError.ReadToEnd()
            return @{
                Success = $false
                Error = "Failed to encrypt secrets: $errorOutput"
            }
        }

        # Verify encrypted file was created and is not empty
        if (-not (Test-Path $EncryptedPath) -or (Get-Item $EncryptedPath).Length -eq 0) {
            return @{
                Success = $false
                Error = "Failed to encrypt secrets file"
            }
        }

        # Set secure permissions on encrypted file (cross-platform)
        if (-not (Set-SecureFilePermissions -Path $EncryptedPath)) {
            return @{
                Success = $false
                Error = "Failed to set secure permissions on encrypted file"
            }
        }

        # Verify encrypted file integrity by attempting to decrypt
        Write-ClauverLog "Verifying encrypted file integrity..."
        $integrityCheck = Test-EncryptedFileIntegrity -EncryptedPath $EncryptedPath
        if (-not $integrityCheck.Success) {
            # Clean up the corrupted encrypted file
            Remove-Item -Path $EncryptedPath -Force -ErrorAction SilentlyContinue
            return @{
                Success = $false
                Error = "Encrypted file integrity check failed: $($integrityCheck.Error)"
            }
        }

        # Remove plaintext file
        Remove-Item -Path $PlaintextPath -Force -ErrorAction SilentlyContinue

        Write-ClauverSuccess "Secrets successfully encrypted!"
        Write-Host "  Encrypted file: $(Sanitize-ClauverPath $EncryptedPath)" -ForegroundColor Green
        Write-Host "  Plaintext file: removed" -ForegroundColor Green
        Write-Host "  Variables encrypted: $($integrityCheck.VariableCount)" -ForegroundColor Green
        Write-Host ""
        Write-ClauverWarn "IMPORTANT: Back up your age key at: $(Sanitize-ClauverPath $ageKeyPath)"
        Write-Host "Without this key, you cannot decrypt your secrets."

        return @{
            Success = $true
            EncryptedPath = $EncryptedPath
            VariableCount = $integrityCheck.VariableCount
        }
    }
    catch {
        Write-ClauverError "Migration failed: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}