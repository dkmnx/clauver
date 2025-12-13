function Show-ClauverSetup {
    <#
    .SYNOPSIS
    Interactive setup wizard for Clauver provider configuration.

    .DESCRIPTION
    Displays an interactive menu to help users configure their first Claude Code provider.
    Matches the bash cmd_setup() function exactly.
    #>

    # Display ASCII art banner
    Write-Host "" -ForegroundColor Blue
    Write-Host @"
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗     ███████╗███████╗████████╗██╗   ██╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝    ███████╗█████╗     ██║   ██║   ██║██████╔╝
 ██║     ██║     ██╔══██║██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝
"@ -ForegroundColor Blue

    # Welcome message
    Write-Host ""
    Write-Host "Welcome to Clauver Setup!" -ForegroundColor White -BackgroundColor Blue
    Write-Host "This wizard will help you configure your first provider."
    Write-Host ""

    # Interactive menu
    Write-Host "What would you like to do?" -ForegroundColor Yellow
    Write-Host "  1) Use Native Anthropic (free - uses your existing Claude subscription)"
    Write-Host "  2) Configure Z.AI (GLM models - requires API key)"
    Write-Host "  3) Configure MiniMax (MiniMax-M2 - requires API key)"
    Write-Host "  4) Configure Kimi (Moonshot AI - requires API key)"
    Write-Host "  5) Configure DeepSeek (DeepSeek Chat - requires API key)"
    Write-Host "  6) Add a custom provider"
    Write-Host "  7) Skip (I'll configure later)"
    Write-Host ""

    $choice = Read-Host "Choose [1-7]"

    # Process user choice
    switch ($choice) {
        "1" {
            Write-Host ""
            Write-ClauverSuccess "Native Anthropic is ready to use!"
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Green
            Write-Host "  • Simply run: clauver anthropic" -ForegroundColor White
            Write-Host "  • Or use claude directly: claude ""hello""" -ForegroundColor White
            Write-Host ""
        }
        "2" {
            Write-Host ""
            Write-Host "Let's configure Z.AI for you..."
            try {
                Set-ClauverConfig -Provider "zai" -ErrorAction Stop
            }
            catch {
                Write-ClauverError "Failed to configure Z.AI: $_"
                exit 1
            }
        }
        "3" {
            Write-Host ""
            Write-Host "Let's configure MiniMax for you..."
            try {
                Set-ClauverConfig -Provider "minimax" -ErrorAction Stop
            }
            catch {
                Write-ClauverError "Failed to configure MiniMax: $_"
                exit 1
            }
        }
        "4" {
            Write-Host ""
            Write-Host "Let's configure Kimi for you..."
            try {
                Set-ClauverConfig -Provider "kimi" -ErrorAction Stop
            }
            catch {
                Write-ClauverError "Failed to configure Kimi: $_"
                exit 1
            }
        }
        "5" {
            Write-Host ""
            Write-Host "Let's configure DeepSeek for you..."
            try {
                Set-ClauverConfig -Provider "deepseek" -ErrorAction Stop
            }
            catch {
                Write-ClauverError "Failed to configure DeepSeek: $_"
                exit 1
            }
        }
        "6" {
            Write-Host ""
            Write-Host "Let's add your custom provider..."
            try {
                Set-ClauverConfig -Provider "custom" -ErrorAction Stop
            }
            catch {
                Write-ClauverError "Failed to configure custom provider: $_"
                exit 1
            }
        }
        "7" {
            Write-Host ""
            Write-ClauverWarn "Setup skipped."
            Write-Host "Run 'clauver setup' anytime to configure a provider."
            Write-Host ""
        }
        default {
            Write-Host ""
            Write-ClauverError "Invalid choice. Run 'clauver setup' again to retry."
            exit 1
        }
    }

    # Post-setup information
    Write-Host "Setup complete!" -ForegroundColor White -BackgroundColor Blue
    Write-Host ""
    Write-Host "Quick reference:" -ForegroundColor Yellow
    Write-Host "  clauver setup        # Run this wizard again"
    Write-Host "  clauver list         # See all providers"
    Write-Host "  clauver status       # Check configuration"
    Write-Host "  clauver help         # View all commands"
    Write-Host ""
    Write-Host "Start using Claude:" -ForegroundColor Yellow
    Write-Host "  clauver anthropic    # Use Native Anthropic"
    Write-Host "  clauver <provider>   # Use any configured provider"
    Write-Host "  claude ""your prompt"" # Use current provider"
}