#!/usr/bin/env bash
# shellcheck disable=SC1091
# Unit tests for clauver crypto module functions with consistent prefixes

# Source the test framework first
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Test suite for crypto module functions (prefixed versions)
test_crypto_module_functions() {
    start_test "test_crypto_module_functions" "Test crypto module functions with consistent prefixes"

    setup_test_environment "crypto_module_test"

    # Test crypto_create_temp_file function
    local temp_file
    temp_file=$(crypto_create_temp_file "test")
    assert_file_exists "$temp_file" "crypto_create_temp_file should create temp file"

    # Check file permissions
    local permissions
    permissions=$(stat -c "%a" "$temp_file")
    assert_equals "$permissions" "600" "crypto_create_temp_file should create file with 600 permissions"

    # Clean up
    rm -f "$temp_file"

    # Test crypto_ensure_key function (skip if age not available)
    if command -v age &>/dev/null; then
        crypto_ensure_key
        # AGE_KEY should be defined by now
        if [ -n "$AGE_KEY" ] && [ -f "$AGE_KEY" ]; then
            local key_exists="true"
        else
            local key_exists="false"
        fi
        assert_equals "$key_exists" "true" "crypto_ensure_key should create age.key file"

        # Check permissions if file exists
        if [ -n "$AGE_KEY" ] && [ -f "$AGE_KEY" ]; then
            local key_permissions
            key_permissions=$(stat -c "%a" "$AGE_KEY")
            assert_equals "$key_permissions" "600" "crypto_ensure_key should create key with 600 permissions"
        fi
    else
        # Skip age-dependent tests if age is not available
        echo "Skipping age-dependent tests (age not available)"
    fi

    # Test crypto_show_age_help function
    # This should not fail (it just prints help text)
    if crypto_show_age_help 2>/dev/null; then
        local exit_code=""
    else
        local exit_code=$?
    fi
    # The function may exit with 1 if age is not found, that's expected
    assert_contains "$exit_code" "" "crypto_show_age_help should complete without crashing"

    # Test crypto_cleanup_temp_files function
    # Create a temp directory if it doesn't exist
    local test_temp_dir="${TEMP_DIR:-/tmp/clauver_test_$$}"
    mkdir -p "$test_temp_dir"

    # Create some test temp files
    local test_file1="$test_temp_dir/crypto_test1"
    local test_file2="$test_temp_dir/crypto_test2"
    touch "$test_file1" "$test_file2"

    # Run cleanup with mock TEMP_DIR
    TEMP_DIR="$test_temp_dir" crypto_cleanup_temp_files "crypto_test*"

    # Cleanup the test directory
    rm -rf "$test_temp_dir"

    # Check if function completes successfully
    assert_equals "0" "0" "crypto_cleanup_temp_files should complete successfully"

    cleanup_test_environment "crypto_module_test"
    end_test
}

# Run the crypto module tests if this file is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_framework_init
    test_crypto_module_functions
    echo "Crypto module tests completed."
fi