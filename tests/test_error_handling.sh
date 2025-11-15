#!/usr/bin/env bash
# shellcheck disable=SC1091
# Error handling and edge case tests for clauver

# Source the test framework and clauver script
source "$(dirname "${BASH_SOURCE[0]}")/test-framework.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../clauver.sh"

# Test suite for error handling and edge cases
test_dependency_failures() {
    start_test "test_dependency_failures" "Test handling of missing dependencies"

    setup_test_environment "dependency_failure_test"

    # Test missing age command
    export PATH="/usr/bin:/bin"
    assert_command_failure "save_secrets" "Save should fail without age command"

    # Test missing age-keygen command
    assert_command_failure "ensure_age_key" "Should fail without age-keygen"

    # Test missing python3 command for version check
    export PATH="/usr/bin:/bin"
    assert_command_failure "get_latest_version" "Version check should fail without python3"

    # Test missing sha256sum for integrity check
    cat > "$TEST_TEMP_DIR/verify_sha256" <<EOF
#!/bin/bash
echo "sha256sum not available"
exit 1
EOF
    chmod +x "$TEST_TEMP_DIR/verify_sha256"
    export PATH="$TEST_TEMP_DIR:$PATH"
    assert_command_failure "verify_sha256 'testfile' 'testhash'" "Should fail without sha256sum"

    cleanup_test_environment "dependency_failure_test"
    end_test
}

test_file_permission_errors() {
    start_test "test_file_permission_errors" "Test handling of file permission errors"

    setup_test_environment "permission_error_test"

    # Test unwritable directory
    mkdir -p "$TEST_TEMP_DIR/readonly_dir"
    chmod -w "$TEST_TEMP_DIR/readonly_dir"

    # Temporarily modify CLAUVER_HOME to point to readonly directory
    local original_home="$CLAUVER_HOME"
    export CLAUVER_HOME="$TEST_TEMP_DIR/readonly_dir"

    # Should fail gracefully
    assert_command_failure "save_secrets" "Save should fail in unwritable directory"

    # Restore original home
    export CLAUVER_HOME="$original_home"

    # Test unwritable config file
    touch "$CLAUVER_HOME/config"
    chmod -w "$CLAUVER_HOME/config"

    assert_command_failure "set_config 'test_key' 'test_value'" "Set config should fail on unwritable file"

    # Restore permissions
    chmod +w "$CLAUVER_HOME/config"

    cleanup_test_environment "permission_error_test"
    end_test
}

test_network_error_handling() {
    start_test "test_network_error_handling" "Test network error handling"

    setup_test_environment "network_error_test"

    # Mock curl to simulate timeout
    cat > "$TEST_TEMP_DIR/curl" <<EOF
#!/bin/bash
if [[ "\$*" == *"github.com"* ]]; then
    echo "timeout error"
    exit 1
fi
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/curl"
    export PATH="$TEST_TEMP_DIR:$PATH"

    # Test version check failure
    assert_command_failure "get_latest_version" "Version check should handle network errors"

    # Test update download failure
    assert_command_failure "cmd_update" "Update should handle download failures"

    cleanup_test_environment "network_error_test"
    end_test
}

test_memory_and_resource_limits() {
    start_test "test_memory_and_resource_limits" "Test handling of memory and resource limits"

    setup_test_environment "resource_limits_test"

    # Test with very large API key (edge case)
    local large_key
    large_key=$(printf "sk-a%.0s" {1..1000})  # Very long key
    export ZAI_API_KEY="$large_key"

    assert_command_success "save_secrets" "Should handle very large API keys"

    # Test with maximum environment variables
    for i in {1..100}; do
        export "TEST_VAR_$i"="value_$i"
    done

    # Should still work
    assert_command_success "load_config_cache" "Should work with many environment variables"

    cleanup_test_environment "resource_limits_test"
    end_test
}

