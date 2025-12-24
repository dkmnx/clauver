#!/usr/bin/env bash
# shellcheck disable=SC1091
# Performance and mock/stub framework tests for clauver

# Source the test framework first
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Initialize test framework BEFORE sourcing clauver.sh to ensure CLAUVER_HOME is set
test_framework_init

# Source clauver script AFTER framework initialization with correct environment
source "$(dirname "${BASH_SOURCE[0]}")/../clauver.sh"

# Performance testing framework
measure_performance() {
    local command="$1"
    local timeout="${2:-30}"

    # Start time measurement
    local start_time
    start_time=$(date +%s.%N)

    # Execute command with timeout
    timeout "$timeout" bash -c "$command" >/dev/null 2>&1

    # End time measurement
    local end_time
    end_time=$(date +%s.%N)

    # Calculate duration
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")

    echo "$duration"
}

# Mock performance testing functions
test_performance_constants_accuracy() {
    start_test "test_performance_constants_accuracy" "Test performance constants are correctly defined"

    setup_test_environment "performance_constants_test"

    # Verify all performance constants are properly set
    local network_timeout="${PERFORMANCE_DEFAULTS[network_connect_timeout]}"
    local max_time="${PERFORMANCE_DEFAULTS[network_max_time]}"
    local minimax_timeout="${PERFORMANCE_DEFAULTS[minimax_small_fast_timeout]}"
    local kimi_timeout="${PERFORMANCE_DEFAULTS[kimi_small_fast_timeout]}"
    local test_timeout="${PERFORMANCE_DEFAULTS[test_api_timeout_ms]}"

    assert_equals "$network_timeout" "10" "Network timeout should be 10 seconds"
    assert_equals "$max_time" "30" "Max time should be 30 seconds"
    assert_equals "$minimax_timeout" "120" "MiniMax timeout should be 120 seconds"
    assert_equals "$kimi_timeout" "240" "Kimi timeout should be 240 seconds"
    assert_equals "$test_timeout" "3000000" "Test timeout should be 3000000ms"

    cleanup_test_environment "performance_constants_test"
    end_test
}

test_encryption_performance() {
    start_test "test_encryption_performance" "Test encryption performance"

    setup_test_environment "encryption_performance_test"

    # Source clauver script AFTER setting up test environment to get correct paths
    source "$TEST_ROOT/../clauver.sh"

    # Ensure age key exists for encryption tests
    ensure_age_key

    # Test encryption performance with different data sizes
    export ZAI_API_KEY="sk-performance-test-key"

    # Time save_secrets operation
    measure_performance "save_secrets" >/dev/null

    assert_command_success "save_secrets" "Encryption should succeed"
    assert_file_exists "$CLAUVER_HOME/secrets.env.age" "Encrypted file should exist"

    # Test decryption performance
    load_secrets
    assert_equals "$SECRETS_LOADED" "1" "Secrets should be loaded"

    # Test multiple key saves
    for i in {1..5}; do
        export ZAI_API_KEY="sk-multi-test-key-$i"
        save_secrets >/dev/null 2>&1
    done

    echo "Encryption performance test completed"

    cleanup_test_environment "encryption_performance_test"
    end_test
}

test_config_caching_performance() {
    start_test "test_config_caching_performance" "Test configuration caching performance"

    setup_test_environment "config_caching_test"

    # Set up many configuration values
    for i in {1..100}; do
        set_config "perf_test_key_$i" "perf_test_value_$i"
    done

    # Time cache loading
    local cache_load_time
    cache_load_time=$(measure_performance "source $CLAUVER_SCRIPT && load_config_cache")
    echo "Cache load time: ${cache_load_time}s"

    # Time cache access
    local cache_access_time
    cache_access_time=$(measure_performance "source $CLAUVER_SCRIPT && get_config 'perf_test_key_50'")
    echo "Cache access time: ${cache_access_time}s"

    # Time reload vs cache hit
    load_config_cache
    local cache_hit_time
    cache_hit_time=$(measure_performance "source $CLAUVER_SCRIPT && get_config 'perf_test_key_50'")
    echo "Cache hit time: ${cache_hit_time}s"

    # Verify caching works
    assert_command_success "get_config 'perf_test_key_1'" "Should access cached config"
    assert_equals "$CONFIG_CACHE_LOADED" "1" "Cache should be loaded"

    echo "Config caching performance test completed"

    cleanup_test_environment "config_caching_test"
    end_test
}

