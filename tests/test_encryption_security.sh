#!/usr/bin/env bash
# shellcheck disable=SC1091
# Comprehensive encryption and security tests for clauver

# Source the test framework and clauver script
source "$(dirname "${BASH_SOURCE[0]}")/test-framework.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../clauver.sh"

# Test suite for encryption and security functions
test_age_encryption_basic() {
    start_test "test_age_encryption_basic" "Test basic age encryption/decryption functionality"

    setup_test_environment "encryption_basic_test"

    # Create test secrets
    export ZAI_API_KEY="sk-test-zai-key-123456789"
    export MINIMAX_API_KEY="sk-test-minimax-key-987654321"
    export KIMI_API_KEY="sk-test-kimi-key-abcdef123"

    # Test save_secrets function
    assert_command_success "save_secrets" "Save secrets should succeed"

    # Verify encrypted file exists
    assert_file_exists "$CLAUVER_HOME/secrets.env.age" "Encrypted secrets file should exist"

    # Verify permissions on encrypted file
    local age_permissions
    age_permissions=$(stat -c "%a" "$CLAUVER_HOME/secrets.env.age")
    assert_equals "$age_permissions" "600" "Encrypted file should have 600 permissions"

    # Test that plaintext file is removed after encryption
    assert_file_not_exists "$CLAUVER_HOME/secrets.env" "Plaintext file should be removed after encryption"

    cleanup_test_environment "encryption_basic_test"
    end_test
}

test_age_decryption() {
    start_test "test_age_decryption" "Test age decryption functionality"

    setup_test_environment "encryption_decryption_test"

    # Set up test secrets
    export ZAI_API_KEY="sk-test-zai-decrypt-123"
    export MINIMAX_API_KEY="sk-test-minimax-decrypt-456"

    # Save encrypted secrets
    save_secrets

    # Clear environment variables to test decryption
    unset ZAI_API_KEY
    unset MINIMAX_API_KEY

    # Test load_secrets function
    assert_command_success "load_secrets" "Load secrets should succeed"

    # Verify decrypted secrets are available
    local decrypted_zai_key
    decrypted_zai_key=$(get_secret "ZAI_API_KEY")
    assert_equals "$decrypted_zai_key" "sk-test-zai-decrypt-123" "Decrypted Z.AI key should be available"

    local decrypted_minimax_key
    decrypted_minimax_key=$(get_secret "MINIMAX_API_KEY")
    assert_equals "$decrypted_minimax_key" "sk-test-minimax-decrypt-456" "Decrypted MiniMax key should be available"

    cleanup_test_environment "encryption_decryption_test"
    end_test
}

test_secrets_management() {
    start_test "test_secrets_management" "Test secret management operations"

    setup_test_environment "secrets_management_test"

    # Test get_secret with no secrets loaded
    assert_command_failure "get_secret 'ZAI_API_KEY'" "Getting secret before loading should fail"

    # Set up initial secrets
    export ZAI_API_KEY="initial-key-123"

    # Save initial secrets
    save_secrets

    # Add new secret using set_secret
    set_secret "MINIMAX_API_KEY" "new-key-456"

    # Verify both secrets exist
    local initial_key
    initial_key=$(get_secret "ZAI_API_KEY")
    assert_equals "$initial_key" "initial-key-123" "Initial key should still exist"

    local new_key
    new_key=$(get_secret "MINIMAX_API_KEY")
    assert_equals "$new_key" "new-key-456" "New key should exist"

    # Test removing a secret (by setting empty value)
    export MINIMAX_API_KEY=""
    save_secrets

    local removed_key
    removed_key=$(get_secret "MINIMAX_API_KEY")
    assert_equals "$removed_key" "" "Key should be removed"

    cleanup_test_environment "secrets_management_test"
    end_test
}

test_encryption_error_handling() {
    start_test "test_encryption_error_handling" "Test encryption error handling scenarios"

    setup_test_environment "encryption_error_test"

    # Test save_secrets without age command
    export PATH="/usr/bin:/bin"  # Remove age from PATH
    export ZAI_API_KEY="test-key"

    assert_command_failure "save_secrets" "Save should fail without age command"

    # Test load_secrets without age command
    create_age_key  # Ensure we have a key file but no age command

    assert_command_failure "load_secrets" "Load should fail without age command"

    # Test load_secrets without age key
    rm -f "$CLAUVER_HOME/age.key"
    export PATH="/usr/bin:/bin"  # Ensure no age command

    assert_command_failure "load_secrets" "Load should fail without age key"

    # Test save_secrets with invalid age key
    create_age_key
    echo "invalid-key-content" > "$CLAUVER_HOME/age.key"
    export ZAI_API_KEY="test-key"

    assert_command_failure "save_secrets" "Save should fail with invalid age key"

    cleanup_test_environment "encryption_error_test"
    end_test
}

