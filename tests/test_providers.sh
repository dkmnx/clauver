#!/usr/bin/env bash
# shellcheck disable=SC1091
# Provider switching and configuration tests for clauver

# Source the test framework and clauver script
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../clauver.sh"

# Mock claude CLI for testing
mock_claude_command() {
    # Create mock claude script
    cat > "$TEST_TEMP_DIR/claude" <<EOF
#!/bin/bash
echo "Mock Claude CLI called with arguments: \$*"
# Return success for basic operations
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    export PATH="$TEST_TEMP_DIR:$PATH"
}

# Test suite for provider functions
test_provider_switching_basic() {
    start_test "test_provider_switching_basic" "Test basic provider switching functionality"

    setup_test_environment "provider_switching_test"

    # Mock claude command
    mock_claude_command

    # Test switch_to_anthropic function
    assert_command_success "switch_to_anthropic --version" "Switch to anthropic should succeed"

    # Test switch_to_zai function
    export ZAI_API_KEY="sk-test-zai-key-123"
    assert_command_success "switch_to_zai --version" "Switch to Z.AI should succeed with API key"

    # Test switch_to_minimax function
    export MINIMAX_API_KEY="sk-test-minimax-key-456"
    assert_command_success "switch_to_minimax --version" "Switch to MiniMax should succeed with API key"

    # Test switch_to_kimi function
    export KIMI_API_KEY="sk-test-kimi-key-789"
    set_config "kimi_model" "kimi-for-coding"
    set_config "kimi_base_url" "https://api.kimi.com/coding/"
    assert_command_success "switch_to_kimi --version" "Switch to Kimi should succeed with API key and config"

    cleanup_test_environment "provider_switching_test"
    end_test
}

test_provider_configuration() {
    start_test "test_provider_configuration" "Test provider configuration management"

    setup_test_environment "provider_config_test"

    # Test Z.AI configuration
    export ZAI_API_KEY="sk-test-zai-config"

    # Mock key input for ZAI config
    echo "sk-test-zai-config" | cmd_config "zai"

    # Verify Z.AI key is stored
    local zai_key
    zai_key=$(get_secret "ZAI_API_KEY")
    assert_equals "$zai_key" "sk-test-zai-config" "Z.AI API key should be stored"

    # Test MiniMax configuration
    echo "sk-test-minimax-config" | cmd_config "minimax"

    local minimax_key
    minimax_key=$(get_secret "MINIMAX_API_KEY")
    assert_equals "$minimax_key" "sk-test-minimax-config" "MiniMax API key should be stored"

    # Test Kimi configuration with custom model
    cat > "$TEST_TEMP_DIR/kimi_input.txt" <<EOF
sk-test-kimi-config
kimi-custom-model
https://custom.kimi.com/api/
EOF

    # Test Kimi configuration with model and URL settings
    cat "$TEST_TEMP_DIR/kimi_input.txt" | cmd_config "kimi"

    local kimi_key
    kimi_key=$(get_secret "KIMI_API_KEY")
    assert_equals "$kimi_key" "sk-test-kimi-config" "Kimi API key should be stored"

    local kimi_model
    kimi_model=$(get_config "kimi_model")
    assert_equals "$kimi_model" "kimi-custom-model" "Kimi model should be stored"

    local kimi_url
    kimi_url=$(get_config "kimi_base_url")
    assert_equals "$kimi_url" "https://custom.kimi.com/api/" "Kimi URL should be stored"

    cleanup_test_environment "provider_config_test"
    end_test
}

test_custom_provider_configuration() {
    start_test "test_custom_provider_configuration" "Test custom provider configuration"

    setup_test_environment "custom_provider_test"

    # Test custom provider configuration
    cat > "$TEST_TEMP_DIR/custom_input.txt" <<EOF
my-custom-provider
https://custom.api.com/v1/
sk-custom-test-key-123
custom-model-name
EOF

    cat "$TEST_TEMP_DIR/custom_input.txt" | cmd_config "custom"

    # Verify custom provider configuration
    local custom_key
    custom_key=$(get_config "custom_my-custom-provider_api_key")
    assert_equals "$custom_key" "sk-custom-test-key-123" "Custom API key should be stored"

    local custom_url
    custom_url=$(get_config "custom_my-custom-provider_base_url")
    assert_equals "$custom_url" "https://custom.api.com/v1/" "Custom base URL should be stored"

    local custom_model
    custom_model=$(get_config "custom_my-custom-provider_model")
    assert_equals "$custom_model" "custom-model-name" "Custom model should be stored"

    # Test custom provider switching
    mock_claude_command
    assert_command_success "switch_to_custom my-custom-provider --version" "Switch to custom provider should succeed"

    cleanup_test_environment "custom_provider_test"
    end_test
}

