function Set-ClauverConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Provider
    )

    # Handle different provider types exactly like bash implementation
    switch ($Provider) {
        "anthropic" {
            Set-AnthropicProviderConfig
        }
        { $_ -in @("zai", "minimax", "kimi", "deepseek") } {
            Set-StandardProviderConfig -Provider $Provider
        }
        "custom" {
            Set-CustomProviderConfig
        }
        default {
            Write-ClauverError "Unknown provider: '$Provider'"
            Write-Host ""
            Write-Host "Available providers: anthropic, zai, minimax, kimi, deepseek, custom"
            Write-Host "Example: clauver config zai"
            exit 1
        }
    }
}

function Set-AnthropicProviderConfig {
    Write-Host ""
    Write-ClauverSuccess "Native Anthropic is ready to use!"
    Write-Host "No configuration needed. Simply run: clauver anthropic"
}

function Set-StandardProviderConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Provider
    )

    Write-Host ""
    Write-Host "$($Provider.ToUpper()) Configuration" -ForegroundColor White -BackgroundColor DarkBlue

    # Show current API key if exists
    $config = Read-ClauverConfig
    $secrets = Get-ClauverSecrets
    $apiKeyVar = "${Provider}_api_key"
    $currentKey = $secrets[$apiKeyVar]

    if ($currentKey) {
        $maskedKey = Format-ClauverMaskedKey -Key $currentKey
        Write-Host "Current key: $maskedKey"
    }

    # Prompt for API key
    $apiKey = Read-ClauverSecureInput -Prompt "API Key"
    if ([string]::IsNullOrEmpty($apiKey)) {
        Write-ClauverError "Key is required"
        exit 1
    }

    # Validate API key using validation function
    if (-not (Test-ApiKeyFormat -ApiKey $apiKey -Provider $Provider)) {
        exit 1
    }

    # Save API key
    if ($PSCmdlet.ShouldProcess("secrets configuration", "Set $Provider API key")) {
        Set-ClauverSecret -Key $apiKeyVar -Value $apiKey

        # Configure provider-specific settings
        Set-ProviderSettings -Provider $Provider
    }

    Write-ClauverSuccess "$($Provider.ToUpper()) configured. Use: clauver $Provider"

    # Show encryption status
    $secretsFile = Join-Path (Get-ClauverHome) "secrets.env.age"
    if (Test-Path $secretsFile) {
        Write-Host "🔒 Secrets encrypted at: $secretsFile" -ForegroundColor Green
    }
}

function Set-CustomProviderConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    Write-Host ""
    Write-Host "Custom Provider Configuration" -ForegroundColor White -BackgroundColor DarkBlue

    $name = Read-ClauverInput -Prompt "Provider name (e.g., 'my-provider')"

    # Validate provider name using validation function
    if (-not (Test-ProviderName -ProviderName $name)) {
        exit 1
    }

    $baseUrl = Read-ClauverInput -Prompt "Base URL"
    $apiKey = Read-ClauverSecureInput -Prompt "API Key"
    $model = Read-ClauverInput -Prompt "Default model (optional)"

    if ([string]::IsNullOrEmpty($name) -or
        [string]::IsNullOrEmpty($baseUrl) -or
        [string]::IsNullOrEmpty($apiKey)) {
        Write-ClauverError "Name, Base URL and API Key are required"
        exit 1
    }

    # Validate inputs using validation functions
    if (-not (Test-UrlFormat -Url $baseUrl)) {
        exit 1
    }

    if (-not (Test-ApiKeyFormat -ApiKey $apiKey -Provider "custom")) {
        exit 1
    }

    if ($model -and -not (Test-ModelName -ModelName $model)) {
        exit 1
    }

    # Save configuration
    if ($PSCmdlet.ShouldProcess("configuration file", "Save custom provider '$name' settings")) {
        $config = Read-ClauverConfig
        $config["custom_${name}_api_key"] = $apiKey
        $config["custom_${name}_base_url"] = $baseUrl
        if ($model) {
            $config["custom_${name}_model"] = $model
        }
        Write-ClauverConfig -Config $config
    }

    Write-ClauverSuccess "Custom provider '$name' configured. Use: clauver $name"
}

