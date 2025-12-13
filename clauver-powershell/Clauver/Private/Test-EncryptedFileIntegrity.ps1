function Test-EncryptedFileIntegrity {
    <#
    .SYNOPSIS
    Verifies that an encrypted file can be successfully decrypted.

    .DESCRIPTION
    Tests the integrity of an encrypted age file by attempting to decrypt it
    and validating that the content is valid environment variable format.

    .PARAMETER EncryptedPath
    Path to the encrypted file to test.

    .RETURNS
    Hashtable with Success boolean and optional Error message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EncryptedPath
    )

    try {
        if (-not (Test-Path $EncryptedPath)) {
            return @{
                Success = $false
                Error = "Encrypted file not found: $EncryptedPath"
            }
        }

        # Get the age key path
        $ageKeyPath = Get-ClauverAgeKey
        if (-not $ageKeyPath) {
            return @{
                Success = $false
                Error = "Age key not found"
            }
        }

        # Attempt to decrypt the file
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "age"
        $processInfo.Arguments = "-d", "-i", $ageKeyPath, $EncryptedPath
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
            return @{
                Success = $false
                Error = "Failed to decrypt file for integrity check: $errorOutput"
            }
        }

        # Get the decrypted content
        $decryptedContent = $process.StandardOutput.ReadToEnd()

        # Validate the decrypted content
        if ([string]::IsNullOrWhiteSpace($decryptedContent)) {
            return @{
                Success = $false
                Error = "Decrypted content is empty"
            }
        }

        # Check for error indicators that suggest corruption
        if ($decryptedContent -match 'error|Error|ERROR|failed|Failed|FAILED|invalid|Invalid|INVALID|corrupt|Corrupt|CORRUPT') {
            return @{
                Success = $false
                Error = "Decrypted content contains error indicators - may be corrupted"
            }
        }

        # Check for dangerous bash constructs
        if ($decryptedContent -match '\$\(|`|;|\|\||&&|rm\s+-rf|chmod|chown|wget|curl|nc\s+-') {
            return @{
                Success = $false
                Error = "Decrypted content contains potentially malicious code"
            }
        }

        # Validate environment variable format
        $lines = $decryptedContent -split "`n"
        $hasValidLines = $false

        foreach ($line in $lines) {
            $line = $line.Trim()

            # Skip empty lines and comments
            if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#')) {
                continue
            }

            # Check for valid environment variable format
            if ($line -notmatch '^[A-Z_][A-Z0-9_]*=.*$') {
                return @{
                    Success = $false
                    Error = "Invalid environment variable format: $line"
                }
            }

            $hasValidLines = $true
        }

        if (-not $hasValidLines) {
            return @{
                Success = $false
                Error = "No valid environment variables found in decrypted content"
            }
        }

        return @{
            Success = $true
            VariableCount = ($lines | Where-Object { $_ -match '^[A-Z_][A-Z0-9_]*=.*$' }).Count
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}