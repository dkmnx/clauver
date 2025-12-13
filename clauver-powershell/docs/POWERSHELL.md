# Clauver PowerShell Documentation

## Overview

Clauver PowerShell is a complete PowerShell implementation of the Clauver CLI tool, providing full feature parity with the bash version. It allows you to manage and switch between multiple Claude Code API providers seamlessly on Windows, macOS, and Linux.

## Requirements

- **PowerShell 7+** - Download from [Microsoft PowerShell](https://github.com/PowerShell/PowerShell/releases)
- **claude CLI** - Install with: `npm install -g @anthropic-ai/claude-code`
- **age** - For encryption:
  - Windows: Download from [GitHub Releases](https://github.com/FiloSottile/age/releases)
  - macOS: `brew install age`
  - Linux: `sudo apt install age` (or equivalent)
- **API Keys** - For third-party providers

## Installation

### Quick Start

```powershell
# Clone the repository
git clone https://github.com/dkmnx/clauver.git
cd clauver/clauver-powershell

# Run the setup wizard
./clauver.ps1 setup

# Install tab completion (optional)
. ./Completion/clauver-completion.ps1
```

### Module Structure

```
clauver-powershell/
├── clauver.ps1              # Main entry point
├── Clauver.psm1             # PowerShell module
├── Clauver/                 # Module source
│   ├── Public/              # Public functions
│   │   ├── Get-Clauver*
│   │   ├── Set-Clauver*
│   │   ├── Invoke-Clauver*
│   │   ├── Show-Clauver*
│   │   ├── Register-*
│   │   └── etc.
│   └── Private/             # Private helpers
├── Completion/              # Tab completion scripts
└── tests/                   # Pester tests
```

## Usage

### Basic Commands

```powershell
# Show help
./clauver.ps1 help

# Check version
./clauver.ps1 version

# Interactive setup
./clauver.ps1 setup

# List providers
./clauver.ps1 list

# Check status
./clauver.ps1 status
```

### Configuring Providers

```powershell
# Configure Z.AI
./clauver.ps1 config zai

# Configure MiniMax
./clauver.ps1 config minimax

# Configure Kimi
./clauver.ps1 config kimi

# Configure DeepSeek
./clauver.ps1 config deepseek

# Add custom provider
./clauver.ps1 config custom
```

### Using Providers

```powershell
# Use specific provider
./clauver.ps1 zai "Your prompt here"
./clauver.ps1 minimax "Your prompt here"

# Use Native Anthropic (no API key needed)
./clauver.ps1 anthropic "Your prompt here"

# Use custom provider
./clauver.ps1 my-custom-provider "Your prompt here"
```

### Default Provider

```powershell
# Set default provider
./clauver.ps1 default zai

# Check default provider
./clauver.ps1 default

# Use default provider (no provider argument needed)
./clauver.ps1 "What can you help me with?"
```

### Testing Providers

```powershell
# Test specific provider
./clauver.ps1 test zai
./clauver.ps1 test minimax
./clauver.ps1 test anthropic
```

### Update and Migration

```powershell
# Check for updates
./clauver.ps1 update

# Migrate plaintext secrets to encrypted storage
./clauver.ps1 migrate

# Check migration status only
./clauver.ps1 migrate --check-only
```

## Tab Completion

### Installation

```powershell
# Install tab completion
. ./Completion/clauver-completion.ps1

# Or register manually
Import-Module ./Clauver.psm1
Register-ClauverTabCompletion
```

### Using Tab Completion

```powershell
# Complete commands
./clauver.ps1 <TAB>
# Shows: help, setup, version, update, list, status, config, test, default, migrate, anthropic, zai, minimax, kimi, deepseek

# Complete providers for specific commands
./clauver.ps1 config <TAB>
# Shows: anthropic, zai, minimax, kimi, deepseek, custom

# Complete custom providers
./clauver.ps1 my-cu<TAB>
# Shows: my-custom-provider (if configured)
```

## PowerShell Module Functions

### Public Functions

Clauver exposes PowerShell functions for programmatic use:

```powershell
# Import the module
Import-Module ./Clauver.psm1

# Get configuration values
$apiKey = Get-ConfigValue -Key "zai_api_key"
$defaultProvider = Get-ClauverDefault

# Set configuration
Set-ConfigValue -Key "zai_model" -Value "glm-4.6"
Set-ClauverDefault -Name "zai"

# Read/write configuration files
$config = Read-ClauverConfig
Write-ClauverConfig -Key "test" -Value "value"

# Invoke operations
Invoke-ClauverProvider -Provider "zai" -ClaudeArgs @("test prompt")
Update-Clauver -CheckOnly
Invoke-ClauverMigrate -CheckOnly

# Show information
Show-ClauverHelp
Show-ClauverVersion
Show-ClauverBanner -Provider "Z.AI"
```

### Examples

```powershell
# Script: Check all configured providers
Import-Module ./Clauver.psm1

$config = Read-ClauverConfig
$providers = $config.Keys | Where-Object { $_ -match "_api_key$" }

foreach ($key in $providers) {
    $provider = $key -replace "_api_key$", ""
    $apiKey = Get-Secret -Key ($provider.ToUpper() + "_API_KEY")

    if ($apiKey) {
        Write-Host "$provider is configured with key: $($apiKey.Substring(0, 8))****"
    } else {
        Write-Host "$provider is not configured"
    }
}
```

## Configuration Storage

### Location

Configuration is stored in `$HOME/.clauver`:

```
~/.clauver/
├── config          # Provider configuration
├── secrets.env.age # Encrypted API keys
└── age.key         # Encryption key
```

### PowerShell Profile Integration

Add to your PowerShell profile (`$PROFILE`):

```powershell
# Clauver auto-loading
$clauverPath = Join-Path $HOME "clauver/clauver-powershell"
if (Test-Path $clauverPath) {
    Set-Alias clauver (Join-Path $clauverPath "clauver.ps1")
    Import-Module (Join-Path $clauverPath "Clauver.psm1")
    Register-ClauverTabCompletion
}
```

## Security

### Encryption

- All API keys are encrypted using [age](https://github.com/FiloSottile/age)
- Encryption key: `~/.clauver/age.key` (permissions: 600)
- Secrets file: `~/.clauver/secrets.env.age` (permissions: 600)
- Decryption happens in memory only

### Best Practices

1. **Back up your age key**: Without it, encrypted secrets cannot be recovered
2. **Never share** the `age.key` file
3. **Use secure API keys** from your provider's dashboard
4. **Regular updates**: Run `./clauver.ps1 update` regularly

## Troubleshooting

### Common Issues

#### "age command not found"
```powershell
# Windows: Download and add to PATH
# macOS/Linux
brew install age  # macOS
sudo apt install age  # Ubuntu/Debian
```

#### "claude command not found"
```powershell
npm install -g @anthropic-ai/claude-code
```

#### Permission Denied
```powershell
# On Windows, ensure execution policy allows scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# On Linux/macOS, ensure clauver.ps1 is executable
chmod +x clauver.ps1
```

#### Tab completion not working
```powershell
# Re-register completion
Import-Module ./Clauver.psm1 -Force
Register-ClauverTabCompletion

# Or reinstall completion script
. ./Completion/clauver-completion.ps1
```

### Debug Mode

Enable debug output:

```powershell
$env:CLAUVER_DEBUG = "1"
./clauver.ps1 <command>
```

Or use PowerShell's `-Verbose` parameter:

```powershell
Import-Module ./Clauver.psm1
Invoke-ClauverProvider -Provider "zai" -ClaudeArgs @("test") -Verbose
```

## Development

### Running Tests

```powershell
# Install Pester if not installed
Install-Module -Name Pester -Force

# Run all tests
Invoke-Pester tests/

# Run unit tests only
Invoke-Pester tests/Unit/

# Run integration tests
Invoke-Pester tests/Integration/

# Run with coverage
Invoke-Pester -CodeCoverage .
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Comparison with Bash Version

| Feature | Bash | PowerShell |
|---------|------|-----------|
| All providers | ✅ | ✅ |
| Custom providers | ✅ | ✅ |
| Encrypted storage | ✅ | ✅ |
| Tab completion | ✅ | ✅ |
| Auto-update | ✅ | ✅ |
| Migration tool | ✅ | ✅ |
| Module functions | ❌ | ✅ |
| Pipeline support | ❌ | ✅ |
| Object output | ❌ | ✅ |

## Additional Resources

- [Main Clauver Repository](https://github.com/dkmnx/clauver)
- [Claude Code Documentation](https://docs.anthropic.com/claude/docs/claude-code)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Age Encryption](https://github.com/FiloSottile/age)