function Set-ProviderSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Provider
    )

    # Get provider requirements from constants
    $requirements = $script:ProviderRequires[$Provider]

    # Skip if no requirements specified
    if (-not $requirements) {
        return
    }

    Write-Host ""
    Write-Host "$($Provider.ToUpper()) Configuration" -ForegroundColor White -BackgroundColor DarkBlue

    foreach ($field in $requirements) {
        switch ($field) {
            "model" {
                $currentModel = Get-ConfigValue -Key "${Provider}_model"
                if ($currentModel) {
                    Write-Host "Current model: $currentModel"
                }
                $defaultModel = $script:ProviderDefaults["${Provider}_default_model"]
                $model = Read-ClauverInput -Prompt "Model (default: $defaultModel)"
                $model = if ($model) { $model } else { $defaultModel }

                # Validate model name
                if ($model -and -not (Test-ModelName -ModelName $model)) {
                    exit 1
                }

                if ($model) {
                    Set-ConfigValue -Key "${Provider}_model" -Value $model
                }
            }

            "url" {
                $currentUrl = Get-ConfigValue -Key "${Provider}_base_url"
                if ($currentUrl) {
                    Write-Host "Current base URL: $currentUrl"
                }
                $defaultUrl = $script:ProviderDefaults["${Provider}_base_url"]
                $url = Read-ClauverInput -Prompt "Base URL (default: $defaultUrl)"
                $url = if ($url) { $url } else { $defaultUrl }

                # Validate URL
                if ($url -and -not (Test-UrlFormat -Url $url)) {
                    exit 1
                }

                if ($url) {
                    Set-ConfigValue -Key "${Provider}_base_url" -Value $url
                }
            }

            # api_key is handled by main config flow, skip here
            "api_key" {
                continue
            }

            default {
                Write-ClauverError "Unknown configuration field: $field"
                exit 1
            }
        }
    }
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $config = Read-ClauverConfig
    return $config[$Key]
}

function Set-ConfigValue {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    # Security: Validate key format (alphanumeric, underscore, hyphen only)
    if ($Key -notmatch '^[a-zA-Z0-9_-]+$') {
        Write-ClauverError "Invalid config key format: $Key"
        exit 1
    }

    if ($PSCmdlet.ShouldProcess("configuration", "Set $Key")) {
        $config = Read-ClauverConfig
        $config[$Key] = $Value
        Write-ClauverConfig -Config $config
    }
}


function Set-ClauverSecret {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    # Ensure age key exists before setting secrets
    $ageKey = Get-ClauverAgeKey
    if (-not $ageKey) {
        # Generate age key if it doesn't exist
        $ageKeyPath = Join-Path (Get-ClauverHome) "age.key"
        if (-not (Test-Path $ageKeyPath)) {
            Write-ClauverLog "Generating age encryption key..."
            & age-keygen -o $ageKeyPath
            chmod 600 $ageKeyPath
            Write-ClauverSuccess "Age encryption key generated at $ageKeyPath"
            Write-Host ""
            Write-ClauverWarn "IMPORTANT: Back up your age key! Without this key, you cannot decrypt your secrets."
        }
    }

    # Load existing secrets
    $secrets = Get-ClauverSecrets

    # Add new secret
    $secrets[$Key] = $Value

    # Build secrets data string
    $secretsData = ""
    foreach ($secret in $secrets.GetEnumerator()) {
        $secretsData += "$($secret.Key)=$($secret.Value)`n"
    }

    # Encrypt and save
    $secretsFile = Join-Path (Get-ClauverHome) "secrets.env.age"
    if ($PSCmdlet.ShouldProcess("encrypted secrets file", "Save $Key")) {
        try {
            Write-ClauverLog "Encrypting secrets..."
            Invoke-AgeEncrypt -Plaintext $secretsData -OutputFile $secretsFile

            # Set secure permissions
            chmod 600 $secretsFile

            # Remove any existing plaintext file
            $plaintextFile = Join-Path (Get-ClauverHome) "secrets.env"
            if (Test-Path $plaintextFile) {
                Remove-Item $plaintextFile -Force
            }
        }
        catch {
            Write-ClauverError "Failed to encrypt secrets: $_"
            exit 1
        }
    }
}

function Get-ProviderDefault {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Property
    )

    # Use the ProviderDefaults from constants
    $key = "${Name}_${Property.ToLower()}"
    return $script:ProviderDefaults[$key]
}
