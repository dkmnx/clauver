#!/usr/bin/env bash
# Clauver Installer - Simplified installation script
set -euo pipefail
IFS=$'\n\t'
umask 077

VERSION="1.12.1"
BASE="${CLAUVER_HOME:-$HOME/.clauver}"
CONFIG="$BASE/config"
SECRETS="$BASE/secrets.env"
BIN="$BASE/bin"
AGE_KEY="$BASE/age.key"

# Detect if script is being run via curl

# Check if we can detect stdin is not a terminal AND the script file doesn't exist locally
# Use a safer approach to detect if script is local or piped
SCRIPT_TEMP_FILE=$(mktemp)
echo "$0" > "$SCRIPT_TEMP_FILE"

if [ -n "${INSTALL_SCRIPT_URL:-}" ]; then
  SCRIPT_SOURCE="remote"
  SCRIPT_DIR="$(pwd)"
elif [ -f "$0" ] && [ "$(head -c 10 "$SCRIPT_TEMP_FILE")" != "bash" ]; then
  SCRIPT_SOURCE="local"
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
  SCRIPT_SOURCE="curl"
  INSTALL_SCRIPT_URL="${INSTALL_SCRIPT_URL:-https://raw.githubusercontent.com/dkmnx/clauver/main}"
  SCRIPT_DIR="$(pwd)"
fi

rm -f "$SCRIPT_TEMP_FILE"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}→${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }

# Ensure age encryption key exists
ensure_age_key() {
  if [ ! -f "$AGE_KEY" ]; then
    log "Generating age encryption key..."
    age-keygen -o "$AGE_KEY"
    chmod 600 "$AGE_KEY"
    success "Age encryption key generated at $AGE_KEY"
    echo
    echo -e "${YELLOW}IMPORTANT: Back up your age key!${NC}"
    echo "The key file is: $AGE_KEY"
    echo "Without this key, you cannot decrypt your secrets."
    echo
  else
    success "Age encryption key found at $AGE_KEY"
  fi
}

case "${SHELL##*/}" in
  zsh)  SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
  fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
  *)    SHELL_RC="${SHELL_RC:-$HOME/.bashrc}" ;;
esac
SHELL_NAME="${SHELL##*/}"

echo -e "${BOLD}Clauver v${VERSION}${NC}"
echo
if [ "$SCRIPT_SOURCE" = "curl" ]; then
  echo -e "${YELLOW}Installing via curl${NC}"
  echo
fi
log "Checking for 'claude' command..."
if ! command -v claude &>/dev/null; then
  error "'claude' command not found."
  echo
  echo "Clauver requires the 'claude' command-line tool to be installed."
  echo "Please install it first:"
  echo -e " ${YELLOW}npm install -g @anthropic-ai/claude-code${NC}"
  echo
  exit 1
fi
success "'claude' command found."

# Check for age encryption
log "Checking for 'age' encryption..."
if ! command -v age &>/dev/null; then
  error "'age' command not found."
  echo
  echo "Clauver requires 'age' for encrypted secret storage."
  echo "Please install it first:"
  echo
  case "$(uname -s)" in
    Linux*)
      echo -e " ${YELLOW}# Ubuntu/Debian:${NC}"
      echo -e " ${YELLOW}sudo apt install age${NC}"
      echo
      echo -e " ${YELLOW}# Fedora/CentOS:${NC}"
      echo -e " ${YELLOW}sudo dnf install age${NC}"
      echo
      echo -e " ${YELLOW}# Arch Linux:${NC}"
      echo -e " ${YELLOW}sudo pacman -S age${NC}"
      ;;
    Darwin*)
      echo -e " ${YELLOW}# macOS:${NC}"
      echo -e " ${YELLOW}brew install age${NC}"
      ;;
    *)
      echo -e " ${YELLOW}# From source:${NC}"
      echo -e " ${YELLOW}go install github.com/FiloSottile/age/cmd/age@latest${NC}"
      ;;
  esac
  echo
  exit 1
fi

if ! command -v age-keygen &>/dev/null; then
  error "'age-keygen' command not found."
  echo "This should come with the 'age' package."
  exit 1
fi

success "'age' encryption found."

mkdir -p "$BASE" "$BIN"

# Ensure age encryption key exists
ensure_age_key

# Check for existing plaintext secrets and prompt for migration
if [ -f "$SECRETS" ] && [ ! -f "$BASE/secrets.env.age" ]; then
  echo
  warn "Found existing plaintext secrets file."
  echo "For better security, clauver now encrypts all secrets."
  echo
  read -p "Would you like to migrate to encrypted storage now? [Y/n]: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    log "Migration will be performed after installation completes."
    NEEDS_MIGRATION=1
  else
    warn "Skipping migration. You can migrate later with: clauver migrate"
  fi
fi

touch "$CONFIG"
chmod 600 "$CONFIG"

touch "$SECRETS"
chmod 600 "$SECRETS"

# Clean installation: Copy or download the clauver script
if [ "$SCRIPT_SOURCE" = "curl" ] || [ "$SCRIPT_SOURCE" = "remote" ]; then
  log "Installing from remote source..."
  curl -fsSL "$INSTALL_SCRIPT_URL/clauver.sh" -o "$BIN/clauver"
  chmod +x "$BIN/clauver"
else
  cp "$SCRIPT_DIR/clauver.sh" "$BIN/clauver"
  chmod +x "$BIN/clauver"
fi

if ! "$BIN/clauver" help &>/dev/null; then
  error "Installation failed - clauver command doesn't work"
  exit 1
