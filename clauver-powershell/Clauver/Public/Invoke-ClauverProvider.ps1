function Invoke-ClauverProvider {
    param(
        [string]$Name,
        [string[]]$ClaudeArgs = @()
    )

    Write-ClauverLog "Using $Name provider..."

    # Check if this is a provider command or if we should launch claude
    if ($Name -in @("anthropic", "minimax", "zai", "kimi", "deepseek", "custom")) {
        # This is a provider shortcut - we need to launch claude CLI

        # Load configuration and secrets
        $config = Read-ClauverConfig
        $secretsFile = Join-Path (Get-ClauverHome) "secrets.env.age"

        # Handle anthropic specially (no API key needed)
        if ($Name -eq "anthropic") {
            Write-Host "Using Anthropic provider" -ForegroundColor Green
            # Launch claude with anthropic (direct API)
            & claude @ClaudeArgs
            return
        }

        # For other providers, load encrypted secrets
        if (Test-Path $secretsFile) {
            try {
                $secrets = Invoke-AgeDecrypt -InputFile $secretsFile
                # Parse API key properly - split lines and find the key in environment variable format
                $lines = $secrets -split "`n"
                $varName = "$($Name.ToUpper())_API_KEY"
                $keyLine = $lines | Where-Object { $_ -match "^${varName}=" } | Select-Object -First 1
                $apiKey = if ($keyLine) {
                    ($keyLine -split '=', 2)[1].Trim().Trim('"', "'")
                } else {
                    $null
                }

                if (-not $apiKey) {
                    Write-ClauverError "$Name not configured. Run: clauver config $Name"
                    exit 1
                }

                # Get provider configuration
                $baseUrl = $config["${Name}_base_url"]
                $model = $config["${Name}_model"]

                # Set environment variables for claude
                $env:ANTHROPIC_BASE_URL = $baseUrl
                $env:ANTHROPIC_AUTH_TOKEN = $apiKey
                $env:ANTHROPIC_MODEL = $model

                # Provider-specific model configuration (matching bash script)
                switch ($Name) {
                    "zai" {
                        # Z.AI uses different models for different roles
                        $env:ANTHROPIC_SMALL_FAST_MODEL = "glm-4.5-air"
                        $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.5-air"
                        $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $model
                    }
                    "minimax" {
                        $env:ANTHROPIC_SMALL_FAST_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $model
                    }
                    "kimi" {
                        $env:ANTHROPIC_SMALL_FAST_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $model
                    }
                    "deepseek" {
                        $env:ANTHROPIC_SMALL_FAST_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $model
                    }
                    default {
                        # Fallback for custom providers
                        $env:ANTHROPIC_SMALL_FAST_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $model
                        $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $model
                    }
                }

                # Provider-specific settings
                switch ($Name) {
                    "minimax" {
                        $env:ANTHROPIC_SMALL_FAST_MODEL_TIMEOUT = "120"
                        $env:ANTHROPIC_SMALL_FAST_MAX_TOKENS = "24576"
                    }
                    "kimi" {
                        $env:ANTHROPIC_SMALL_FAST_MODEL_TIMEOUT = "240"
                        $env:ANTHROPIC_SMALL_FAST_MAX_TOKENS = "200000"
                    }
                    "deepseek" {
                        $env:API_TIMEOUT_MS = "600000"
                        $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
                    }
                }

                Write-Host "Using $Name provider ($model)" -ForegroundColor Green

                # Launch claude with the provider
                & claude @ClaudeArgs
            }
            catch {
                Write-ClauverError "Failed to decrypt secrets: $_"
                exit 1
            }
        } else {
            Write-ClauverError "$Name not configured. Run: clauver config $Name"
            exit 1
        }
    } else {
        # This is just switching the provider without launching claude
        Write-Host "Switched to $Name provider" -ForegroundColor Green
    }
}