test_provider_switching_performance() {
    start_test "test_provider_switching_performance" "Test provider switching performance"

    setup_test_environment "provider_switching_test"

    # Mock claude command
    cat > "$TEST_TEMP_DIR/claude" <<EOF
#!/bin/bash
sleep 0.1  # Simulate some processing time
echo "Mock Claude executed"
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    export PATH="$TEST_TEMP_DIR:$PATH"

    # Set up providers
    export ZAI_API_KEY="sk-perf-zai-key"
    export MINIMAX_API_KEY="sk-perf-minimax-key"
    export KIMI_API_KEY="sk-perf-kimi-key"
    set_config "kimi_model" "kimi-perf-model"
    set_config "kimi_base_url" "https://perf.kimi.com/api/"

    # Test switching performance
    local switch_zai_time
    switch_zai_time=$(measure_performance "source $CLAUVER_SCRIPT && switch_to_zai --version")
    echo "ZAI switch time: ${switch_zai_time}s"

    local switch_minimax_time
    switch_minimax_time=$(measure_performance "source $CLAUVER_SCRIPT && switch_to_minimax --version")
    echo "MiniMax switch time: ${switch_minimax_time}s"

    local switch_kimi_time
    switch_kimi_time=$(measure_performance "source $CLAUVER_SCRIPT && switch_to_kimi --version")
    echo "Kimi switch time: ${switch_kimi_time}s"

    # Test custom provider switching
    set_config "custom_perf_api_key" "sk-perf-custom-key"
    set_config "custom_perf_base_url" "https://perf.custom.com/"
    local switch_custom_time
    switch_custom_time=$(measure_performance "source $CLAUVER_SCRIPT && switch_to_custom perf --version")
    echo "Custom provider switch time: ${switch_custom_time}s"

    echo "Provider switching performance test completed"

    cleanup_test_environment "provider_switching_test"
    end_test
}

test_memory_usage() {
    start_test "test_memory_usage" "Test memory usage patterns"

    setup_test_environment "memory_usage_test"

    # Check memory usage before operations
    local initial_memory
    initial_memory=$(ps -p $$ -o rss=)

    # Set up large configuration
    for i in {1..200}; do
        set_config "memory_test_key_$i" "memory_test_value_$(printf 'a%.0s' {1..50})"
    done

    # Set up secrets
    local zai_key
    zai_key="memory-test-key-with-extra-data-$(printf 'a%.0s' {1..100})"
    export ZAI_API_KEY="$zai_key"
    local minimax_key
    minimax_key="memory-test-minimax-key-with-extra-data-$(printf 'a%.0s' {1..100})"
    export MINIMAX_API_KEY="$minimax_key"

    # Trigger memory operations
    save_secrets
    load_secrets
    load_config_cache

    # Check memory usage after operations
    local final_memory
    final_memory=$(ps -p $$ -o rss=)

    # Calculate memory increase (should be reasonable)
    local memory_increase=$((final_memory - initial_memory))

    echo "Memory usage test completed. Increase: ${memory_increase}KB"

    # Reset loaded state to clean up
    SECRETS_LOADED=0
    CONFIG_CACHE_LOADED=0

    cleanup_test_environment "memory_usage_test"
    end_test
}

test_disk_usage() {
    start_test "test_disk_usage" "Test disk usage patterns"

    setup_test_environment "disk_usage_test"

    # Check initial disk usage
    local initial_disk_usage
    initial_disk_usage=$(du -sb "$TEST_TEMP_DIR" | cut -f1)

    # Create many configuration entries
    for i in {1..500}; do
        set_config "disk_test_key_$i" "disk_test_value_$(printf 'a%.0s' {1..100})"
    done

    # Set up secrets
    for i in {1..100}; do
        local var_name="TEST_KEY_$i"
        export "$var_name"="test-key-xxxx$(printf 'a%.0s' {1..50})"
    done

    save_secrets

    # Check final disk usage
    local final_disk_usage
    final_disk_usage=$(du -sb "$TEST_TEMP_DIR" | cut -f1)

    local disk_increase=$((final_disk_usage - initial_disk_usage))
    echo "Disk usage test completed. Increase: ${disk_increase} bytes"

    # Verify files are reasonable size
    local config_size
    config_size=$(stat -c "%s" "$CLAUVER_HOME/config")
    assert_equals "$config_size" "0" "Config should be empty after encryption"

    local secrets_size
    secrets_size=$(stat -c "%s" "$CLAUVER_HOME/secrets.env.age")
    [ "$secrets_size" -lt 10000 ] || warn "Secrets file might be too large: $secrets_size bytes"

    cleanup_test_environment "disk_usage_test"
    end_test
}

