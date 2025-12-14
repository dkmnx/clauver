# Provider defaults matching bash script
$script:ProviderDefaults = @{
    zai_base_url = 'https://api.z.ai/api/anthropic'
    zai_default_model = 'glm-4.6'
    minimax_base_url = 'https://api.minimax.io/anthropic'
    minimax_default_model = 'MiniMax-M2'
    kimi_base_url = 'https://api.kimi.com/coding/'
    kimi_default_model = 'kimi-for-coding'
    deepseek_base_url = 'https://api.deepseek.com/anthropic'
    deepseek_default_model = 'deepseek-chat'
}

function Get-ClauverProvider {
    <#
    .SYNOPSIS
    Lists all configured providers with their status and details.

    .DESCRIPTION
    This function displays a comprehensive list of all Claude API providers,
    showing which ones are configured, their API keys (masked), and which
    ones still need configuration. It matches the bash implementation exactly.

    .EXAMPLE
    Get-ClauverProvider

    Lists all providers with their configuration status.
    #>
    [CmdletBinding()]
    param()

    try {
        # Load secrets (check for both encrypted and plaintext)
        $secrets = Get-ClauverSecrets

        # Determine encryption status
        $clauverHome = Get-ClauverHome
        $secretsEnvPath = Join-Path $clauverHome "secrets.env"
        $secretsAgePath = Join-Path $clauverHome "secrets.env.age"

        $encryptionStatus = ""
        if (Test-Path $secretsAgePath) {
            $encryptionStatus = "$([char]27)[0;32m[encrypted]$([char]27)[0m"
        }
        elseif (Test-Path $secretsEnvPath) {
            $encryptionStatus = "$([char]27)[1;33m[plaintext]$([char]27)[0m"
        }

        # Read config
        $config = Read-ClauverConfig

        # Display header
        Write-Host "$([char]27)[1mConfigured Providers:$([char]27)[0m"
        if ($encryptionStatus) {
            Write-Host "  Storage: $encryptionStatus"
        }
        Write-Host ""

        # Always show Native Anthropic as available
        Write-Host "$([char]27)[0;32m✓ Native Anthropic$([char]27)[0m"
        Write-Host "  Command: clauver anthropic"
        Write-Host "  Description: Use your Claude Pro/Team subscription"
        Write-Host ""

        # Check standard providers
        $standardProviders = @('zai', 'minimax', 'kimi', 'deepseek')
        $configuredProviders = @()

        foreach ($provider in $standardProviders) {
            $keyName = "$($provider.ToUpper())_API_KEY"
            $apiKey = $secrets[$keyName]

            if ($apiKey) {
                $configuredProviders += $provider
                Write-Host "$([char]27)[0;32m✓ $provider$([char]27)[0m"
                Write-Host "  Command: clauver $provider"
                Write-Host "  API Key: $(Mask-ApiKey $apiKey)"

                # Show model and URL for Kimi
                if ($provider -eq 'kimi') {
                    $kimiModel = if ($config.ContainsKey('kimi_model')) {
                        $config['kimi_model']
                    } else {
                        $script:ProviderDefaults.kimi_default_model
                    }
                    Write-Host "  Model: $kimiModel"

                    $kimiBaseUrl = if ($config.ContainsKey('kimi_base_url')) {
                        $config['kimi_base_url']
                    } else {
                        $script:ProviderDefaults.kimi_base_url
                    }
                    Write-Host "  Base URL: $kimiBaseUrl"
                }
                Write-Host ""
            }
        }

        # Check custom providers from config
        $configPath = Join-Path $clauverHome "config"
        if (Test-Path $configPath) {
            Get-Content $configPath | ForEach-Object {
                $line = $_.Trim()
                if ($line -and -not $line.StartsWith("#") -and $line -match '^custom_(.+)_api_key=(.*)$') {
                    $providerName = $matches[1]
                    $apiKey = $matches[2]

                    if ($apiKey) {
                        Write-Host "$([char]27)[0;32m✓ $providerName$([char]27)[0m"
                        Write-Host "  Command: clauver $providerName"
                        Write-Host "  Type: Custom"
                        Write-Host "  API Key: $(Mask-ApiKey $apiKey)"

                        $baseUrlKey = "custom_${providerName}_base_url"
                        if ($config.ContainsKey($baseUrlKey)) {
                            Write-Host "  Base URL: $($config[$baseUrlKey])"
                        }
                        Write-Host ""
                    }
                }
            }
        }

        # Show not configured providers (only if there are any)
        $notConfiguredProviders = @()
        foreach ($provider in $standardProviders) {
            $keyName = "$($provider.ToUpper())_API_KEY"
            $apiKey = $secrets[$keyName]

            if (-not $apiKey) {
                $notConfiguredProviders += $provider
            }
        }

        # Only show "Not Configured:" section if there are providers that need configuration
        if ($notConfiguredProviders.Count -gt 0) {
            Write-Host "$([char]27)[1;33mNot Configured:$([char]27)[0m"
            foreach ($provider in $notConfiguredProviders) {
                Write-Host "  - $provider (run: clauver config $provider)"
            }
        }
        # If all providers are configured, add a helpful message instead of an empty section
        elseif ($standardProviders.Count -gt 0 -and ($configuredProviders.Count + 1 -eq $standardProviders.Count)) {
            Write-Host "$([char]27)[0;32mAll standard providers configured!$([char]27)[0m"
        }
    }
    catch {
        Write-ClauverError "Failed to list providers: $_"
    }
}

