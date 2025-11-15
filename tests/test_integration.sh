#!/usr/bin/env bash
# shellcheck disable=SC1091
# Integration tests for clauver end-to-end scenarios

# Source the test framework and clauver script
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../clauver.sh"

# Test suite for integration scenarios
test_full_workflow_setup_to_usage() {
    start_test "test_full_workflow_setup_to_usage" "Test complete workflow from setup to usage"

    setup_test_environment "full_workflow_test"

    # Mock claude command
    cat > "$TEST_TEMP_DIR/claude" <<EOF
#!/bin/bash
echo "Mock Claude executed with: \$*"
if [[ "\$1" == "test" ]]; then
    echo "Test successful"
    exit 0
fi
echo "Hello from mock Claude!"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    export PATH="$TEST_TEMP_DIR:$PATH"

    # Step 1: Test setup wizard (choose option 1 - Native Anthropic)
    echo "1" | cmd_setup 2>/dev/null || true

    # Step 2: Configure Z.AI provider
    echo "sk-test-zai-integration-key" | cmd_config "zai" 2>/dev/null || true

    # Step 3: Configure MiniMax provider
    echo "sk-test-minimax-integration-key" | cmd_config "minimax" 2>/dev/null || true

    # Step 4: Set Z.AI as default
    cmd_default "zai"

    # Step 5: Verify setup
    local list_output
    list_output=$(cmd_list)
    assert_contains "$list_output" "Z.AI" "Z.AI should be configured"
    assert_contains "$list_output" "MiniMax" "MiniMax should be configured"

    # Step 6: Test default provider usage
    switch_to_zai --version

    # Step 7: Test provider testing
    cmd_test "zai"

    # Step 8: Test status
    local status_output
    status_output=$(cmd_status)
    assert_contains "$status_output" "Z.AI" "Status should show Z.AI configured"

    # Step 9: Check version
    local version_output
    version_output=$(cmd_version)
    assert_contains "$version_output" "v1.8.0" "Version should be displayed"

    cleanup_test_environment "full_workflow_test"
    end_test
}

test_secrets_migration_workflow() {
    start_test "test_secrets_migration_workflow" "Test secrets migration workflow"

    setup_test_environment "migration_workflow_test"

    # Create initial plaintext secrets
    cat > "$CLAUVER_HOME/secrets.env" <<EOF
ZAI_API_KEY=sk-plaintext-migration-zai-123
MINIMAX_API_KEY=sk-plaintext-migration-minimax-456
KIMI_API_KEY=sk-plaintext-migration-kimi-789
EOF

    # Ensure age key exists
    ensure_age_key

    # Run migration
    cmd_migrate

    # Verify encryption
    assert_file_exists "$CLAUVER_HOME/secrets.env.age" "Encrypted file should exist"
    assert_file_not_exists "$CLAUVER_HOME/secrets.env" "Plaintext file should be removed"

    # Verify migration works
    load_secrets

    local migrated_zai
    migrated_zai=$(get_secret "ZAI_API_KEY")
    assert_equals "$migrated_zai" "sk-plaintext-migration-zai-123" "Migrated Z.AI key should be accessible"

    local migrated_minimax
    migrated_minimax=$(get_secret "MINIMAX_API_KEY")
    assert_equals "$migrated_minimax" "sk-plaintext-migration-minimax-456" "Migrated MiniMax key should be accessible"

    local migrated_kimi
    migrated_kimi=$(get_secret "KIMI_API_KEY")
    assert_equals "$migrated_kimi" "sk-plaintext-migration-kimi-789" "Migrated Kimi key should be accessible"

    # Test that second migration doesn't break anything
    cmd_migrate

    cleanup_test_environment "migration_workflow_test"
    end_test
}

