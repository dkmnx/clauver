#!/usr/bin/env bash
# shellcheck disable=SC1091
# Unit tests for clauver validation module functions with consistent prefixes

# Source the test framework first
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Test suite for validation module functions (prefixed versions)
test_validation_module_functions() {
    start_test "test_validation_module_functions" "Test validation module functions with consistent prefixes"

    setup_test_environment "validation_module_test"

    # Test validation_api_key function
    # Test empty key
    validation_api_key "" "test" || local exit_code=$?
    assert_equals "$exit_code" "1" "validation_api_key should reject empty key with exit code 1"

    # Test short key
    validation_api_key "abc" "test" || local exit_code=$?
    assert_equals "$exit_code" "1" "validation_api_key should reject short key with exit code 1"

    # Test valid key should pass (not return error code)
    local valid_key="sk-test-1234567890abcdef"
    if validation_api_key "$valid_key" "test"; then
        local exit_code=""
    else
        local exit_code=$?
    fi
    assert_equals "$exit_code" "" "validation_api_key should accept valid key (no exit code)"

    # Test validation_url function
    # Test empty URL
    validation_url "" || local exit_code=$?
    assert_equals "$exit_code" "1" "validation_url should reject empty URL with exit code 1"

    # Test HTTP URL (should fail for security)
    validation_url "http://example.com" || local exit_code=$?
    assert_equals "$exit_code" "1" "validation_url should reject HTTP URL for security with exit code 1"

    # Test valid HTTPS URL should pass
    if validation_url "https://api.example.com"; then
        local exit_code=""
    else
        local exit_code=$?
    fi
    assert_equals "$exit_code" "" "validation_url should accept valid HTTPS URL (no exit code)"

    # Test validation_provider_name function
    # Test empty name
    validation_provider_name "" || local exit_code=$?
    assert_equals "$exit_code" "1" "validation_provider_name should reject empty name with exit code 1"

    # Test invalid characters (spaces)
    validation_provider_name "invalid name" || local exit_code=$?
    assert_equals "$exit_code" "1" "validation_provider_name should reject spaces with exit code 1"

    # Test reserved names
    validation_provider_name "anthropic" || local exit_code=$?
    assert_equals "$exit_code" "1" "validation_provider_name should reject reserved name 'anthropic' with exit code 1"

    # Test valid name should pass
    if validation_provider_name "custom-provider"; then
        local exit_code=""
    else
        local exit_code=$?
    fi
    assert_equals "$exit_code" "" "validation_provider_name should accept valid kebab-case name (no exit code)"

    # Test validation_model_name function
    # Test empty model
    validation_model_name "" || local exit_code=$?
    assert_equals "$exit_code" "1" "validation_model_name should reject empty model with exit code 1"

    # Test valid model name should pass
    if validation_model_name "gpt-4"; then
        local exit_code=""
    else
        local exit_code=$?
    fi
    assert_equals "$exit_code" "" "validation_model_name should accept valid model name (no exit code)"

    # Test validation_decrypted_content function
    # Test empty content
    validation_decrypted_content "" || local exit_code=$?
    assert_equals "$exit_code" "1" "validation_decrypted_content should reject empty content with exit code 1"

    # Test valid content should pass
    if validation_decrypted_content "API_KEY=sk-test-123"; then
        local exit_code=""
    else
        local exit_code=$?
    fi
    assert_equals "$exit_code" "" "validation_decrypted_content should accept valid content (no exit code)"

    cleanup_test_environment "validation_module_test"
    end_test
}

# Run the validation module tests if this file is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_framework_init
    test_validation_module_functions
    echo "Validation module tests completed."
fi