test_encryption_migration() {
    start_test "test_encryption_migration" "Test migration from plaintext to encrypted storage"

    setup_test_environment "encryption_migration_test"

    # Create plaintext secrets file
    cat > "$CLAUVER_HOME/secrets.env" <<EOF
ZAI_API_KEY=sk-plaintext-zai-key-123
MINIMAX_API_KEY=sk-plaintext-minimax-key-456
EOF

    # Ensure age key exists
    ensure_age_key
    assert_file_exists "$CLAUVER_HOME/age.key"

    # Run migration
    assert_command_success "cmd_migrate" "Migration command should succeed"

    # Verify encrypted file exists
    assert_file_exists "$CLAUVER_HOME/secrets.env.age" "Encrypted file should exist after migration"

    # Verify plaintext file is removed
    assert_file_not_exists "$CLAUVER_HOME/secrets.env" "Plaintext file should be removed after migration"

    # Verify we can load the migrated secrets
    load_secrets

    local migrated_zai_key
    migrated_zai_key=$(get_secret "ZAI_API_KEY")
    assert_equals "$migrated_zai_key" "sk-plaintext-zai-key-123" "Migrated Z.AI key should be accessible"

    local migrated_minimax_key
    migrated_minimax_key=$(get_secret "MINIMAX_API_KEY")
    assert_equals "$migrated_minimax_key" "sk-plaintext-minimax-key-456" "Migrated MiniMax key should be accessible"

    # Test running migration twice (should not fail)
    assert_command_success "cmd_migrate" "Second migration should not fail"

    cleanup_test_environment "encryption_migration_test"
    end_test
}

test_config_file_security() {
    start_test "test_config_file_security" "Test configuration file security"

    setup_test_environment "config_security_test"

    # Test that config file has correct permissions
    set_config "test_config_key" "test_config_value"

    local config_permissions
    config_permissions=$(stat -c "%a" "$CLAUVER_HOME/config")
    assert_equals "$config_permissions" "600" "Config file should have 600 permissions"

    # Test config key validation
    assert_command_failure "set_config 'invalid key with spaces' 'value'" "Invalid config key with spaces should fail"
    assert_command_failure "set_config 'key-with-@-symbol' 'value'" "Invalid config key with @ symbol should fail"

    # Test config value escaping
    set_config "escape_test" "value with spaces and special chars: !@#$%"
    local escaped_value
    escaped_value=$(get_config "escape_test")
    assert_equals "$escaped_value" "value with spaces and special chars: !@#$%" "Config value should be preserved correctly"

    cleanup_test_environment "config_security_test"
    end_test
}

test_input_validation_security() {
    start_test "test_input_validation_security" "Test input validation for security"

    setup_test_environment "input_validation_test"

    # Test API key validation against injection attempts
    assert_command_failure "validate_api_key 'sk-test; rm -rf /' 'zai'" "API key with command injection should fail"
    assert_command_failure "validate_api_key 'sk-test\"; echo hacked\"' 'zai'" "API key with quote injection should fail"
    assert_command_failure "validate_api_key 'sk-test\$(echo hacked)' 'zai'" "API key with command substitution should fail"

    # Test URL validation against attacks
    assert_command_failure "validate_url 'javascript:alert(\"xss\")'" "JavaScript URL should fail"
    assert_command_failure "validate_url 'data:text/html,<script>alert(1)</script>'" "Data URL should fail"
    assert_command_failure "validate_url 'file:///etc/passwd'" "File URL should fail"
    assert_command_failure "validate_url 'ftp://attacker.com/malicious'" "FTP protocol should fail"

    # Test model name validation
    assert_command_failure "validate_model_name 'model; rm -rf /'" "Model name with command injection should fail"
    assert_command_failure "validate_model_name 'model\$(whoami)'\" 'zai'" "Model name with command substitution should fail"

    cleanup_test_environment "input_validation_test"
    end_test
}

