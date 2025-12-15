function Set-ClauverConfig {
    param([string]$Name)

    Write-ClauverLog "Configuring $Name provider..."

    # Prompt for provider details
    $baseUrl = Read-ClauverInput -Prompt "Enter base URL" -Default (Get-ProviderDefault -Name $Name -Property "BaseUrl")
    $model = Read-ClauverInput -Prompt "Enter model" -Default (Get-ProviderDefault -Name $Name -Property "Model")
    $apiKey = Read-ClauverSecureInput -Prompt "Enter API key for $Name"

    # Update config
    $config = Read-ClauverConfig
    $config["${Name}_type"] = $Name
    $config["${Name}_base_url"] = $baseUrl
    $config["${Name}_model"] = $model
    Write-ClauverConfig -Config $config

    # Encrypt and store API key in environment variable format (matching bash version)
    $secretsFile = Join-Path (Get-ClauverHome) "secrets.env.age"
    try {
        # Load existing secrets if they exist
        $existingSecrets = ""
        if (Test-Path $secretsFile) {
            try {
                $existingSecrets = Invoke-AgeDecrypt -InputFile $secretsFile
            } catch {
                Write-ClauverLog "Could not load existing secrets, starting fresh"
            }
        }

        # Process existing secrets and add new one
        $allApiKeys = @()
        
        # Add existing API keys (if any)
        if ($existingSecrets -and $existingSecrets.Trim()) {
            # Split by newline and filter out empty lines
            $secretsLines = $existingSecrets -split "`r`n|`n|`r" | Where-Object { $_.Trim() }
            
            # Remove any existing API key for this provider
            $providerUpper = $Name.ToUpper()
            $pattern = "^${providerUpper}_API_KEY="
            $filteredLines = $secretsLines | Where-Object { $_ -notmatch $pattern }
            $allApiKeys += $filteredLines
        }
        
        # Add the new API key
        $allApiKeys += "$($Name.ToUpper())_API_KEY=$apiKey"
        
        # Join with proper newlines
        $updatedSecrets = $allApiKeys -join "`n"
        
        # Encrypt the updated secrets
        Invoke-AgeEncrypt -Plaintext $updatedSecrets -OutputFile $secretsFile
        Write-ClauverSuccess "$Name provider configured successfully"
    } catch {
        Write-ClauverError "Failed to encrypt API key: $_"
        exit 1
    }
}

function Get-ProviderDefault {
    param([string]$Name, [string]$Property)

    # Match the bash script's PROVIDER_DEFAULTS exactly (lines 30-39 of clauver.sh)
    $defaults = @{
        'minimax' = @{
            'BaseUrl' = 'https://api.minimax.io/anthropic'
            'Model' = 'MiniMax-M2'
        }
        'zai' = @{
            'BaseUrl' = 'https://api.z.ai/api/anthropic'
            'Model' = 'glm-4.6'
        }
        'kimi' = @{
            'BaseUrl' = 'https://api.kimi.com/coding/'
            'Model' = 'kimi-for-coding'
        }
        'deepseek' = @{
            'BaseUrl' = 'https://api.deepseek.com/anthropic'
            'Model' = 'deepseek-chat'
        }
        'anthropic' = @{
            'BaseUrl' = ''
            'Model' = ''
        }
        'custom' = @{
            'BaseUrl' = ''
            'Model' = ''
        }
    }

    # Return null if provider doesn't have defaults
    if (-not $defaults.ContainsKey($Name)) {
        return $null
    }

    return $defaults[$Name][$Property]
}

Export-ModuleMember -Function Set-ClauverConfig, Get-ProviderDefault
