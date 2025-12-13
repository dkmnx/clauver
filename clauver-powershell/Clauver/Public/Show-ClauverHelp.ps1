function Show-ClauverHelp {
    $Version = "1.12.1"
    Write-Host @"
Clauver v$Version
Manage and switch between Claude Code providers

Quick Start:
  clauver setup        # Interactive setup wizard
  clauver zai          # Switch to Z.AI
  claude "hello"       # Use current provider

Usage:
  clauver <command> [args]

Setup & Help:
  setup, -s               Interactive setup wizard for beginners
  help, -h, --help        Show this help message
  version, -v, --version  Show current version and check for updates
  update                  Update to the latest version

Provider Management:
  list                    List all configured providers
  status                  Check status of all providers
  config <provider>       Configure a specific provider
  test <provider>         Test a provider configuration
  default [provider]      Set or show default provider
  migrate                 Migrate plaintext secrets to encrypted storage

Switch Providers:
  anthropic               Use Native Anthropic (no API key needed)
  zai                     Switch to Z.AI provider
  minimax                 Switch to MiniMax provider
  kimi                    Switch to Moonshot Kimi provider
  <custom>                Switch to your custom provider

Examples:
  clauver setup           # Guided setup for first-time users
  clauver list            # Show all providers
  clauver config zai      # Configure Z.AI provider
  clauver test zai        # Test Z.AI provider
  clauver zai             # Use Z.AI for this session
  clauver anthropic       # Use Native Anthropic
  clauver default zai     # Set Z.AI as default provider
  clauver migrate         # Encrypt plaintext secrets
  clauver version         # Check current version and updates
  clauver update          # Update to latest version
  clauver                 # Use default provider (after setting one)

💡 Tips:
  • Set a default: clauver default <provider>
  • Run clauver without arguments to use your default provider
  • Auto-completion available: clauver <TAB><TAB>
  • Any valid provider name works: clauver your-provider
  • All claude flags work: clauver zai --dangerously-skip-permissions

For more information, visit: https://github.com/dkmnx/clauver
"@ -ForegroundColor Cyan
}
