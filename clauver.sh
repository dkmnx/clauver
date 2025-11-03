#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

VERSION="1.2.3"
BASE="${CLAUVER_HOME:-$HOME/.clauver}"
CONFIG="$BASE/config"
SECRETS="$BASE/secrets.env"

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

banner() {
  provider="$1"
  echo -e "${BOLD}${BLUE}"
  cat <<BANNER
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██║██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
  v${VERSION} - ${provider}
BANNER
  echo -e "${NC}"
}

[ -f "$CONFIG" ] || true
[ -f "$SECRETS" ] || true

# Load secrets from secrets.env
load_secrets() {
  if [ -f "$SECRETS" ]; then
    # Export all variables from secrets.env
    # shellcheck disable=SC1090
    source "$SECRETS"
  fi
}

# Get config value from CONFIG file
get_config() {
  local key="$1"
  grep "^${key}=" "$CONFIG" 2>/dev/null | cut -d= -f2- || echo ""
}

# Get secret value from SECRETS file
get_secret() {
  local key="$1"
  grep "^${key}=" "$SECRETS" 2>/dev/null | cut -d= -f2- || echo ""
}

set_config() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp "${CONFIG}.XXXXXX")"
  if [ -f "$CONFIG" ]; then
    grep -v -E "^${key}=" "$CONFIG" > "$tmp" 2>/dev/null || true
  fi
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$CONFIG"
  chmod 600 "$CONFIG"
}

set_secret() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp "${SECRETS}.XXXXXX")"
  if [ -f "$SECRETS" ]; then
    grep -v -E "^${key}=" "$SECRETS" > "$tmp" 2>/dev/null || true
  fi
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$SECRETS"
  chmod 600 "$SECRETS"
}

