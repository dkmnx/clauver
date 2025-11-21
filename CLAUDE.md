# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Clauver** is a bash-based CLI tool that manages multiple Claude Code API providers. It allows switching between different AI providers (Anthropic, Z.AI, MiniMax, Kimi, DeepSeek, and custom providers) with encrypted API key storage using age encryption.

## Commands

### Installation and Setup

```bash
# Install via curl (recommended)
curl -fsSL https://raw.githubusercontent.com/dkmnx/clauver/main/install.sh | bash

# Manual installation
mkdir -p ~/.clauver/bin
cp clauver.sh ~/.clauver/bin/clauver
chmod +x ~/.clauver/bin/clauver
export PATH="$HOME/.clauver/bin:$PATH"

# Interactive setup wizard
clauver setup
```

### Development and Testing

```bash
# Test the script locally (without installation)
./clauver.sh --help

# Check shell script quality
shellcheck clauver.sh install.sh

# Test provider configurations
clauver test <provider>

# Check all providers status
clauver status

# Verify encryption/decryption functionality
age -d -i ~/.clauver/age.key ~/.clauver/secrets.env.age
```

### Provider Management

```bash
# Configure providers
clauver config zai          # Configure Z.AI
clauver config minimax      # Configure MiniMax
clauver config kimi         # Configure Kimi
clauver config deepseek     # Configure DeepSeek
clauver config anthropic    # Configure Native Anthropic
clauver config custom       # Add custom provider

# Switch between providers
clauver zai "Your prompt here"
clauver minimax "Your prompt here"
clauver deepseek "Your prompt here"

# Manage default provider
clauver default zai         # Set default
clauver default             # Show current default
clauver "Your prompt"       # Use default provider
```

## Architecture

### Core Components

**Main Script (`clauver.sh` - 1200+ lines)**

- Single-file bash application with modular functions
- Command dispatcher pattern with `cmd_*` functions
- Encrypted secrets management using age encryption
- Provider abstraction layer for different APIs

**Key Function Categories:**

- **Utility functions**: `log()`, `success()`, `warn()`, `error()`, `banner()`
- **Crypto functions**: `ensure_age_key()`, `save_secrets()`, `load_secrets()`, `get_secret()`, `set_secret()`
- **Config functions**: `get_config()`, `set_config()`, `mask_key()`
- **Command functions**: `cmd_version()`, `cmd_update()`, `cmd_list()`, `cmd_config()`, `cmd_test()`, `cmd_status()`, `cmd_default()`, `cmd_migrate()`, `cmd_setup()`
- **Provider functions**: `switch_to_anthropic()`, and provider-specific switching logic

### Storage Architecture

**Encrypted Configuration System:**

```text
~/.clauver/
├── secrets.env.age        # Age-encrypted API keys
├── age.key                # X25519 encryption key (chmod 600)
├── config                 # Provider configurations (chmod 600)
├── bin/clauver           # Installed binary
└── completions/          # Shell completion files
```

**Security Features:**

- API keys encrypted at rest using age (X25519)
- Memory-only decryption via process substitution
- No plaintext secrets written to disk
- Session caching for performance
- Automatic key generation and migration support

### Provider Support

**Built-in Providers:**

- **anthropic**: Native Anthropic Claude (requires `claude` CLI)
- **zai**: Zhipu AI's GLM models
- **minimax**: MiniMax AI's MiniMax-M2 model
- **kimi**: Moonshot AI's Kimi K2 model
- **deepseek**: DeepSeek AI's DeepSeek models

**Custom Provider Configuration:**

- Dynamic provider addition via `clauver config custom`
- Configurable base URLs, models, and API keys
- Stored in `config` file with `custom_*` prefixes

### Shell Integration

**Auto-completion System:**

- Bash completion in `completion/clauver.bash`
- Zsh completion in `completion/clauver.zsh`
- Fish completion in `completion/clauver.fish`
- Tab completion for commands and provider names

## Development Notes

### Script Structure

- **Header**: Version, paths, colors, utility functions (lines 1-65)
- **Crypto Layer**: Age encryption management (lines 42-223)
- **Command Implementations**: Individual command handlers (lines 267-994)
- **Provider Switching**: API-specific logic (lines 551-900+)
- **Main Dispatcher**: Command routing and execution (lines 1000+)

### Error Handling

- `set -euo pipefail` for strict error handling
- Comprehensive error messages with color coding
- Graceful fallbacks for missing dependencies
- Input validation and sanitization

### Security Considerations

- All API keys encrypted with age X25519
- File permissions set to 600 for sensitive files
- Process substitution to avoid temp files for secrets
- Memory-only decryption (no plaintext on disk)
- Backup/migration support for encryption keys

### Testing Strategy

- Manual testing via `clauver test <provider>`
- Status checking via `clauver status`
- Encryption verification via age CLI tools
- Shell script linting with shellcheck
- Integration testing with actual provider APIs

## Dependencies

**Runtime Requirements:**

- `bash` 4.0+ (for associative arrays)
- `age` (for encryption/decryption)
- `claude` CLI (for anthropic provider)
- Standard Unix tools (`curl`, `grep`, `sed`, `awk`)

**Development Tools:**

- `shellcheck` for script linting
- `age` for testing encryption
- Provider API accounts for integration testing