test_concurrent_operations() {
    start_test "test_concurrent_operations" "Test concurrent operation performance"

    setup_test_environment "concurrent_test"

    # Set up initial data
    export ZAI_API_KEY="concurrent-test-key"
    save_secrets

    # Test concurrent config access
    local concurrent_config_start
    concurrent_config_start=$(date +%s.%N)

    for i in {1..20}; do
        (
            load_config_cache >/dev/null 2>&1
            get_config "nonexistent_$i" >/dev/null 2>&1
        ) &
    done

    wait
    local concurrent_config_end
    concurrent_config_end=$(date +%s.%N)
    local concurrent_config_duration
    concurrent_config_duration=$(echo "$concurrent_config_end - $concurrent_config_start" | bc -l 2>/dev/null || echo "0")

    # Test concurrent secrets access
    load_secrets
    local concurrent_secrets_start
    concurrent_secrets_start=$(date +%s.%N)

    for i in {1..20}; do
        (
            get_secret "ZAI_API_KEY" >/dev/null 2>&1
        ) &
    done

    wait
    local concurrent_secrets_end
    concurrent_secrets_end=$(date +%s.%N)
    local concurrent_secrets_duration
    concurrent_secrets_duration=$(echo "$concurrent_secrets_end - $concurrent_secrets_start" | bc -l 2>/dev/null || echo "0")

    echo "Concurrent operations test completed"
    echo "Concurrent config access time: $concurrent_config_duration seconds"
    echo "Concurrent secrets access time: $concurrent_secrets_duration seconds"

    cleanup_test_environment "concurrent_test"
    end_test
}

test_large_input_handling() {
    start_test "test_large_input_handling" "Test handling of large inputs"

    setup_test_environment "large_input_test"

    # Test large API key (should handle but warn)
    local large_key
    large_key="sk-$(printf 'a%.0s' {1..500})"
    export ZAI_API_KEY="$large_key"

    assert_command_success "save_secrets" "Should handle large API key"
    assert_command_success "load_secrets" "Should load large API key"

    # Test large config values
    local large_value
    large_value=$(printf 'a%.0s' {1..1000})
    set_config "large_config_key" "$large_value"

    local retrieved_value
    retrieved_value=$(get_config "large_config_key")
    assert_equals "${retrieved_value:0:100}" "$(printf 'a%.0s' {1..100})" "Large config value should be preserved"

    # Test large model name
    local large_model
    large_model="model-$(printf 'a%.0s' {1..200})"
    set_config "large_model_key" "$large_model"

    local retrieved_model
    retrieved_model=$(get_config "large_model_key")
    assert_equals "${retrieved_model:0:50}" "model-$(printf 'a%.0s' {1..50})" "Large model name should be preserved"

    echo "Large input handling test completed"

    cleanup_test_environment "large_input_test"
    end_test
}

test_command_execution_overhead() {
    start_test "test_command_execution_overhead" "Test command execution overhead"

    setup_test_environment "overhead_test"

    # Test basic command execution overhead
    local basic_overhead_start
    basic_overhead_start=$(date +%s.%N)

    # Time simple operations
    for i in {1..100}; do
        get_config "nonexistent_key_$i" >/dev/null 2>&1
    done

    local basic_overhead_end
    basic_overhead_end=$(date +%s.%N)
    local basic_overhead
    basic_overhead=$(echo "$basic_overhead_end - $basic_overhead_start" | bc -l 2>/dev/null || echo "0")

    # Test with cache loaded
    load_config_cache
    local cached_overhead_start
    cached_overhead_start=$(date +%s.%N)

    for i in {1..100}; do
        get_config "nonexistent_key_$i" >/dev/null 2>&1
    done

    local cached_overhead_end
    cached_overhead_end=$(date +%s.%N)
    local cached_overhead
    cached_overhead=$(echo "$cached_overhead_end - $cached_overhead_start" | bc -l 2>/dev/null || echo "0")

    echo "Command execution overhead test completed"
    echo "Basic overhead: $basic_overhead seconds for 100 operations"
    echo "Cached overhead: $cached_overhead seconds for 100 operations"

    cleanup_test_environment "overhead_test"
    end_test
}

# Run all performance tests
main() {
    echo "Starting performance tests..."

    test_performance_constants_accuracy
    test_encryption_performance
    test_config_caching_performance
    test_provider_switching_performance
    test_memory_usage
    test_disk_usage
    test_concurrent_operations
    test_large_input_handling
    test_command_execution_overhead

    echo "Performance tests completed."
}

# If this file is run directly, execute tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi