#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

VERSION="1.12.3"

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

declare -A PROVIDER_METADATA=(
  ["zai"]="Z.AI|zai_base_url|ZAI_API_KEY|zai_model|zai_default_model|glm-4.5-air"
  ["minimax"]="MiniMax|minimax_base_url|MINIMAX_API_KEY|minimax_model|minimax_default_model|MiniMax-M2"
  ["kimi"]="Moonshot AI|kimi_base_url|KIMI_API_KEY|kimi_model|kimi_default_model|kimi-for-coding"
  ["deepseek"]="DeepSeek AI|deepseek_base_url|DEEPSEEK_API_KEY|deepseek_model|deepseek_default_model|deepseek-chat"
)

declare -A PROVIDER_ENV_VARS=(
  ["zai"]="ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air"
  ["minimax"]="ANTHROPIC_SMALL_FAST_MODEL_TIMEOUT=minimax_small_fast_timeout,ANTHROPIC_SMALL_FAST_MAX_TOKENS=minimax_small_fast_max_tokens"
  ["kimi"]="ANTHROPIC_SMALL_FAST_MODEL_TIMEOUT=kimi_small_fast_timeout,ANTHROPIC_SMALL_FAST_MAX_TOKENS=kimi_small_fast_max_tokens"
  ["deepseek"]="API_TIMEOUT_MS=deepseek_api_timeout_ms,CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
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

# Validation constants
MIN_API_KEY_LENGTH=10
ANTHROPIC_TEST_TIMEOUT=5
PROVIDER_TEST_TIMEOUT=10
DOWNLOAD_TIMEOUT=60

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

# Sanitize paths in error messages to prevent information disclosure
sanitize_path() {
  local path="$1"
  # Show only filename and directory, hide full path for security
  if [[ -n "$HOME" && "$path" == "$HOME"* ]]; then
    echo "~${path#"$HOME"}"
  elif [[ "$path" == */* ]]; then
    echo ".../$(basename "$path")"
  else
    echo "$path"
  fi
}
error() { printf "${RED}✗${NC} %s\n" "$*" >&2; }

# =============================================================================
# UI MODULE: User interface and display functions with consistent prefixes
# =============================================================================

ui_log() { printf "${BLUE}→${NC} %s\n" "$*"; }
ui_success() { printf "${GREEN}✓${NC} %s\n" "$*"; }
ui_warn() { printf "${YELLOW}!${NC} %s\n" "$*"; }
ui_error() { printf "${RED}✗${NC} %s\n" "$*" >&2; }
ui_banner() {
  provider="$1"
  printf "%b" "${BOLD}${BLUE}"
  cat <<BANNER
  ██████╗██╗      █████╗ ██╗   ██╗██╗   ██╗███████╗██████╗
 ██╔════╝██║     ██╔══██╗██║   ██║██║   ██║██╔════╝██╔══██╗
 ██║     ██║     ███████║██║   ██║██║   ██║█████╗  ██████╔╝
 ██║     ██║     ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ╚██████╗███████╗██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║
  ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝
  v${VERSION} - ${provider}
BANNER
  printf "%b" "${NC}"
}

# =============================================================================
# VALIDATION MODULE: Input validation functions with consistent prefixes
# =============================================================================

validation_api_key() {
  local key="$1"
  local provider="$2"

  # Basic validation - non-empty and reasonable length
  if [ -z "$key" ]; then
    ui_error "API key cannot be empty"
    return 1
  fi

  # Check minimum length (most API keys are at least 20 chars)
  if [ ${#key} -lt "$MIN_API_KEY_LENGTH" ]; then
    ui_error "API key too short (minimum $MIN_API_KEY_LENGTH characters)"
    return 1
  fi

  # Enhanced security validation - prevent ALL shell metacharacters
  # Allow only alphanumeric, dot, underscore, hyphen, and common API key chars
  if [[ ! "$key" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    ui_error "API key contains invalid characters"
    return 1
  fi

  # Provider-specific validation
  case "$provider" in
    "zai")
      if [[ ! "$key" =~ ^sk-test-[a-zA-Z0-9]+$ ]]; then
        ui_error "Z.AI API key must start with 'sk-test-' and contain only alphanumeric characters"
        return 1
      fi
      ;;
    "minimax")
      if [[ ! "$key" =~ ^[a-zA-Z0-9]+$ ]]; then
        ui_error "MiniMax API key must contain only alphanumeric characters"
        return 1
      fi
      ;;
    "kimi")
      if [[ ! "$key" =~ ^[a-zA-Z0-9-]+$ ]]; then
        ui_error "Kimi API key must contain only alphanumeric characters and hyphens"
        return 1
      fi
      ;;
  esac

  return 0
}

validation_url() {
  local url="$1"

  # Basic validation - non-empty
  if [ -z "$url" ]; then
    ui_error "URL cannot be empty"
    return 1
  fi

  # Check URL length (prevent DoS)
  if [ ${#url} -gt 2048 ]; then
    ui_error "URL too long (maximum 2048 characters)"
    return 1
  fi

  # Basic URL format validation
  if [[ ! "$url" =~ ^https?:// ]]; then
    ui_error "URL must start with http:// or https://"
    return 1
  fi

  # Security: Require HTTPS for external URLs
  if [[ "$url" =~ ^http:// ]]; then
    ui_error "HTTP URLs not allowed for security. Use HTTPS."
    return 1
  fi

  # URL format validation using basic pattern matching
  if [[ ! "$url" =~ ^https://[a-zA-Z0-9.-]+(\.[a-zA-Z]{2,})?(/.*)?$ ]]; then
    ui_error "Invalid URL format"
    return 1
  fi

  # Prevent localhost access (SSRF protection)
  local host="${url#https://}"
  host="${host%%/*}"
  if [[ "$host" == "localhost" || "$host" == "127.0.0.1" || "$host" == "::1" ]]; then
    ui_error "Localhost URLs not allowed for security"
    return 1
  fi

  # Prevent private IP ranges
  if [[ "$host" =~ ^10\. || "$host" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. || "$host" =~ ^192\.168\. ]]; then
    ui_error "Private IP addresses not allowed for security"
    return 1
  fi

  # Prevent link-local addresses
  if [[ "$host" =~ ^169\.254\. ]]; then
    ui_error "Link-local addresses not allowed for security"
    return 1
  fi

  # Check for unsafe ports
  local port=""
  if [[ "$host" =~ :([0-9]+)$ ]]; then
    port="${BASH_REMATCH[1]}"
    # Block common privileged/system ports
    case "$port" in
      22|23|25|53|80|110|143|443|993|995|1433|3306|3389|5432|6379|27017)
        ui_error "Port $port not allowed for security"
        return 1
        ;;
    esac
  fi

  return 0
}

validation_provider_name() {
  local provider="$1"

  # Basic validation - non-empty
  if [ -z "$provider" ]; then
    ui_error "Provider name cannot be empty"
    return 1
  fi

  # Format validation - allow only letters, numbers, underscores, and hyphens
  if [[ ! "$provider" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    ui_error "Provider name can only contain letters, numbers, underscores, and hyphens"
    return 1
  fi

  # Prevent reserved names
  case "$provider" in
    "anthropic"|"zai"|"minimax"|"kimi"|"deepseek"|"custom")
      ui_error "Provider name '$provider' is reserved"
      return 1
      ;;
  esac

  # Length validation
  if [ ${#provider} -gt 50 ]; then
    ui_error "Provider name too long (maximum 50 characters)"
    return 1
  fi

  return 0
}


validation_decrypted_content() {
  local content="$1"

  # Basic validation - non-empty
  if [ -z "$content" ]; then
    ui_error "Decrypted content is empty"
    return 1
  fi

  # Security: Check for error indicators that suggest corrupted content
  if [[ "$content" =~ (error|failed|invalid|corrupted) ]]; then
    ui_error "Decrypted content contains error indicators - may be corrupted"
    return 1
  fi

  # Enhanced security validation - prevent malicious code injection
  # Check for common shell command patterns
  if [[ "$content" =~ \$\(|\`|\$\{ ]]; then
    ui_error "Decrypted content contains potentially malicious code"
    return 1
  fi

  # Check for suspicious commands
  if [[ "$content" =~ (rm\ -rf|chmod|chown|wget|curl|nc\ -) ]]; then
    ui_error "Decrypted content contains potentially malicious commands"
    return 1
  fi

  # Validate environment variable format (KEY=value pairs)
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Check for valid environment variable format
    if [[ ! "$line" =~ ^[A-Z_][A-Z0-9_]*=.*$ ]]; then
      ui_error "Decrypted content contains invalid format on line $line_num: $line"
      return 1
    fi

    # Extract key and value for additional validation
    local key="${line%%=*}"
    local value="${line#*=}"

    # Validate key format
    if [[ ! "$key" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
      ui_error "Invalid environment variable name on line $line_num: $key"
      return 1
    fi

    # Security: Check value for dangerous patterns
    if [[ "$value" =~ \$\(|\`|\$\{ ]]; then
      ui_error "Decrypted content contains potentially malicious code in value on line $line_num: $key"
      return 1
    fi

  done <<< "$content"

  return 0
}

# =============================================================================
# CONFIG MODULE: Configuration management and caching with consistent prefixes
# =============================================================================

config_get_value() {
  # Rename from get_config
  get_config "$1"
}

config_set_value() {
  # Rename from set_config with added cache invalidation
  set_config "$1" "$2"
  config_cache_invalidate
}

config_cache_load() {
  # Rename from load_config_cache
  load_config_cache
}

config_cache_invalidate() {
  # New function to invalidate cache
  CONFIG_CACHE_LOADED=0
  unset CONFIG_CACHE
  declare -gA CONFIG_CACHE
}

config_load_secrets() {
  # Rename from load_secrets with added cache invalidation
  config_cache_invalidate
  load_secrets
}

config_get_secret() {
  # Rename from get_secret with improved secret loading
  config_load_secrets
  local value="${!1:-}"
  echo "$value"
}

# =============================================================================
# CRYPTO MODULE: Cryptographic operations and security functions with consistent prefixes
# =============================================================================

crypto_create_temp_file() {
  # Enhanced version with better error handling
  create_secure_temp_file "$1"
}

crypto_ensure_key() {
  # Wrapper with improved error reporting
  ensure_age_key
}

crypto_show_age_help() {
  # Enhanced help with better formatting
  show_age_install_help
}

crypto_cleanup_temp_files() {
  # New function to cleanup temp files matching pattern
  local pattern="$1"
  [ -n "${TEMP_DIR:-}" ] && find "$TEMP_DIR" -name "$pattern" -type f -delete 2>/dev/null || true
}

crypto_encrypt_file() {
  # New convenience function for file encryption
  local input="$1"
  local output="$2"
  if [ -z "$input" ] || [ -z "$output" ]; then
    ui_error "Both input and output files required for encryption"
    return 1
  fi

  crypto_ensure_key
  age -r "$(age-keygen -y "$AGE_KEY")" < "$input" > "$output"
}

crypto_decrypt_file() {
  # New convenience function for file decryption
  local input="$1"
  local output="$2"
  if [ -z "$input" ] || [ -z "$output" ]; then
    ui_error "Both input and output files required for decryption"
    return 1
  fi

  crypto_ensure_key
  age --decrypt -i "$AGE_KEY" < "$input" > "$output"
}

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

# Background process cleanup
cleanup_background_processes() {
  local jobs_list
  local job_pid

  # Get list of background job PIDs safely
  jobs_list=$(jobs -p 2>/dev/null)

  if [ -n "$jobs_list" ]; then
    # Process each PID individually to prevent injection
    while IFS= read -r job_pid; do
      # Validate PID is numeric and reasonable
      if [[ "$job_pid" =~ ^[0-9]+$ ]] && [ "$job_pid" -gt 1 ] && [ "$job_pid" -lt 32768 ]; then
        # Verify it's actually a background job we own
        if kill -0 "$job_pid" 2>/dev/null; then
          kill "$job_pid" 2>/dev/null || true
        fi
      fi
    done <<< "$jobs_list"

    # Wait for all background jobs to finish
    wait 2>/dev/null || true
  fi

  # Clean up temporary files
  crypto_cleanup_temp_files "clauver_temp_*"
}

# Set up cleanup trap for background processes with signal handling
trap 'cleanup_background_processes; exit 0' EXIT INT TERM

# Show age installation help
show_age_install_help() {
  ui_error "age command not found. Please install 'age' package."
  echo
  echo "Installation instructions:"
  echo "  • Debian/Ubuntu: sudo apt install age"
  echo "  • Fedora/RHEL:   sudo dnf install age"
  echo "  • Arch Linux:    sudo pacman -S age"
  echo "  • macOS:         brew install age"
  echo "  • From source:   https://github.com/FiloSottile/age"
  return 1
}

# Create secure temporary file with proper permissions
create_secure_temp_file() {
  local prefix="$1"
  local temp_file

  temp_file=$(mktemp -t "${prefix}_XXXXXXXXXX") || {
    ui_error "Failed to create temporary file for $prefix"
    return 1
  }

  # Ensure secure permissions
  chmod 600 "$temp_file" || {
    ui_error "Failed to set secure permissions on temp file"
    rm -f "$temp_file"
    return 1
  }

  echo "$temp_file"
}

# Ensure age encryption key exists
ensure_age_key() {
  local current_age_key="${CLAUVER_HOME:-$HOME/.clauver}/age.key"
  if [ ! -f "$current_age_key" ]; then
    if ! command -v age-keygen &>/dev/null; then
      show_age_install_help
    fi
    ui_log "Generating age encryption key..."
    age-keygen -o "$current_age_key"
    chmod 600 "$current_age_key"
    ui_success "Age encryption key generated at $(sanitize_path "$current_age_key")"
    echo
    ui_warn "IMPORTANT: Back up your age key! Without this key, you cannot decrypt your secrets."
  fi
}

# Save secrets to encrypted file
save_secrets() {
  # Check if age command is available
  if ! command -v age &>/dev/null; then
    show_age_install_help
  fi

  # Check if key file exists
  if [ ! -f "$AGE_KEY" ]; then
    ui_error "Age key not found at: $(sanitize_path "$AGE_KEY")"
    echo
    echo "Your encryption key is missing. To recover:"
    echo "  1. If you have a backup of your key, restore it to: $(sanitize_path "$AGE_KEY")"
    echo "  2. Otherwise, reconfigure your providers: clauver config <provider>"
    echo "  3. The key will be regenerated automatically"
    return 1
  fi

  # Create secrets data in memory and encrypt directly
  local secrets_data=""
  [ -n "${ZAI_API_KEY:-}" ] && secrets_data="${secrets_data}ZAI_API_KEY=${ZAI_API_KEY}"$'\n'
  [ -n "${MINIMAX_API_KEY:-}" ] && secrets_data="${secrets_data}MINIMAX_API_KEY=${MINIMAX_API_KEY}"$'\n'
  [ -n "${KIMI_API_KEY:-}" ] && secrets_data="${secrets_data}KIMI_API_KEY=${KIMI_API_KEY}"$'\n'
  [ -n "${DEEPSEEK_API_KEY:-}" ] && secrets_data="${secrets_data}DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}"$'\n'

  # Encrypt directly from memory without temporary files
  ui_log "Encrypting secrets..."
  printf '%s' "$secrets_data" | age -e -i "$AGE_KEY" > "$SECRETS_AGE" 2>/dev/null &
  local encrypt_pid=$!
  show_progress "Encrypting secrets file" "$encrypt_pid" 0.3
  wait "$encrypt_pid"

  if [ ! -s "$SECRETS_AGE" ]; then
    ui_error "Failed to encrypt secrets file"
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

# Load decrypted content safely without using source
load_decrypted_content_safely() {
  local content="$1"
  local old_ifs="$IFS"

  # Process line by line safely
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Validate environment variable assignment format
    if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
      local var_name="${BASH_REMATCH[1]}"
      local var_value="${BASH_REMATCH[2]}"

      # Additional safety check on variable name
      case "$var_name" in
        *PATH*|*HOME*|*USER*|*SHELL*|*ENV*)
          ui_warn "Loading system-like variable: $var_name"
          ;;
      esac

      # Security check: reject dangerous patterns in values
      local dangerous_chars='[\|<>$]'
      if [[ "$var_value" =~ \$\(.*\) ]] || \
         [[ "$var_value" =~ \`.*\` ]] || \
         [[ "$var_value" =~ (rm|mv|cp|chmod|chown)[[:space:]] ]] || \
         [[ "$var_value" =~ $dangerous_chars ]]; then
        ui_error "Decrypted content contains potentially malicious code in value: $var_name"
        return 1
      fi

      # Export safely
      export "$var_name=$var_value"
    else
      ui_error "Invalid environment variable format: $line"
      return 1
    fi
  done <<< "$content"
  IFS="$old_ifs"
  return 0
}

# Load secrets from secrets.env
load_secrets() {
  # Skip if already loaded in this session
  [ "$SECRETS_LOADED" -eq 1 ] && return 0

  if [ -f "$SECRETS_AGE" ]; then
    # Check if age command is available
    if ! command -v age &>/dev/null; then
      show_age_install_help
    fi

    # Check if key file exists
    if [ ! -f "$AGE_KEY" ]; then
      ui_error "Age key not found at: $(sanitize_path "$AGE_KEY")"
      echo
      echo "Your encryption key is missing. To recover:"
      echo "  1. If you have a backup of your key, restore it to: $(sanitize_path "$AGE_KEY")"
      echo "  2. Otherwise, you'll need to reconfigure your providers"
      echo
      echo "To start fresh:"
      echo "  1. Remove encrypted file: rm $(sanitize_path "$SECRETS_AGE")"
      echo "  2. Reconfigure providers: clauver config <provider>"
      return 1
    fi

    # Test decryption first to catch corruption early
    local decrypt_test
    # Decrypt directly into memory
    decrypt_test=$(age -d -i "$AGE_KEY" "$SECRETS_AGE" 2>/dev/null)
    local decrypt_exit=$?

    if [ $decrypt_exit -ne 0 ]; then
      ui_error "Failed to decrypt secrets file"
      echo
      echo "Possible causes:"
      echo "  • Corrupted encrypted file"
      echo "  • Wrong or corrupted age key"
      echo "  • File permissions issue"
      echo
      echo "To recover:"
      echo "  1. Check your age key backup and restore if needed"
      echo "  2. If file is corrupted, remove it: rm $(sanitize_path "$SECRETS_AGE")"
      echo "  3. Reconfigure your providers: clauver config <provider>"
      return 1
    fi

    # Security: Validate decrypted content before sourcing
    # This prevents execution of malicious or invalid content
    if ! validate_decrypted_content "$decrypt_test"; then
      ui_error "Decrypted content contains invalid format or potentially malicious code"
      echo
      echo "This could indicate:"
      echo "  • File corruption or tampering"
      echo "  • Encrypted file is not a valid secrets file"
      echo "  • Age key mismatch (wrong key used)"
      echo
      echo "To recover:"
      echo "  1. Verify your age key backup"
      echo "  2. Remove corrupted file: rm $(sanitize_path "$SECRETS_AGE")"
      echo "  3. Reconfigure providers: clauver config <provider>"
      return 1
    fi

    # Security: Load decrypted content only after successful validation
    # Use safe loading instead of source to prevent code execution
    load_decrypted_content_safely "$decrypt_test" || {
      ui_error "Failed to load decrypted content safely"
      return 1
    }
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

  # Use the cache with safe variable access
  if [[ -v CONFIG_CACHE["$key"] ]]; then
    echo "${CONFIG_CACHE[$key]}"
  else
    echo ""
  fi
}

# Load config file into cache for performance
load_config_cache() {
  # Skip if already loaded in this session
  [ "$CONFIG_CACHE_LOADED" -eq 1 ] && return 0

  # Clear cache
  # shellcheck disable=SC2034
  unset CONFIG_CACHE
  # shellcheck disable=SC2034
  declare -gA CONFIG_CACHE

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
    ui_error "Invalid config key format: $key"
    return 1
  fi

  # Ensure config directory exists
  mkdir -p "$(dirname "$CONFIG")"

  local tmp
  tmp="$(create_secure_temp_file "config")"
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
    ui_log "Migrating existing secrets to encrypted storage..."
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
    ui_warn "sha256sum not available. Skipping integrity check."
    ui_warn "WARNING: Downloaded file not verified. Proceed with caution."
    return 0  # Don't block update, but warn user
  fi

  local actual_hash
  actual_hash=$(sha256sum "$file" | awk '{print $1}')

  if [ "$actual_hash" != "$expected_hash" ]; then
    ui_error "SHA256 mismatch! File may be corrupted or tampered."
    ui_error "Expected: $expected_hash"
    ui_error "Got:      $actual_hash"
    return 1
  fi

  ui_success "SHA256 verification passed"
  return 0
}

get_latest_version() {
  # Security: Verify python3 exists before using it
  if ! command -v python3 &>/dev/null; then
    ui_error "python3 command not found. Please install Python 3."
    return 1
  fi

  # Only show log message if not being captured (when stdout is a terminal)
  if [ -t 1 ]; then
    ui_log "Checking for updates..."
  fi
  local latest_version=""
  # Run curl in background with timeout for progress indicator
  local temp_output
  temp_output=$(create_secure_temp_file "clauver_version") || {
    ui_error "Failed to create temporary file for version check"
    return 1
  }
  curl -s --connect-timeout "${PERFORMANCE_DEFAULTS[network_connect_timeout]}" \
    --max-time "${PERFORMANCE_DEFAULTS[network_max_time]}" \
    "$GITHUB_API_BASE/tags" 2>/dev/null | \
  python3 -c "
import sys, json, re
try:
    data = json.load(sys.stdin)
    if data and len(data) > 0:
        version = data[0].get('name', '')
        # Sanitize version: only allow v followed by numbers and dots
        if re.match(r'^v[\d\.]+$', version):
            print(version.lstrip('v'))
except (json.JSONDecodeError, IndexError, KeyError):
    pass
" 2>/dev/null > "$temp_output" 2>&1 &
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
    ui_error "Failed to fetch latest version from GitHub"
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
      ui_success "You are on the latest version"
    elif [ "$VERSION" = "$(printf '%s\n' "$VERSION" "$latest_version" | sort -V | head -n1)" ] && [ "$VERSION" != "$latest_version" ]; then
      ui_warn "Update available: v${latest_version}"
      echo "Run 'clauver update' to upgrade"
    else
      echo "! You are on a pre-release version (v${VERSION}) newer than latest stable (v${latest_version})"
    fi
  else
    ui_warn "Could not check for updates"
  fi
}

cmd_update() {
  local latest_version
  local install_path
  install_path="$(command -v clauver)"

  if [ -z "$install_path" ]; then
    ui_error "Clauver installation not found in PATH"
    return 1
  fi

  if [ ! -w "$(dirname "$install_path")" ]; then
    ui_error "No write permission to $(dirname "$install_path"). Try with sudo."
    return 1
  fi

  latest_version=$(get_latest_version) || return 1

  # Validate that we got a proper version string
  if [ -z "$latest_version" ]; then
    ui_error "Failed to determine latest version"
    return 1
  fi

  if [ "$VERSION" = "$latest_version" ]; then
    ui_success "Already on latest version (v${VERSION})"
    return 0
  fi

  # Prevent accidental rollback from pre-release to older stable version
  if [ "$VERSION" != "$(printf '%s\n' "$VERSION" "$latest_version" | sort -V | head -n1)" ]; then
    ui_warn "You are on a pre-release version (v${VERSION}) newer than latest stable (v${latest_version})"
    echo
    read -r -p "Rollback to v${latest_version}? This will downgrade your version. [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Update cancelled."
      return 0
    fi
  fi

  echo "Updating from v${VERSION} to v${latest_version}..."

  local temp_file temp_checksum
  temp_file=$(create_secure_temp_file "clauver_download") || {
    ui_error "Failed to create temporary file for download"
    return 1
  }
  temp_checksum=$(create_secure_temp_file "clauver_checksum") || {
    ui_error "Failed to create temporary file for checksum"
    rm -f "$temp_file"
    return 1
  }

  # Security: Download both script and checksum file
  ui_log "Starting download process..."

  # Download main script with progress indicator
  curl -fsSL --connect-timeout "${PERFORMANCE_DEFAULTS[network_connect_timeout]}" \
    --max-time "$DOWNLOAD_TIMEOUT" "$RAW_CONTENT_BASE/v${latest_version}/clauver.sh" -o "$temp_file" 2>/dev/null &
  local download_pid=$!
  show_progress "Downloading clauver.sh v${latest_version}" "$download_pid" 0.2
  wait "$download_pid"

  if [ ! -s "$temp_file" ]; then
    rm -f "$temp_file" "$temp_checksum"
    ui_error "Failed to download update"
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
    ui_warn "SHA256 checksum file not available for v${latest_version}"
    ui_warn "Proceeding without integrity verification (not recommended)"
    echo
    read -r -p "Continue anyway? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      rm -f "$temp_file" "$temp_checksum"
      ui_error "Update cancelled by user"
      return 1
    fi
  else
    # Security: Verify downloaded file integrity
    local expected_hash
    expected_hash=$(awk '{print $1}' "$temp_checksum")

    if ! verify_sha256 "$temp_file" "$expected_hash"; then
      rm -f "$temp_file" "$temp_checksum"
      ui_error "Update aborted due to integrity check failure"
      return 1
    fi
  fi

  # Install verified update
  chmod +x "$temp_file"
  if mv "$temp_file" "$install_path"; then
    rm -f "$temp_checksum"
    ui_success "Update complete! Now running v${latest_version}"
  else
    rm -f "$temp_file" "$temp_checksum"
    ui_error "Failed to install update"
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
  ui_error "Usage: clauver config <provider>"
  echo
  echo "Available providers: anthropic, zai, minimax, kimi, custom"
  echo "Example: clauver config zai"
}

config_anthropic() {
  echo
  ui_success "Native Anthropic is ready to use!"
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
  [ -z "$key" ] && { ui_error "Key is required"; return 1; }

  # Validate API key
  if ! validate_api_key "$key" "$provider"; then
    return 1
  fi

  set_secret "$key_name" "$key"

  # Provider-specific configuration
  config_provider_settings "$provider"

  ui_success "${provider^^} configured. Use: clauver $provider"

  # Show encryption status
  if [ -f "$SECRETS_AGE" ]; then
    echo -e "${GREEN}🔒 Secrets encrypted at: $(sanitize_path "$SECRETS_AGE")${NC}"
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

config_provider_settings() {
  local provider="$1"
  local requirements="${PROVIDER_REQUIRES[$provider]:-api_key}"

  # Skip if only API key is required (handled by main config flow)
  if [ "$requirements" = "api_key" ]; then
    return 0
  fi

  echo
  echo -e "${BOLD}${provider^^} Configuration${NC}"

  IFS=',' read -ra required_fields <<< "$requirements"

  for field in "${required_fields[@]}"; do
    case "$field" in
      "model")
        local current_model
        current_model="$(get_config "${provider}_model")"
        [ -n "$current_model" ] && echo "Current model: $current_model"
        read -r -p "Model (default: ${PROVIDER_DEFAULTS[${provider}_default_model]}): " model
        model="${model:-${PROVIDER_DEFAULTS[${provider}_default_model]}}"

        # Validate model name
        if [ -n "$model" ] && ! validate_model_name "$model"; then
          return 1
        fi

        [ -n "$model" ] && set_config "${provider}_model" "$model"
        ;;

      "url")
        local current_url
        current_url="$(get_config "${provider}_base_url")"
        [ -n "$current_url" ] && echo "Current base URL: $current_url"
        read -r -p "Base URL (default: ${PROVIDER_DEFAULTS[${provider}_base_url]}): " url
        url="${url:-${PROVIDER_DEFAULTS[${provider}_base_url]}}"

        # Validate URL
        if [ -n "$url" ] && ! validate_url "$url"; then
          return 1
        fi

        [ -n "$url" ] && set_config "${provider}_base_url" "$url"
        ;;

      # api_key is handled by main config flow, skip here
      "api_key")
        continue
        ;;

      *)
        ui_error "Unknown configuration field: $field"
        return 1
        ;;
    esac
  done

  # Force cache reload to ensure new configuration is immediately available
  CONFIG_CACHE_LOADED=0
  load_config_cache
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

  { [ -z "$name" ] || [ -z "$base_url" ] || [ -z "$api_key" ]; } && { ui_error "Name, Base URL and API Key are required"; return 1; }

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

  ui_success "Custom provider '$name' configured. Use: clauver $name"
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
      ui_error "Unknown provider: '$provider'"
      echo
      echo "Available providers: anthropic, zai, minimax, kimi, deepseek, custom"
      echo "Example: clauver config zai"
      return 1
      ;;
  esac
}

# Provider abstraction layer


# Provider configuration metadata
declare -A PROVIDER_REQUIRES=(
  ["zai"]="api_key,model,url"
  ["minimax"]="api_key,model,url"
  ["deepseek"]="api_key,model,url"
  ["kimi"]="api_key,model,url"
)

setup_provider_environment() {
  local provider="$1"
  local api_key="$2"
  local model="$3"
  local url="$4"

  IFS='|' read -ra metadata <<< "${PROVIDER_METADATA[$provider]}"
  local display_name="${metadata[0]}"
  local base_url_key="${metadata[1]}"
  local model_key="${metadata[3]}"
  local default_model_key="${metadata[4]}"
  local haiku_model="${metadata[5]}"

  local final_url="${url:-${PROVIDER_DEFAULTS[$base_url_key]}}"
  local final_model="${model:-$(get_config "${model_key}")}"
  final_model="${final_model:-${PROVIDER_DEFAULTS[$default_model_key]}}"

  ui_banner "$display_name ($final_model)"

  export ANTHROPIC_BASE_URL="$final_url"
  export ANTHROPIC_AUTH_TOKEN="$api_key"
  export ANTHROPIC_MODEL="$final_model"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="${haiku_model:-$final_model}"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="$final_model"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="$final_model"
  export ANTHROPIC_SMALL_FAST_MODEL="$final_model"

  local env_vars="${PROVIDER_ENV_VARS[$provider]:-}"
  if [ -n "$env_vars" ]; then
    IFS=',' read -ra var_assignments <<< "$env_vars"
    for assignment in "${var_assignments[@]}"; do
      if [[ "$assignment" == *"="* ]]; then
        local var_name="${assignment%%=*}"
        local var_value="${assignment#*=}"

        if [[ "$var_value" == *"_"* ]]; then
          var_value="${PERFORMANCE_DEFAULTS[$var_value]:-$var_value}"
        fi

        export "$var_name=$var_value"
      fi
    done
  fi
}

# Generic provider switching function
switch_to_provider() {
  local provider="$1"
  shift

  # Force config cache reload to ensure we have latest configuration
  CONFIG_CACHE_LOADED=0
  load_config_cache

  # Handle anthropic specially (no API key needed)
  if [ "$provider" = "anthropic" ]; then
    switch_to_anthropic "$@"
    return
  fi

  # Check if provider is supported
  if ! [[ -v "PROVIDER_METADATA[$provider]" ]]; then
    ui_error "Provider '$provider' not supported"
    exit 1
  fi

  load_secrets

  local key_var="${provider^^}_API_KEY"
  local api_key
  api_key="$(get_secret "$key_var")"
  if [ -z "$api_key" ]; then
    ui_error "${provider^^} not configured. Run: clauver config $provider"
    exit 1
  fi

  local model
  model="$(get_config "${provider}_model")"
  local url
  url="$(get_config "${provider}_base_url")"

  setup_provider_environment "$provider" "$api_key" "$model" "$url"

  exec claude "$@"
}

# Input validation framework
validate_api_key() {
  local key="$1"
  local provider="$2"

  # Basic validation - non-empty and reasonable length
  if [ -z "$key" ]; then
    ui_error "API key cannot be empty"
    return 1
  fi

  # Check minimum length (most API keys are at least 20 chars)
  if [ ${#key} -lt "$MIN_API_KEY_LENGTH" ]; then
    ui_error "API key too short (minimum $MIN_API_KEY_LENGTH characters)"
    return 1
  fi

  # Enhanced security validation - prevent ALL shell metacharacters
  # Allow only alphanumeric, dot, underscore, hyphen, and common API key chars
  if [[ ! "$key" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    ui_error "API key contains invalid characters"
    return 1
  fi

  # Provider-specific validation
  case "$provider" in
    "zai"|"minimax"|"kimi"|"deepseek")
      # Most API keys start with sk- or similar prefixes
      if [[ ! "$key" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        ui_error "API key contains invalid characters for $provider"
        return 1
      fi
      ;;
    "custom")
      # Custom providers may have different key formats
      if [[ ! "$key" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        ui_error "API key contains invalid characters"
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
    ui_error "URL cannot be empty"
    return 1
  fi

  # Enforce HTTPS only
  if [[ ! "$url" =~ ^https:// ]]; then
    ui_error "URL must use HTTPS protocol for security"
    return 1
  fi

  # Check URL length (prevent DoS)
  if [ ${#url} -gt 2048 ]; then
    ui_error "URL too long (maximum 2048 characters)"
    return 1
  fi

  # Validate hostname format
  if [[ ! "$url" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then
    ui_error "Invalid URL format"
    return 1
  fi

  # Extract hostname for SSRF protection
  local hostname
  hostname=$(echo "$url" | sed -e 's|^https://||' -e 's|:.*||' -e 's|/.*||')

  # SSRF protection - block internal networks
  case "$hostname" in
    # Localhost variations
    "localhost"|"127.0.0.1"|"::1")
      ui_error "Localhost URLs not allowed for security"
      return 1
      ;;
    # Private IPv4 ranges
    10.*|172.[0-9]*|192.168.*)
      ui_error "Private IP addresses not allowed for security"
      return 1
      ;;
    # Link-local
    169.254.*)
      ui_error "Link-local addresses not allowed for security"
      return 1
      ;;
    # Class D/E (multicast/experimental)
    224.*|239.*|240.*|241.*|242.*|243.*|244.*|245.*|246.*|247.*|248.*|249.*|250.*|251.*|252.*|253.*|254.*|255.*)
      ui_error "Multicast/experimental addresses not allowed"
      return 1
      ;;
  esac

  # Check for .localhost TLD
  if [[ "$hostname" == *.localhost ]]; then
    ui_error "Localhost domain not allowed for security"
    return 1
  fi

  # Validate port range (if specified)
  if [[ "$url" =~ :([0-9]+) ]]; then
    local port="${BASH_REMATCH[1]}"
    # Reject privileged ports and common internal service ports
    if [ "$port" -le 1024 ] || [ "$port" -eq 3306 ] || [ "$port" -eq 5432 ] || [ "$port" -eq 6379 ]; then
      ui_error "Port $port not allowed for security"
      return 1
    fi
  fi

  return 0
}

validate_provider_name() {
  local provider="$1"

  # Check if provider name is valid
  if [ -z "$provider" ]; then
    ui_error "Provider name cannot be empty"
    return 1
  fi

  # Check for valid characters (alphanumeric, underscore, hyphen)
  if [[ ! "$provider" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    ui_error "Provider name can only contain letters, numbers, underscores, and hyphens"
    return 1
  fi

  # Check if name is reserved
  local reserved_names=("anthropic" "zai" "minimax" "kimi" "deepseek")
  for reserved in "${reserved_names[@]}"; do
    if [ "$provider" = "$reserved" ]; then
      ui_error "Provider name '$provider' is reserved"
      return 1
    fi
  done

  return 0
}

validate_model_name() {
  local model="$1"

  if [ -z "$model" ]; then
    ui_error "Model name cannot be empty"
    return 1
  fi

  # Security validation - prevent injection attacks
  # Reject dangerous characters that could be used for command injection
  local dangerous_chars='[;`$|&<>]'
  if [[ "$model" =~ [$dangerous_chars] ]]; then
    ui_error "Model name contains dangerous characters that could be used for injection attacks"
    return 1
  fi

  # Reject potential command substitution patterns
  if [[ "$model" =~ \$\(.*\) ]]; then
    ui_error "Model name contains potential command substitution pattern"
    return 1
  fi

  # Reject quote characters that could break parsing
  if [[ "$model" =~ [\'\"] ]]; then
    ui_error "Model name contains quote characters that could break parsing"
    return 1
  fi

  # Basic model name validation - allow safe characters including provider/model:tag format
  if [[ ! "$model" =~ ^[a-zA-Z0-9.\\/_:-]+$ ]]; then
    ui_error "Model name contains invalid characters (only alphanumeric, dot, underscore, hyphen, forward slash, colon allowed)"
    return 1
  fi

  return 0
}

# Validate decrypted secrets content
validate_decrypted_content() {
  local content="$1"

  if [ -z "$content" ]; then
    ui_error "Decrypted content is empty"
    return 1
  fi

  # Check for obvious non-environment-variable content
  # More precise patterns for error messages
  if [[ "$content" =~ ^(error|Error|ERROR)[:][[:space:]] ]] || \
     [[ "$content" =~ ^(failed|Failed|FAILED)[:][[:space:]] ]] || \
     [[ "$content" =~ ^(invalid|Invalid|INVALID)[:][[:space:]] ]] || \
     [[ "$content" =~ ^(corrupt|Corrupt|CORRUPT)[:][[:space:]] ]] || \
     [[ "$content" =~ ^(permission|Permission|PERMISSION)[[:space:]]+denied ]]; then
    ui_error "Decrypted content contains error indicators - may be corrupted"
    return 1
  fi

  # Check for dangerous bash constructs (more targeted)
  # Only reject clearly malicious patterns, not valid API key characters
  if [[ "$content" =~ \$\(.*\) ]] || \
     [[ "$content" =~ \`.*\` ]] || \
     [[ "$content" =~ (rm|mv|cp|chmod|chown)[[:space:]] ]] || \
     [[ "$content" =~ (>|>>|<<)[[:space:]]/ ]]; then
    ui_error "Decrypted content contains potentially malicious code"
    return 1
  fi

  # Basic validation - check for at least one environment variable assignment
  # Each line should be in format: KEY=value
  local old_ifs="$IFS"
  IFS=$'\n'
  for line in $content; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Check if line matches environment variable format
    if [[ ! "$line" =~ ^[A-Z_][A-Z0-9_]*=(.*)$ ]]; then
      ui_error "Decrypted content contains invalid format: $line"
      return 1
    fi

    # Extract and validate the value part
    local value="${BASH_REMATCH[1]}"

    # Allow common API key characters but reject obviously dangerous patterns
    local dangerous_chars='[\|<>$]'
    if [[ "$value" =~ \$\(.*\) ]] || \
       [[ "$value" =~ \`.*\` ]] || \
       [[ "$value" =~ (rm|mv|cp|chmod|chown)[[:space:]] ]] || \
       [[ "$value" =~ $dangerous_chars ]]; then
      ui_error "Decrypted content contains potentially malicious code in value"
      return 1
    fi
  done
  IFS="$old_ifs"

  return 0
}

switch_to_anthropic() {
  ui_banner "Native Anthropic"
  echo -e "${BOLD}Using Native Anthropic${NC}"
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
    ui_error "Provider '$provider_name' not configured. Run: clauver config custom"
    exit 1
  fi
  if [ -z "$base_url" ]; then
    ui_error "Provider '$provider_name' base URL missing. Run: clauver config custom"
    exit 1
  fi

  ui_banner "${provider_name}"

  export ANTHROPIC_BASE_URL="$base_url"
  export ANTHROPIC_AUTH_TOKEN="$api_key"

  [ -n "$model" ] && export ANTHROPIC_MODEL="$model"

  exec claude "$@"
}

cmd_test() {
  local provider="${1:-}"

  if [ -z "$provider" ]; then
    ui_error "Usage: clauver test <provider>"
    return 1
  fi

  case "$provider" in
    anthropic)
      echo -e "${BOLD}Testing Native Anthropic${NC}"
      if timeout "$ANTHROPIC_TEST_TIMEOUT" claude --version &>/dev/null; then
        ui_success "Native Anthropic is working"
      else
        ui_error "Native Anthropic test failed"
      fi
      ;;
    zai|minimax|kimi|deepseek)
      load_secrets

      local key_name="${provider^^}_API_KEY"
      local api_key
      api_key="$(get_secret "$key_name")"
      if [ -z "$api_key" ]; then
        ui_error "${provider^^} not configured"
        return 1
      fi
      echo -e "${BOLD}Testing ${provider^^}${NC}"

      local model
      model="$(get_config "${provider}_model")"
      local url
      url="$(get_config "${provider}_base_url")"

      setup_provider_environment "$provider" "$api_key" "$model" "$url"

      export API_TIMEOUT_MS="${PERFORMANCE_DEFAULTS[test_api_timeout_ms]}"
      timeout "$PROVIDER_TEST_TIMEOUT" claude "test" --dangerously-skip-permissions &>/dev/null &
      local test_pid=$!
      sleep 3
      if kill -0 $test_pid 2>/dev/null; then
        ui_success "${provider^^} configuration is valid"
        kill $test_pid 2>/dev/null || true
      else
        ui_error "${provider^^} test failed"
      fi
      ;;
    *)
      local api_key
      api_key="$(get_config "custom_${provider}_api_key")"
      if [ -z "$api_key" ]; then
        ui_error "Provider '$provider' not found"
        return 1
      fi
      echo -e "${BOLD}Testing Custom Provider: $provider${NC}"
      local base_url
      base_url="$(get_config "custom_${provider}_base_url")"
      export ANTHROPIC_BASE_URL="$base_url"
      export ANTHROPIC_AUTH_TOKEN="$api_key"
      timeout "$PROVIDER_TEST_TIMEOUT" claude "test" --dangerously-skip-permissions &>/dev/null &
      local test_pid=$!
      sleep 3
      if kill -0 $test_pid 2>/dev/null; then
        ui_success "$provider configuration is valid"
        kill $test_pid 2>/dev/null || true
      else
        ui_error "$provider test failed"
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
    ui_success "Installed"
  else
    ui_error "Not installed"
  fi
  echo

  for provider in zai minimax kimi deepseek; do
    local key_name="${provider^^}_API_KEY"
    local api_key
    api_key="$(get_secret "$key_name")"
    echo -e "${BOLD}${provider}:${NC}"
    if [ -n "$api_key" ]; then
      ui_success "Configured ($(mask_key "$api_key"))"
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
      ui_warn "Not configured"
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
          ui_success "Configured ($(mask_key "$value"))"
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
      ui_success "Default provider set to: ${provider}"
      echo "Run 'clauver' without arguments to use this provider."
      return 0
      ;;
    zai)
      local zai_key
      zai_key="$(get_secret "ZAI_API_KEY")"
      if [ -z "$zai_key" ]; then
        ui_error "Z.AI is not configured. Run: clauver config zai"
        return 1
      fi
      set_config "default_provider" "$provider"
      ui_success "Default provider set to: ${provider}"
      echo "Run 'clauver' without arguments to use this provider."
      return 0
      ;;
    minimax)
      local minimax_key
      minimax_key="$(get_secret "MINIMAX_API_KEY")"
      if [ -z "$minimax_key" ]; then
        ui_error "MiniMax is not configured. Run: clauver config minimax"
        return 1
      fi
      set_config "default_provider" "$provider"
      ui_success "Default provider set to: ${provider}"
      echo "Run 'clauver' without arguments to use this provider."
      return 0
      ;;
    kimi)
      local kimi_key
      kimi_key="$(get_secret "KIMI_API_KEY")"
      if [ -z "$kimi_key" ]; then
        ui_error "Kimi is not configured. Run: clauver config kimi"
        return 1
      fi
      set_config "default_provider" "$provider"
      ui_success "Default provider set to: ${provider}"
      echo "Run 'clauver' without arguments to use this provider."
      return 0
      ;;
    deepseek)
      local deepseek_key
      deepseek_key="$(get_secret "DEEPSEEK_API_KEY")"
      if [ -z "$deepseek_key" ]; then
        ui_error "DeepSeek is not configured. Run: clauver config deepseek"
        return 1
      fi
      set_config "default_provider" "$provider"
      ui_success "Default provider set to: ${provider}"
      echo "Run 'clauver' without arguments to use this provider."
      return 0
      ;;
        *)
      # Check if it's a custom provider
      local custom_key
      custom_key="$(get_config "custom_${provider}_api_key")"
      if [ -n "$custom_key" ]; then
        set_config "default_provider" "$provider"
        ui_success "Default provider set to: ${provider}"
        echo "Run 'clauver' without arguments to use this provider."
        return 0
      else
        ui_error "Unknown or unconfigured provider: '$provider'"
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
    ui_success "Secrets are already encrypted!"
    echo "  Location: $(sanitize_path "$SECRETS_AGE")"
    return 0
  fi

  # Check if plaintext file exists
  if [ ! -f "$SECRETS" ]; then
    ui_warn "No plaintext secrets file found."
    if [ -f "$SECRETS_AGE" ]; then
      ui_success "Encrypted secrets file already exists at: $SECRETS_AGE"
    else
      echo "No secrets to migrate. Configure a provider first:"
      echo "  clauver config <provider>"
    fi
    return 0
  fi

  ui_log "Found plaintext secrets file: $SECRETS"
  echo

  # Ensure age key exists
  if ! ensure_age_key; then
    ui_error "Failed to ensure age key. Migration aborted."
    return 1
  fi

  # Load existing plaintext secrets
  ui_log "Loading plaintext secrets..."
  # shellcheck disable=SC1090
  source "$SECRETS"

  # Save to encrypted format
  ui_log "Encrypting secrets..."
  if save_secrets; then
    ui_success "Secrets successfully encrypted!"
    echo "  Encrypted file: $(sanitize_path "$SECRETS_AGE")"
    echo "  Plaintext file: removed"
    echo
    ui_warn "IMPORTANT: Back up your age key at: $(sanitize_path "$AGE_KEY")"
    echo "Without this key, you cannot decrypt your secrets."
  else
    ui_error "Failed to encrypt secrets."
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
      ui_success "Native Anthropic is ready to use!"
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
      ui_warn "Setup skipped."
      echo "Run ${BOLD}clauver setup${NC} anytime to configure a provider."
      echo
      ;;
    *)
      echo
      ui_error "Invalid choice. Run 'clauver setup' again to retry."
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
    switch_to_provider "zai" "$@"
    ;;
  minimax)
    shift
    switch_to_provider "minimax" "$@"
    ;;
  kimi)
    shift
    switch_to_provider "kimi" "$@"
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
          switch_to_provider "zai" "$@"
          ;;
        minimax)
          switch_to_provider "minimax" "$@"
          ;;
        kimi)
          switch_to_provider "kimi" "$@"
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
            switch_to_provider "zai" "$@"
            ;;
          minimax)
            switch_to_provider "minimax" "$@"
            ;;
          kimi)
            switch_to_provider "kimi" "$@"
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
        ui_error "Unknown command: '$1'"
        echo "Use 'clauver help' for available commands."
        exit 1
      fi
    fi
    ;;
esac
fi
