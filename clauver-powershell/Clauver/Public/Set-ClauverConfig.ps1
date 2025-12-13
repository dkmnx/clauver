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

    # Encrypt and store API key
    $secretsFile = Join-Path (Get-ClauverHome) "secrets.env.age"
    try {
        $apiKey | Invoke-AgeEncrypt -OutputFile $secretsFile
        Write-ClauverSuccess "$Name provider configured successfully"
    } catch {
        Write-ClauverError "Failed to encrypt API key: $_"
        exit 1
    }
}

function Get-ProviderDefault {
    param([string]$Name, [string]$Property)

    $defaults = @{
        'minimax' = @{
            'BaseUrl' = 'https://api.minimax.io'
            'Model' = 'MiniMax-M2'
        }
        'zai' = @{
            'BaseUrl' = 'https://api.z.ai/api/anthropic'
            'Model' = 'glm-4.6'
        }
    }

    return $defaults[$Name][$Property]
}

Export-ModuleMember -Function Set-ClauverConfig, Get-ProviderDefault