test_provider_validation() {
    start_test "test_provider_validation" "Test provider validation scenarios"

    setup_test_environment "provider_validation_test"

    # Test Z.AI without API key
    unset ZAI_API_KEY
    assert_command_failure "switch_to_zai --version" "Switch to Z.AI should fail without API key"

    # Test MiniMax without API key
    unset MINIMAX_API_KEY
    assert_command_failure "switch_to_minimax --version" "Switch to MiniMax should fail without API key"

    # Test Kimi without API key
    unset KIMI_API_KEY
    assert_command_failure "switch_to_kimi --version" "Switch to Kimi should fail without API key"

    # Test invalid provider name
    assert_command_failure "switch_to_invalid_provider --version" "Switch to invalid provider should fail"

    # Test custom provider without configuration
    assert_command_failure "switch_to_custom nonexistent-provider --version" "Switch to nonexistent custom provider should fail"

    cleanup_test_environment "provider_validation_test"
    end_test
}

test_provider_status() {
    start_test "test_provider_status" "Test provider status checking"

    setup_test_environment "provider_status_test"

    # Set up some providers
    export ZAI_API_KEY="sk-zai-status-test"
    export MINIMAX_API_KEY="sk-minimax-status-test"
    set_config "kimi_model" "kimi-test-model"
    set_config "kimi_base_url" "https://api.test.kimi.com/"

    # Test status command
    local status_output
    status_output=$(cmd_status)

    assert_contains "$status_output" "Native Anthropic" "Status should show Native Anthropic"
    assert_contains "$status_output" "Z.AI" "Status should show Z.AI"
    assert_contains "$status_output" "MiniMax" "Status should show MiniMax"
    assert_contains "$status_output" "Kimi" "Status should show Kimi"
    assert_contains "$status_output" "sk-zai****est" "Status should show masked Z.AI key"
    assert_contains "$status_output" "sk-minim****est" "Status should show masked MiniMax key"

    # Test status with encryption
    save_secrets
    status_output=$(cmd_status)
    assert_contains "$status_output" "🔒 Secrets Storage: Encrypted" "Status should show encrypted storage"

    cleanup_test_environment "provider_status_test"
    end_test
}

test_provider_list() {
    start_test "test_provider_list" "Test provider listing functionality"

    setup_test_environment "provider_list_test"

    # Set up providers
    export ZAI_API_KEY="sk-list-test-zai"
    export MINIMAX_API_KEY="sk-list-test-minimax"
    set_config "kimi_model" "kimi-list-model"
    set_config "kimi_base_url" "https://api.list.kimi.com/"
    set_config "custom_testprovider_api_key" "sk-custom-list-key"
    set_config "custom_testprovider_base_url" "https://custom.list.api.com/"

    # Test list command
    local list_output
    list_output=$(cmd_list)

    assert_contains "$list_output" "Native Anthropic" "List should show Native Anthropic"
    assert_contains "$list_output" "Z.AI" "List should show Z.AI"
    assert_contains "$list_output" "MiniMax" "List should show MiniMax"
    assert_contains "$list_output" "Kimi" "List should show Kimi"
    assert_contains "$list_output" "testprovider" "List should show custom provider"
    assert_contains "$list_output" "sk-li****est" "List should show masked keys"

    # Test with encrypted storage
    save_secrets
    list_output=$(cmd_list)
    assert_contains "$list_output" "Storage: [encrypted]" "List should show encrypted storage"

    cleanup_test_environment "provider_list_test"
    end_test
}