function Get-ClauverSecrets {
    <#
    .SYNOPSIS
    Loads and decrypts secrets from storage.

    .DESCRIPTION
    This function loads API keys and other secrets, supporting both
    encrypted (.age) and plaintext storage formats.

    .OUTPUTS
    [hashtable] Dictionary of secret name/value pairs.
    #>
    [CmdletBinding()]
    param()

    $clauverHome = Get-ClauverHome
    $secretsEnvPath = Join-Path $clauverHome "secrets.env"
    $secretsAgePath = Join-Path $clauverHome "secrets.env.age"
    $ageKeyPath = Join-Path $clauverHome "age.key"

    $secrets = @{}

    # Try encrypted first
    if (Test-Path $secretsAgePath) {
        try {
            # Check if age command is available
            if (-not (Get-Command age -ErrorAction SilentlyContinue)) {
                Write-ClauverError "age command not found. Please install 'age' package."
                return $secrets
            }

            # Check if key file exists
            if (-not (Test-Path $ageKeyPath)) {
                Write-ClauverError "Age key not found. Reconfigure your providers with: Set-ClauverConfig"
                return $secrets
            }

            # Decrypt to memory
            $decryptedContent = & age --decrypt -i $ageKeyPath $secretsAgePath 2>$null

            if ($LASTEXITCODE -eq 0 -and $decryptedContent) {
                # Validate content before processing
                if (Test-DecryptedContent -Content $decryptedContent) {
                    # Parse environment variables
                    $decryptedContent -split "`n" | ForEach-Object {
                        $line = $_.Trim()
                        if ($line -and -not $line.StartsWith("#") -and $line -match '^(.+?)=(.*)$') {
                            $secrets[$matches[1]] = $matches[2]
                        }
                    }
                }
            }
        }
        catch {
            Write-ClauverError "Failed to decrypt secrets: $($_.Exception.Message)"
        }
    }
    # Fallback to plaintext
    elseif (Test-Path $secretsEnvPath) {
        try {
            Get-Content $secretsEnvPath | ForEach-Object {
                $line = $_.Trim()
                if ($line -and -not $line.StartsWith("#") -and $line -match '^(.+?)=(.*)$') {
                    $secrets[$matches[1]] = $matches[2]
                }
            }
        }
        catch {
            Write-ClauverError "Failed to read secrets file: $($_.Exception.Message)"
        }
    }

    return $secrets
}

function Mask-ApiKey {
    <#
    .SYNOPSIS
    Masks an API key for display purposes.

    .DESCRIPTION
    Masks an API key showing only the first 4 and last 4 characters.
    Matches the bash mask_key function behavior.

    .PARAMETER ApiKey
    The API key to mask.

    .OUTPUTS
    [string] The masked API key.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    if ([string]::IsNullOrEmpty($ApiKey)) {
        return ""
    }

    if ($ApiKey.Length -le 8) {
        return "****"
    }

    return "$($ApiKey.Substring(0, 4))****$($ApiKey.Substring($ApiKey.Length - 4))"
}

