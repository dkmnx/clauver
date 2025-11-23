#!/usr/bin/env bash
# shellcheck disable=SC1090
# Test framework for clauver.sh
# Provides a structured testing environment with mocks, assertions, and reporting

# Framework Configuration
TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUVER_SCRIPT="$TEST_ROOT/../clauver.sh"
TEST_TEMP_DIR="$TEST_ROOT/tmp"
TEST_LOGS_DIR="$TEST_ROOT/logs"
TEST_REPORTS_DIR="$TEST_ROOT/reports"
FRAMEWORK_LOG="$TEST_LOGS_DIR/framework.log"

# Test framework state
declare -i TEST_COUNT=0
declare -i TEST_PASSED=0
declare -i TEST_FAILED=0
declare -i TEST_SKIPPED=0
CURRENT_TEST=""
MOCKED_COMMANDS=()

# Ensure test isolation from global clauver config
export CLAUVER_TEST_MODE="1"
export CLAUVER_HOME=""
export AGE_KEY=""

# Color codes for test output
FRAMEWORK_RED='\033[0;31m'
FRAMEWORK_GREEN='\033[0;32m'
FRAMEWORK_YELLOW='\033[1;33m'
FRAMEWORK_BLUE='\033[0;34m'
FRAMEWORK_BOLD='\033[1m'
FRAMEWORK_NC='\033[0m'

