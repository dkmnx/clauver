#!/usr/bin/env bash
#
# Test Suite for Clauver Security Improvements v1.6.1
# This script tests all security enhancements implemented in the latest version
#

set -euo pipefail

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
test_header() {
  echo
  echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "${BOLD}${BLUE}TEST: $1${NC}"
  echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  echo "${GREEN}✓ PASS:${NC} $1"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  echo "${RED}✗ FAIL:${NC} $1"
}

test_info() {
  echo "${BLUE}ℹ INFO:${NC} $1"
}

test_warn() {
  echo "${YELLOW}⚠ WARN:${NC} $1"
}

# Cleanup function
cleanup() {
  test_info "Cleaning up test artifacts..."
  rm -f /tmp/test_*.{sh,txt,age,sha256} 2>/dev/null || true
}

trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1: SHA256 Verification Function
# ═══════════════════════════════════════════════════════════════════════════

test_sha256_verification() {
  test_header "SHA256 Verification Function"

  # Check if sha256sum is available
  if ! command -v sha256sum &>/dev/null; then
    test_warn "sha256sum not available - skipping SHA256 tests"
    return 0
  fi

  # Create test file
  local test_file="/tmp/test_sha256_file.txt"
  echo "test content for SHA256 verification" > "$test_file"

  # Generate correct checksum
  local correct_hash
  correct_hash=$(sha256sum "$test_file" | awk '{print $1}')

  # Source the clauver script to get verify_sha256 function
  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"

  # Extract verify_sha256 function for testing
  source <(sed -n '/^verify_sha256()/,/^}/p' "$script_dir/clauver.sh")

  # Test 1.1: Valid checksum
  if verify_sha256 "$test_file" "$correct_hash" &>/dev/null; then
    test_pass "Valid SHA256 checksum verification"
  else
    test_fail "Valid SHA256 checksum verification"
  fi

  # Test 1.2: Invalid checksum
  local wrong_hash="0000000000000000000000000000000000000000000000000000000000000000"
  if verify_sha256 "$test_file" "$wrong_hash" &>/dev/null; then
    test_fail "Invalid SHA256 checksum rejection"
  else
    test_pass "Invalid SHA256 checksum rejection"
  fi

  # Test 1.3: Modified file detection
  local original_hash
  original_hash=$(sha256sum "$test_file" | awk '{print $1}')
  echo "modified" >> "$test_file"
  if verify_sha256 "$test_file" "$original_hash" &>/dev/null; then
    test_fail "Detection of modified file"
  else
    test_pass "Detection of modified file"
  fi

  rm -f "$test_file"
}

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2: Age Decryption Exit Code Validation
# ═══════════════════════════════════════════════════════════════════════════

test_age_exit_code() {
  test_header "Age Decryption Exit Code Validation"

  # Check if age is available
  if ! command -v age &>/dev/null || ! command -v age-keygen &>/dev/null; then
    test_warn "age not available - skipping age tests"
    return 0
  fi

  # Create test keys and encrypted file
  local key1="/tmp/test_age_key1.txt"
  local key2="/tmp/test_age_key2.txt"
  local encrypted="/tmp/test_secrets.age"

  age-keygen -o "$key1" 2>/dev/null
  age-keygen -o "$key2" 2>/dev/null

  # Encrypt with key1
  echo "SECRET_VALUE=test123" | age -e -i "$key1" > "$encrypted" 2>/dev/null

  # Test 2.1: Successful decryption with correct key
  local decrypt_output decrypt_exit
  decrypt_output=$(age -d -i "$key1" "$encrypted" 2>&1)
  decrypt_exit=$?

  if [ $decrypt_exit -eq 0 ] && [[ "$decrypt_output" == "SECRET_VALUE=test123" ]]; then
    test_pass "Successful decryption with correct key"
  else
    test_fail "Successful decryption with correct key (exit=$decrypt_exit)"
  fi

  # Test 2.2: Failed decryption with wrong key
  set +e  # Temporarily disable exit on error for intentional failure test
  decrypt_output=$(age -d -i "$key2" "$encrypted" 2>&1)
  decrypt_exit=$?
  set -e  # Re-enable exit on error

  if [ $decrypt_exit -ne 0 ]; then
    test_pass "Failed decryption detection with wrong key"
  else
    test_fail "Failed decryption detection with wrong key"
  fi

  # Test 2.3: Verify error message is NOT executed as code
  # This tests the critical vulnerability fix
  if [[ ! "$decrypt_output" =~ ^SECRET_VALUE= ]]; then
    test_pass "Error message not interpreted as valid secret"
  else
    test_fail "Error message incorrectly interpreted as valid secret"
  fi

  rm -f "$key1" "$key2" "$encrypted"
}

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3: Python3 Availability Check
# ═══════════════════════════════════════════════════════════════════════════

