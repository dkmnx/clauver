#!/usr/bin/env bash
# shellcheck disable=SC1091
# Unit tests for clauver UI module functions

# Source the test framework first
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Test suite for UI module functions (prefixed versions)
test_ui_module_functions() {
    start_test "test_ui_module_functions" "Test UI module functions with consistent prefixes"

    setup_test_environment "ui_module_test"

    # Test ui_log function
    local ui_log_output
    ui_log_output=$(ui_log "Test message" 2>&1)
    assert_contains "$ui_log_output" "Test message" "ui_log() function should output the test message"
    assert_contains "$ui_log_output" "→" "ui_log() function should output arrow prefix"

    # Test ui_success function
    local ui_success_output
    ui_success_output=$(ui_success "Success message")
    assert_contains "$ui_success_output" "✓" "ui_success() function should output checkmark symbol"
    assert_contains "$ui_success_output" "Success message" "ui_success() function should output the success message"

    # Test ui_warn function
    local ui_warn_output
    ui_warn_output=$(ui_warn "Warning message")
    assert_contains "$ui_warn_output" "!" "ui_warn() function should output exclamation mark"
    assert_contains "$ui_warn_output" "Warning message" "ui_warn() function should output the warning message"

    # Test ui_error function
    local ui_error_output
    ui_error_output=$(ui_error "Error message" 2>&1)
    assert_contains "$ui_error_output" "✗" "ui_error() function should output X mark symbol"
    assert_contains "$ui_error_output" "Error message" "ui_error() function should output the error message"

    # Test ui_banner function
    local ui_banner_output
    ui_banner_output=$(ui_banner "Z.AI")
    assert_contains "$ui_banner_output" "Z.AI" "ui_banner() should display provider name 'Z.AI'"
    assert_contains "$ui_banner_output" "v1.11.2" "ui_banner() should display version 'v1.11.2'"

    cleanup_test_environment "ui_module_test"
    end_test
}

# Run the UI module tests if this file is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_framework_init
    test_ui_module_functions
    echo "UI module tests completed."
fi