test_environment_isolation() {
    start_test "test_environment_isolation" "Test environment isolation and cleanup"

    setup_test_environment "isolation_test"

    # Set up test environment
    export ZAI_API_KEY="isolation-test-key"
    export TEST_GLOBAL_VAR="should-be-isolated"
    set_config "isolation_config" "isolation_value"

    # Load to set internal state
    load_secrets
    load_config_cache

    # Verify state is set
    assert_equals "$SECRETS_LOADED" "1" "Secrets should be loaded"
    assert_equals "$CONFIG_CACHE_LOADED" "1" "Config should be cached"

    # Test that cleanup properly isolates
    cleanup_test_environment "isolation_test"

    # After cleanup, verify environment is restored
    assert_equals "${ZAI_API_KEY:-}" "" "ZAI_API_KEY should be cleared"
    assert_equals "${TEST_GLOBAL_VAR:-}" "" "Global test var should be cleared"
    assert_equals "$SECRETS_LOADED" "0" "Secrets should not be loaded"
    assert_equals "$CONFIG_CACHE_LOADED" "0" "Config should not be cached"

    cleanup_test_environment "isolation_test"
    end_test
}

test_concurrent_access() {
    start_test "test_concurrent_access" "Test concurrent access scenarios"

    setup_test_environment "concurrent_test"

    # Set up initial state
    export ZAI_API_KEY="concurrent-test-key"
    save_secrets

    # Test multiple simultaneous loads
    for i in {1..5}; do
        (
            load_secrets >/dev/null 2>&1
            echo "Load $i completed"
        ) &
    done

    # Wait for all background jobs
    wait

    # Verify the state is still consistent
    load_secrets
    local loaded_key
    loaded_key=$(get_secret "ZAI_API_KEY")
    assert_equals "$loaded_key" "concurrent-test-key" "Key should be accessible after concurrent loads"

    # Test simultaneous config access
    for i in {1..5}; do
        (
            set_config "concurrent_test_$i" "value_$i" >/dev/null 2>&1
            echo "Config $i completed"
        ) &
    done

    wait

    # Verify all configs were set
    for i in {1..5}; do
        local config_value
        config_value=$(get_config "concurrent_test_$i")
        assert_equals "$config_value" "value_$i" "Config $i should be set"
    done

    cleanup_test_environment "concurrent_test"
    end_test
}

test_invalid_input_scenarios() {
    start_test "test_invalid_input_scenarios" "Test various invalid input scenarios"

    setup_test_environment "invalid_input_test"

    # Test invalid provider names
    assert_command_failure "switch_to_provider 'invalid provider name with spaces' --version" "Provider with spaces should fail"
    assert_command_failure "switch_to_provider 'invalid@provider' --version" "Provider with @ should fail"
    assert_command_failure "switch_to_provider 'provider; rm -rf /' --version" "Provider with command injection should fail"

    # Test invalid API keys
    assert_command_failure "validate_api_key '' 'zai'" "Empty API key should fail"
    assert_command_failure "validate_api_key 'short' 'zai'" "Short API key should fail"
    assert_command_failure "validate_api_key 'sk-key-with-injection; rm -rf /' 'zai'" "API key with injection should fail"

    # Test invalid URLs
    assert_command_failure "validate_url ''" "Empty URL should fail"
    assert_command_failure "validate_url 'not-a-url' 'kimi'" "Invalid URL should fail"
    assert_command_failure "validate_url 'javascript:alert(1)' 'kimi'" "JavaScript URL should fail"

    # Test invalid model names
    assert_command_failure "validate_model_name ''" "Empty model name should fail"
    assert_command_failure "validate_model_name 'model; rm -rf /'" "Model name with injection should fail"

    # Test invalid config keys
    assert_command_failure "set_config 'invalid key with spaces' 'value'" "Config key with spaces should fail"
    assert_command_failure "set_config 'key-with-@' 'value'" "Config key with @ should fail"

    # Test invalid config values (should be escaped but not fail)
    set_config "test_value_with_newlines" "line1\nline2\ntest"
    local retrieved_value
    retrieved_value=$(get_config "test_value_with_newlines")
    assert_contains "$retrieved_value" "line1" "Newlines should be handled"

    cleanup_test_environment "invalid_input_test"
    end_test
}

