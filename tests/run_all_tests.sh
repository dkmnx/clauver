#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Test runner script for clauver comprehensive test suite

# Source the test framework
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Disable exit on error for test runner (tests are expected to fail)
set +e

# Set test mode before sourcing clauver script
export CLAUVER_TEST_MODE="1"

# Set temporary CLAUVER_HOME for clauver.sh initialization
TEST_ROOT="$(dirname "${BASH_SOURCE[0]}")"
export CLAUVER_HOME="$TEST_ROOT/tmp/.clauver"

# Create the CLAUVER_HOME directory with proper permissions
mkdir -p "$CLAUVER_HOME"
chmod 700 "$CLAUVER_HOME"

# Source clauver script to make functions available
source "$CLAUVER_SCRIPT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
CLAUVER_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/../clauver.sh"
TEST_ROOT="$(dirname "${BASH_SOURCE[0]}")"

# Test categories
declare -A TEST_CATEGORIES=(
    ["utilities"]="test_utilities.sh"
    ["encryption"]="test_encryption_security.sh"
    ["providers"]="test_providers.sh"
    ["integration"]="test_integration.sh"
    ["error_handling"]="test_error_handling.sh"
    ["performance"]="test_performance.sh"
)

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Function to read test results from files
read_test_results() {
    local results_file="$TEST_ROOT/reports/test_results.txt"
    if [ -f "$results_file" ]; then
        local file_tests file_passed file_failed file_skipped
        file_tests=$(grep "TEST_COUNT=" "$results_file" | cut -d'=' -f2)
        file_passed=$(grep "TEST_PASSED=" "$results_file" | cut -d'=' -f2)
        file_failed=$(grep "TEST_FAILED=" "$results_file" | cut -d'=' -f2)
        file_skipped=$(grep "TEST_SKIPPED=" "$results_file" | cut -d'=' -f2)

        TOTAL_TESTS=$((TOTAL_TESTS + ${file_tests:-0}))
        PASSED_TESTS=$((PASSED_TESTS + ${file_passed:-0}))
        FAILED_TESTS=$((FAILED_TESTS + ${file_failed:-0}))
        SKIPPED_TESTS=$((SKIPPED_TESTS + ${file_skipped:-0}))
    fi
}

# Function to run a specific test file
run_test_file() {
    local test_file="$1"
    local category="$2"

    echo -e "${BLUE}🔬 Running $category tests: $test_file${NC}"
    echo "==============================================="

    # Set up test environment
    test_framework_init

    # Source and run the test file's main function
    if source "$test_file"; then
        # Run the main function from the test file if it exists
        if declare -f main > /dev/null; then
            main
            echo -e "${GREEN}✅ $category tests completed successfully${NC}"
            # Write results to file for aggregation
            write_test_results
            # Read results from file
            read_test_results
        else
            echo -e "${YELLOW}⚠️ Warning: No main function found in $test_file${NC}"
        fi
    else
        echo -e "${RED}❌ $category tests failed${NC}"
    fi

    echo
}

# Function to run all tests
run_all_tests() {
    echo -e "${BOLD}${BLUE}🚀 Clauver Comprehensive Test Suite${NC}"
    echo "==============================================="
    echo "Script: $CLAUVER_SCRIPT"
    echo "Root: $TEST_ROOT"
    echo "Date: $(date)"
    echo

    # Ensure clauver script exists
    if [ ! -f "$CLAUVER_SCRIPT" ]; then
        echo -e "${RED}❌ Error: clauver.sh not found at $CLAUVER_SCRIPT${NC}"
        exit 1
    fi

    echo -e "${YELLOW}📋 Test Categories:${NC}"
    for category in "${!TEST_CATEGORIES[@]}"; do
        echo "  • $category"
    done
    echo

    # Run each test category
    for category in "${!TEST_CATEGORIES[@]}"; do
        local test_file="$TEST_ROOT/${TEST_CATEGORIES[$category]}"

        if [ -f "$test_file" ]; then
            run_test_file "$test_file" "$category"
        else
            echo -e "${YELLOW}⚠️ Warning: Test file not found: $test_file${NC}"
        fi
    done

    # Print summary
    print_test_summary
}

