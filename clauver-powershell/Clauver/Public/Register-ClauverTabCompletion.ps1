function Register-ClauverTabCompletion {
    [CmdletBinding()]
    param()

    try {
        # Register argument completer for clauver command
        Register-ArgumentCompleter -CommandName 'clauver' -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # Get completion items
            $completions = Get-ClauverCompletions -WordToComplete $wordToComplete -CommandAst $commandAst

            # Return completion results
            return $completions | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.Text,
                    $_.ListItemText,
                    $_.CompletionType,
                    $_.ToolTip
                )
            }
        }

        Write-Success "Clauver tab completion registered"
        Write-Host "Restart PowerShell to use tab completion"

    } catch {
        Write-ClauverError "Failed to register tab completion: $_"
    }
}

function Get-ClauverCompletions {
    param(
        [string]$WordToComplete,
        $CommandAst
    )

    try {
        # Get command position
        $commandElements = $CommandAst.CommandElements
        $currentPosition = $commandElements.Count

        # Main commands completion (position 1 means just 'clauver' was typed)
        if ($currentPosition -le 2) {
            return Get-CommandCompletions -WordToComplete $wordToComplete
        }

        # Provider completion for specific commands (position 2 means command was typed)
        if ($currentPosition -eq 3) {
            $mainCommand = $commandElements[1].Value
            switch ($mainCommand) {
                "config" { return Get-ProviderCompletions -WordToComplete $wordToComplete -IncludeCustom }
                "test" { return Get-ProviderCompletions -WordToComplete $wordToComplete }
                "default" { return Get-ProviderCompletions -WordToComplete $wordToComplete }
            }
        }

        # Custom providers completion for direct provider invocation
        return Get-CustomProviderCompletions -WordToComplete $wordToComplete

    } catch {
        Write-Debug "Completion error: $_"
        return @()
    }
}

function Get-CommandCompletions {
    param([string]$WordToComplete)

    $commands = @(
        @{ Text = "help"; ToolTip = "Show help message" }
        @{ Text = "setup"; ToolTip = "Interactive setup wizard" }
        @{ Text = "-s"; ToolTip = "Interactive setup wizard (shortcut)" }
        @{ Text = "version"; ToolTip = "Show current version and check for updates" }
        @{ Text = "-v"; ToolTip = "Show current version and check for updates (shortcut)" }
        @{ Text = "--version"; ToolTip = "Show current version and check for updates (shortcut)" }
        @{ Text = "update"; ToolTip = "Update to the latest version" }
        @{ Text = "list"; ToolTip = "List all configured providers" }
        @{ Text = "status"; ToolTip = "Check status of all providers" }
        @{ Text = "config"; ToolTip = "Configure a specific provider" }
        @{ Text = "test"; ToolTip = "Test a provider configuration" }
        @{ Text = "default"; ToolTip = "Set or show default provider" }
        @{ Text = "migrate"; ToolTip = "Migrate plaintext secrets to encrypted storage" }
        @{ Text = "anthropic"; ToolTip = "Use Native Anthropic provider" }
        @{ Text = "zai"; ToolTip = "Use Z.AI provider" }
        @{ Text = "minimax"; ToolTip = "Use MiniMax provider" }
        @{ Text = "kimi"; ToolTip = "Use Moonshot Kimi provider" }
        @{ Text = "deepseek"; ToolTip = "Use DeepSeek provider" }
        @{ Text = "custom"; ToolTip = "Configure custom provider" }
    )

    return $commands | Where-Object { $_.Text -like "$WordToComplete*" } | ForEach-Object {
        @{
            Text = $_.Text
            ListItemText = $_.Text
            CompletionType = [System.Management.Automation.CompletionResultType]::ParameterValue
            ToolTip = $_.ToolTip
        }
    }
}

function Get-ProviderCompletions {
    param(
        [string]$WordToComplete,
        [switch]$IncludeCustom
    )

    # Standard providers
    $providers = @(
        @{ Text = "anthropic"; ToolTip = "Native Anthropic (no API key needed)" }
        @{ Text = "zai"; ToolTip = "Z.AI (GLM models)" }
        @{ Text = "minimax"; ToolTip = "MiniMax (MiniMax-M2)" }
        @{ Text = "kimi"; ToolTip = "Moonshot AI (kimi-for-coding)" }
        @{ Text = "deepseek"; ToolTip = "DeepSeek (deepseek-chat)" }
    )

    # Add custom option if requested
    if ($IncludeCustom) {
        $providers += @{ Text = "custom"; ToolTip = "Add custom provider" }
    }

    # Add configured custom providers
    if ($IncludeCustom) {
        try {
            $configPath = Join-Path (Get-ClauverHome) "config"
            if (Test-Path $configPath) {
                $configContent = Get-Content $configPath -ErrorAction SilentlyContinue
                $customProviders = $configContent | Where-Object { $_ -match "^custom_([^_]+)_api_key=" } |
                    ForEach-Object {
                        $providerName = $matches[1]
                        @{ Text = $providerName; ToolTip = "Custom provider: $providerName" }
                    }
                $providers += $customProviders
            }
        } catch {
            Write-Debug "Failed to read custom providers: $_"
        }
    }

    return $providers | Where-Object { $_.Text -like "$WordToComplete*" } | ForEach-Object {
        @{
            Text = $_.Text
            ListItemText = $_.Text
            CompletionType = [System.Management.Automation.CompletionResultType]::ParameterValue
            ToolTip = $_.ToolTip
        }
    }
}

function Get-CustomProviderCompletions {
    param([string]$WordToComplete)

    # Get configured custom providers only
    try {
        $configPath = Join-Path (Get-ClauverHome) "config"
        if (Test-Path $configPath) {
            $configContent = Get-Content $configPath -ErrorAction SilentlyContinue
            $customProviders = $configContent | Where-Object { $_ -match "^custom_([^_]+)_api_key=" } |
                ForEach-Object {
                    $providerName = $matches[1]
                    if ($providerName -like "$WordToComplete*") {
                        @{
                            Text = $providerName
                            ListItemText = $providerName
                            CompletionType = [System.Management.Automation.CompletionResultType]::ParameterValue
                            ToolTip = "Custom provider: $providerName"
                        }
                    }
                }
            return $customProviders
        }
    } catch {
        Write-Debug "Failed to read custom providers: $_"
    }

    return @()
}