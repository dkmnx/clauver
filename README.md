# Clauver

**Claude Code Provider Manager** - Switch between multiple Claude API providers seamlessly.

[![Shellcheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)](https://github.com/koalaman/shellcheck)
[![Version](https://img.shields.io/badge/version-1.0.1-blue)](https://github.com/anthropics/claude-code)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

Clauver is a powerful CLI tool that allows you to easily manage and switch
between different Claude API providers, including:

- **Native Anthropic** - Use your existing Claude Pro/Team subscription
- **Z.AI (GLM)** - Zhipu AI's GLM models
- **MiniMax (MiniMax-M2)** - High-performance Chinese LLM
- **Kimi (K2)** - Moonshot AI's Kimi K2 model
- **KAT-Coder** - Kwaipilot's KAT-Coder
- **Custom Providers** - Add your own provider

> **⚠️ Platform Compatibility**:
This script has been tested and confirmed to work on Linux only.
While it may work on other Unix-like systems (macOS, WSL), compatibility is not guaranteed.

## Features

- **Easy Provider Switching** - Switch providers with a single command
- **Secure API Key Management** - Store and mask API keys safely
- **Configuration Testing** - Test provider configurations before use
- **Auto-completion** - Tab completion for bash, zsh, and fish
- **Quick Setup Wizard** - Interactive setup for beginners
- **Status Monitoring** - Check all configured providers at once

## Credits

Clauver is heavily inspired by **[clother](https://github.com/jolehuit/clother)** by [jolehuit](https://github.com/jolehuit).
Special thanks to the original project for the inspiration and architectural concepts.

## Installation

### Quick Install

```bash
git clone <repository-url> clauver
cd clauver
bash clauver-installer.sh
```

The installer will:

- ✅ Check for the `claude` command
- ✅ Install clauver to `~/.clauver/bin/`
- ✅ Set up auto-completion
- ✅ Add to PATH (if needed)

### Manual Installation

```bash
# Clone the repository
git clone <repository-url> clauver
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
clauver config katcoder      # Configure KAT-Coder
clauver config anthropic     # Configure Native Anthropic
clauver config custom        # Add custom provider
```

### Use Providers

```bash
clauver anthropic    # Use Native Anthropic
clauver zai          # Use Z.AI
clauver minimax      # Use MiniMax
clauver kimi         # Use Kimi
clauver katcoder     # Use KAT-Coder
clauver <custom>     # Use custom provider
```

### Manage Providers

```bash
clauver list         # List all providers
clauver status       # Check provider status
clauver test <name>  # Test a provider
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

Clauver includes auto-completion for bash, zsh, and fish.

After installation, try:

```bash
clauver <TAB><TAB>        # Show available commands
clauver z<TAB>            # Complete to 'clauver zai'
```

## Requirements

- **claude CLI** - Install with: `npm install -g @anthropic-ai/claude-code`
- **Bash/Zsh/Fish** - For auto-completion
- **API Keys** - For third-party providers

## Architecture

```text
clauver/
├── clauver.sh              # Main CLI script
├── clauver-installer.sh    # Installation script
├── completion/             # Auto-completion files
│   ├── clauver.bash
│   ├── clauver.zsh
│   └── clauver.fish
├── README.md               # This file
└── LICENSE                 # MIT license
```

## Configuration Storage

Clauver uses a two-file configuration system:

```text
~/.clauver/
├── secrets.env            # API keys and sensitive data (chmod 600)
├── config                 # Custom providers only (chmod 600)
├── bin/
│   └── clauver           # Installed binary
└── completions/          # Auto-completion files
```

### Configuration Files

- **secrets.env**: Stores API keys for all providers in uppercase format:
  - `ZAI_API_KEY`
  - `MINIMAX_API_KEY`
  - `KIMI_API_KEY`
  - `KATCODER_API_KEY`

- **config**: Stores only custom provider configurations:
  - Base URLs, models, and endpoint IDs
  - Custom provider definitions

## Troubleshooting

### PATH Issues

If `clauver` is not found after installation:

Export the path for the current session.

```bash
export PATH="$HOME/.clauver/bin:$PATH"
```

Make it permanent by adding the path to your shell config file.

```bash
# Bash
echo 'export PATH="$HOME/.clauver/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Zsh
echo 'export PATH="$HOME/.clauver/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Fish
echo 'set -gx PATH $HOME/.clauver/bin $PATH' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish
```

### Provider Test Fails

1. Make sure you have a valid API key and valid subscription or enough credits
for the provider.
2. Check your API key is correctly configured: `clauver list`
3. Ensure you have internet connectivity
4. Test the provider directly: `clauver test <provider>`

### Claude Command Not Found

Install Claude Code CLI:

```bash
npm install -g @anthropic-ai/claude-code
```

## License

MIT (c) 2025 [dkmnx](https://github.com/dkmnx)