# Function to run specific test category
run_category_tests() {
    local category="$1"

    if [ -z "$category" ]; then
        echo "Usage: $0 <category>"
        echo "Available categories: ${!TEST_CATEGORIES[*]}"
        exit 1
    fi

    if [[ ! -v "TEST_CATEGORIES[$category]" ]]; then
        echo -e "${RED}❌ Error: Unknown category '$category'${NC}"
        echo "Available categories: ${!TEST_CATEGORIES[*]}"
        exit 1
    fi

    local test_file="$TEST_ROOT/${TEST_CATEGORIES[$category]}"
    run_test_file "$test_file" "$category"
    print_test_summary
}

# Function to run specific test function
run_specific_test() {
    local test_file="$1"
    local test_function="$2"

    if [ -z "$test_file" ] || [ -z "$test_function" ]; then
        echo "Usage: $0 specific <test_file> <test_function>"
        echo "Example: $0 specific test_utilities.sh test_logging_functions"
        exit 1
    fi

    local full_test_file="$TEST_ROOT/$test_file"
    if [ ! -f "$full_test_file" ]; then
        echo -e "${RED}❌ Error: Test file not found: $full_test_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}🔬 Running specific test: $test_file::$test_function${NC}"
    echo "==============================================="

    test_framework_init

    # Source the test file and run the specific function
    source "$full_test_file"

    if declare -f "$test_function" > /dev/null; then
        "$test_function"
        echo -e "${GREEN}✅ Specific test completed${NC}"
    else
        echo -e "${RED}❌ Error: Test function '$test_function' not found${NC}"
    fi

    print_test_summary
}

# Function to generate test report
generate_test_report() {
    local report_file
    report_file="$TEST_ROOT/reports/summary_$(date +%Y%m%d_%H%M%S).json"

    mkdir -p "$(dirname "$report_file")"

    cat > "$report_file" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "clauver_version": "$(grep 'VERSION=' "$CLAUVER_SCRIPT" | cut -d'"' -f2)",
    "test_results": {
        "total_tests": $TOTAL_TESTS,
        "passed": $PASSED_TESTS,
        "failed": $FAILED_TESTS,
        "skipped": $SKIPPED_TESTS,
        "success_rate": $(echo "scale=2; $PASSED_TESTS * 100 / ($TOTAL_TESTS)" | bc -l 2>/dev/null || echo "0.00"),
        "categories": {
$(generate_category_report)
        }
    }
}
EOF

    echo -e "${GREEN}📊 Test report generated: $report_file${NC}"
}

# Function to generate category report
generate_category_report() {
    local category_report=""

    for category in "${!TEST_CATEGORIES[@]}"; do
        local test_file="$TEST_ROOT/${TEST_CATEGORIES[$category]}"
        local category_tests
        category_tests=$(grep -c "start_test" "$test_file" 2>/dev/null || echo "0")

        category_report+="            \"$category\": {
                \"file\": \"$test_file\",
                \"tests_count\": $category_tests
            },"
    done

    echo "${category_report%,}"
}

# Function to clean up test artifacts
cleanup_tests() {
    echo -e "${YELLOW}🧹 Cleaning up test artifacts...${NC}"

    if [ -d "$TEST_ROOT/tmp" ]; then
        rm -rf "$TEST_ROOT/tmp"
    fi

    if [ -d "$TEST_ROOT/logs" ]; then
        rm -rf "$TEST_ROOT/logs"
    fi

    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Function to show help
show_help() {
    echo -e "${BOLD}Clauver Test Runner${NC}"
    echo
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  all                    Run all test categories"
    echo "  <category>             Run specific test category"
    echo "  specific <file> <func> Run specific test function"
    echo "  report                 Generate test report"
    echo "  clean                  Clean up test artifacts"
    echo "  help                   Show this help message"
    echo
    echo "Available test categories:"
    for category in "${!TEST_CATEGORIES[@]}"; do
        echo "  • $category"
    done
    echo
    echo "Examples:"
    echo "  $0 all                    # Run all tests"
    echo "  $0 utilities              # Run utility tests only"
    echo "  $0 specific test_utilities.sh test_logging_functions"
    echo
}

# Main execution
main() {
    case "${1:-all}" in
        "all")
            run_all_tests
            generate_test_report
            ;;
        "utilities"|"encryption"|"providers"|"integration"|"error_handling"|"performance")
            run_category_tests "$1"
            generate_test_report
            ;;
        "specific")
            run_specific_test "$2" "$3"
            generate_test_report
            ;;
        "report")
            generate_test_report
            ;;
        "clean")
            cleanup_tests
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}❌ Error: Unknown command '$1'${NC}"
            echo "Use '$0 help' for usage instructions"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"