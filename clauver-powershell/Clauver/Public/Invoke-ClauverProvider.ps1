function Invoke-ClauverProvider {
    param(
        [string]$Provider,
        [string[]]$ClaudeArgs = @()
    )


    # Generic provider switching function matching bash implementation
    # Handle anthropic specially (no API key needed)
    if ($Provider -eq "anthropic") {
        Switch-ToAnthropic -ClaudeArgs $ClaudeArgs
        return
    }

    # Load configuration and secrets first (needed for custom provider detection)
    $config = Read-ClauverConfig
    $secrets = Get-ClauverSecrets

    # Check if it's a custom provider first
    $customApiKey = $config["custom_${Provider}_api_key"]
    if ($customApiKey) {
        Switch-ToCustom -ProviderName $Provider -ClaudeArgs $ClaudeArgs
        return
    }

    # Check if provider is supported (built-in providers)
    if (-not $script:ProviderConfigs.ContainsKey($Provider) -and $Provider -ne "kimi") {
        Write-ClauverError "Provider '$Provider' not supported"
        exit 1
    }

    # Validate required configuration
    $requirements = $script:ProviderRequires[$Provider]
    if (-not $requirements) {
        $requirements = @('api_key')
    }

    foreach ($field in $requirements) {
        switch ($field) {
            "api_key" {
                $keyVar = "${Provider}_api_key"
                $apiKey = $secrets[$keyVar]
                if (-not $apiKey) {
                    Write-ClauverError "$($Provider.ToUpper()) not configured. Run: clauver config $Provider"
                    exit 1
                }
            }
            "model" {
                $model = $config["${Provider}_model"]
                if ($Provider -eq "kimi" -and -not $model) {
                    $model = $script:ProviderDefaults["kimi_default_model"]
                }
            }
            "url" {
                $url = $config["${Provider}_base_url"]
                if ($Provider -eq "kimi" -and -not $url) {
                    $url = $script:ProviderDefaults["kimi_base_url"]
                }
            }
        }
    }

    # Set provider-specific environment
    switch ($Provider) {
        "zai" {
            Switch-ToZai -ApiKey $apiKey -ClaudeArgs $ClaudeArgs
        }
        "minimax" {
            Switch-ToMiniMax -ApiKey $apiKey -Model $model -ClaudeArgs $ClaudeArgs
        }
        "kimi" {
            Switch-ToKimi -ApiKey $apiKey -Model $model -Url $url -ClaudeArgs $ClaudeArgs
        }
        "deepseek" {
            Switch-ToDeepSeek -ApiKey $apiKey -Model $model -ClaudeArgs $ClaudeArgs
        }
        default {
            Write-ClauverError "Unknown provider: '$Provider'"
            exit 1
        }
    }
}

function Switch-ToAnthropic {
    param([string[]]$ClaudeArgs)

    # Show banner matching bash implementation
    Write-Host @"
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
  v$script:ClauverVersion - Native Anthropic
"@ -ForegroundColor Cyan

    Write-Host "Using Native Anthropic" -ForegroundColor Green
    & claude @ClaudeArgs
}

function Switch-ToZai {
    param(
        [string]$ApiKey,
        [string[]]$ClaudeArgs
    )

    $zaiModel = Get-ConfigValue -Key "zai_model"
    $zaiModel = if ($zaiModel) { $zaiModel } else { $script:ProviderDefaults["zai_default_model"] }

    # Show banner matching bash implementation
    Write-Host @"
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
  v$script:ClauverVersion - Zhipu AI ($zaiModel)
"@ -ForegroundColor Cyan

    $env:ANTHROPIC_BASE_URL = $script:ProviderDefaults["zai_base_url"]
    $env:ANTHROPIC_AUTH_TOKEN = $ApiKey
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.5-air"
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $zaiModel
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $zaiModel

    & claude @ClaudeArgs
}

function Switch-ToMiniMax {
    param(
        [string]$ApiKey,
        [string]$Model,
        [string[]]$ClaudeArgs
    )

    $minimaxModel = if ($Model) { $Model } else { $script:ProviderDefaults["minimax_default_model"] }

    # Show banner matching bash implementation
    Write-Host @"
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
  v$script:ClauverVersion - MiniMax ($minimaxModel)
"@ -ForegroundColor Cyan

    $env:ANTHROPIC_BASE_URL = $script:ProviderDefaults["minimax_base_url"]
    $env:ANTHROPIC_AUTH_TOKEN = $ApiKey
    $env:ANTHROPIC_MODEL = $minimaxModel
    $env:ANTHROPIC_SMALL_FAST_MODEL = $minimaxModel
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $minimaxModel
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $minimaxModel
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $minimaxModel
    $env:ANTHROPIC_SMALL_FAST_MODEL_TIMEOUT = $script:PerformanceDefaults["minimax_small_fast_timeout"]
    $env:ANTHROPIC_SMALL_FAST_MAX_TOKENS = $script:PerformanceDefaults["minimax_small_fast_max_tokens"]

    & claude @ClaudeArgs
}

