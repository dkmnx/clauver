#!/usr/bin/env pwsh
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

# Import Clauver module
$scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$scriptDir = Split-Path -Parent $scriptPath
$modulePath = Join-Path $scriptDir "Clauver.psm1"
Import-Module $modulePath -Force -ErrorAction Stop

# Route command to appropriate function
$command = if ($RemainingArgs.Count -gt 0) { $RemainingArgs[0] } else { $null }

# Handle no command first before switch
if (-not $command) {
    $defaultProvider = Get-ClauverDefault
    if ($defaultProvider) {
        # Launch Claude CLI with default provider
        $providerArgs = if ($RemainingArgs.Count -gt 1) { $RemainingArgs[1..($RemainingArgs.Count - 1)] } else { @() }
        Invoke-ClauverProvider -Provider $defaultProvider -ClaudeArgs $providerArgs
    } else {
        # No default provider set - show help
        Show-ClauverHelp
        exit 1
    }
} else {
    switch ($command) {
        { $_ -in @("help", "-h", "--help") } {
            Show-ClauverHelp
        }
        { $_ -in @("setup", "-s") } {
            Show-ClauverSetup
        }
        { $_ -in @("version", "-v", "--version") } {
            Get-ClauverVersion
        }
        "update" {
            Update-Clauver
        }
        "config" {
            Set-ClauverConfig -Provider $RemainingArgs[1]
        }
        "list" {
            Get-ClauverProvider
        }
        "status" {
            Get-ClauverStatus
        }
        "test" {
            Test-ClauverProvider -Name $RemainingArgs[1]
        }
        "default" {
            if ($RemainingArgs[1]) {
                Set-ClauverDefault -Name $RemainingArgs[1]
            } else {
                $default = Get-ClauverDefault
                if ($default) {
                    Write-Output "Default provider: $default"
                } else {
                    Write-Output "No default provider set"
                }
            }
        }
        "migrate" {
            Invoke-ClauverMigrate
        }
        { $_ -in @("anthropic", "minimax", "zai", "kimi", "deepseek", "custom") } {
            # Provider shortcut - switch to provider and launch Claude CLI
            # All remaining arguments after the provider name
            $providerArgs = if ($RemainingArgs.Count -gt 1) { $RemainingArgs[1..($RemainingArgs.Count - 1)] } else { @() }
            Invoke-ClauverProvider -Provider $_ -ClaudeArgs $providerArgs
        }
        default {
            # Check if it's a custom provider
            $customApiKey = Get-ConfigValue -Key "custom_${command}_api_key"
            if ($customApiKey) {
                # It's a custom provider
                Write-Debug "Found custom provider: $command"
                $providerArgs = if ($RemainingArgs.Count -gt 1) { $RemainingArgs[1..($RemainingArgs.Count - 1)] } else { @() }
                Invoke-ClauverProvider -Provider $command -ClaudeArgs $providerArgs
            } else {
                # Check if a default provider is set
                $defaultProvider = Get-ClauverDefault
                if ($defaultProvider) {
                    # Use the default provider with all arguments
                    $providerArgs = $RemainingArgs
                    Invoke-ClauverProvider -Provider $defaultProvider -ClaudeArgs $providerArgs
                } else {
                    # Unknown command
                    Write-Host "Unknown command: $command" -ForegroundColor Red
                    Show-ClauverHelp
                    exit 1
                }
            }
        }
    }
}