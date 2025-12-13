function Show-ClauverHelp {
    Write-Host @"
Clauver - Claude Code Provider Manager

USAGE:
    clauver <command> [options]

COMMANDS:
    setup        Initialize clauver configuration
    config       Configure a provider
    list         List all configured providers
    status       Check provider status
    test         Test a provider configuration
    version      Show version information
    default      Set or show default provider
    migrate      Migrate plaintext secrets to encrypted

PROVIDER COMMANDS:
    clauver anthropic   Use anthropic provider
    clauver minimax     Use minimax provider
    clauver zai         Use zai provider
    clauver kimi        Use kimi provider
    clauver deepseek    Use deepseek provider
    clauver custom      Use custom provider

EXAMPLES:
    clauver setup
    clauver config minimax
    clauver default minimax
    clauver version

For more information, visit: https://github.com/dkmnx/clauver
"@ -ForegroundColor Cyan
}