function Switch-ToKimi {
    param(
        [string]$ApiKey,
        [string]$Model,
        [string]$Url,
        [string[]]$ClaudeArgs
    )

    $kimiModel = if ($Model) { $Model } else { $script:ProviderDefaults["kimi_default_model"] }
    $kimiUrl = if ($Url) { $Url } else { $script:ProviderDefaults["kimi_base_url"] }

    # Show banner matching bash implementation
    Write-Host @"
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
  v$script:ClauverVersion - Moonshot AI ($kimiModel)
"@ -ForegroundColor Cyan

    $env:ANTHROPIC_BASE_URL = $kimiUrl
    $env:ANTHROPIC_AUTH_TOKEN = $ApiKey
    $env:ANTHROPIC_MODEL = $kimiModel
    $env:ANTHROPIC_SMALL_FAST_MODEL = $kimiModel
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $kimiModel
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $kimiModel
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $kimiModel
    $env:ANTHROPIC_SMALL_FAST_MODEL_TIMEOUT = $script:PerformanceDefaults["kimi_small_fast_timeout"]
    $env:ANTHROPIC_SMALL_FAST_MAX_TOKENS = $script:PerformanceDefaults["kimi_small_fast_max_tokens"]

    & claude @ClaudeArgs
}

function Switch-ToDeepSeek {
    param(
        [string]$ApiKey,
        [string]$Model,
        [string[]]$ClaudeArgs
    )

    $deepseekModel = if ($Model) { $Model } else { $script:ProviderDefaults["deepseek_default_model"] }

    # Show banner matching bash implementation
    Write-Host @"
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
  v$script:ClauverVersion - DeepSeek AI ($deepseekModel)
"@ -ForegroundColor Cyan

    $env:ANTHROPIC_BASE_URL = $script:ProviderDefaults["deepseek_base_url"]
    $env:ANTHROPIC_AUTH_TOKEN = $ApiKey
    $env:ANTHROPIC_MODEL = $deepseekModel
    $env:ANTHROPIC_SMALL_FAST_MODEL = $deepseekModel
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $deepseekModel
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $deepseekModel
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $deepseekModel
    $env:API_TIMEOUT_MS = $script:PerformanceDefaults["deepseek_api_timeout_ms"]
    $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"

    & claude @ClaudeArgs
}

function Switch-ToCustom {
    param(
        [string]$ProviderName,
        [string[]]$ClaudeArgs
    )

    $config = Read-ClauverConfig
    $apiKey = $config["custom_${ProviderName}_api_key"]
    $baseUrl = $config["custom_${ProviderName}_base_url"]
    $model = $config["custom_${ProviderName}_model"]

    if (-not $apiKey) {
        Write-ClauverError "Provider '$ProviderName' not configured. Run: clauver config custom"
        exit 1
    }
    if (-not $baseUrl) {
        Write-ClauverError "Provider '$ProviderName' base URL missing. Run: clauver config custom"
        exit 1
    }

    # Show banner matching bash implementation
    Write-Host @"
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
  v$script:ClauverVersion - $ProviderName
"@ -ForegroundColor Cyan

    $env:ANTHROPIC_BASE_URL = $baseUrl
    $env:ANTHROPIC_AUTH_TOKEN = $apiKey

    if ($model) {
        $env:ANTHROPIC_MODEL = $model
    }

    & claude @ClaudeArgs
}

# Helper function to get secrets (moved from Set-ClauverConfig to be reusable)
function Get-ClauverSecrets {
    # Load secrets from encrypted storage
    $secretsFile = Join-Path (Get-ClauverHome) "secrets.env.age"
    $secrets = @{}

    if (Test-Path $secretsFile) {
        try {
            $decryptedContent = Invoke-AgeDecrypt -InputFile $secretsFile
            $lines = $decryptedContent -split "`n"

            foreach ($line in $lines) {
                if ($line -and -not $line.StartsWith("#")) {
                    $parts = $line -split '=', 2
                    if ($parts.Count -eq 2) {
                        $secrets[$parts[0].Trim()] = $parts[1].Trim().Trim('"', "'")
                    }
                }
            }
        }
        catch {
            Write-ClauverError "Failed to decrypt secrets: $_"
            exit 1
        }
    }

    return $secrets
}

# Helper function to get config value (moved from Set-ClauverConfig to be reusable)
function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $config = Read-ClauverConfig
    return $config[$Key]
}