# Initialize test framework
test_framework_init() {
    # Create necessary directories
    mkdir -p "$TEST_TEMP_DIR"
    mkdir -p "$TEST_LOGS_DIR"
    mkdir -p "$TEST_REPORTS_DIR"

    # Clean previous test data
    if [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "${TEST_TEMP_DIR:?}"/*
    fi
    rm -f "$TEST_LOGS_DIR"/*.log
    rm -f "$TEST_REPORTS_DIR"/*.json

    # Set up test environment
    export CLAUVER_HOME="$TEST_TEMP_DIR/.clauver"
    export CLAUVER_BASE="$TEST_TEMP_DIR/.clauver"

    # Ensure AGE_KEY is updated to use the test CLAUVER_HOME
    export AGE_KEY="$CLAUVER_HOME/age.key"

    # Initialize age key for tests - generate real key for encryption tests
    if [ ! -f "$CLAUVER_HOME/age.key" ]; then
        mkdir -p "$CLAUVER_HOME"
        if command -v age-keygen >/dev/null 2>&1; then
            # Generate real age key for encryption tests
            age-keygen -o "$CLAUVER_HOME/age.key" 2>/dev/null
        else
            # Fallback to fake key (but encryption tests will fail)
            echo "TEST_AGE_PRIVATE_KEY" | base64 -d > "$CLAUVER_HOME/age.key" 2>/dev/null || \
            echo "TEST_AGE_PRIVATE_KEY" > "$CLAUVER_HOME/age.key"
        fi
        chmod 600 "$CLAUVER_HOME/age.key"
    fi

    # Set up clauver configuration
    mkdir -p "$CLAUVER_HOME/bin"
    cp "$CLAUVER_SCRIPT" "$CLAUVER_HOME/bin/clauver"
    chmod +x "$CLAUVER_HOME/bin/clauver"

    # Initialize result counters
    TEST_COUNT=0
    TEST_PASSED=0
    TEST_FAILED=0
    TEST_SKIPPED=0

    # Validate critical environment variables
    if [ -z "${CLAUVER_HOME:-}" ]; then
        echo "ERROR: CLAUVER_HOME is not set after test_framework_init!"
        echo "This indicates a framework initialization failure."
        echo "Current working directory: $(pwd)"
        exit 1
    fi

    if [ ! -d "$CLAUVER_HOME" ]; then
        echo "ERROR: CLAUVER_HOME directory does not exist: $CLAUVER_HOME"
        echo "Creating directory..."
        mkdir -p "$CLAUVER_HOME" || {
            echo "ERROR: Failed to create CLAUVER_HOME directory"
            exit 1
        }
    fi

    log_framework "Test framework initialized"
    log_framework "CLAUVER_HOME: $CLAUVER_HOME"
    log_framework "Test directory: $TEST_TEMP_DIR"
}

# Log framework messages
log_framework() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [FRAMEWORK] $*" >> "$FRAMEWORK_LOG"
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected values to be equal}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if [ "$expected" = "$actual" ]; then
        echo -e "${FRAMEWORK_GREEN}✓${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "PASS: $message (expected: '$expected', actual: '$actual')"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        echo -e "${FRAMEWORK_RED}✗${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  Expected: '$expected'" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  Actual:   '$actual'" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "FAIL: $message (expected: '$expected', actual: '$actual')"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 0  # Return 0 to continue testing, even if this assertion fails
    fi
}

assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Expected values to be different}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if [ "$unexpected" != "$actual" ]; then
        echo -e "${FRAMEWORK_GREEN}✓${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "PASS: $message (unexpected: '$unexpected', actual: '$actual')"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        echo -e "${FRAMEWORK_RED}✗${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  Unexpected: '$unexpected'" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  Actual:    '$actual'" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "FAIL: $message (unexpected: '$unexpected', actual: '$actual')"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 0  # Return 0 to continue testing, even if this assertion fails
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected to contain substring}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${FRAMEWORK_GREEN}✓${FRAMEWORK_NC} $message"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        echo -e "${FRAMEWORK_RED}✗${FRAMEWORK_NC} $message"
        echo -e "  Expected: '$needle' to be found in: '$haystack'"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 0  # Return 0 to continue testing, even if this assertion fails
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected to not contain substring}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if [[ "$haystack" != *"$needle"* ]]; then
        echo -e "${FRAMEWORK_GREEN}✓${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "PASS: $message ('$needle' not found in '$haystack')"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        echo -e "${FRAMEWORK_RED}✗${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  Expected to not contain: '$needle'" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  Actual: '$haystack'" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "FAIL: $message (found '$needle' in '$haystack')"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 0  # Return 0 to continue testing, even if this assertion fails
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-Expected file to exist}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if [ -f "$file_path" ]; then
        echo -e "${FRAMEWORK_GREEN}✓${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "PASS: $message (file: $file_path)"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        echo -e "${FRAMEWORK_RED}✗${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  File not found: $file_path" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "FAIL: $message (file: $file_path)"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 0  # Return 0 to continue testing, even if this assertion fails
    fi
}

assert_file_not_exists() {
    local file_path="$1"
    local message="${2:-Expected file to not exist}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if [ ! -f "$file_path" ]; then
        echo -e "${FRAMEWORK_GREEN}✓${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "PASS: $message (file: $file_path)"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        echo -e "${FRAMEWORK_RED}✗${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  File exists but shouldn't: $file_path" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "FAIL: $message (file: $file_path)"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 0  # Return 0 to continue testing, even if this assertion fails
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-Expected command to succeed}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if eval "$command" >/dev/null 2>&1; then
        echo -e "${FRAMEWORK_GREEN}✓${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "PASS: $message (command: $command)"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        echo -e "${FRAMEWORK_RED}✗${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  Command failed: $command" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "FAIL: $message (command: $command)"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 0  # Return 0 to continue testing, even if this assertion fails
    fi
}

assert_command_failure() {
    local command="$1"
    local message="${2:-Expected command to fail}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if ! eval "$command" >/dev/null 2>&1; then
        echo -e "${FRAMEWORK_GREEN}✓${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "PASS: $message (command: $command)"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        echo -e "${FRAMEWORK_RED}✗${FRAMEWORK_NC} $message" | tee -a "$TEST_LOGS_DIR/current.log"
        echo -e "  Command succeeded but should have failed: $command" | tee -a "$TEST_LOGS_DIR/current.log"
        log_framework "FAIL: $message (command: $command)"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 0  # Return 0 to continue testing, even if this assertion fails
    fi
}

# Mocking framework
mock_command() {
    local command_name="$1"
    local mock_command="$2"
    local return_code="${3:-0}"

    # Add to mocked commands list
    MOCKED_COMMANDS+=("$command_name")

    # Create a wrapper script for the mocked command
    local mock_script="$TEST_TEMP_DIR/mock_$command_name"
    cat > "$mock_script" <<EOF
#!/bin/bash
MOCK_COMMAND="$command_name"
MOCK_RETURN_CODE=$return_code
MOCK_COMMAND_CALLED="true"

# Check if there's a custom mock command
if [ -n "$mock_command" ]; then
    if [ "$mock_command" == "FAIL" ]; then
        exit $return_code
    elif [ "$mock_command" == "EMPTY" ]; then
        exit 0
    else
        eval "$mock_command"
        exit $return_code
    fi
else
    # Default mock behavior
    case "\$1" in
        --version)
            echo "mock-v1.0.0"
            ;;
        *)
            echo "Mocked: $command_name \$*"
            ;;
    esac
    exit $return_code
fi
EOF
    chmod +x "$mock_script"

    # Override the PATH to include our mock directory first
    export TEST_MOCK_PATH="$TEST_TEMP_DIR:$PATH"
    PATH="$TEST_TEMP_DIR:$PATH"

    log_framework "Mocked command: $command_name -> $mock_script (return code: $return_code)"
}

unmock_command() {
    local command_name="$1"

    # Remove from PATH
    export TEST_MOCK_PATH="${TEST_MOCK_PATH//$TEST_TEMP_DIR:/}"
    PATH="${PATH//$TEST_TEMP_DIR:/}"

    # Remove mock script
    rm -f "$TEST_TEMP_DIR/mock_$command_name"

    log_framework "Unmocked command: $command_name"
}

# Test environment setup and cleanup
setup_test_environment() {
    local test_name="$1"

    # Create test-specific directory
    mkdir -p "$TEST_TEMP_DIR/$test_name"

    # Save current environment
    export TEST_ENV_BACKUP_FILE="$TEST_TEMP_DIR/$test_name/env_backup"
    env > "$TEST_ENV_BACKUP_FILE"

    # Set up test environment
    cd "$TEST_TEMP_DIR/$test_name" || return 1

    log_framework "Set up test environment: $test_name"
}

cleanup_test_environment() {
    local test_name="$1"

    # Clean up test directory
    cd "$TEST_ROOT" || return 1
    if [ -d "$TEST_TEMP_DIR/$test_name" ]; then
        rm -rf "${TEST_TEMP_DIR:?}/$test_name"
    fi

    log_framework "Cleaned up test environment: $test_name"
}

# Test execution functions
start_test() {
    local test_name="$1"
    local description="$2"

    CURRENT_TEST="$test_name"

    # Start new test log
    : > "$TEST_LOGS_DIR/current.log"

    echo -e "\n${FRAMEWORK_BLUE}🧪 Running: $test_name${FRAMEWORK_NC}"
    echo -e "${FRAMEWORK_YELLOW}   $description${FRAMEWORK_NC}"

    log_framework "START: $test_name - $description"
}

end_test() {
    local test_name="$CURRENT_TEST"

    if [ -z "$test_name" ]; then
        log_framework "ERROR: No current test to end"
        return 1
    fi

    # Move test log to specific test file
    mv "$TEST_LOGS_DIR/current.log" "$TEST_LOGS_DIR/$test_name.log"

    log_framework "END: $test_name"
    CURRENT_TEST=""
}

skip_test() {
    local reason="$1"

    TEST_SKIPPED=$((TEST_SKIPPED + 1))
    echo -e "${FRAMEWORK_YELLOW}⚠ SKIPPED: $reason${FRAMEWORK_NC}"
    log_framework "SKIP: $reason"
}

# Test reporting
generate_test_report() {
    local report_file
    report_file="$TEST_REPORTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).json"

    cat > "$report_file" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "summary": {
        "total_tests": $TEST_COUNT,
        "passed": $TEST_PASSED,
        "failed": $TEST_FAILED,
        "skipped": $TEST_SKIPPED,
        "success_rate": $(echo "scale=2; $TEST_PASSED * 100 / $TEST_COUNT" | bc 2>/dev/null || echo "0.00")
    },
    "tests": [
        $(generate_test_details)
    ]
}
EOF

    echo "Test report generated: $report_file"
    log_framework "Report generated: $report_file"
}

generate_test_details() {
    # This would generate detailed test results
    # For now, return empty array
    echo ""
}

print_test_summary() {
    echo -e "\n${FRAMEWORK_BOLD}${FRAMEWORK_BLUE}=== TEST SUMMARY ===${FRAMEWORK_NC}"

    # Try to read aggregated results from test runner, fall back to local counts
    local total_tests passed_tests failed_tests skipped_tests
    if [ -f "$TEST_REPORTS_DIR/test_results.txt" ]; then
        total_tests=$(grep "TEST_COUNT=" "$TEST_REPORTS_DIR/test_results.txt" | cut -d'=' -f2)
        passed_tests=$(grep "TEST_PASSED=" "$TEST_REPORTS_DIR/test_results.txt" | cut -d'=' -f2)
        failed_tests=$(grep "TEST_FAILED=" "$TEST_REPORTS_DIR/test_results.txt" | cut -d'=' -f2)
        skipped_tests=$(grep "TEST_SKIPPED=" "$TEST_REPORTS_DIR/test_results.txt" | cut -d'=' -f2)
    else
        # Fall back to local framework variables
        total_tests=$TEST_COUNT
        passed_tests=$TEST_PASSED
        failed_tests=$TEST_FAILED
        skipped_tests=$TEST_SKIPPED
    fi

    echo -e "Total tests: ${total_tests:-0}"
    echo -e "${FRAMEWORK_GREEN}Passed: ${passed_tests:-0}${FRAMEWORK_NC}"
    echo -e "${FRAMEWORK_RED}Failed: ${failed_tests:-0}${FRAMEWORK_NC}"
    echo -e "${FRAMEWORK_YELLOW}Skipped: ${skipped_tests:-0}${FRAMEWORK_NC}"

    if [ "${total_tests:-0}" -gt 0 ]; then
        local success_rate
        # Use bash arithmetic instead of bc to avoid dependency issues
        success_rate=$(( (${passed_tests:-0} * 100) / ${total_tests:-0} ))
        echo -e "Success rate: ${success_rate}%"

        if [ "${failed_tests:-0}" -eq 0 ]; then
            echo -e "\n${FRAMEWORK_GREEN}🎉 All tests passed!${FRAMEWORK_NC}"
        else
            echo -e "\n${FRAMEWORK_RED}❌ ${failed_tests:-0} test(s) failed${FRAMEWORK_NC}"
        fi
    fi
}

# Test discovery and execution
run_test_file() {
    local test_file="$1"

    if [ ! -f "$test_file" ]; then
        echo "Error: Test file not found: $test_file"
        return 1
    fi

    echo -e "\n${FRAMEWORK_BOLD}${FRAMEWORK_BLUE}Running test file: $test_file${FRAMEWORK_NC}"

    # Source the test file
    source "$test_file"
}

run_all_tests() {
    echo -e "${FRAMEWORK_BOLD}${FRAMEWORK_BLUE}🚀 Starting comprehensive test suite${FRAMEWORK_NC}"

    # Initialize test framework
    test_framework_init

    # Find and run all test files
    local test_files
    test_files=("$TEST_ROOT"/test_*.sh)

    for test_file in "${test_files[@]}"; do
        if [ -f "$test_file" ]; then
            run_test_file "$test_file"
        fi
    done

    # Generate report and summary
    generate_test_report
    print_test_summary

    # Cleanup
    log_framework "Test suite completed"
}

# Write test results to file for test runner to read
write_test_results() {
    local results_file="$TEST_REPORTS_DIR/test_results.txt"
    {
        echo "TEST_COUNT=$TEST_COUNT"
        echo "TEST_PASSED=$TEST_PASSED"
        echo "TEST_FAILED=$TEST_FAILED"
        echo "TEST_SKIPPED=$TEST_SKIPPED"
    } > "$results_file"
    log_framework "Test results written to: $results_file"
}

# Export framework functions
export -f assert_equals assert_not_equals assert_contains assert_not_contains \
          assert_file_exists assert_file_not_exists assert_command_success assert_command_failure \
          mock_command unmock_command setup_test_environment cleanup_test_environment \
          start_test end_test skip_test test_framework_init generate_test_report \
          print_test_summary write_test_results log_framework

export TEST_ROOT CLAUVER_SCRIPT TEST_TEMP_DIR TEST_LOGS_DIR TEST_REPORTS_DIR