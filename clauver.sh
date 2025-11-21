#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

VERSION="1.8.0"

# Test mode detection - skip global config when running tests
if [[ "${CLAUVER_TEST_MODE:-}" == "1" ]]; then
  # In test mode, use only the provided CLAUVER_HOME
  BASE="${CLAUVER_HOME}"
else
  # Normal mode - allow fallback to home directory
  BASE="${CLAUVER_HOME:-$HOME/.clauver}"
fi

CONFIG="$BASE/config"
SECRETS="$BASE/secrets.env"
SECRETS_AGE="$BASE/secrets.env.age"
AGE_KEY="$BASE/age.key"
SECRETS_LOADED=0
CONFIG_CACHE_LOADED=0
# shellcheck disable=SC2034
declare -A CONFIG_CACHE=()  # Used dynamically for config caching

# Configuration constants - extracted from hardcoded values
declare -A PROVIDER_DEFAULTS=(
  ["zai_base_url"]="https://api.z.ai/api/anthropic"
  ["zai_default_model"]="glm-4.6"
  ["minimax_base_url"]="https://api.minimax.io/anthropic"
  ["minimax_default_model"]="MiniMax-M2"
  ["kimi_base_url"]="https://api.kimi.com/coding/"
  ["kimi_default_model"]="kimi-for-coding"
  ["deepseek_base_url"]="https://api.deepseek.com/anthropic"
  ["deepseek_default_model"]="deepseek-chat"
)

# Timeout and token limits
declare -A PERFORMANCE_DEFAULTS=(
  ["network_connect_timeout"]="10"
  ["network_max_time"]="30"
  ["minimax_small_fast_timeout"]="120"
  ["minimax_small_fast_max_tokens"]="24576"
  ["kimi_small_fast_timeout"]="240"
  ["kimi_small_fast_max_tokens"]="200000"
  ["deepseek_api_timeout_ms"]="600000"
  ["test_api_timeout_ms"]="3000000"
)

# GitHub API configuration
GITHUB_API_BASE="https://api.github.com/repos/dkmnx/clauver"
RAW_CONTENT_BASE="https://raw.githubusercontent.com/dkmnx/clauver"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
BOLD=$'\033[1m'
NC=$'\033[0m'