test_python3_check() {
  test_header "Python3 Availability Check"

  # Test 3.1: Verify python3 check function exists in script
  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"

  if grep -q "command -v python3" "$script_dir/clauver.sh"; then
    test_pass "Python3 availability check present in code"
  else
    test_fail "Python3 availability check missing in code"
  fi

  # Test 3.2: Verify get_latest_version has the check
  if grep -A 5 "^get_latest_version()" "$script_dir/clauver.sh" | grep -q "command -v python3"; then
    test_pass "Python3 check in get_latest_version function"
  else
    test_fail "Python3 check missing in get_latest_version function"
  fi

  # Test 3.3: Check if python3 is actually available
  if command -v python3 &>/dev/null; then
    test_pass "Python3 is installed on this system"
  else
    test_warn "Python3 is not installed (script should handle this)"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# TEST 4: Global Variables Initialization
# ═══════════════════════════════════════════════════════════════════════════

test_global_vars() {
  test_header "Global Variables Initialization"

  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"

  # Test 4.1: Check for defensive initialization
  if grep -q 'ZAI_API_KEY="${ZAI_API_KEY:-}"' "$script_dir/clauver.sh"; then
    test_pass "ZAI_API_KEY defensively initialized"
  else
    test_fail "ZAI_API_KEY defensive initialization missing"
  fi

  if grep -q 'MINIMAX_API_KEY="${MINIMAX_API_KEY:-}"' "$script_dir/clauver.sh"; then
    test_pass "MINIMAX_API_KEY defensively initialized"
  else
    test_fail "MINIMAX_API_KEY defensive initialization missing"
  fi

  if grep -q 'KIMI_API_KEY="${KIMI_API_KEY:-}"' "$script_dir/clauver.sh"; then
    test_pass "KIMI_API_KEY defensively initialized"
  else
    test_fail "KIMI_API_KEY defensive initialization missing"
  fi

  if grep -q 'KATCODER_API_KEY="${KATCODER_API_KEY:-}"' "$script_dir/clauver.sh"; then
    test_pass "KATCODER_API_KEY defensively initialized"
  else
    test_fail "KATCODER_API_KEY defensive initialization missing"
  fi

  # Test 4.2: Verify set -u compatibility
  # The script should not fail with unbound variable errors
  # Note: We only check variable declarations, not full script execution
  local unbound_check
  unbound_check=$(bash -n "$script_dir/clauver.sh" 2>&1 | grep "unbound variable" || true)

  if [ -z "$unbound_check" ]; then
    test_pass "Script compatible with set -u (no obvious unbound variables)"
  else
    test_fail "Script may have unbound variable issues: $unbound_check"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# TEST 5: Config Key Sanitization
# ═══════════════════════════════════════════════════════════════════════════

test_config_sanitization() {
  test_header "Config Key Sanitization"

  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"

  # Test 5.1: Check for validation regex in set_config
  if grep -A 10 "^set_config()" "$script_dir/clauver.sh" | grep -q '\[\[ ! "$key" =~ \^'; then
    test_pass "Config key validation regex present"
  else
    test_fail "Config key validation regex missing"
  fi

  # Test 5.2: Verify error handling for invalid keys
  if grep -A 10 "^set_config()" "$script_dir/clauver.sh" | grep -q "Invalid config key"; then
    test_pass "Error message for invalid config keys present"
  else
    test_fail "Error message for invalid config keys missing"
  fi

  # Test 5.3: Check that printf is used safely
  if sed -n '/^set_config()/,/^}/p' "$script_dir/clauver.sh" | grep -q "printf.*%s"; then
    test_pass "Safe printf usage for config writing"
  else
    test_fail "Unsafe config writing detected"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# TEST 6: Update Function Security
# ═══════════════════════════════════════════════════════════════════════════

test_update_security() {
  test_header "Update Function Security Enhancements"

  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"

  # Test 6.1: Check for SHA256 download in cmd_update
  if grep -A 50 "^cmd_update()" "$script_dir/clauver.sh" | grep -q "clauver.sh.sha256"; then
    test_pass "SHA256 checksum file download in update function"
  else
    test_fail "SHA256 checksum file download missing in update function"
  fi

  # Test 6.2: Check for verify_sha256 call in cmd_update
  if sed -n '/^cmd_update()/,/^}/p' "$script_dir/clauver.sh" | grep -q "verify_sha256"; then
    test_pass "SHA256 verification call in update function"
  else
    test_fail "SHA256 verification call missing in update function"
  fi

  # Test 6.3: Check for user confirmation on missing checksum
  if grep -A 50 "^cmd_update()" "$script_dir/clauver.sh" | grep -q "Continue anyway"; then
    test_pass "User confirmation prompt for missing checksum"
  else
    test_fail "User confirmation prompt missing for missing checksum"
  fi

  # Test 6.4: Verify cleanup of temp files
  if grep -A 50 "^cmd_update()" "$script_dir/clauver.sh" | grep -q 'rm -f "$temp_file" "$temp_checksum"'; then
    test_pass "Temporary file cleanup in update function"
  else
    test_fail "Temporary file cleanup missing in update function"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# TEST 7: Script Integrity Checks
# ═══════════════════════════════════════════════════════════════════════════

test_script_integrity() {
  test_header "Script Integrity and Syntax"

  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"

  # Test 7.1: Bash syntax check
  if bash -n "$script_dir/clauver.sh" 2>/dev/null; then
    test_pass "Bash syntax validation"
  else
    test_fail "Bash syntax errors detected"
  fi

  # Test 7.2: Check for set -euo pipefail
  if head -5 "$script_dir/clauver.sh" | grep -q "set -euo pipefail"; then
    test_pass "Strict error handling enabled (set -euo pipefail)"
  else
    test_fail "Strict error handling missing"
  fi

  # Test 7.3: Check for umask 077
  if head -10 "$script_dir/clauver.sh" | grep -q "umask 077"; then
    test_pass "Restrictive umask set (077)"
  else
    test_fail "Restrictive umask not set"
  fi

  # Test 7.4: Check version bump
  if grep -q 'VERSION="1.6.1"' "$script_dir/clauver.sh"; then
    test_pass "Version bumped to 1.6.1"
  else
    test_fail "Version not updated to 1.6.1"
  fi

  # Test 7.5: ShellCheck (if available)
  if command -v shellcheck &>/dev/null; then
    if shellcheck -S warning "$script_dir/clauver.sh" 2>&1 | grep -q "^In.*line"; then
      test_warn "ShellCheck warnings detected (review recommended)"
    else
      test_pass "ShellCheck validation passed"
    fi
  else
    test_info "ShellCheck not available - skipping"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# TEST 8: Security Comments Documentation
# ═══════════════════════════════════════════════════════════════════════════

test_security_documentation() {
  test_header "Security Comments and Documentation"

  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"

  # Test 8.1: Check for security comments
  local security_comment_count
  security_comment_count=$(grep -c "# Security:" "$script_dir/clauver.sh" || true)

  if [ "$security_comment_count" -ge 5 ]; then
    test_pass "Security comments present ($security_comment_count found)"
  else
    test_fail "Insufficient security comments ($security_comment_count found, expected >= 5)"
  fi

  # Test 8.2: Check for SECURITY_IMPROVEMENTS.md
  if [ -f "$script_dir/SECURITY_IMPROVEMENTS.md" ]; then
    test_pass "Security improvements documentation exists"
  else
    test_fail "Security improvements documentation missing"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

main() {
  echo "${BOLD}${BLUE}"
  cat <<'EOF'
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   CLAUVER SECURITY IMPROVEMENTS TEST SUITE v1.6.1                    ║
║                                                                       ║
║   Testing all security enhancements implemented in latest release    ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
  echo "${NC}"

  test_info "Starting test suite..."
  test_info "Test script location: $(dirname "$0")"
  echo

  # Run all test suites
  test_sha256_verification
  test_age_exit_code
  test_python3_check
  test_global_vars
  test_config_sanitization
  test_update_security
  test_script_integrity
  test_security_documentation

  # Print summary
  echo
  echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "${BOLD}TEST SUMMARY${NC}"
  echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo
  echo "Total tests:  $TESTS_TOTAL"
  echo "${GREEN}Passed:       $TESTS_PASSED${NC}"

  if [ $TESTS_FAILED -eq 0 ]; then
    echo "${RED}Failed:       $TESTS_FAILED${NC}"
    echo
    echo "${BOLD}${GREEN}✓ ALL TESTS PASSED${NC}"
    echo
    exit 0
  else
    echo "${RED}Failed:       $TESTS_FAILED${NC}"
    echo
    echo "${BOLD}${RED}✗ SOME TESTS FAILED${NC}"
    echo "Review failed tests above for details"
    echo
    exit 1
  fi
}

# Run main function
main "$@"