test_provider_switching_workflow() {
    start_test "test_provider_switching_workflow" "Test provider switching workflow"

    setup_test_environment "switching_workflow_test"

    # Mock claude command
    cat > "$TEST_TEMP_DIR/claude" <<EOF
#!/bin/bash
echo "Provider: \$1 - Mock Claude executed"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    export PATH="$TEST_TEMP_DIR:$PATH"

    # Configure multiple providers
    export ZAI_API_KEY="sk-switch-zai-key"
    export MINIMAX_API_KEY="sk-switch-minimax-key"
    export KIMI_API_KEY="sk-switch-kimi-key"
    set_config "kimi_model" "kimi-switch-model"
    set_config "kimi_base_url" "https://switch.kimi.com/api/"

    # Test switching between providers
    switch_to_zai --version
    switch_to_minimax --version
    switch_to_kimi --version

    # Set and use default provider
    cmd_default "minimax"
    switch_to_minimax --version

    # Test custom provider
    set_config "custom_switchcustom_api_key" "sk-switch-custom-key"
    set_config "custom_switchcustom_base_url" "https://switchcustom.api.com/"
    switch_to_custom switchcustom --version

    # Test provider list shows all configured providers
    local list_output
    list_output=$(cmd_list)
    assert_contains "$list_output" "Z.AI" "Should show Z.AI"
    assert_contains "$list_output" "MiniMax" "Should show MiniMax"
    assert_contains "$list_output" "Kimi" "Should show Kimi"
    assert_contains "$list_output" "switchcustom" "Should show custom provider"

    cleanup_test_environment "switching_workflow_test"
    end_test
}

test_update_workflow() {
    start_test "test_update_workflow" "Test update workflow (simulated)"

    setup_test_environment "update_workflow_test"

    # Mock GitHub API response
    cat > "$TEST_TEMP_DIR/curl" <<EOF
#!/bin/bash
if [[ "\$*" == *"github.com"*"tags"* ]]; then
    echo '[{"name": "v1.6.2"}]'
else
    echo "Mock curl called with: \$*"
    exit 0
fi
EOF
    chmod +x "$TEST_TEMP_DIR/curl"
    export PATH="$TEST_TEMP_DIR:$PATH"

    # Mock Python for JSON parsing
    cat > "$TEST_TEMP_DIR/python3" <<EOF
#!/bin/bash
echo "Mock python3 called"
echo "v1.6.2"
EOF
    chmod +x "$TEST_TEMP_DIR/python3"

    # Mock sha256sum
    cat > "$TEST_TEMP_DIR/sha256sum" <<EOF
#!/bin/bash
echo "mocksha256checksum filename"
EOF
    chmod +x "$TEST_TEMP_DIR/sha256sum"

    # Temporarily modify version to test update detection
    local original_version="$VERSION"
    VERSION="1.8.0"

    # Test version check (simulate update available)
    local version_output
    version_output=$(cmd_version 2>/dev/null) || true

    # Restore original version
    VERSION="$original_version"

    cleanup_test_environment "update_workflow_test"
    end_test
}

test_configuration_workflow() {
    start_test "test_configuration_workflow" "Test configuration management workflow"

    setup_test_environment "configuration_workflow_test"

    # Test setting various configurations
    set_config "test_global_config" "global_value"
    set_config "zai_model" "glm-4.5-test"
    set_config "minimax_model" "MiniMax-M2-test"

    # Test provider-specific configurations
    cmd_config "anthropic" 2>/dev/null || true

    echo "sk-test-zai-config-key" | cmd_config "zai" 2>/dev/null || true

    # Verify configurations are stored
    local global_config
    global_config=$(get_config "test_global_config")
    assert_equals "$global_config" "global_value" "Global config should be stored"

    local zai_model
    zai_model=$(get_config "zai_model")
    assert_equals "$zai_model" "glm-4.5-test" "Z.AI model config should be stored"

    # Test custom provider configuration
    cat > "$TEST_TEMP_DIR/custom_input.txt" <<EOF
workflow-custom-provider
https://workflow.custom.api.com/
sk-workflow-custom-key
workflow-custom-model
EOF

    cat "$TEST_TEMP_DIR/custom_input.txt" | cmd_config "custom" 2>/dev/null || true

    local custom_key
    custom_key=$(get_config "custom_workflow-custom-provider_api_key")
    assert_equals "$custom_key" "sk-workflow-custom-key" "Custom provider key should be stored"

    # Test configuration listing
    local list_output
    list_output=$(cmd_list)
    assert_contains "$list_output" "workflow-custom-provider" "Custom provider should be listed"

    cleanup_test_environment "configuration_workflow_test"
    end_test
}

