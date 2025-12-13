function Import-ClauverSecrets {
    <#
    .SYNOPSIS
    Imports secrets from a plaintext file into environment variables.

    .DESCRIPTION
    This function reads a secrets.env file and imports the key-value pairs
    into environment variables, matching the behavior of the bash 'source' command.

    .PARAMETER SecretsPath
    Path to the secrets.env file to import.

    .RETURNS
    Nothing. Sets environment variables.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SecretsPath
    )

    try {
        if (-not (Test-Path $SecretsPath)) {
            Write-ClauverError "Secrets file not found: $SecretsPath"
            return
        }

        # Read all lines from the secrets file
        $lines = Get-Content -Path $SecretsPath -Encoding UTF8

        foreach ($line in $lines) {
            $line = $line.Trim()

            # Skip empty lines and comments
            if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#')) {
                continue
            }

            # Parse KEY=VALUE format
            if ($line -match '^([A-Z_][A-Z0-9_]*)=(.*)$') {
                $key = $matches[1]
                $value = $matches[2]

                # Additional safety check on variable name (like bash version)
                if ($key -match 'PATH|HOME|USER|SHELL|ENV') {
                    Write-ClauverWarn "Loading system-like variable: $key"
                }

                # Security: Reject dangerous patterns in values
                if ($value -match '\$\(|`|;|\|\||&&|rm\s+-rf|chmod|chown|wget|curl|nc\s+-') {
                    Write-ClauverError "Secrets file contains potentially malicious code in value: $key"
                    throw "Invalid content in secrets file"
                }

                # Set the environment variable
                [System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
            }
            else {
                Write-ClauverError "Invalid environment variable format: $line"
                throw "Invalid format in secrets file"
            }
        }
    }
    catch {
        Write-ClauverError "Failed to import secrets: $_"
        throw
    }
}