mask_key() {
  local key="${1:-}"
  [ -z "$key" ] && { echo ""; return; }
  [ ${#key} -le 8 ] && { echo "****"; return; }
  echo "${key:0:4}****${key: -4}"
}

show_help() {
  echo -e "${BOLD}Clauver v${VERSION}${NC}"
  echo "Manage and switch between Claude Code providers"
  echo
  echo -e "${YELLOW}Quick Start:${NC}"
  echo "  clauver setup        # Interactive setup wizard"
  echo "  clauver zai          # Switch to Z.AI"
  echo "  claude \"hello\"       # Use current provider"
  echo
  echo -e "${YELLOW}Usage:${NC}"
  echo "  clauver <command> [args]"
  echo
  echo -e "${BOLD}Setup & Help:${NC}"
  echo "  setup, -s            Interactive setup wizard for beginners"
  echo "  help, -h, --help     Show this help message"
  echo
  echo -e "${BOLD}Provider Management:${NC}"
  echo "  list                 List all configured providers"
  echo "  status               Check status of all providers"
  echo "  config <provider>    Configure a specific provider"
  echo "  test <provider>      Test a provider configuration"
  echo
  echo -e "${BOLD}Switch Providers:${NC}"
  echo "  anthropic            Use Native Anthropic (no API key needed)"
  echo "  zai                  Switch to Z.AI provider"
  echo "  minimax              Switch to MiniMax provider"
  echo "  kimi                 Switch to Moonshot Kimi provider"
  echo "  katcoder             Switch to KAT-Coder provider"
  echo "  <custom>             Switch to your custom provider"
  echo
  echo -e "${YELLOW}Examples:${NC}"
  echo "  clauver setup        # Guided setup for first-time users"
  echo "  clauver list         # Show all providers"
  echo "  clauver config zai   # Configure Z.AI provider"
  echo "  clauver test zai     # Test Z.AI provider"
  echo "  clauver zai          # Use Z.AI for this session"
  echo "  clauver anthropic    # Use Native Anthropic"
  echo
  echo -e "${YELLOW}💡 Tips:${NC}"
  echo "  • Space-separated commands: clauver zai, clauver minimax, etc."
  echo "  • Auto-completion available: clauver <TAB><TAB>"
  echo "  • Any valid provider name works: clauver your-provider"
  echo "  • All claude flags work: clauver zai --dangerously-skip-permissions"
}

cmd_list() {
  # Load secrets
  load_secrets

  echo -e "${BOLD}Configured Providers:${NC}"
  echo

  echo -e "${GREEN}✓ Native Anthropic${NC}"
  echo "  Command: clauver anthropic"
  echo "  Description: Use your Claude Pro/Team subscription"
  echo

  for provider in zai minimax kimi katcoder; do
    local key_name="${provider^^}_API_KEY"
    local api_key
    api_key="$(get_secret "$key_name")"
    if [ -n "$api_key" ]; then
      echo -e "${GREEN}✓ ${provider}${NC}"
      echo "  Command: clauver $provider"
      echo "  API Key: $(mask_key "$api_key")"
      echo
    fi
  done

  if [ -f "$CONFIG" ]; then
    while IFS="=" read -r key value; do
      if [[ "$key" == custom_*_api_key ]]; then
        local provider_name="${key#custom_}"
        provider_name="${provider_name%_api_key}"
        if [ -n "$value" ]; then
          echo -e "${GREEN}✓ ${provider_name}${NC}"
          echo "  Command: clauver $provider_name"
          echo "  Type: Custom"
          echo "  API Key: $(mask_key "$value")"
          echo "  Base URL: $(get_config "custom_${provider_name}_base_url")"
          echo
        fi
      fi
    done < "$CONFIG"
  fi

  echo -e "${YELLOW}Not Configured:${NC}"
  for provider in zai minimax kimi katcoder; do
    local key_name="${provider^^}_API_KEY"
    local api_key
    api_key="$(get_secret "$key_name")"
    if [ -z "$api_key" ]; then
      echo "  - $provider (run: clauver config)"
    fi
  done
}

cmd_config() {
  local provider="${1:-}"

  if [ -z "$provider" ]; then
    error "Usage: clauver config <provider>"
    echo
    echo "Available providers: anthropic, zai, minimax, kimi, katcoder, custom"
    echo "Example: clauver config zai"
    return 1
  fi

  case "$provider" in
    anthropic)
      echo
      success "Native Anthropic is ready to use!"
      echo "No configuration needed. Simply run: clauver anthropic"
      ;;
    zai|minimax|kimi|katcoder)
      echo
      echo -e "${BOLD}${provider^^} Configuration${NC}"
      local key_name="${provider^^}_API_KEY"
      local current_key
      current_key="$(get_secret "$key_name")"
      [ -n "$current_key" ] && echo "Current key: $(mask_key "$current_key")"
      read -rs -p "API Key: " key; echo
      [ -z "$key" ] && { error "Key is required"; return 1; }
      set_secret "$key_name" "$key"

      # Save endpoint ID for KAT-Coder
      if [ "$provider" == "katcoder" ]; then
        local endpoint_id
        endpoint_id="$(get_config "katcoder_endpoint_id")"
        [ -n "$endpoint_id" ] && echo "Current endpoint: $endpoint_id"
        read -r -p "Endpoint ID (e.g., ep-xxx-xxx): " endpoint
        [ -z "$endpoint" ] && { error "Endpoint ID is required"; return 1; }
        set_config "katcoder_endpoint_id" "$endpoint"
      fi

      success "${provider^^} configured. Use: clauver $provider"
      ;;
    custom)
      echo
      echo -e "${BOLD}Custom Provider Configuration${NC}"
      read -r -p "Provider name (e.g., 'my-provider'): " name

      if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid name. Use letters, numbers, underscore and hyphen only."
        return 1
      fi

      if [[ "$name" == "anthropic" || "$name" == "zai" || "$name" == "minimax" || "$name" == "kimi" || "$name" == "katcoder" ]]; then
        error "Provider name '$name' is reserved."
        return 1
      fi

      read -r -p "Base URL: " base_url
      read -rs -p "API Key: " api_key; echo
      read -r -p "Default model (optional): " model

      { [ -z "$name" ] || [ -z "$base_url" ] || [ -z "$api_key" ]; } && { error "Name, Base URL and API Key are required"; return 1; }

      set_config "custom_${name}_api_key" "$api_key"
      set_config "custom_${name}_base_url" "$base_url"
      [ -n "$model" ] && set_config "custom_${name}_model" "$model"

      success "Custom provider '$name' configured. Use: clauver $name"
      ;;
    *)
      error "Unknown provider: '$provider'"
      echo
      echo "Available providers: anthropic, zai, minimax, kimi, katcoder, custom"
      echo "Example: clauver config zai"
      return 1
      ;;
  esac
}

