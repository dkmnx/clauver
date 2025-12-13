function Test-ClauverProvider {
    <#
    .SYNOPSIS
    Tests a Claude API provider configuration and connectivity.

    .DESCRIPTION
    This function tests whether a provider is properly configured and can connect
    to the API. It matches the bash cmd_test function behavior exactly.

    .PARAMETER Name
    The name of the provider to test (anthropic, zai, minimax, kimi, deepseek, or custom).

    .EXAMPLE
    Test-ClauverProvider -Name zai

    Tests the Z.AI provider configuration.

    .EXAMPLE
    Test-ClauverProvider -Name anthropic

    Tests Native Anthropic connectivity.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    # Provider defaults matching bash script (lines 30-39 of clauver.sh)
    $ProviderDefaults = @{
        'zai_base_url' = 'https://api.z.ai/api/anthropic'
        'zai_default_model' = 'glm-4.6'
        'minimax_base_url' = 'https://api.minimax.io/anthropic'
        'minimax_default_model' = 'MiniMax-M2'
        'kimi_base_url' = 'https://api.kimi.com/coding/'
        'kimi_default_model' = 'kimi-for-coding'
        'deepseek_base_url' = 'https://api.deepseek.com/anthropic'
        'deepseek_default_model' = 'deepseek-chat'
    }

    # Constants matching bash script
    $ANTHROPIC_TEST_TIMEOUT = 5
    $PROVIDER_TEST_TIMEOUT = 10
    $TEST_API_TIMEOUT_MS = "3000000"

    # Check if claude command is available
    $claudeCommand = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCommand) {
        Write-ClauverError "claude command not found. Please install Claude CLI first."
        return 1
    }

    try {
        # Test Native Anthropic
        if ($Name -eq "anthropic") {
            Write-Host "$([char]27)[1mTesting Native Anthropic$([char]27)[0m"

            # Run claude --version with timeout
            $process = Start-Process -FilePath "claude" -ArgumentList "--version" -NoNewWindow -PassThru -RedirectStandardOutput "$null" -RedirectStandardError "$null"

            # Wait for process with timeout
            $completed = $process.WaitForExit($ANTHROPIC_TEST_TIMEOUT * 1000)

            if ($completed -and $process.ExitCode -eq 0) {
                Write-ClauverSuccess "Native Anthropic is working"
            } else {
                # Kill process if still running
                if (-not $completed) {
                    $process.Kill()
                }
                Write-ClauverError "Native Anthropic test failed"
            }
            return
        }

        # Load secrets for API-based providers
        $secrets = Get-ClauverSecrets

        # Test standard providers (zai, minimax, kimi, deepseek)
        if ($Name -in @("zai", "minimax", "kimi", "deepseek")) {
            $keyName = "$($Name.ToUpper())_API_KEY"
            $apiKey = $secrets[$keyName]

            if ([string]::IsNullOrEmpty($apiKey)) {
                Write-ClauverError "$($Name.ToUpper()) not configured"
                return 1
            }

            Write-Host "$([char]27)[1mTesting $($Name.ToUpper())$([char]27)[0m"

            # Set environment variables
            $env:ANTHROPIC_AUTH_TOKEN = $apiKey

            # Provider-specific configuration
            switch ($Name) {
                "zai" {
                    $env:ANTHROPIC_BASE_URL = $ProviderDefaults.zai_base_url
                }
                "minimax" {
                    $env:ANTHROPIC_BASE_URL = $ProviderDefaults.minimax_base_url
                    $env:API_TIMEOUT_MS = $TEST_API_TIMEOUT_MS
                }
                "kimi" {
                    $config = Read-ClauverConfig
                    $kimiBaseUrl = if ($config.ContainsKey('kimi_base_url')) {
                        $config['kimi_base_url']
                    } else {
                        $ProviderDefaults.kimi_base_url
                    }
                    $kimiModel = if ($config.ContainsKey('kimi_model')) {
                        $config['kimi_model']
                    } else {
                        $ProviderDefaults.kimi_default_model
                    }
                    $env:ANTHROPIC_BASE_URL = $kimiBaseUrl
                    $env:ANTHROPIC_MODEL = $kimiModel
                    $env:API_TIMEOUT_MS = $TEST_API_TIMEOUT_MS
                }
                "deepseek" {
                    $env:ANTHROPIC_BASE_URL = $ProviderDefaults.deepseek_base_url
                    $env:API_TIMEOUT_MS = $TEST_API_TIMEOUT_MS
                }
            }

            # Start claude test in background job
            $job = Start-Job -ScriptBlock {
                param($ClaudePath)
                & $ClaudePath "test" --dangerously-skip-permissions 2>&1 | Out-Null
                return $LASTEXITCODE
            } -ArgumentList $claudeCommand.Source

            # Wait for 3 seconds to check if it's still running
            Start-Sleep -Seconds 3

            # Check job status
            if ($job.State -eq "Running") {
                Write-ClauverSuccess "$($Name.ToUpper()) configuration is valid"
                # Remove the job
                $job.StopJob()
                $job | Remove-Job -Force
            } else {
                # Job completed or failed
                $jobResult = Receive-Job -Job $job
                $job | Remove-Job -Force
                if ($jobResult -eq 0) {
                    Write-ClauverSuccess "$($Name.ToUpper()) configuration is valid"
                } else {
                    Write-ClauverError "$($Name.ToUpper()) test failed"
                }
            }
        }
        # Test custom providers
        else {
            $config = Read-ClauverConfig
            $customApiKeyKey = "custom_${Name}_api_key"
            $customApiKey = $config[$customApiKeyKey]

            if ([string]::IsNullOrEmpty($customApiKey)) {
                Write-ClauverError "Provider '$Name' not found"
                return 1
            }

            Write-Host "$([char]27)[1mTesting Custom Provider: $Name$([char]27)[0m"

            $customBaseUrlKey = "custom_${Name}_base_url"
            $customBaseUrl = $config[$customBaseUrlKey]

            # Set environment variables
            $env:ANTHROPIC_BASE_URL = $customBaseUrl
            $env:ANTHROPIC_AUTH_TOKEN = $customApiKey

            # Start claude test in background job
            $job = Start-Job -ScriptBlock {
                param($ClaudePath)
                & $ClaudePath "test" --dangerously-skip-permissions 2>&1 | Out-Null
                return $LASTEXITCODE
            } -ArgumentList $claudeCommand.Source

            # Wait for 3 seconds to check if it's still running
            Start-Sleep -Seconds 3

            # Check job status
            if ($job.State -eq "Running") {
                Write-ClauverSuccess "$Name configuration is valid"
                # Remove the job
                $job.StopJob()
                $job | Remove-Job -Force
            } else {
                # Job completed or failed
                $jobResult = Receive-Job -Job $job
                $job | Remove-Job -Force
                if ($jobResult -eq 0) {
                    Write-ClauverSuccess "$Name configuration is valid"
                } else {
                    Write-ClauverError "$Name test failed"
                }
            }
        }
    }
    catch {
        Write-ClauverError "Failed to test provider: $($_.Exception.Message)"
        return 1
    }
}