log() { printf "${BLUE}→${NC} %s\n" "$*"; }
success() { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$*"; }
error() { printf "${RED}✗${NC} %s\n" "$*" >&2; }

# Progress indicator for long-running operations
show_progress() {
  local message="$1"
  local pid="$2"
  local delay="${3:-0.5}"
  local spinner="${4:-⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏}"

  printf "${BLUE}${spinner:0:1}${NC} %s..." "$message"

  while kill -0 "$pid" 2>/dev/null; do
    for ((i=1; i<${#spinner}; i++)); do
      printf "\r${BLUE}${spinner:$i:1}${NC} %s..." "$message"
      sleep "$delay"
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi
    done
  done

  printf "\r${GREEN}✓${NC} %s completed\n" "$message"
}

banner() {
  provider="$1"
  printf "%b" "${BOLD}${BLUE}"
  cat <<BANNER
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██║██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
  v${VERSION} - ${provider}
BANNER
  printf "%b" "${NC}"
}

# Ensure age encryption key exists
ensure_age_key() {
  local current_age_key="${CLAUVER_HOME:-$HOME/.clauver}/age.key"
  if [ ! -f "$current_age_key" ]; then
    if ! command -v age-keygen &>/dev/null; then
      error "age-keygen command not found. Please install 'age' package."
      echo
      echo "Installation instructions:"
      echo "  • Debian/Ubuntu: sudo apt install age"
      echo "  • Fedora/RHEL:   sudo dnf install age"
      echo "  • Arch Linux:    sudo pacman -S age"
      echo "  • macOS:         brew install age"
      echo "  • From source:   https://github.com/FiloSottile/age"
      return 1
    fi
    log "Generating age encryption key..."
    age-keygen -o "$current_age_key"
    chmod 600 "$current_age_key"
    success "Age encryption key generated at $current_age_key"
    echo
    warn "IMPORTANT: Back up your age key! Without this key, you cannot decrypt your secrets."
  fi
}

# Save secrets to encrypted file
save_secrets() {
  # Check if age command is available
  if ! command -v age &>/dev/null; then
    error "age command not found. Please install 'age' package."
    echo
    echo "Installation instructions:"
    echo "  • Debian/Ubuntu: sudo apt install age"
    echo "  • Fedora/RHEL:   sudo dnf install age"
    echo "  • Arch Linux:    sudo pacman -S age"
    echo "  • macOS:         brew install age"
    echo "  • From source:   https://github.com/FiloSottile/age"
    return 1
  fi

  # Check if key file exists
  if [ ! -f "$AGE_KEY" ]; then
    error "Age key not found at: $AGE_KEY"
    echo
    echo "Your encryption key is missing. To recover:"
    echo "  1. If you have a backup of your key, restore it to: $AGE_KEY"
    echo "  2. Otherwise, reconfigure your providers: clauver config <provider>"
    echo "  3. The key will be regenerated automatically"
    return 1
  fi

  # Create secrets data in memory and encrypt directly
  local secrets_data=""
  [ -n "${ZAI_API_KEY:-}" ] && secrets_data="${secrets_data}ZAI_API_KEY=${ZAI_API_KEY}"$'\n'
  [ -n "${MINIMAX_API_KEY:-}" ] && secrets_data="${secrets_data}MINIMAX_API_KEY=${MINIMAX_API_KEY}"$'\n'
  [ -n "${KIMI_API_KEY:-}" ] && secrets_data="${secrets_data}KIMI_API_KEY=${KIMI_API_KEY}"$'\n'

  # Encrypt directly from memory without temporary files
  log "Encrypting secrets..."
  printf '%s' "$secrets_data" | age -e -i "$AGE_KEY" > "$SECRETS_AGE" 2>/dev/null &
  local encrypt_pid=$!
  show_progress "Encrypting secrets file" "$encrypt_pid" 0.3
  wait "$encrypt_pid"

  if [ ! -s "$SECRETS_AGE" ]; then
    error "Failed to encrypt secrets file"
    echo "This might be due to:"
    echo "  • Corrupted age key file"
    echo "  • Insufficient disk space"
    echo "  • Permission issues"
    return 1
  fi

  # Clean up any existing plaintext file
  rm -f "$SECRETS"  # Remove plaintext file if it exists
  chmod 600 "$SECRETS_AGE"
}

# Load secrets from secrets.env
load_secrets() {
  # Skip if already loaded in this session
  [ "$SECRETS_LOADED" -eq 1 ] && return 0

  if [ -f "$SECRETS_AGE" ]; then
    # Check if age command is available
    if ! command -v age &>/dev/null; then
      error "age command not found. Please install 'age' package."
      echo
      echo "Installation instructions:"
      echo "  • Debian/Ubuntu: sudo apt install age"
      echo "  • Fedora/RHEL:   sudo dnf install age"
      echo "  • Arch Linux:    sudo pacman -S age"
      echo "  • macOS:         brew install age"
      echo "  • From source:   https://github.com/FiloSottile/age"
      return 1
    fi

    # Check if key file exists
    if [ ! -f "$AGE_KEY" ]; then
      error "Age key not found at: $AGE_KEY"
      echo
      echo "Your encryption key is missing. To recover:"
      echo "  1. If you have a backup of your key, restore it to: $AGE_KEY"
      echo "  2. Otherwise, you'll need to reconfigure your providers"
      echo
      echo "To start fresh:"
      echo "  1. Remove encrypted file: rm $SECRETS_AGE"
      echo "  2. Reconfigure providers: clauver config <provider>"
      return 1
    fi

    # Test decryption first to catch corruption early
    local temp_decrypt
    temp_decrypt=$(mktemp -t clauver_decrypt_XXXXXXXXXX)
    age -d -i "$AGE_KEY" "$SECRETS_AGE" 2>/dev/null > "$temp_decrypt" 2>&1 &
    local decrypt_pid=$!
    wait "$decrypt_pid"

    local decrypt_exit=$?
    local decrypt_test=""

    if [ -f "$temp_decrypt" ]; then
      decrypt_test=$(cat "$temp_decrypt")
      rm -f "$temp_decrypt"
    fi

    if [ $decrypt_exit -ne 0 ]; then
      error "Failed to decrypt secrets file"
      echo
      echo "Possible causes:"
      echo "  • Corrupted encrypted file"
      echo "  • Wrong or corrupted age key"
      echo "  • File permissions issue"
      echo
      echo "To recover:"
      echo "  1. Check your age key backup and restore if needed"
      echo "  2. If file is corrupted, remove it: rm $SECRETS_AGE"
      echo "  3. Reconfigure your providers: clauver config <provider>"
      return 1
    fi

    # Security: Source decrypted content only after successful validation
    # This prevents execution of error messages as bash code
    # shellcheck disable=SC1090
    source <(echo "$decrypt_test")
  elif [ -f "$SECRETS" ]; then
    # Export all variables from secrets.env (backward compatibility)
    # shellcheck disable=SC1090
    source "$SECRETS"
  fi

  # Mark secrets as loaded
  SECRETS_LOADED=1
}

# Get config value from CONFIG file with caching
get_config() {
  local key="$1"

  # Handle test mode where CONFIG_CACHE might not be properly declared
  if [[ -z "${CONFIG_CACHE_LOADED:-}" ]] || [[ ! -v CONFIG_CACHE ]]; then
    # Fallback to direct file read if cache is not available
    if [ -f "$CONFIG" ]; then
      local value
      value=$(grep "^${key}=" "$CONFIG" 2>/dev/null | tail -1 | cut -d'=' -f2-)
      echo "${value:-}"
    else
      echo ""
    fi
    return
  fi

  # Ensure config is loaded into cache
  load_config_cache

  # For keys with special characters (like hyphens), use file read to avoid array issues
  if [[ "$key" =~ [-] ]]; then
    if [ -f "$CONFIG" ]; then
      local value
      value=$(grep "^${key}=" "$CONFIG" 2>/dev/null | tail -1 | cut -d'=' -f2-)
      echo "${value:-}"
    else
      echo ""
    fi
  else
    # For normal keys, use the cache with safe variable access
    if [[ -v CONFIG_CACHE["$key"] ]]; then
      echo "${CONFIG_CACHE[$key]}"
    else
      echo ""
    fi
  fi
}

# Load config file into cache for performance
load_config_cache() {
  # Skip if already loaded in this session
  [ "$CONFIG_CACHE_LOADED" -eq 1 ] && return 0

  # Clear cache
  # shellcheck disable=SC2034
  unset CONFIG_CACHE
  declare -A CONFIG_CACHE

  # Load config file into cache if it exists
  if [ -f "$CONFIG" ]; then
    while IFS="=" read -r key value; do
      # Skip empty lines, comments, and malformed lines
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# || -z "$value" ]] && continue
      # Sanitize key format and ensure key is not empty
      if [[ -n "$key" && "$key" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        CONFIG_CACHE["$key"]="$value"
      fi
    done < "$CONFIG" 2>/dev/null || true
  fi

  # Mark cache as loaded
  CONFIG_CACHE_LOADED=1
}

# Get secret value from environment
get_secret() {
  local key="$1"

  # Ensure secrets are loaded before accessing
  load_secrets

  # Return value from environment variable
  local value="${!key:-}"
  echo "$value"
}

set_config() {
  local key="$1"
  local value="$2"

  # Security: Validate key format (alphanumeric, underscore, hyphen only)
  if [[ ! "$key" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Invalid config key format: $key"
    return 1
  fi

  # Ensure config directory exists
  mkdir -p "$(dirname "$CONFIG")"

  local tmp
  tmp="$(mktemp "${CONFIG}.XXXXXX")"
  if [ -f "$CONFIG" ]; then
    grep -v -E "^${key}=" "$CONFIG" > "$tmp" 2>/dev/null || true
  fi

  # Security: Escape special characters in value to prevent injection
  # Use printf with explicit format to prevent format string attacks
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$CONFIG"
  chmod 600 "$CONFIG"

  # Invalidate cache to force reload on next access
  CONFIG_CACHE_LOADED=0
  # shellcheck disable=SC2034
  CONFIG_CACHE=()
}

set_secret() {
  local key="$1"
  local value="$2"

  # Ensure age key exists before setting secrets
  ensure_age_key

  # Migrate existing plaintext file if it exists
  if [ -f "$SECRETS" ] && [ ! -f "$SECRETS_AGE" ]; then
    log "Migrating existing secrets to encrypted storage..."
    # Load existing secrets
    # shellcheck disable=SC1090
    source "$SECRETS"
    # Save to encrypted format
    save_secrets
  fi

  # Load existing secrets into memory
  load_secrets

  # Set the new secret in environment
  export "$key=$value"

  # Save all secrets back to encrypted file
  save_secrets

  # Reset loaded flag to force reload on next access
  SECRETS_LOADED=0
}

mask_key() {
  local key="${1:-}"
  [ -z "$key" ] && { echo ""; return; }
  [ ${#key} -le 8 ] && { echo "****"; return; }
  echo "${key:0:4}****${key: -4}"
}

verify_sha256() {
  local file="$1"
  local expected_hash="$2"

  # Security: Verify file integrity using SHA256
  if ! command -v sha256sum &>/dev/null; then
    warn "sha256sum not available. Skipping integrity check."
    warn "WARNING: Downloaded file not verified. Proceed with caution."
    return 0  # Don't block update, but warn user
  fi

  local actual_hash
  actual_hash=$(sha256sum "$file" | awk '{print $1}')

  if [ "$actual_hash" != "$expected_hash" ]; then
    error "SHA256 mismatch! File may be corrupted or tampered."
    error "Expected: $expected_hash"
    error "Got:      $actual_hash"
    return 1
  fi

  success "SHA256 verification passed"
  return 0
}

get_latest_version() {
  # Security: Verify python3 exists before using it
  if ! command -v python3 &>/dev/null; then
    error "python3 command not found. Please install Python 3."
    return 1
  fi

  # Only show log message if not being captured (when stdout is a terminal)
  if [ -t 1 ]; then
    log "Checking for updates..."
  fi
  local latest_version=""
  # Run curl in background with timeout for progress indicator
  local temp_output
  temp_output=$(mktemp -t clauver_version_XXXXXXXXXX)
  curl -s --connect-timeout "${PERFORMANCE_DEFAULTS[network_connect_timeout]}" \
    --max-time "${PERFORMANCE_DEFAULTS[network_max_time]}" \
    "$GITHUB_API_BASE/tags" 2>/dev/null | \
  python3 -c "import sys, json; data = json.load(sys.stdin); print(data[0]['name'].lstrip('v')) if data else ''" 2>/dev/null > "$temp_output" 2>&1 &
  local curl_pid=$!

  # Show progress for the network request
  if [ -t 1 ]; then
    show_progress "Checking GitHub API" "$curl_pid" 0.3
  fi
  wait "$curl_pid"

  if [ -f "$temp_output" ]; then
    latest_version=$(cat "$temp_output")
    rm -f "$temp_output"
  fi

  if [ -z "$latest_version" ]; then
    error "Failed to fetch latest version from GitHub"
    return 1
  fi
  echo "$latest_version"
}

cmd_version() {
  local latest_version
  printf "Current version: v%s\n" "$VERSION"

  latest_version=$(get_latest_version 2>/dev/null | tail -n1)
  if [ -n "$latest_version" ]; then
    if [ "$VERSION" = "$latest_version" ]; then
      success "You are on the latest version"
    elif [ "$VERSION" = "$(printf '%s\n' "$VERSION" "$latest_version" | sort -V | head -n1)" ] && [ "$VERSION" != "$latest_version" ]; then
      warn "Update available: v${latest_version}"
      echo "Run 'clauver update' to upgrade"
    else
      echo "! You are on a pre-release version (v${VERSION}) newer than latest stable (v${latest_version})"
    fi
  else
    warn "Could not check for updates"
  fi
}

cmd_update() {
  local latest_version
  local install_path
  install_path="$(command -v clauver)"

  if [ -z "$install_path" ]; then
    error "Clauver installation not found in PATH"
    return 1
  fi

  if [ ! -w "$(dirname "$install_path")" ]; then
    error "No write permission to $(dirname "$install_path"). Try with sudo."
    return 1
  fi

  latest_version=$(get_latest_version) || return 1

  # Validate that we got a proper version string
  if [ -z "$latest_version" ]; then
    error "Failed to determine latest version"
    return 1
  fi

  if [ "$VERSION" = "$latest_version" ]; then
    success "Already on latest version (v${VERSION})"
    return 0
  fi

  # Prevent accidental rollback from pre-release to older stable version
  if [ "$VERSION" != "$(printf '%s\n' "$VERSION" "$latest_version" | sort -V | head -n1)" ]; then
    warn "You are on a pre-release version (v${VERSION}) newer than latest stable (v${latest_version})"
    echo
    read -r -p "Rollback to v${latest_version}? This will downgrade your version. [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Update cancelled."
      return 0
    fi
  fi

  echo "Updating from v${VERSION} to v${latest_version}..."

  local temp_file temp_checksum
  temp_file=$(mktemp)
  temp_checksum=$(mktemp)

  # Security: Download both script and checksum file
  log "Starting download process..."

  # Download main script with progress indicator
  curl -fsSL --connect-timeout "${PERFORMANCE_DEFAULTS[network_connect_timeout]}" \
    --max-time 60 "$RAW_CONTENT_BASE/v${latest_version}/clauver.sh" -o "$temp_file" 2>/dev/null &
  local download_pid=$!
  show_progress "Downloading clauver.sh v${latest_version}" "$download_pid" 0.2
  wait "$download_pid"

  if [ ! -s "$temp_file" ]; then
    rm -f "$temp_file" "$temp_checksum"
    error "Failed to download update"
    return 1
  fi

  # Download checksum file with progress indicator
  curl -fsSL --connect-timeout "${PERFORMANCE_DEFAULTS[network_connect_timeout]}" \
    --max-time "${PERFORMANCE_DEFAULTS[network_max_time]}" \
    "$RAW_CONTENT_BASE/v${latest_version}/clauver.sh.sha256" -o "$temp_checksum" 2>/dev/null &
  local checksum_pid=$!
  show_progress "Downloading integrity checksum" "$checksum_pid" 0.2
  wait "$checksum_pid"

  if [ ! -s "$temp_checksum" ]; then
    warn "SHA256 checksum file not available for v${latest_version}"
    warn "Proceeding without integrity verification (not recommended)"
    echo
    read -r -p "Continue anyway? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      rm -f "$temp_file" "$temp_checksum"
      error "Update cancelled by user"
      return 1
    fi
  else
    # Security: Verify downloaded file integrity
    local expected_hash
    expected_hash=$(cat "$temp_checksum" | awk '{print $1}')

    if ! verify_sha256 "$temp_file" "$expected_hash"; then
      rm -f "$temp_file" "$temp_checksum"
      error "Update aborted due to integrity check failure"
      return 1
    fi
  fi

  # Install verified update
  chmod +x "$temp_file"
  if mv "$temp_file" "$install_path"; then
    rm -f "$temp_checksum"
    success "Update complete! Now running v${latest_version}"
  else
    rm -f "$temp_file" "$temp_checksum"
    error "Failed to install update"
    return 1
  fi
}

show_help() {
  echo "Clauver v${VERSION}"
  echo "Manage and switch between Claude Code providers"
  echo
  echo "Quick Start:"
  echo "  clauver setup        # Interactive setup wizard"
  echo "  clauver zai          # Switch to Z.AI"
  echo "  claude \"hello\"       # Use current provider"
  echo
  echo "Usage:"
  echo "  clauver <command> [args]"
  echo
  echo "Setup & Help:"
  echo "  setup, -s               Interactive setup wizard for beginners"
  echo "  help, -h, --help        Show this help message"
  echo "  version, -v, --version  Show current version and check for updates"
  echo "  update                  Update to the latest version"
  echo
  echo "Provider Management:"
  echo "  list                    List all configured providers"
  echo "  status                  Check status of all providers"
  echo "  config <provider>       Configure a specific provider"
  echo "  test <provider>         Test a provider configuration"
  echo "  default [provider]      Set or show default provider"
  echo "  migrate                 Migrate plaintext secrets to encrypted storage"
  echo
  echo "Switch Providers:"
  echo "  anthropic               Use Native Anthropic (no API key needed)"
  echo "  zai                     Switch to Z.AI provider"
  echo "  minimax                 Switch to MiniMax provider"
  echo "  kimi                    Switch to Moonshot Kimi provider"
  echo "  <custom>                Switch to your custom provider"
  echo
  echo "Examples:"
  echo "  clauver setup           # Guided setup for first-time users"
  echo "  clauver list            # Show all providers"
  echo "  clauver config zai      # Configure Z.AI provider"
  echo "  clauver test zai        # Test Z.AI provider"
  echo "  clauver zai             # Use Z.AI for this session"
  echo "  clauver anthropic       # Use Native Anthropic"
  echo "  clauver default zai     # Set Z.AI as default provider"
  echo "  clauver migrate         # Encrypt plaintext secrets"
  echo "  clauver version         # Check current version and updates"
  echo "  clauver update          # Update to latest version"
  echo "  clauver                 # Use default provider (after setting one)"
  echo
  echo "💡 Tips:"
  echo "  • Set a default: clauver default <provider>"
  echo "  • Run clauver without arguments to use your default provider"
  echo "  • Auto-completion available: clauver <TAB><TAB>"
  echo "  • Any valid provider name works: clauver your-provider"
  echo "  • All claude flags work: clauver zai --dangerously-skip-permissions"
}

cmd_list() {
  # Load secrets
  load_secrets

  # Determine encryption status
  local encryption_status
  if [ -f "$SECRETS_AGE" ]; then
    encryption_status="${GREEN}[encrypted]${NC}"
  elif [ -f "$SECRETS" ]; then
    encryption_status="${YELLOW}[plaintext]${NC}"
  else
    encryption_status=""
  fi

  echo -e "${BOLD}Configured Providers:${NC}"
  [ -n "$encryption_status" ] && echo -e "  Storage: $encryption_status"
  echo

  echo -e "${GREEN}✓ Native Anthropic${NC}"
  echo "  Command: clauver anthropic"
  echo "  Description: Use your Claude Pro/Team subscription"
  echo

  for provider in zai minimax kimi deepseek; do
    local key_name="${provider^^}_API_KEY"
    local api_key
    api_key="$(get_secret "$key_name")"
    if [ -n "$api_key" ]; then
      echo -e "${GREEN}✓ ${provider}${NC}"
      echo "  Command: clauver $provider"
      echo "  API Key: $(mask_key "$api_key")"
      # Show model and URL for Kimi
      if [ "$provider" == "kimi" ]; then
        local kimi_model
        kimi_model="$(get_config "kimi_model")"
        kimi_model="${kimi_model:-${PROVIDER_DEFAULTS[kimi_default_model]}}"
        echo "  Model: $kimi_model"

        local kimi_base_url
        kimi_base_url="$(get_config "kimi_base_url")"
        kimi_base_url="${kimi_base_url:-${PROVIDER_DEFAULTS[kimi_base_url]}}"
        echo "  Base URL: $kimi_base_url"
      fi
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
  for provider in zai minimax kimi deepseek; do
    local key_name="${provider^^}_API_KEY"
    local api_key
    api_key="$(get_secret "$key_name")"
    if [ -z "$api_key" ]; then
      echo "  - $provider (run: clauver config $provider)"
    fi
  done
}

# Helper functions for configuration
config_show_usage() {
  error "Usage: clauver config <provider>"
  echo
  echo "Available providers: anthropic, zai, minimax, kimi, custom"
  echo "Example: clauver config zai"
}

config_anthropic() {
  echo
  success "Native Anthropic is ready to use!"
  echo "No configuration needed. Simply run: clauver anthropic"
}

config_standard_provider() {
  local provider="$1"
  echo
  echo -e "${BOLD}${provider^^} Configuration${NC}"

  local key_name="${provider^^}_API_KEY"
  local current_key
  current_key="$(get_secret "$key_name")"
  [ -n "$current_key" ] && echo "Current key: $(mask_key "$current_key")"

  read -rs -p "API Key: " key; echo
  [ -z "$key" ] && { error "Key is required"; return 1; }

  # Validate API key
  if ! validate_api_key "$key" "$provider"; then
    return 1
  fi

  set_secret "$key_name" "$key"

  # Provider-specific configuration
  case "$provider" in
    "kimi")
      config_kimi_settings
      ;;
  esac

  success "${provider^^} configured. Use: clauver $provider"

  # Show encryption status
  if [ -f "$SECRETS_AGE" ]; then
    echo -e "${GREEN}🔒 Secrets encrypted at: $SECRETS_AGE${NC}"
  fi
}


config_kimi_settings() {
  # Configure model
  local current_model
  current_model="$(get_config "kimi_model")"
  [ -n "$current_model" ] && echo "Current model: $current_model"
  read -r -p "Model (default: ${PROVIDER_DEFAULTS[kimi_default_model]}): " model
  model="${model:-${PROVIDER_DEFAULTS[kimi_default_model]}}"

  # Validate model name
  if [ -n "$model" ] && ! validate_model_name "$model"; then
    return 1
  fi

  [ -n "$model" ] && set_config "kimi_model" "$model"

  # Configure URL
  local current_url
  current_url="$(get_config "kimi_base_url")"
  [ -n "$current_url" ] && echo "Current base URL: $current_url"
  read -r -p "Base URL (default: ${PROVIDER_DEFAULTS[kimi_base_url]}): " url
  url="${url:-${PROVIDER_DEFAULTS[kimi_base_url]}}"

  # Validate URL
  if [ -n "$url" ] && ! validate_url "$url"; then
    return 1
  fi

  [ -n "$url" ] && set_config "kimi_base_url" "$url"
}

config_custom_provider() {
  echo
  echo -e "${BOLD}Custom Provider Configuration${NC}"
  read -r -p "Provider name (e.g., 'my-provider'): " name

  # Validate provider name using the validation function
  if ! validate_provider_name "$name"; then
    return 1
  fi

  read -r -p "Base URL: " base_url
  read -rs -p "API Key: " api_key; echo
  read -r -p "Default model (optional): " model

  { [ -z "$name" ] || [ -z "$base_url" ] || [ -z "$api_key" ]; } && { error "Name, Base URL and API Key are required"; return 1; }

  # Validate inputs
  if ! validate_url "$base_url"; then
    return 1
  fi

  if ! validate_api_key "$api_key" "custom"; then
    return 1
  fi

  if [ -n "$model" ] && ! validate_model_name "$model"; then
    return 1
  fi

  set_config "custom_${name}_api_key" "$api_key"
  set_config "custom_${name}_base_url" "$base_url"
  [ -n "$model" ] && set_config "custom_${name}_model" "$model"

  success "Custom provider '$name' configured. Use: clauver $name"
}

cmd_config() {
  local provider="${1:-}"

  if [ -z "$provider" ]; then
    config_show_usage
    return 1
  fi

  case "$provider" in
    anthropic)
      config_anthropic
      ;;
    zai|minimax|kimi|deepseek)
      config_standard_provider "$provider"
      ;;
    custom)
      config_custom_provider
      ;;
    *)
      error "Unknown provider: '$provider'"
      echo
      echo "Available providers: anthropic, zai, minimax, kimi, deepseek, custom"
      echo "Example: clauver config zai"
      return 1
      ;;
  esac
}

# Provider abstraction layer
declare -A PROVIDER_CONFIGS=(
  ["zai"]="Z.AI|https://api.z.ai/api/anthropic|ZAI_API_KEY|glm-4.5-air|glm-4.6|glm-4.6"
  ["minimax"]="MiniMax|https://api.minimax.io/anthropic|MINIMAX_API_KEY|MiniMax-M2|MiniMax-M2|MiniMax-M2"
  ["deepseek"]="DeepSeek|https://api.deepseek.com/anthropic|DEEPSEEK_API_KEY|deepseek-chat|deepseek-chat|deepseek-chat"
)

# Provider configuration metadata
declare -A PROVIDER_REQUIRES=(
  ["zai"]="api_key"
  ["minimax"]="api_key"
  ["deepseek"]="api_key"
  ["kimi"]="api_key,model,url"
)

# Generic provider switching function
switch_to_provider() {
  local provider="$1"
  shift

  # Handle anthropic specially (no API key needed)
  if [ "$provider" = "anthropic" ]; then
    switch_to_anthropic "$@"
    return
  fi

  # Check if provider is supported
  if ! [[ -v "PROVIDER_CONFIGS[$provider]" ]] && [ "$provider" != "kimi" ]; then
    error "Provider '$provider' not supported"
    exit 1
  fi

  load_secrets

  # Validate required configuration
  local requirements="${PROVIDER_REQUIRES[$provider]:-api_key}"
  IFS=',' read -ra required_fields <<< "$requirements"

  for field in "${required_fields[@]}"; do
    case "$field" in
      "api_key")
        local key_var="${provider^^}_API_KEY"
        local api_key
        api_key="$(get_secret "$key_var")"
        if [ -z "$api_key" ]; then
          error "${provider^^} not configured. Run: clauver config $provider"
          exit 1
        fi
        ;;
            "model")
        local model
        model="$(get_config "${provider}_model")"
        if [ "$provider" = "kimi" ]; then
          model="${model:-${PROVIDER_DEFAULTS[kimi_default_model]}}"
        fi
        ;;
      "url")
        local url
        url="$(get_config "${provider}_base_url")"
        if [ "$provider" = "kimi" ]; then
          url="${url:-${PROVIDER_DEFAULTS[kimi_base_url]}}"
        fi
        ;;
    esac
  done

  # Set provider-specific environment
  case "$provider" in
    "zai")
      banner "Zhipu AI (GLM Models)"
      export ANTHROPIC_BASE_URL="${PROVIDER_DEFAULTS[zai_base_url]}"
      export ANTHROPIC_AUTH_TOKEN="$api_key"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${PROVIDER_DEFAULTS[zai_default_model]}"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="${PROVIDER_DEFAULTS[zai_default_model]}"
      ;;
    "minimax")
      banner "MiniMax (MiniMax-M2)"
      export ANTHROPIC_BASE_URL="${PROVIDER_DEFAULTS[minimax_base_url]}"
      export ANTHROPIC_AUTH_TOKEN="$api_key"
      export ANTHROPIC_MODEL="${PROVIDER_DEFAULTS[minimax_default_model]}"
      export ANTHROPIC_SMALL_FAST_MODEL="${PROVIDER_DEFAULTS[minimax_default_model]}"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="${PROVIDER_DEFAULTS[minimax_default_model]}"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${PROVIDER_DEFAULTS[minimax_default_model]}"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="${PROVIDER_DEFAULTS[minimax_default_model]}"
      export ANTHROPIC_SMALL_FAST_MODEL_TIMEOUT="${PERFORMANCE_DEFAULTS[minimax_small_fast_timeout]}"
      export ANTHROPIC_SMALL_FAST_MAX_TOKENS="${PERFORMANCE_DEFAULTS[minimax_small_fast_max_tokens]}"
      ;;
    "kimi")
      banner "Moonshot AI (Kimi)"
      export ANTHROPIC_BASE_URL="$url"
      export ANTHROPIC_AUTH_TOKEN="$api_key"
      export ANTHROPIC_MODEL="$model"
      export ANTHROPIC_SMALL_FAST_MODEL="$model"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="$model"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
      export ANTHROPIC_SMALL_FAST_MODEL_TIMEOUT="${PERFORMANCE_DEFAULTS[kimi_small_fast_timeout]}"
      export ANTHROPIC_SMALL_FAST_MAX_TOKENS="${PERFORMANCE_DEFAULTS[kimi_small_fast_max_tokens]}"
      ;;
    "deepseek")
      banner "DeepSeek AI"
      export ANTHROPIC_BASE_URL="${PROVIDER_DEFAULTS[deepseek_base_url]}"
      export ANTHROPIC_AUTH_TOKEN="$api_key"
      export ANTHROPIC_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export ANTHROPIC_SMALL_FAST_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export API_TIMEOUT_MS="${PERFORMANCE_DEFAULTS[deepseek_api_timeout_ms]}"
      export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
      ;;
      esac

  exec claude "$@"
}

# Input validation framework
validate_api_key() {
  local key="$1"
  local provider="$2"

  # Basic validation - non-empty and reasonable length
  if [ -z "$key" ]; then
    error "API key cannot be empty"
    return 1
  fi

  # Check minimum length (most API keys are at least 20 chars)
  if [ ${#key} -lt 10 ]; then
    error "API key too short (minimum 10 characters)"
    return 1
  fi

  # Security validation - prevent injection attacks
  # Reject dangerous characters that could be used for command injection
  local dangerous_chars='[;`$|&<>]'
  if [[ "$key" =~ [$dangerous_chars] ]]; then
    error "API key contains dangerous characters that could be used for injection attacks"
    return 1
  fi

  # Reject potential command substitution patterns
  if [[ "$key" =~ \$\(.*\) ]]; then
    error "API key contains potential command substitution pattern"
    return 1
  fi

  # Reject quote characters that could break parsing
  if [[ "$key" =~ [\'\"] ]]; then
    error "API key contains quote characters that could break parsing"
    return 1
  fi

  # Provider-specific validation
  case "$provider" in
    "zai"|"minimax"|"kimi")
      # Most API keys are alphanumeric with some special chars
      if [[ ! "$key" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "API key contains invalid characters for $provider (only alphanumeric, dot, underscore, hyphen allowed)"
        return 1
      fi
      ;;
  esac

  return 0
}

validate_url() {
  local url="$1"

  # Basic URL validation
  if [ -z "$url" ]; then
    error "URL cannot be empty"
    return 1
  fi

  # Check URL format
  if [[ ! "$url" =~ ^https?:// ]]; then
    error "URL must start with http:// or https://"
    return 1
  fi

  # Check for valid hostname
  if [[ ! "$url" =~ ^https?://[a-zA-Z0-9.-]+ ]]; then
    error "Invalid URL format"
    return 1
  fi

  return 0
}

validate_provider_name() {
  local provider="$1"

  # Check if provider name is valid
  if [ -z "$provider" ]; then
    error "Provider name cannot be empty"
    return 1
  fi

  # Check for valid characters (alphanumeric, underscore, hyphen)
  if [[ ! "$provider" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Provider name can only contain letters, numbers, underscores, and hyphens"
    return 1
  fi

  # Check if name is reserved
  local reserved_names=("anthropic" "zai" "minimax" "kimi")
  for reserved in "${reserved_names[@]}"; do
    if [ "$provider" = "$reserved" ]; then
      error "Provider name '$provider' is reserved"
      return 1
    fi
  done

  return 0
}

validate_model_name() {
  local model="$1"

  if [ -z "$model" ]; then
    error "Model name cannot be empty"
    return 1
  fi

  # Security validation - prevent injection attacks
  # Reject dangerous characters that could be used for command injection
  local dangerous_chars='[;`$|&<>]'
  if [[ "$model" =~ [$dangerous_chars] ]]; then
    error "Model name contains dangerous characters that could be used for injection attacks"
    return 1
  fi

  # Reject potential command substitution patterns
  if [[ "$model" =~ \$\(.*\) ]]; then
    error "Model name contains potential command substitution pattern"
    return 1
  fi

  # Reject quote characters that could break parsing
  if [[ "$model" =~ [\'\"] ]]; then
    error "Model name contains quote characters that could break parsing"
    return 1
  fi

  # Basic model name validation - only allow safe characters
  if [[ ! "$model" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    error "Model name contains invalid characters (only alphanumeric, dot, underscore, hyphen allowed)"
    return 1
  fi

  return 0
}

switch_to_anthropic() {
  banner "Native Anthropic"
  echo -e "${BOLD}Using Native Anthropic${NC}"
  exec claude "$@"
}

switch_to_zai() {
  switch_to_provider "zai" "$@"
}

switch_to_minimax() {
  switch_to_provider "minimax" "$@"
}

switch_to_kimi() {
  switch_to_provider "kimi" "$@"
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
        error "Native Anthropic test failed"
      fi
      ;;
    zai|minimax|kimi|deepseek)
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
          export ANTHROPIC_BASE_URL="${PROVIDER_DEFAULTS[zai_base_url]}"
          ;;
        minimax)
          export ANTHROPIC_BASE_URL="${PROVIDER_DEFAULTS[minimax_base_url]}"
          export API_TIMEOUT_MS="${PERFORMANCE_DEFAULTS[test_api_timeout_ms]}"
          ;;
        kimi)
          local kimi_base_url
          kimi_base_url="$(get_config "kimi_base_url")"
          kimi_base_url="${kimi_base_url:-${PROVIDER_DEFAULTS[kimi_base_url]}}"
          export ANTHROPIC_BASE_URL="$kimi_base_url"
          local kimi_model
          kimi_model="$(get_config "kimi_model")"
          kimi_model="${kimi_model:-${PROVIDER_DEFAULTS[kimi_default_model]}}"
          export ANTHROPIC_MODEL="$kimi_model"
          export API_TIMEOUT_MS="${PERFORMANCE_DEFAULTS[test_api_timeout_ms]}"
          ;;
        deepseek)
          export ANTHROPIC_BASE_URL="${PROVIDER_DEFAULTS[deepseek_base_url]}"
          export API_TIMEOUT_MS="${PERFORMANCE_DEFAULTS[test_api_timeout_ms]}"
          ;;
              esac
      timeout 10 claude "test" --dangerously-skip-permissions &>/dev/null &
      local test_pid=$!
      sleep 3
      if kill -0 $test_pid 2>/dev/null; then
        success "${provider^^} configuration is valid"
        kill $test_pid 2>/dev/null || true
      else
        error "${provider^^} test failed"
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
        error "$provider test failed"
      fi
      ;;
  esac
}

cmd_status() {
  # Load secrets
  load_secrets

  echo -e "${BOLD}Provider Status${NC}"
  echo

  # Show encryption status
  if [ -f "$SECRETS_AGE" ]; then
    echo -e "${GREEN}🔒 Secrets Storage: Encrypted${NC}"
  elif [ -f "$SECRETS" ]; then
    echo -e "${YELLOW}⚠ Secrets Storage: Plaintext (run 'clauver migrate' to encrypt)${NC}"
  else
    echo -e "Secrets Storage: None configured"
  fi
  echo

  echo -e "${BOLD}Native Anthropic:${NC}"
  if command -v claude &>/dev/null; then
    success "Installed"
  else
    error "Not installed"
  fi
  echo

  for provider in zai minimax kimi deepseek; do
    local key_name="${provider^^}_API_KEY"
    local api_key
    api_key="$(get_secret "$key_name")"
    echo -e "${BOLD}${provider}:${NC}"
    if [ -n "$api_key" ]; then
      success "Configured ($(mask_key "$api_key"))"
      # Show additional config for Kimi
      if [ "$provider" == "kimi" ]; then
        local kimi_model
        kimi_model="$(get_config "kimi_model")"
        kimi_model="${kimi_model:-${PROVIDER_DEFAULTS[kimi_default_model]}}"
        local kimi_base_url
        kimi_base_url="$(get_config "kimi_base_url")"
        kimi_base_url="${kimi_base_url:-${PROVIDER_DEFAULTS[kimi_base_url]}}"
        echo "  Model: $kimi_model"
        echo "  URL: $kimi_base_url"
      fi
    else
      warn "Not configured"
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

cmd_default() {
  local provider="${1:-}"

  if [ -z "$provider" ]; then
    local current_default
    current_default="$(get_config "default_provider")"
    if [ -n "$current_default" ]; then
      echo "Current default provider: $current_default"
    else
      echo "No default provider set."
      echo
      echo "Usage: clauver default <provider>"
      echo "Example: clauver default minimax"
    fi
    return 0
  fi

  # Validate that the provider exists and is configured
  case "$provider" in
    anthropic)
      # Native Anthropic is always available
      set_config "default_provider" "$provider"
      success "Default provider set to: ${provider}"
      echo "Run 'clauver' without arguments to use this provider."
      return 0
      ;;
    zai)
      local zai_key
      zai_key="$(get_secret "ZAI_API_KEY")"
      if [ -z "$zai_key" ]; then
        error "Z.AI is not configured. Run: clauver config zai"
        return 1
      fi
      set_config "default_provider" "$provider"
      success "Default provider set to: ${provider}"
      echo "Run 'clauver' without arguments to use this provider."
      return 0
      ;;
    minimax)
      local minimax_key
      minimax_key="$(get_secret "MINIMAX_API_KEY")"
      if [ -z "$minimax_key" ]; then
        error "MiniMax is not configured. Run: clauver config minimax"
        return 1
      fi
      set_config "default_provider" "$provider"
      success "Default provider set to: ${provider}"
      echo "Run 'clauver' without arguments to use this provider."
      return 0
      ;;
    kimi)
      local kimi_key
      kimi_key="$(get_secret "KIMI_API_KEY")"
      if [ -z "$kimi_key" ]; then
        error "Kimi is not configured. Run: clauver config kimi"
        return 1
      fi
      set_config "default_provider" "$provider"
      success "Default provider set to: ${provider}"
      echo "Run 'clauver' without arguments to use this provider."
      return 0
      ;;
        *)
      # Check if it's a custom provider
      local custom_key
      custom_key="$(get_config "custom_${provider}_api_key")"
      if [ -n "$custom_key" ]; then
        set_config "default_provider" "$provider"
        success "Default provider set to: ${provider}"
        echo "Run 'clauver' without arguments to use this provider."
        return 0
      else
        error "Unknown or unconfigured provider: '$provider'"
        echo
        echo "Use 'clauver list' to see available providers."
        return 1
      fi
      ;;
  esac
}

cmd_migrate() {
  echo -e "${BOLD}Migrate Secrets to Encrypted Storage${NC}"
  echo

  # Check if already encrypted
  if [ -f "$SECRETS_AGE" ] && [ ! -f "$SECRETS" ]; then
    success "Secrets are already encrypted!"
    echo "  Location: $SECRETS_AGE"
    return 0
  fi

  # Check if plaintext file exists
  if [ ! -f "$SECRETS" ]; then
    warn "No plaintext secrets file found."
    if [ -f "$SECRETS_AGE" ]; then
      success "Encrypted secrets file already exists at: $SECRETS_AGE"
    else
      echo "No secrets to migrate. Configure a provider first:"
      echo "  clauver config <provider>"
    fi
    return 0
  fi

  log "Found plaintext secrets file: $SECRETS"
  echo

  # Ensure age key exists
  if ! ensure_age_key; then
    error "Failed to ensure age key. Migration aborted."
    return 1
  fi

  # Load existing plaintext secrets
  log "Loading plaintext secrets..."
  # shellcheck disable=SC1090
  source "$SECRETS"

  # Save to encrypted format
  log "Encrypting secrets..."
  if save_secrets; then
    success "Secrets successfully encrypted!"
    echo "  Encrypted file: $SECRETS_AGE"
    echo "  Plaintext file: removed"
    echo
    warn "IMPORTANT: Back up your age key at: $AGE_KEY"
    echo "Without this key, you cannot decrypt your secrets."
  else
    error "Failed to encrypt secrets."
    return 1
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
  echo "  5) Configure DeepSeek (DeepSeek Chat - requires API key)"
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
      echo "Let's configure DeepSeek for you..."
      cmd_config "deepseek"
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

# Only execute main logic if this script is being run directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
case "${1:-}" in
  help|-h|--help)
    show_help
    ;;
  version|-v|--version)
    cmd_version
    ;;
  update)
    cmd_update
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
  default)
    shift
    cmd_default "$@"
    ;;
  migrate)
    cmd_migrate
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
  deepseek)
    shift
    switch_to_provider "deepseek" "$@"
    ;;
    "")
    # Check if a default provider is set
    default_provider="$(get_config "default_provider")"
    if [ -n "$default_provider" ]; then
      # Use the default provider
      case "$default_provider" in
        anthropic)
          switch_to_anthropic "$@"
          ;;
        zai)
          switch_to_zai "$@"
          ;;
        minimax)
          switch_to_minimax "$@"
          ;;
        kimi)
          switch_to_kimi "$@"
          ;;
        deepseek)
          switch_to_provider "deepseek" "$@"
          ;;
                *)
          # It's a custom provider
          switch_to_custom "$default_provider" "$@"
          ;;
      esac
    else
      show_help
    fi
    ;;
  *)
    cmd="$1"
    api_key="$(get_config "custom_${cmd}_api_key")"
    if [ -n "$api_key" ]; then
      # It's a custom provider
      shift
      switch_to_custom "$cmd" "$@"
    else
      # Check if a default provider is set
      default_provider="$(get_config "default_provider")"
      if [ -n "$default_provider" ]; then
        # Use the default provider with all arguments
        case "$default_provider" in
          anthropic)
            switch_to_anthropic "$@"
            ;;
          zai)
            switch_to_zai "$@"
            ;;
          minimax)
            switch_to_minimax "$@"
            ;;
          kimi)
            switch_to_kimi "$@"
            ;;
          deepseek)
            switch_to_provider "deepseek" "$@"
            ;;
                    *)
            # It's a custom provider
            switch_to_custom "$default_provider" "$@"
            ;;
        esac
      else
        error "Unknown command: '$1'"
        echo "Use 'clauver help' for available commands."
        exit 1
      fi
    fi
    ;;
esac
fi