test_secrets_caching() {
    start_test "test_secrets_caching" "Test secrets caching mechanism"

    setup_test_environment "secrets_caching_test"

    # Set up multiple API keys
    export ZAI_API_KEY="cached-zai-key-123"
    export MINIMAX_API_KEY="cached-minimax-key-456"
    export KIMI_API_KEY="cached-kimi-key-789"

    # Save secrets
    save_secrets

    # Clear environment to test loading
    unset ZAI_API_KEY
    unset MINIMAX_API_KEY
    unset KIMI_API_KEY

    # Load secrets and verify SECRETS_LOADED flag
    load_secrets
    assert_equals "$SECRETS_LOADED" "1" "SECRETS_LOADED should be 1 after loading"

    # Test that subsequent calls don't reload
    SECRETS_LOADED=0
    load_secrets
    assert_equals "$SECRETS_LOADED" "0" "SECRETS_LOADED should remain 0 (already loaded)"

    # Test accessing secrets after caching
    local cached_zai_key
    cached_zai_key=$(get_secret "ZAI_API_KEY")
    assert_equals "$cached_zai_key" "cached-zai-key-123" "Cached Z.AI key should be accessible"

    local cached_minimax_key
    cached_minimax_key=$(get_secret "MINIMAX_API_KEY")
    assert_equals "$cached_minimax_key" "cached-minimax-key-456" "Cached MiniMax key should be accessible"

    local cached_kimi_key
    cached_kimi_key=$(get_secret "KIMI_API_KEY")
    assert_equals "$cached_kimi_key" "cached-kimi-key-789" "Cached Kimi key should be accessible"

    cleanup_test_environment "secrets_caching_test"
    end_test
}

test_config_caching() {
    start_test "test_config_caching" "Test configuration caching mechanism"

    setup_test_environment "config_caching_test"

    # Set multiple config values
    set_config "cache_test_1" "value1"
    set_config "cache_test_2" "value2"
    set_config "cache_test_3" "value3"

    # Verify cache is initially not loaded
    assert_equals "$CONFIG_CACHE_LOADED" "0" "CONFIG_CACHE_LOADED should be 0 initially"

    # Load config cache
    load_config_cache
    assert_equals "$CONFIG_CACHE_LOADED" "1" "CONFIG_CACHE_LOADED should be 1 after loading"

    # Test getting values from cache
    local cached_value1
    cached_value1=$(get_config "cache_test_1")
    assert_equals "$cached_value1" "value1" "Cached value 1 should be correct"

    local cached_value2
    cached_value2=$(get_config "cache_test_2")
    assert_equals "$cached_value2" "value2" "Cached value 2 should be correct"

    local cached_value3
    cached_value3=$(get_config "cache_test_3")
    assert_equals "$cached_value3" "value3" "Cached value 3 should be correct"

    # Test adding new value after cache is loaded
    set_config "cache_test_4" "value4"
    assert_equals "$CONFIG_CACHE_LOADED" "0" "Cache should be invalidated after setting config"

    # Reload cache
    load_config_cache
    local new_cached_value
    new_cached_value=$(get_config "cache_test_4")
    assert_equals "$new_cached_value" "value4" "New value should be in cache after reload"

    cleanup_test_environment "config_caching_test"
    end_test
}

test_age_key_backup() {
    start_test "test_age_key_backup" "Test age key backup and recovery"

    setup_test_environment "age_key_backup_test"

    # Create initial age key
    ensure_age_key
    local original_key_content
    original_key_content=$(cat "$CLAUVER_HOME/age.key")

    # Create some encrypted secrets
    export ZAI_API_KEY="backup-test-key"
    save_secrets

    # Backup the key
    cp "$CLAUVER_HOME/age.key" "$CLAUVER_HOME/age.key.backup"

    # Remove the original key
    rm -f "$CLAUVER_HOME/age.key"

    # Restore from backup
    cp "$CLAUVER_HOME/age.key.backup" "$CLAUVER_HOME/age.key"

    # Test that we can still decrypt secrets
    load_secrets

    local decrypted_key
    decrypted_key=$(get_secret "ZAI_API_KEY")
    assert_equals "$decrypted_key" "backup-test-key" "Decryption should work after key restore"

    cleanup_test_environment "age_key_backup_test"
    end_test
}

# Helper function to create age key for testing
create_age_key() {
    local test_key_content="TEST_AGE_PRIVATE_KEY_GENERATED_FOR_TESTING"
    echo "$test_key_content" > "$CLAUVER_HOME/age.key"
    chmod 600 "$CLAUVER_HOME/age.key"
}

# Run all encryption and security tests
main() {
    echo "Starting encryption and security tests..."

    test_age_encryption_basic
    test_age_decryption
    test_secrets_management
    test_encryption_error_handling
    test_encryption_migration
    test_config_file_security
    test_input_validation_security
    test_secrets_caching
    test_config_caching
    test_age_key_backup

    echo "Encryption and security tests completed."
}

# If this file is run directly, execute tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi