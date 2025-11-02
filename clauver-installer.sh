#!/usr/bin/env bash
# Clauver Installer - Simplified installation script
set -euo pipefail
IFS=$'\n\t'
umask 077

VERSION="1.0.1"
BASE="${CLAUVER_HOME:-$HOME/.clauver}"
CONFIG="$BASE/config"
SECRETS="$BASE/secrets.env"
BIN="$BASE/bin"

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

case "${SHELL##*/}" in
  zsh)  SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
  fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
  *)    SHELL_RC="${SHELL_RC:-$HOME/.bashrc}" ;;
esac
SHELL_NAME="${SHELL##*/}"

echo -e "${BOLD}Clauver v${VERSION}${NC}"
echo
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

mkdir -p "$BASE" "$BIN"

touch "$CONFIG"
chmod 600 "$CONFIG"

touch "$SECRETS"
chmod 600 "$SECRETS"

# Clean installation: Copy the clauver script directly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/clauver.sh" "$BIN/clauver"
chmod +x "$BIN/clauver"

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
    cp "$SCRIPT_DIR/completion/clauver.bash" "$COMPLETION_DIR/" 2>/dev/null || true
    success "Auto-completion installed for bash"
    ;;
  zsh)
    COMPLETION_DIR_ZSH="$HOME/.zfunc"
    mkdir -p "$COMPLETION_DIR_ZSH"
    cp "$SCRIPT_DIR/completion/clauver.zsh" "$COMPLETION_DIR_ZSH/_clauver" 2>/dev/null || true
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
    cp "$SCRIPT_DIR/completion/clauver.fish" "$HOME/.config/fish/completions/clauver.fish" 2>/dev/null || true
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
echo -e "${BOLD}What's next?${NC}"
echo " 1. Quick start:"
echo -e "   ${GREEN}clauver setup${NC}             # Interactive setup wizard"
echo
echo " 2. Configure a provider:"
echo -e "   ${GREEN}clauver config zai${NC}"
echo -e "   ${GREEN}clauver config minimax${NC}"
echo -e "   ${GREEN}clauver config kimi${NC}"
echo -e "   ${GREEN}clauver config katcoder${NC}"
echo -e "   ${GREEN}clauver config anthropic${NC}"
echo
echo " 3. Use a provider:"
echo -e "   ${GREEN}clauver zai${NC}"
echo -e "   ${GREEN}clauver minimax${NC}"
echo -e "   ${GREEN}clauver anthropic${NC}"
echo
echo " 4. For all commands:"
echo -e "   ${GREEN}clauver help${NC}"
echo
echo -e "${YELLOW}Auto-completion enabled!${NC}"
echo "  Try: clauver <TAB><TAB> to see available commands"