switch_to_anthropic() {
  banner "Native Anthropic"
  echo -e "${BOLD}Using Native Anthropic${NC}"
  exec claude "$@"
}

switch_to_zai() {
  load_secrets
  local zai_key
  zai_key="$(get_secret "ZAI_API_KEY")"
  if [ -z "$zai_key" ]; then
    error "Z.AI not configured. Run: clauver config zai"
    exit 1
  fi

  banner "Zhipu AI (GLM Models)"

  export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
  export ANTHROPIC_AUTH_TOKEN="$zai_key"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.6"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-4.6"
  exec claude "$@"
}

switch_to_minimax() {
  load_secrets
  local minimax_key
  minimax_key="$(get_secret "MINIMAX_API_KEY")"
  if [ -z "$minimax_key" ]; then
    error "MiniMax not configured. Run: clauver config minimax"
    exit 1
  fi

  banner "MiniMax (MiniMax-M2)"

  export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
  export ANTHROPIC_AUTH_TOKEN="$minimax_key"
  export ANTHROPIC_MODEL="MiniMax-M2"
  export ANTHROPIC_SMALL_FAST_MODEL="MiniMax-M2"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="MiniMax-M2"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="MiniMax-M2"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="MiniMax-M2"
  export API_TIMEOUT_MS="3000000"
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
  exec claude "$@"
}

switch_to_kimi() {
  load_secrets
  local kimi_key
  kimi_key="$(get_secret "KIMI_API_KEY")"
  if [ -z "$kimi_key" ]; then
    error "Kimi not configured. Run: clauver config kimi"
    exit 1
  fi

  banner "Moonshot AI (kimi-k2)"

  export ANTHROPIC_BASE_URL="https://api.moonshot.ai/anthropic"
  export ANTHROPIC_AUTH_TOKEN="$kimi_key"
  export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
  export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2-turbo-preview"
  export API_TIMEOUT_MS="3000000"
  exec claude "$@"
}

switch_to_katcoder() {
  load_secrets
  local vc_key
  vc_key="$(get_secret "KATCODER_API_KEY")"
  local endpoint_id
  endpoint_id="$(get_config "katcoder_endpoint_id")"

  if [ -z "$vc_key" ]; then
    error "KAT-Coder not configured. Run: clauver config katcoder"
    exit 1
  fi
  if [ -z "$endpoint_id" ]; then
    error "KAT-Coder endpoint ID missing. Run: clauver config katcoder"
    exit 1
  fi

  banner "Kwaipilot (KAT-Coder)"

  export ANTHROPIC_BASE_URL="https://vanchin.streamlake.ai/api/gateway/v1/endpoints/$endpoint_id/claude-code-proxy"
  export ANTHROPIC_AUTH_TOKEN="$vc_key"
  export ANTHROPIC_MODEL="KAT-Coder"
  export ANTHROPIC_SMALL_FAST_MODEL="KAT-Coder"
  export API_TIMEOUT_MS="3000000"
  exec claude "$@"
}

switch_to_custom() {
  local provider_name="$1"
  shift

  local api_key
  api_key="$(get_config "custom_${provider_name}_api_key")"
  local base_url
  base_url="$(get_config "custom_${provider_name}_base_url")"
  local model
  model="$(get_config "custom_${provider_name}_model")"

  if [ -z "$api_key" ]; then
    error "Provider '$provider_name' not configured. Run: clauver config custom"
    exit 1
  fi
  if [ -z "$base_url" ]; then
    error "Provider '$provider_name' base URL missing. Run: clauver config custom"
    exit 1
  fi

  banner "${provider_name}"

  export ANTHROPIC_BASE_URL="$base_url"
  export ANTHROPIC_AUTH_TOKEN="$api_key"
  [ -n "$model" ] && export ANTHROPIC_MODEL="$model"
  exec claude "$@"
}

