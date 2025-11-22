# clauver

```text
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██║██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
```

[![CI](https://github.com/dkmnx/clauver/workflows/CI%20Test%20Suite/badge.svg)](https://github.com/dkmnx/clauver/actions)
[![Shellcheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)](https://github.com/koalaman/shellcheck)
[![Version](https://img.shields.io/badge/version-1.10.0-blue)](https://github.com/dkmnx/clauver/tree/v1.10.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Claude Code Provider Manager** - Switch between multiple Claude Code API
providers seamlessly.

## Overview

_Clauver_ is a powerful CLI tool that allows you to easily manage and switch
between different Claude Code API providers, including:

- **Native Anthropic** - Use your existing Claude Pro/Team subscription
- **Z.AI** - Zhipu AI's GLM models
- **MiniMax** - MiniMax AI's MiniMax-M2 model
- **Kimi** - Moonshot AI's Kimi K2 model
- **DeepSeek** - DeepSeek AI's DeepSeek models
- **Custom Providers** - Add your own provider

> _**⚠️ Platform Compatibility**:
This script has been tested and confirmed to work on Linux only.
While it may work on other Unix-like systems (macOS, WSL), compatibility is not guaranteed._

## Features

- **Easy Provider Switching** - Switch providers with a single command
- **Secure API Key Management** - API keys encrypted with age (X25519)
- **Configuration Testing** - Test provider configurations before use
- **Default Provider** - Set a default provider for quick access
- **Auto-completion** - Tab completion for bash, zsh, and fish
- **Quick Setup Wizard** - Interactive setup for beginners
- **Status Monitoring** - Check all configured providers at once
- **Self-Update** - Update to the latest version with a single command
- **Encrypted Storage** - Secrets encrypted at rest, decrypted in memory only

## Credits

_Clauver_ is heavily inspired by **[clother](https://github.com/jolehuit/clother)**
by [jolehuit](https://github.com/jolehuit).
Special thanks to the original project for the inspiration and architectural concepts.

## Requirements

- **claude CLI** - Install with: `npm install -g @anthropic-ai/claude-code`
- **age** - For encryption: `sudo apt install age` (or `brew install age` on macOS)
- **Bash/Zsh/Fish** - For auto-completion
- **API Keys** - For third-party providers

## Installation

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/dkmnx/clauver/main/install.sh | bash
```

The installer will:

- ✅ Check for the `claude` command
- ✅ Install clauver to `~/.clauver/bin/`
- ✅ Set up auto-completion
- ✅ Add to PATH (if needed)

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/dkmnx/clauver clauver
cd clauver

# Install
mkdir -p ~/.clauver/bin
cp clauver.sh ~/.clauver/bin/clauver
chmod +x ~/.clauver/bin/clauver

# Add to PATH
echo 'export PATH="$HOME/.clauver/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Usage

### Setup Wizard

```bash
clauver setup        # Interactive setup wizard
```

### Configure Providers

```bash
clauver config zai           # Configure Z.AI
clauver config minimax       # Configure MiniMax
clauver config kimi          # Configure Kimi
clauver config deepseek      # Configure DeepSeek
clauver config anthropic     # Configure Native Anthropic
clauver config custom        # Add custom provider
```

### Use Providers

```bash
clauver anthropic    # Use Native Anthropic
clauver zai          # Use Z.AI
clauver minimax      # Use MiniMax
clauver kimi         # Use Kimi
clauver deepseek     # Use DeepSeek
clauver <custom>     # Use custom provider
```

### Default Provider

Set a default provider for quick access:

```bash
# Set default provider
clauver default zai

# Show current default
clauver default

# Use default provider (no arguments needed)
clauver "What can you help me with?"
```

### Manage Providers

```bash
clauver list         # List all providers
clauver status       # Check provider status
clauver test <name>  # Test a provider
clauver migrate      # Migrate plaintext secrets to encrypted storage
clauver default      # Show or set default provider
clauver version      # Show current version and check for updates
clauver update       # Update to the latest version
clauver help         # Show help
```

## Examples

### Basic Usage

```bash
# First time setup
clauver setup

# Configure a provider
clauver config minimax
# Enter your MiniMax API key when prompted

# Use the provider
clauver minimax "Write a Python function to calculate fibonacci numbers"

# Check status
clauver status
```

### Testing Configuration

```bash
# Test a specific provider
clauver test zai

# Test all providers
clauver status
```

### Setting a Default Provider

```bash
# Set your preferred default provider
clauver default minimax

# Verify the default is set
clauver default

# Use the default provider
clauver "Help me write a bash script"

# Change your default anytime
clauver default anthropic
```

### Version Management

```bash
# Check current version and available updates
clauver version

# Update to the latest version
clauver update

# Both commands work without confirmation prompts
# Update will show "already up to date" if on latest version
```

## Encryption & Key Management

### Encryption Overview

Clauver automatically encrypts all API keys using
[age](https://github.com/FiloSottile/age), a modern and secure file encryption
tool. Your secrets are:

- Encrypted at rest on disk
- Only decrypted into memory when needed
- Never written to disk as plaintext

### Key Backup

**CRITICAL**: Back up your encryption key immediately after installation!

```bash
# Your encryption key location
~/.clauver/age.key

# Back up your key (choose one method):
cp ~/.clauver/age.key ~/backup/clauver-age.key.backup
cp ~/.clauver/age.key /path/to/external/drive/
```

**Without your age key, you cannot decrypt your secrets!**

### Key Recovery

If you lose your encryption key:

```bash
# 1. If you have a backup, restore it:
cp ~/backup/clauver-age.key.backup ~/.clauver/age.key
chmod 600 ~/.clauver/age.key

# 2. If you don't have a backup, you'll need to reconfigure:
rm ~/.clauver/secrets.env.age  # Remove encrypted file
clauver config <provider>       # Reconfigure your providers
```

### Migrating from Plaintext

If you're upgrading from an older version with plaintext secrets:

```bash
# Check your current storage type
clauver status

# Migrate to encrypted storage
clauver migrate

# Verify encryption is active
clauver status  # Should show "🔒 Secrets Storage: Encrypted"
```

### Using Configs on Multiple Machines

Your encryption key is portable! To use your configs on another machine:

```bash
# On original machine - backup both files:
cp ~/.clauver/age.key ~/backup/
cp ~/.clauver/secrets.env.age ~/backup/

# On new machine - restore both files:
mkdir -p ~/.clauver
cp ~/backup/age.key ~/.clauver/
cp ~/backup/secrets.env.age ~/.clauver/
chmod 600 ~/.clauver/age.key
chmod 600 ~/.clauver/secrets.env.age

# Verify it works:
clauver list
```

### Custom Provider

```bash
# Add a custom provider
clauver config custom
# Provider name: my-provider
# Base URL: https://api.example.com/anthropic
# API Key: your-api-key
# Model: your-model

# Use it
clauver my-provider "Hello"
```

## Auto-completion

_Clauver_ includes auto-completion for `bash`, `zsh`, and `fish`.

After installation, try:

```bash
clauver <TAB><TAB>        # Show available commands
clauver z<TAB>            # Complete to 'clauver zai'
```

## Testing

_Clauver_ includes a comprehensive test suite with unit tests, integration tests,
security validation, and performance benchmarks.

### Quick Test

```bash
# Run all tests
cd tests/
make test

# Or use the test runner
./run_all_tests.sh
```

### Full Documentation

For detailed testing information, including:

- Test categories and coverage areas
- CI/CD pipeline and continuous integration
- Security testing and performance benchmarks
- Contributing guidelines for tests

👉 See **[tests/README.md](tests/README.md)** for complete testing documentation.

## Configuration Storage

_Clauver_ uses an encrypted configuration system:

```text
~/.clauver/
├── secrets.env.age        # Encrypted API keys (age encrypted)
├── age.key                # Encryption key (chmod 600) - BACK THIS UP!
├── config                 # Provider configurations (chmod 600)
├── bin/
│   └── clauver           # Installed binary
└── completions/          # Auto-completion files
```

### Configuration Files

- **secrets.env.age**: Encrypted API keys using age (X25519) encryption
  - `ZAI_API_KEY`
  - `MINIMAX_API_KEY`
  - `KIMI_API_KEY`
  - `DEEPSEEK_API_KEY`
    - Secrets are only decrypted into memory, never written to disk as plaintext

- **age.key**: Your encryption key (automatically generated)
  - **CRITICAL**: Back up this file! Without it, you cannot decrypt your secrets
  - Portable across machines - copy this file to use your configs elsewhere
  - Located at: `~/.clauver/age.key`

- **config**: Stores provider configurations:
  - Base URLs, models, and endpoint IDs
  - Custom provider definitions
  - `default_provider` - Your preferred default provider

### Security Features

- **Encrypted at Rest**: API keys are encrypted using age (modern, secure encryption)
- **Memory-Only Decryption**: Secrets decrypted directly into memory via
  process substitution
- **No Plaintext on Disk**: Encrypted file is never written as plaintext
- **Session Caching**: Secrets decrypted once per session for performance
- **Automatic Key Generation**: Encryption key auto-generated on first use
- **Migration Support**: Seamlessly migrate from plaintext to encrypted storage

## Troubleshooting

Having issues? See complete **[troubleshooting](TROUBLESHOOTING.md)** guide.

Common fixes:

- **PATH issues**: `export PATH="$HOME/.clauver/bin:$PATH"`
- **Missing dependencies**: `npm install -g @anthropic-ai/claude-code`
- **age encryption**: `sudo apt install age` (or `brew install age`)
- **Provider tests**: `clauver test <provider>`
- **Status check**: `clauver status`

## License

[MIT](LICENSE) (c) 2025 [dkmnx](https://github.com/dkmnx)