test_provider_test_function() {
    start_test "test_provider_test_function" "Test provider testing functionality"

    setup_test_environment "provider_test_test"

    # Mock claude test command
    cat > "$TEST_TEMP_DIR/claude" <<EOF
#!/bin/bash
if [[ "\$1" == "test" && "\$2" == "--dangerously-skip-permissions" ]]; then
    echo "Test successful"
    exit 0
fi
echo "Claude called with: \$*"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    export PATH="$TEST_TEMP_DIR:$PATH"

    # Test Z.AI provider test
    export ZAI_API_KEY="sk-test-zai-key"
    cmd_test "zai"

    # Test MiniMax provider test
    export MINIMAX_API_KEY="sk-test-minimax-key"
    cmd_test "minimax"

    # Test Kimi provider test
    export KIMI_API_KEY="sk-test-kimi-key"
    set_config "kimi_model" "kimi-test-model"
    set_config "kimi_base_url" "https://api.test.kimi.com/"
    cmd_test "kimi"

    # Test Native Anthropic provider test
    cmd_test "anthropic"

    # Test custom provider test
    set_config "custom_testcustom_api_key" "sk-test-custom-key"
    set_config "custom_testcustom_base_url" "https://custom.test.api.com/"
    cmd_test "testcustom"

    cleanup_test_environment "provider_test_test"
    end_test
}

test_default_provider() {
    start_test "test_default_provider" "Test default provider functionality"

    setup_test_environment "default_provider_test"

    # Test showing default (none)
    local default_output
    default_output=$(cmd_default)
    assert_contains "$default_output" "No default provider set" "Should show no default set"

    # Set default provider
    cmd_default "zai"

    # Show default
    default_output=$(cmd_default)
    assert_equals "$default_output" "Current default provider: zai" "Should show Z.AI as default"

    # Set another default
    export MINIMAX_API_KEY="sk-default-minimax-key"
    cmd_default "minimax"

    default_output=$(cmd_default)
    assert_equals "$default_output" "Current default provider: minimax" "Should show MiniMax as default"

    # Test invalid default provider
    assert_command_failure "cmd_default 'invalid-provider'" "Setting invalid provider should fail"

    cleanup_test_environment "default_provider_test"
    end_test
}

test_provider_environment_setup() {
    start_test "test_provider_environment_setup" "Test provider environment variable setup"

    setup_test_environment "provider_env_test"

    # Mock claude to capture environment
    cat > "$TEST_TEMP_DIR/claude" <<EOF
#!/bin/bash
echo "ANTHROPIC_BASE_URL: \$ANTHROPIC_BASE_URL"
echo "ANTHROPIC_AUTH_TOKEN: \$ANTHROPIC_AUTH_TOKEN"
echo "ANTHROPIC_MODEL: \$ANTHROPIC_MODEL"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    export PATH="$TEST_TEMP_DIR:$PATH"

    # Test Z.AI environment setup
    export ZAI_API_KEY="sk-zai-env-test"
    switch_to_zai --version

    # Test MiniMax environment setup
    export MINIMAX_API_KEY="sk-minimax-env-test"
    switch_to_minimax --version

    # Test Kimi environment setup
    export KIMI_API_KEY="sk-kimi-env-test"
    set_config "kimi_model" "kimi-env-model"
    set_config "kimi_base_url" "https://env.kimi.com/api/"
    switch_to_kimi --version

    cleanup_test_environment "provider_env_test"
    end_test
}

test_provider_error_scenarios() {
    start_test "test_provider_error_scenarios" "Test provider error scenarios"

    setup_test_environment "provider_error_test"

    # Test configuration with invalid API keys
    echo "invalid-key" | cmd_config "zai" 2>/dev/null || true

    # Test configuration with missing required fields
    echo "" | cmd_config "zai" 2>/dev/null || true

    # Test configuration with invalid URLs
    cat > "$TEST_TEMP_DIR/invalid_input.txt" <<EOF
sk-test-key
invalid-url-not-a-url
EOF

    cat "$TEST_TEMP_DIR/invalid_input.txt" | cmd_config "kimi" 2>/dev/null || true

    # Test configuration with reserved names
    cat > "$TEST_TEMP_DIR/reserved_input.txt" <<EOF
sk-test-key
http://valid-url.com
sk-test-key
EOF

    # Should fail for reserved name
    assert_command_failure "validate_provider_name 'anthropic'" "Reserved provider name should fail"

    cleanup_test_environment "provider_error_test"
    end_test
}

# Run all provider tests
main() {
    echo "Starting provider tests..."

    test_provider_switching_basic
    test_provider_configuration
    test_custom_provider_configuration
    test_provider_validation
    test_provider_status
    test_provider_list
    test_provider_test_function
    test_default_provider
    test_provider_environment_setup
    test_provider_error_scenarios

    echo "Provider tests completed."
}

# If this file is run directly, execute tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi