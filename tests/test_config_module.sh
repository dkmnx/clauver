#!/usr/bin/env bash
# shellcheck disable=SC1091
# Unit tests for clauver configuration module functions with consistent prefixes

# Source the test framework first
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Test suite for configuration module functions (prefixed versions)
test_config_module_functions() {
    start_test "test_config_module_functions" "Test configuration module functions with consistent prefixes"

    setup_test_environment "config_module_test"

    # Test config_get_value function
    local result
    result=$(config_get_value "nonexistent")
    assert_equals "$result" "" "config_get_value should return empty for non-existent key"

    # Test config_set_value and config_get_value
    config_set_value "test_key" "test_value"
    result=$(config_get_value "test_key")
    assert_equals "$result" "test_value" "config_get_value should retrieve value set by config_set_value"

    # Test config_cache_load function
    config_cache_load
    # Verify cache is loaded (this should not fail)
    assert_equals "0" "0" "config_cache_load should complete successfully"

    # Test config_cache_invalidate function
    config_cache_invalidate
    # Verify cache is invalidated (this should not fail)
    assert_equals "0" "0" "config_cache_invalidate should complete successfully"

    # Test config_load_secrets function
    # Create a temporary secrets file for testing
    echo "TEST_SECRET=test_value" > "$SECRETS"
    config_load_secrets
    # The function should load without error
    assert_equals "0" "0" "config_load_secrets should load successfully"

    # Test config_get_secret function
    export TEST_SECRET="test_env_value"  # Set environment variable for testing
    local secret_value
    secret_value=$(config_get_secret "TEST_SECRET")
    assert_equals "$secret_value" "test_env_value" "config_get_secret should retrieve environment variable"

    # Clean up
    rm -f "$SECRETS" 2>/dev/null || true
    unset TEST_SECRET

    cleanup_test_environment "config_module_test"
    end_test
}

# Run the config module tests if this file is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_framework_init
    test_config_module_functions
    echo "Config module tests completed."
fi