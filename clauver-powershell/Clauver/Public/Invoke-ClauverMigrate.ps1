function Invoke-ClauverMigrate {
    <#
    .SYNOPSIS
    Migrates plaintext secrets to encrypted age-encrypted storage.

    .DESCRIPTION
    Migrates existing plaintext secrets.env file to encrypted secrets.env.age format.
    This function checks the current state and performs migration if needed.
    Supports -CheckOnly flag to check migration status without performing it.

    .PARAMETER CheckOnly
    If specified, only checks migration status without performing migration.

    .PARAMETER Force
    If specified, forces migration even if already encrypted.

    .RETURNS
    Hashtable with migration status and results.
    #>
    [CmdletBinding()]
    param(
        [switch]$CheckOnly,
        [switch]$Force
    )

    try {
        $clauverHome = Get-ClauverHome
        $secretsPath = Join-Path $clauverHome "secrets.env"
        $secretsAgePath = Join-Path $clauverHome "secrets.env.age"
        $ageKeyPath = Join-Path $clauverHome "age.key"

        # Display banner
        Write-Host "" -ForegroundColor Blue
        Write-Host @"
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
"@ -ForegroundColor Blue
        Write-Host ""
        Write-Host "Migrate Secrets to Encrypted Storage" -ForegroundColor Cyan -BackgroundColor DarkBlue
        Write-Host ""

        # Check if already encrypted
        if ((Test-Path $secretsAgePath) -and (-not (Test-Path $secretsPath))) {
            Write-ClauverSuccess "Secrets are already encrypted!"
            Write-Host "  Location: $(Sanitize-ClauverPath $secretsAgePath)"

            if ($CheckOnly) {
                return @{
                    Success = $true
                    AlreadyEncrypted = $true
                    NeedsMigration = $false
                }
            }

            # If not using -Force, return early
            if (-not $Force) {
                return @{
                    Success = $true
                    AlreadyEncrypted = $true
                    NeedsMigration = $false
                }
            }

            # With -Force, ask for confirmation to re-encrypt
            Write-Host ""
            Write-ClauverWarn "You are using -Force to re-encrypt already encrypted secrets."
            Write-Host "This will create a new encrypted file but won't affect your existing secrets."
            $confirm = Read-Host "Continue? [y/N]"
            if ($confirm -notmatch '^[Yy]') {
                Write-Host "Migration cancelled."
                return @{
                    Success = $true
                    AlreadyEncrypted = $true
                    NeedsMigration = $false
                    Cancelled = $true
                }
            }
        }

        # Check if plaintext file exists
        if (-not (Test-Path $secretsPath)) {
            if (Test-Path $secretsAgePath) {
                Write-ClauverSuccess "Encrypted secrets file already exists at: $(Sanitize-ClauverPath $secretsAgePath)"
            } else {
                Write-ClauverWarn "No secrets file found. Configure a provider first:"
                Write-Host "  clauver config <provider>"
            }

            if ($CheckOnly) {
                return @{
                    Success = $true
                    AlreadyEncrypted = $false
                    NeedsMigration = $false
                    NoSecretsFound = $true
                }
            }

            return @{
                Success = $true
                AlreadyEncrypted = $false
                NeedsMigration = $false
                NoSecretsFound = $true
            }
        }

        Write-ClauverLog "Found plaintext secrets file: $(Sanitize-ClauverPath $secretsPath)"
        Write-Host ""

        if ($CheckOnly) {
            return @{
                Success = $true
                AlreadyEncrypted = $false
                NeedsMigration = $true
                PlaintextPath = $secretsPath
            }
        }

        # Ensure age key exists
        $ensureResult = Ensure-AgeKey
        if (-not $ensureResult.Success) {
            Write-ClauverError "Failed to ensure age key. Migration aborted."
            return @{
                Success = $false
                Error = "Age key creation failed"
            }
        }

        # Perform migration
        return Perform-Migration -PlaintextPath $secretsPath -EncryptedPath $secretsAgePath

    }
    catch {
        Write-ClauverError "Migration failed: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}