fi

success "Installed Clauver to '$BIN/clauver'."

# Install auto-completion
COMPLETION_DIR="$BASE/completions"
mkdir -p "$COMPLETION_DIR"

case "$SHELL_NAME" in
  bash)
    COMPLETION_FILE="$HOME/.bash_completion"
    if [ -f "$COMPLETION_FILE" ]; then
      if ! grep -q "clauver.bash" "$COMPLETION_FILE" 2>/dev/null; then
        {
          echo ""
          echo "# Clauver completion"
          echo "[ -f \"$COMPLETION_DIR/clauver.bash\" ] && . \"$COMPLETION_DIR/clauver.bash\""
        } >> "$COMPLETION_FILE"
      fi
    else
      COMPLETION_FILE="$HOME/.bashrc"
      {
        echo ""
        echo "# Clauver completion"
        echo "[ -f \"$COMPLETION_DIR/clauver.bash\" ] && . \"$COMPLETION_DIR/clauver.bash\""
      } >> "$COMPLETION_FILE"
    fi
    if [ "$SCRIPT_SOURCE" = "curl" ] || [ "$SCRIPT_SOURCE" = "remote" ]; then
      curl -fsSL "$INSTALL_SCRIPT_URL/completion/clauver.bash" -o "$COMPLETION_DIR/clauver.bash" 2>/dev/null || true
    else
      cp "$SCRIPT_DIR/completion/clauver.bash" "$COMPLETION_DIR/" 2>/dev/null || true
    fi
    success "Auto-completion installed for bash"
    ;;
  zsh)
    COMPLETION_DIR_ZSH="$HOME/.zfunc"
    mkdir -p "$COMPLETION_DIR_ZSH"
    if [ "$SCRIPT_SOURCE" = "curl" ] || [ "$SCRIPT_SOURCE" = "remote" ]; then
      curl -fsSL "$INSTALL_SCRIPT_URL/completion/clauver.zsh" -o "$COMPLETION_DIR_ZSH/_clauver" 2>/dev/null || true
    else
      cp "$SCRIPT_DIR/completion/clauver.zsh" "$COMPLETION_DIR_ZSH/_clauver" 2>/dev/null || true
    fi
    if ! grep -q "# Clauver completion" "$HOME/.zshrc" 2>/dev/null; then
      {
        echo ""
        echo "# Clauver completion"
        echo "autoload -U compinit && compinit"
      } >> "$HOME/.zshrc"
    fi
    success "Auto-completion installed for zsh"
    ;;
  fish)
    mkdir -p "$HOME/.config/fish/completions"
    if [ "$SCRIPT_SOURCE" = "curl" ] || [ "$SCRIPT_SOURCE" = "remote" ]; then
      curl -fsSL "$INSTALL_SCRIPT_URL/completion/clauver.fish" -o "$HOME/.config/fish/completions/clauver.fish" 2>/dev/null || true
    else
      cp "$SCRIPT_DIR/completion/clauver.fish" "$HOME/.config/fish/completions/clauver.fish" 2>/dev/null || true
    fi
    success "Auto-completion installed for fish"
    ;;
esac

if [[ ":$PATH:" != *":$BIN:"* ]]; then
  echo
  warn "ACTION REQUIRED: Add '$BIN' to your PATH."
  echo "To use 'clauver', run:"
  echo
  echo -e " ${YELLOW}echo 'export PATH=\"$BIN:\$PATH\"' >> $SHELL_RC${NC}"
  echo -e " ${YELLOW}source $SHELL_RC${NC}"
  echo
  echo "You may need to restart your terminal."
fi

echo
if [ "$SCRIPT_SOURCE" = "local" ]; then
  echo -e "${BOLD}Installation methods:${NC}"
  echo "  Local install: $(basename "$0")"
  echo -e "  Curl install:  ${GREEN}curl -fsSL https://raw.githubusercontent.com/dkmnx/clauver/main/install.sh | bash${NC}"
  echo
fi

echo -e "${BOLD}What's next?${NC}"
echo " 1. Quick start:"
echo -e "   ${GREEN}clauver setup${NC}             # Interactive setup wizard"
echo
echo " 2. Configure a provider:"
echo -e "   ${GREEN}clauver config zai${NC}"
echo -e "   ${GREEN}clauver config minimax${NC}"
echo -e "   ${GREEN}clauver config kimi${NC}"
echo -e "   ${GREEN}clauver config anthropic${NC}"
echo
echo " 3. Set a default provider (optional):"
echo -e "   ${GREEN}clauver default zai${NC}       # Set Z.AI as default"
echo -e "   ${GREEN}clauver default${NC}           # Show current default"
echo
echo " 4. Use a provider:"
echo -e "   ${GREEN}clauver zai${NC}               # Use specific provider"
echo -e "   ${GREEN}clauver minimax${NC}"
echo -e "   ${GREEN}clauver anthropic${NC}"
echo -e "   ${GREEN}clauver \"your prompt\"${NC}     # Use default provider"
echo
echo " 5. For all commands:"
echo -e "   ${GREEN}clauver help${NC}"
echo
echo -e "${YELLOW}Auto-completion enabled!${NC}"
echo "  Try: clauver <TAB><TAB> to see available commands"

# Run migration if needed
if [ "${NEEDS_MIGRATION:-0}" -eq 1 ]; then
  echo
  log "Running migration to encrypted storage..."
  if "$BIN/clauver" migrate; then
    success "Migration complete!"
  else
    warn "Migration failed. You can try again with: clauver migrate"
  fi
fi
