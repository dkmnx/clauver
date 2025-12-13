function Get-ClauverStatus {
    <#
    .SYNOPSIS
    Checks and displays the status of all Clauver providers and configuration.

    .DESCRIPTION
    This function displays a detailed status report of all Claude API providers,
    showing which ones are configured, their API keys (masked), storage encryption
    status, and Claude CLI installation status. Matches the bash cmd_status function
    exactly.

    .EXAMPLE
    Get-ClauverStatus

    Displays the complete status of all providers and configuration.
    #>
    [CmdletBinding()]
    param()

    try {
        # Load secrets
        $secrets = Get-ClauverSecrets

        # Ensure ProviderDefaults is available (defined in Get-ClauverProviderList.ps1)
        if (-not (Get-Variable -Name ProviderDefaults -Scope Script -ErrorAction SilentlyContinue)) {
            # Define defaults if not already defined
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
        }

        # Display header
        Write-Host "$([char]27)[1mProvider Status$([char]27)[0m"
        Write-Host ""

        # Show encryption status
        $clauverHome = Get-ClauverHome
        $secretsEnvPath = Join-Path $clauverHome "secrets.env"
        $secretsAgePath = Join-Path $clauverHome "secrets.env.age"

        if (Test-Path $secretsAgePath) {
            Write-Host "$([char]27)[0;32m🔒 Secrets Storage: Encrypted$([char]27)[0m"
        }
        elseif (Test-Path $secretsEnvPath) {
            Write-Host "$([char]27)[1;33m⚠ Secrets Storage: Plaintext (run 'clauver migrate' to encrypt)$([char]27)[0m"
        }
        else {
            Write-Host "Secrets Storage: None configured"
        }
        Write-Host ""

        # Check Native Anthropic
        Write-Host "$([char]27)[1mNative Anthropic:$([char]27)[0m"
        if (Get-Command claude -ErrorAction SilentlyContinue) {
            Write-Host "$([char]27)[0;32m✓ Installed$([char]27)[0m"
        }
        else {
            Write-Host "$([char]27)[0;31m✗ Not installed$([char]27)[0m"
        }
        Write-Host ""

        # Read config for additional settings
        $config = Read-ClauverConfig

        # Check standard providers
        $standardProviders = @('zai', 'minimax', 'kimi', 'deepseek')

        foreach ($provider in $standardProviders) {
            $keyName = "$($provider.ToUpper())_API_KEY"
            $apiKey = $secrets[$keyName]

            Write-Host "$([char]27)[1m$($provider -replace '^([a-z])', { $_.Value.ToUpper() }):$([char]27)[0m"

            if ($apiKey) {
                Write-Host "$([char]27)[0;32m✓ Configured ($(Mask-ApiKey $apiKey))$([char]27)[0m"

                # Show additional config for Kimi
                if ($provider -eq 'kimi') {
                    $kimiModel = if ($config.ContainsKey('kimi_model')) {
                        $config['kimi_model']
                    }
                    else {
                        $script:ProviderDefaults.kimi_default_model
                    }

                    $kimiBaseUrl = if ($config.ContainsKey('kimi_base_url')) {
                        $config['kimi_base_url']
                    }
                    else {
                        $script:ProviderDefaults.kimi_base_url
                    }

                    Write-Host "  Model: $kimiModel"
                    Write-Host "  URL: $kimiBaseUrl"
                }
            }
            else {
                Write-Host "$([char]27)[1;33m! Not configured$([char]27)[0m"
            }
            Write-Host ""
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
                        Write-Host "$([char]27)[1m$($providerName -replace '^([a-z])', { $_.Value.ToUpper() }):$([char]27)[0m"
                        Write-Host "$([char]27)[0;32m✓ Configured ($(Mask-ApiKey $apiKey))$([char]27)[0m"

                        $baseUrlKey = "custom_${providerName}_base_url"
                        $baseUrl = if ($config.ContainsKey($baseUrlKey)) {
                            $config[$baseUrlKey]
                        }
                        else {
                            ""
                        }

                        if ($baseUrl) {
                            Write-Host "  Base URL: $baseUrl"
                        }
                        Write-Host ""
                    }
                }
            }
        }
    }
    catch {
        Write-ClauverError "Failed to check status: $_"
    }
}

