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

switch ($command) {
    { $_ -in @("help", "-h", "--help") } {
        Show-ClauverHelp
    }
    { $_ -in @("setup", "-s") } {
        $homePath = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
        Initialize-Clauver -HomePath $homePath
    }
    { $_ -in @("version", "-v", "--version") } {
        Get-ClauverVersion
    }
    "update" {
        Update-Clauver
    }
    "config" {
        Set-ClauverConfig -Name $RemainingArgs[1]
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
        Invoke-ClauverProvider -Name $_ -ClaudeArgs $providerArgs
    }
    default {
        # No command specified - check for default provider
        if (-not $command) {
            $defaultProvider = Get-ClauverDefault
            if ($defaultProvider) {
                # Launch Claude CLI with default provider
                $providerArgs = if ($RemainingArgs.Count -gt 0) { $RemainingArgs[1..($RemainingArgs.Count - 1)] } else { @() }
                Invoke-ClauverProvider -Name $defaultProvider -ClaudeArgs $providerArgs
            } else {
                # No default provider set - show help
                Show-ClauverHelp
                exit 1
            }
        } else {
            # Unknown command
            Write-Host "Unknown command: $command" -ForegroundColor Red
            Show-ClauverHelp
            exit 1
        }
    }
}