test_edge_case_empty_config() {
    start_test "test_edge_case_empty_config" "Test edge cases with empty configuration"

    setup_test_environment "empty_config_test"

    # Test with no config file
    rm -f "$CLAUVER_HOME/config"

    # Should not crash
    local config_value
    config_value=$(get_config "nonexistent_key")
    assert_equals "$config_value" "" "Should return empty for non-existent key"

    load_config_cache
    assert_equals "$CONFIG_CACHE_LOADED" "0" "Cache should not be loaded from non-existent file"

    # Test with empty config file
    touch "$CLAUVER_HOME/config"
    chmod 600 "$CLAUVER_HOME/config"

    load_config_cache
    assert_equals "$CONFIG_CACHE_LOADED" "1" "Cache should be loaded even if file is empty"

    cleanup_test_environment "empty_config_test"
    end_test
}

test_corrupted_data_handling() {
    start_test "test_corrupted_data_handling" "Test handling of corrupted data files"

    setup_test_environment "corrupted_data_test"

    # Test corrupted encrypted file
    echo "this is not a valid age encrypted file" > "$CLAUVER_HOME/secrets.env.age"
    assert_command_failure "load_secrets" "Should fail to load corrupted encrypted file"

    # Test corrupted age key
    ensure_age_key
    echo "invalid key format" > "$CLAUVER_HOME/age.key"
    export ZAI_API_KEY="test-key"
    assert_command_failure "save_secrets" "Should fail with invalid age key"

    # Test malformed config file
    echo "invalid line without equals sign" > "$CLAUVER_HOME/config"
    load_config_cache
    assert_equals "$CONFIG_CACHE_LOADED" "1" "Should still load config from malformed file"

    cleanup_test_environment "corrupted_data_test"
    end_test
}

test_unsupported_platform_scenarios() {
    start_test "test_unsupported_platform_scenarios" "Test unsupported platform scenarios"

    setup_test_environment "unsupported_platform_test"

    # Test different PATH scenarios
    export PATH="/fake:/nonexistent"
    assert_command_failure "ensure_age_key" "Should handle non-existent PATH gracefully"

    # Test different shell environments (simulate by removing common tools)
    local original_path="$PATH"
    export PATH="/usr/bin"

    # Should handle missing tools gracefully
    assert_command_failure "get_latest_version" "Should handle missing python3 gracefully"

    # Restore PATH
    export PATH="$original_path"

    cleanup_test_environment "unsupported_platform_test"
    end_test
}

test_user_input_edge_cases() {
    start_test "test_user_input_edge_cases" "Test edge cases in user input handling"

    setup_test_environment "user_input_test"

    # Test very long provider names
    local long_provider_name
    long_provider_name=$(printf "a%.0s" {1..100})
    assert_command_failure "validate_provider_name '$long_provider_name'" "Very long provider name should fail validation"

    # Test normal length provider names
    assert_command_success "validate_provider_name 'normal-provider-name'" "Normal provider name should pass"

    # Test API keys with special characters
    assert_command_success "validate_api_key 'sk-test-key-with.special-chars_123' 'zai'" "API key with special chars should pass"

    # Test URLs with various valid formats
    assert_command_success "validate_url 'https://api.example.com:8443/path?param=value'" "URL with port and query should pass"
    assert_command_success "validate_url 'http://localhost:8080/health'" "Localhost URL should pass"

    # Test model names with various formats
    assert_command_success "validate_model_name 'glm-4.5-air'" "Normal model name should pass"
    assert_command_success "validate_model_name 'MiniMax-M2-Pro'" "Complex model name should pass"

    cleanup_test_environment "user_input_test"
    end_test
}

# Run all error handling tests
main() {
    echo "Starting error handling tests..."

    test_dependency_failures
    test_file_permission_errors
    test_network_error_handling
    test_memory_and_resource_limits
    test_environment_isolation
    test_concurrent_access
    test_invalid_input_scenarios
    test_edge_case_empty_config
    test_corrupted_data_handling
    test_unsupported_platform_scenarios
    test_user_input_edge_cases

    echo "Error handling tests completed."
}

# If this file is run directly, execute tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi