# Clauver.sh Refactoring Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the 2121-line monolithic clauver.sh script into a maintainable modular structure using function-based prefixes while preserving all existing functionality.

**Architecture:** Extract logical modules (ui, config, crypto, providers, validation) with consistent naming prefixes while keeping single-file deployment for simplicity. Use phased approach to minimize risk.

**Tech Stack:** Bash scripting, shellcheck validation, existing test framework (make test), age encryption

---

## Task 1: Extract UI Module Functions

**Files:**

- Modify: `clauver.sh` (lines 100-200)

**Step 1: Write test for ui_log function**

```bash
test_ui_log_function() {
  start_test "ui_log function should output formatted log message"

  # Capture output
  local output
  output=$(ui_log "test message" 2>&1)

  assert_contains "$output" "→ test message"
  assert_contains "$output" "${BLUE}"
  end_test
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "ui_log function not defined"

**Step 3: Extract and rename ui functions**

```bash
# Replace existing functions with prefixed versions
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
```

**Step 4: Update all function calls to use new names**

Search and replace:

- `log(` → `ui_log(`
- `success(` → `ui_success(`
- `warn(` → `ui_warn(`
- `error(` → `ui_error(`
- `banner(` → `ui_banner(`

**Step 5: Run tests to verify all pass**

Run: `make test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add clauver.sh
git commit -m "refactor: extract UI module with consistent prefixes"
```

---

## Task 2: Extract Validation Module Functions

**Files:**

- Modify: `clauver.sh` (lines 1000-1200)

**Step 1: Write test for validation functions**

```bash
test_validation_api_key() {
  start_test "validation_api_key should reject invalid keys"

  # Test empty key
  validation_api_key "" "test" || local exit_code=$?
  assert_equals "$exit_code" 1

  # Test short key
  validation_api_key "abc" "test" || local exit_code=$?
  assert_equals "$exit_code" 1

  end_test
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with validation functions renamed

**Step 3: Rename validation functions**

```bash
validation_api_key() { ... }
validation_url() { ... }
validation_provider_name() { ...
  # Rename from validate_provider_name
}
validation_model_name() { ...
  # Rename from validate_model_name
}
validation_user_input() { ...
  # Rename from validate_user_input
}
validation_decrypted_content() { ...
  # Rename from validate_decrypted_content
}
```

**Step 4: Update all validation function calls**

Search and replace:

- `validate_api_key(` → `validation_api_key(`
- `validate_url(` → `validation_url(`
- `validate_provider_name(` → `validation_provider_name(`
- `validate_model_name(` → `validation_model_name(`
- `validate_user_input(` → `validation_user_input(`
- `validate_decrypted_content(` → `validation_decrypted_content(`

**Step 5: Run tests**

Run: `make test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add clauver.sh
git commit -m "refactor: extract validation module with consistent prefixes"
```

---

## Task 3: Extract Configuration Module Functions

**Files:**

- Modify: `clauver.sh` (lines 200-400)

**Step 1: Write test for config module**

```bash
test_config_module_functions() {
  start_test "config module should manage configuration correctly"

  # Test config_get_value
  local result=$(config_get_value "nonexistent")
  assert_equals "$result" ""

  # Test config_set_value
  config_set_value "test_key" "test_value"
  local result=$(config_get_value "test_key")
  assert_equals "$result" "test_value"

  # Clean up
  sed -i '/^test_key=/d' "$CONFIG"

  end_test
}
```

**Step 2: Rename config functions**

```bash
config_get_value() {
  # Rename from get_config
}
config_set_value() {
  # Rename from set_config
}
config_cache_load() {
  # Rename from load_config_cache
}
config_cache_invalidate() {
  # New function to invalidate cache
  CONFIG_CACHE_LOADED=0
  unset CONFIG_CACHE
  declare -gA CONFIG_CACHE
}
```

**Step 3: Consolidate config loading logic**

```bash
config_load_secrets() {
  # Rename from load_secrets
  # Add cache invalidation
  config_cache_invalidate
  # Existing implementation...
}

config_get_secret() {
  # Rename from get_secret
  config_load_secrets
  local value="${!key:-}"
  echo "$value"
}
```

**Step 4: Update config function calls**

Search and replace:

- `get_config(` → `config_get_value(`
- `set_config(` → `config_set_value(`
- `load_config_cache(` → `config_cache_load(`
- `load_secrets(` → `config_load_secrets(`
- `get_secret(` → `config_get_secret(`

**Step 5: Add cache invalidation in config_set_value**

```bash
config_set_value() {
  # Existing implementation...
  # Add this at the end:
  config_cache_invalidate
}
```

**Step 6: Run tests**

Run: `make test`
Expected: All tests pass

**Step 7: Commit**

```bash
git add clauver.sh
git commit -m "refactor: extract configuration module with improved caching"
```

---

## Task 4: Extract Crypto Module Functions

**Files:**

- Modify: `clauver.sh` (lines 400-600)

**Step 1: Write test for crypto functions**

```bash
test_crypto_module_functions() {
  start_test "crypto module should handle encryption operations"

  # Test temp file creation
  local temp_file
  temp_file=$(crypto_create_temp_file "test")
  assert_file_exists "$temp_file"
  assert_permissions "$temp_file" "600"

  # Clean up
  rm -f "$temp_file"

  end_test
}
```

**Step 2: Rename crypto functions**

```bash
crypto_create_temp_file() {
  # Rename from create_secure_temp_file
}
crypto_ensure_key() {
  # Rename from ensure_age_key
}
crypto_save_secrets() {
  # Rename from save_secrets
}
crypto_load_secrets() {
  # Rename from load_secrets (already done in Task 3)
}
crypto_validate_content() {
  # Rename from validate_decrypted_content (already done in Task 2)
}
```

**Step 3: Consolidate crypto operations**

```bash
crypto_cleanup_temp_files() {
  # New function to clean up temp files
  local pattern="${1:-clauver_*}"
  find /tmp -name "$pattern" -type f -mtime +1 -delete 2>/dev/null || true
}

crypto_show_age_help() {
  # Rename from show_age_install_help
  # Keep existing implementation
}
```

**Step 4: Update crypto function calls**

Search and replace:

- `create_secure_temp_file(` → `crypto_create_temp_file(`
- `ensure_age_key(` → `crypto_ensure_key(`
- `save_secrets(` → `crypto_save_secrets(`
- `show_age_install_help(` → `crypto_show_age_help(`

**Step 5: Add temp file cleanup**

Add to cleanup_background_processes function:

```bash
crypto_cleanup_temp_files "clauver_*"
```

**Step 6: Run tests**

Run: `make test`
Expected: All tests pass

**Step 7: Commit**

```bash
git add clauver.sh
git commit -m "refactor: extract crypto module with improved cleanup"
```

---

## Task 5: Extract Provider Module Functions

**Files:**

- Modify: `clauver.sh` (lines 1200-1600)

**Step 1: Write test for provider functions**

```bash
test_provider_module_functions() {
  start_test "provider module should handle provider operations"

  # Test provider validation
  provider_validate_config "zai" || local exit_code=$?
  assert_equals "$exit_code" 1  # Should fail without config

  end_test
}
```

**Step 2: Extract provider interface functions**

```bash
provider_switch() {
  # Rename from switch_to_provider
  # Improve error handling and validation
}

provider_test() {
  # Rename from cmd_test but make it more generic
  # Extract testing logic from command handler
}

provider_validate_config() {
  # New function to validate provider configuration
  local provider="$1"
  local requirements="${PROVIDER_REQUIRES[$provider]:-api_key}"

  IFS=',' read -ra required_fields <<< "$requirements"
  for field in "${required_fields[@]}"; do
    case "$field" in
      "api_key")
        local key_var="${provider^^}_API_KEY"
        local api_key
        api_key="$(config_get_secret "$key_var")"
        [ -z "$api_key" ] && return 1
        ;;
      "model"|"url")
        # Validate model and URL configurations
        ;;
    esac
  done
  return 0
}

provider_get_env_vars() {
  # New function to get environment variables for provider
  local provider="$1"
  local api_key="$2"
  local model="$3"
  local url="$4"

  case "$provider" in
    "zai")
      echo "ANTHROPIC_BASE_URL=${PROVIDER_DEFAULTS[zai_base_url]}"
      echo "ANTHROPIC_AUTH_TOKEN=$api_key"
      echo "ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air"
      echo "ANTHROPIC_DEFAULT_SONNET_MODEL=$model"
      echo "ANTHROPIC_DEFAULT_OPUS_MODEL=$model"
      ;;
    # ... other providers
  esac
}
```

**Step 3: Refactor provider switching logic**

```bash
provider_switch() {
  local provider="$1"
  shift

  # Validate provider configuration first
  if ! provider_validate_config "$provider"; then
    ui_error "${provider^^} not configured. Run: clauver config $provider"
    exit 1
  fi

  # Get provider configuration
  local requirements="${PROVIDER_REQUIRES[$provider]:-api_key}"
  local api_key model url

  # Load configuration values
  case "$requirements" in
    *api_key*)
      local key_var="${provider^^}_API_KEY"
      api_key="$(config_get_secret "$key_var")"
      ;;
  esac
  [ -n "${requirements##*model*}" ] || model="$(config_get_value "${provider}_model")"
  [ -n "${requirements##*url*}" ] || url="$(config_get_value "${provider}_base_url")"

  # Set environment using provider interface
  while IFS= read -r env_var; do
    export "$env_var"
  done < <(provider_get_env_vars "$provider" "$api_key" "$model" "$url")

  # Show banner
  ui_banner "$provider"

  # Execute claude
  exec claude "$@"
}
```

**Step 4: Update provider function calls**

Search and replace:

- `switch_to_provider(` → `provider_switch(`
- `switch_to_anthropic(` → `provider_switch_anthropic(`
- `switch_to_custom(` → `provider_switch_custom(`

**Step 5: Run tests**

Run: `make test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add clauver.sh
git commit -m "refactor: extract provider module with unified interface"
```

---

## Task 6: Update Command Handlers to Use New Modules

**Files:**

- Modify: `clauver.sh` (lines 1600-2100)

**Step 1: Update cmd_list function**

```bash
cmd_list() {
  config_load_secrets
  # Use ui_* functions instead of direct printf
  ui_log "Loading configured providers..."
  # Rest of implementation using new module functions
}
```

**Step 2: Update cmd_config function**

```bash
cmd_config() {
  local provider="${1:-}"

  if [ -z "$provider" ]; then
    ui_error "Usage: clauver config <provider>"
    echo
    echo "Available providers: anthropic, zai, minimax, kimi, deepseek, custom"
    echo "Example: clauver config zai"
    return 1
  fi

  # Use validation functions
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
```

**Step 3: Update other cmd_ functions**

Update all command functions to use new module functions:

- Replace error handling with `ui_error`
- Replace validation calls with `validation_*`
- Replace config calls with `config_*`
- Replace crypto calls with `crypto_*`

**Step 4: Run tests**

Run: `make test`
Expected: All tests pass

**Step 5: Commit**

```bash
git add clauver.sh
git commit -m "refactor: update command handlers to use new modules"
```

---

## Task 7: Cleanup and Documentation

**Files:**

- Modify: `clauver.sh`
- Modify: `README.md` (if needed)

**Step 1: Remove unused variables and functions**

Search for and remove:

- Duplicate function definitions
- Unused global variables
- Dead code paths

**Step 2: Add module documentation comments**

```bash
# =============================================================================
# UI MODULE: User interface and display functions
# =============================================================================

# Log information message with formatting
ui_log() { ... }

# =============================================================================
# CONFIG MODULE: Configuration management and caching
# =============================================================================
```

**Step 3: Optimize performance**

```bash
# Add lazy loading for expensive operations
config_lazy_load_secrets() {
  [ "$SECRETS_LOADED" -eq 1 ] && return 0
  config_load_secrets
}

# Optimize provider switching
provider_switch_fast() {
  # Only validate if not recently validated
  local cache_key="provider_${provider}_validated"
  # ... implementation
}
```

**Step 4: Update shellcheck comments**

Add and update shellcheck directives for new function names:

```bash
# shellcheck disable=SC2034
declare -A CONFIG_CACHE=()  # Used dynamically for config caching

# shellcheck disable=SC1090
source "$SECRETS"
```

**Step 5: Run comprehensive tests**

Run: `make ci`
Expected: All tests pass, linting clean

**Step 6: Update documentation**

If needed, update README.md with any breaking changes (should be none).

**Step 7: Final commit**

```bash
git add clauver.sh README.md
git commit -m "refactor: complete modular refactoring of clauver.sh"
```

---

## Task 8: Verification and Testing

**Files:**

- Test: Run full test suite

**Step 1: Run syntax check**

```bash
bash -n clauver.sh
```

Expected: No syntax errors

**Step 2: Run shellcheck**

```bash
shellcheck clauver.sh
```

Expected: No shellcheck errors or warnings

**Step 3: Run full test suite**

```bash
make test
```

Expected: All tests pass

**Step 4: Run integration tests**

```bash
# Test basic functionality
./clauver.sh help
./clauver.sh version
./clauver.sh list
```

Expected: All commands work correctly

**Step 5: Test with actual providers** (if configured)

```bash
# Test provider switching (if configured)
./clauver.sh anthropic --version 2>/dev/null || echo "Claude not installed - OK"
```

**Step 6: Final validation commit**

```bash
git add -A
git commit -m "refactor: validate and complete clauver.sh modular refactoring"
```

---

## Implementation Notes

### Key Principles Applied

1. **Consistent Naming**: All module functions use `module_` prefix
2. **Single Responsibility**: Each module handles one concern
3. **Backward Compatibility**: All CLI interfaces remain unchanged
4. **Error Handling**: Centralized error handling through ui module
5. **Performance**: Improved caching and lazy loading where appropriate

### Migration Strategy

- **Phase 1**: Low-risk modules (UI, Validation)
- **Phase 2**: Medium-risk modules (Config, Crypto)
- **Phase 3**: Higher-risk modules (Providers, Commands)
- **Phase 4**: Cleanup and optimization

### Testing Strategy

- Each module has dedicated tests
- Existing test suite validates no regressions
- Integration tests verify end-to-end functionality

### Benefits Achieved

1. **Maintainability**: Clear module boundaries and responsibilities
2. **Testability**: Each module can be tested independently
3. **Debugging**: Easier to trace issues to specific modules
4. **Extension**: New features require changes to fewer functions
5. **Performance**: Better caching and reduced redundancy