test_error_recovery_workflow() {
    start_test "test_error_recovery_workflow" "Test error recovery workflow"

    setup_test_environment "error_recovery_test"

    # Test scenario 1: Missing age key
    rm -f "$CLAUVER_HOME/age.key"

    # Should fail gracefully and provide helpful error
    assert_command_failure "save_secrets" "Save should fail without age key"

    # Recovery: create age key
    ensure_age_key

    # Should now succeed
    export ZAI_API_KEY="sk-recovery-test-key"
    assert_command_success "save_secrets" "Save should succeed after recovery"

    # Test scenario 2: Corrupted encrypted file
    echo "corrupted content" > "$CLAUVER_HOME/secrets.env.age"

    assert_command_failure "load_secrets" "Load should fail with corrupted file"

    # Recovery: remove corrupted file and recreate
    rm -f "$CLAUVER_HOME/secrets.env.age"
    save_secrets

    # Should now work
    assert_command_success "load_secrets" "Load should succeed after recovery"

    # Test scenario 3: Invalid config format
    echo "invalid_config_line_without_equals" > "$CLAUVER_HOME/config"

    # Should still handle gracefully
    load_config_cache
    assert_equals "$CONFIG_CACHE_LOADED" "1" "Config cache should still load"

    cleanup_test_environment "error_recovery_test"
    end_test
}

test_shell_integration_workflow() {
    start_test "test_shell_integration_workflow" "Test shell integration workflow"

    setup_test_environment "shell_integration_test"

    # Mock claude command
    cat > "$TEST_TEMP_DIR/claude" <<EOF
#!/bin/bash
echo "Mock Claude executed in shell integration"
echo "Arguments received: \$*"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    export PATH="$TEST_TEMP_DIR:$PATH"

    # Configure providers
    export ZAI_API_KEY="sk-shell-integration-key"
    export MINIMAX_API_KEY="sk-shell-integration-minimax"

    # Test direct provider commands
    switch_to_zai --help
    switch_to_minimax --version

    # Set default and test usage
    cmd_default "zai"
    switch_to_zai --version

    # Test with arguments passed through
    switch_to_zai --help --dangerously-skip-permissions

    # Test custom provider
    set_config "custom_shellcustom_api_key" "sk-shell-custom-key"
    set_config "custom_shellcustom_base_url" "https://shellcustom.api.com/"
    switch_to_custom shellcustom --version

    cleanup_test_environment "shell_integration_test"
    end_test
}

test_encryption_security_workflow() {
    start_test "test_encryption_security_workflow" "Test encryption security workflow"

    setup_test_environment "encryption_security_test"

    # Set up secrets
    export ZAI_API_KEY="security-test-zai-key-123456"
    export MINIMAX_API_KEY="security-test-minimax-key-789012"
    export KIMI_API_KEY="security-test-kimi-key-345678"

    # Test saving to encrypted storage
    save_secrets

    # Verify files exist with correct permissions
    assert_file_exists "$CLAUVER_HOME/secrets.env.age" "Encrypted file should exist"
    assert_file_not_exists "$CLAUVER_HOME/secrets.env" "Plaintext file should not exist"

    local age_permissions
    age_permissions=$(stat -c "%a" "$CLAUVER_HOME/secrets.env.age")
    assert_equals "$age_permissions" "600" "Encrypted file should have 600 permissions"

    # Test loading and verification
    load_secrets

    local zai_loaded
    zai_loaded=$(get_secret "ZAI_API_KEY")
    assert_equals "$zai_loaded" "security-test-zai-key-123456" "Z.AI key should load correctly"

    # Test secrets are not visible in environment after loading
    assert_equals "${ZAI_API_KEY:-}" "" "Z.AI key should not be in environment after load"

    # Test masking functionality
    local masked_key
    masked_key=$(mask_key "security-test-zai-key-123456")
    assert_equals "$masked_key" "secur****56" "Key should be properly masked"

    # Test secure configuration
    set_config "secure_config_key" "secure_value"
    local config_permissions
    config_permissions=$(stat -c "%a" "$CLAUVER_HOME/config")
    assert_equals "$config_permissions" "600" "Config file should have 600 permissions"

    cleanup_test_environment "encryption_security_test"
    end_test
}

# Run all integration tests
main() {
    echo "Starting integration tests..."

    test_full_workflow_setup_to_usage
    test_secrets_migration_workflow
    test_provider_switching_workflow
    test_update_workflow
    test_configuration_workflow
    test_error_recovery_workflow
    test_shell_integration_workflow
    test_encryption_security_workflow

    echo "Integration tests completed."
}

# If this file is run directly, execute tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