cmd_test() {
  local provider="${1:-}"

  if [ -z "$provider" ]; then
    error "Usage: clauver test <provider>"
    return 1
  fi

  case "$provider" in
    anthropic)
      echo -e "${BOLD}Testing Native Anthropic${NC}"
      if timeout 5 claude --version &>/dev/null; then
        success "Native Anthropic is working"
      else
        error "✗ Native Anthropic test failed"
      fi
      ;;
    zai|minimax|kimi|katcoder)
      # Load secrets
      load_secrets

      local key_name="${provider^^}_API_KEY"
      local api_key
      api_key="$(get_secret "$key_name")"
      if [ -z "$api_key" ]; then
        error "${provider^^} not configured"
        return 1
      fi
      echo -e "${BOLD}Testing ${provider^^}${NC}"

      export ANTHROPIC_AUTH_TOKEN="$api_key"
      case "$provider" in
        zai)
          export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
          ;;
        minimax)
          export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
          export API_TIMEOUT_MS="3000000"
          ;;
        kimi)
          export ANTHROPIC_BASE_URL="https://api.moonshot.ai/anthropic"
          export API_TIMEOUT_MS="3000000"
          ;;
        katcoder)
          local endpoint_id
          endpoint_id="$(get_config "katcoder_endpoint_id")"
          if [ -z "$endpoint_id" ]; then
            error "KAT-Coder endpoint ID missing. Run: clauver config katcoder"
            return 1
          fi
          export ANTHROPIC_BASE_URL="https://vanchin.streamlake.ai/api/gateway/v1/endpoints/$endpoint_id/claude-code-proxy"
          export API_TIMEOUT_MS="3000000"
          ;;
      esac
      timeout 10 claude "test" --dangerously-skip-permissions &>/dev/null &
      local test_pid=$!
      sleep 3
      if kill -0 $test_pid 2>/dev/null; then
        success "${provider^^} configuration is valid"
        kill $test_pid 2>/dev/null || true
      else
        error "✗ ${provider^^} test failed"
      fi
      ;;
    *)
      local api_key
      api_key="$(get_config "custom_${provider}_api_key")"
      if [ -z "$api_key" ]; then
        error "Provider '$provider' not found"
        return 1
      fi
      echo -e "${BOLD}Testing Custom Provider: $provider${NC}"
      local base_url
      base_url="$(get_config "custom_${provider}_base_url")"
      export ANTHROPIC_BASE_URL="$base_url"
      export ANTHROPIC_AUTH_TOKEN="$api_key"
      timeout 10 claude "test" --dangerously-skip-permissions &>/dev/null &
      local test_pid=$!
      sleep 3
      if kill -0 $test_pid 2>/dev/null; then
        success "$provider configuration is valid"
        kill $test_pid 2>/dev/null || true
      else
        error "✗ $provider test failed"
      fi
      ;;
  esac
}

cmd_status() {
  # Load secrets
  load_secrets

  echo -e "${BOLD}Provider Status${NC}"
  echo

  echo -e "${BOLD}Native Anthropic:${NC}"
  if command -v claude &>/dev/null; then
    success "Installed"
  else
    error "✗ Not installed"
  fi
  echo

  for provider in zai minimax kimi katcoder; do
    local key_name="${provider^^}_API_KEY"
    local api_key
    api_key="$(get_secret "$key_name")"
    echo -e "${BOLD}${provider}:${NC}"
    if [ -n "$api_key" ]; then
      success "Configured ($(mask_key "$api_key"))"
    else
      warn "○ Not configured"
    fi
    echo
  done

  if [ -f "$CONFIG" ]; then
    while IFS="=" read -r key value; do
      if [[ "$key" == custom_*_api_key ]]; then
        local provider_name="${key#custom_}"
        provider_name="${provider_name%_api_key}"
        if [ -n "$value" ]; then
          echo -e "${BOLD}${provider_name}:${NC}"
          success "Configured ($(mask_key "$value"))"
          echo "  Base URL: $(get_config "custom_${provider_name}_base_url")"
          echo
        fi
      fi
    done < "$CONFIG"
  fi
}

cmd_setup() {
  echo -e "${BOLD}${BLUE}"
  cat <<'EOF'
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗     ███████╗███████╗████████╗██╗   ██╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝    ███████╗█████╗     ██║   ██║   ██║██████╔╝
 ██║     ██║     ██╔══██║██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝
EOF
  echo -e "${NC}"

  echo -e "${BOLD}Welcome to Clauver Setup!${NC}"
  echo "This wizard will help you configure your first provider."
  echo

  echo -e "${YELLOW}What would you like to do?${NC}"
  echo "  1) Use Native Anthropic (free - uses your existing Claude subscription)"
  echo "  2) Configure Z.AI (GLM models - requires API key)"
  echo "  3) Configure MiniMax (MiniMax-M2 - requires API key)"
  echo "  4) Configure Kimi (Moonshot AI - requires API key)"
  echo "  5) Configure KAT-Coder (requires API key + Endpoint ID)"
  echo "  6) Add a custom provider"
  echo "  7) Skip (I'll configure later)"
  echo
  read -r -p "Choose [1-7]: " choice

  case "$choice" in
    1)
      echo
      success "Native Anthropic is ready to use!"
      echo
      echo -e "${GREEN}Next steps:${NC}"
      echo "  • Simply run: ${BOLD}clauver anthropic${NC}"
      echo "  • Or use claude directly: ${BOLD}claude \"hello\"${NC}"
      echo
      ;;
    2)
      echo
      echo "Let's configure Z.AI for you..."
      cmd_config "zai"
      ;;
    3)
      echo
      echo "Let's configure MiniMax for you..."
      cmd_config "minimax"
      ;;
    4)
      echo
      echo "Let's configure Kimi for you..."
      cmd_config "kimi"
      ;;
    5)
      echo
      echo "Let's configure KAT-Coder for you..."
      cmd_config "katcoder"
      ;;
    6)
      echo
      echo "Let's add your custom provider..."
      cmd_config "custom"
      ;;
    7)
      echo
      warn "Setup skipped."
      echo "Run ${BOLD}clauver setup${NC} anytime to configure a provider."
      echo
      ;;
    *)
      echo
      error "Invalid choice. Run 'clauver setup' again to retry."
      return 1
      ;;
  esac

  echo -e "${BOLD}Setup complete!${NC}"
  echo
  echo -e "${YELLOW}Quick reference:${NC}"
  echo "  clauver setup        # Run this wizard again"
  echo "  clauver list         # See all providers"
  echo "  clauver status       # Check configuration"
  echo "  clauver help         # View all commands"
  echo
  echo -e "${YELLOW}Start using Claude:${NC}"
  echo "  clauver anthropic    # Use Native Anthropic"
  echo "  clauver <provider>   # Use any configured provider"
  echo "  claude \"your prompt\" # Use current provider"
}

case "${1:-}" in
  help|-h|--help)
    show_help
    ;;
  version|-v|--version)
    echo "${VERSION}"
    ;;
  setup|-s)
    cmd_setup
    ;;
  list)
    cmd_list
    ;;
  config)
    shift
    cmd_config "$@"
    ;;
  test)
    shift
    cmd_test "$@"
    ;;
  status)
    cmd_status
    ;;
  anthropic)
    shift
    switch_to_anthropic "$@"
    ;;
  zai)
    shift
    switch_to_zai "$@"
    ;;
  minimax)
    shift
    switch_to_minimax "$@"
    ;;
  kimi)
    shift
    switch_to_kimi "$@"
    ;;
  katcoder)
    shift
    switch_to_katcoder "$@"
    ;;
  "")
    show_help
    ;;
  *)
    cmd="$1"
    api_key="$(get_config "custom_${cmd}_api_key")"
    if [ -n "$api_key" ]; then
      shift
      switch_to_custom "$cmd" "$@"
    else
      error "Unknown command: '$1'"
      echo "Use 'clauver help' for available commands."
      exit 1
    fi
    ;;
esac
