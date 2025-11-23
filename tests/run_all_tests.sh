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
    ["ui_module"]="test_ui_module.sh"
    ["encryption"]="test_encryption_security.sh"
    ["security"]="test_security.sh"
    ["security_hardening"]="test_security_hardening.sh"
    ["providers"]="test_providers.sh"
    ["integration"]="test_integration.sh"
    ["error_handling"]="test_error_handling.sh"
    ["performance"]="test_performance.sh"
    ["release"]="test_release.sh"
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

# Function to check dependencies
check_dependencies() {
    echo -e "${BLUE}🔍 Checking required dependencies...${NC}"

    local missing_deps=()
    local optional_deps=()

    # Check required dependencies
    local deps=("age" "shellcheck" "bc" "curl")
    for dep in "${deps[@]}"; do
        if which "$dep" >/dev/null 2>&1; then
            echo -e "  ✓ $dep: $(which "$dep")"
        else
            echo -e "  ❌ $dep: NOT FOUND"
            missing_deps+=("$dep")
        fi
    done

    # Check optional dependencies
    if which "claude" >/dev/null 2>&1; then
        echo -e "  ✓ claude: $(which "claude")"
    else
        echo -e "  ⚠️ claude: NOT FOUND (optional but recommended)"
        optional_deps+=("claude")
    fi

    # Summary
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All required dependencies found${NC}"
        return 0
    else
        echo -e "${RED}❌ Missing required dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Install with: sudo apt install ${missing_deps[*]}${NC}"
        return 1
    fi
}

# Function to run CI syntax checks
ci_syntax_checks() {
    echo -e "${BLUE}🔍 Running CI syntax checks...${NC}"
    echo "================================"

    local failed=0

    # Check main script
    echo "Checking clauver.sh..."
    if bash -n "$CLAUVER_SCRIPT"; then
        echo -e "  ✓ clauver.sh syntax OK"
    else
        echo -e "  ❌ clauver.sh syntax FAILED"
        failed=1
    fi

    # Check test framework
    echo "Checking test_framework.sh..."
    if bash -n "$TEST_ROOT/test_framework.sh"; then
        echo -e "  ✓ test_framework.sh syntax OK"
    else
        echo -e "  ❌ test_framework.sh syntax FAILED"
        failed=1
    fi

    # Check all test files
    echo "Checking all test files..."
    for test_file in "$TEST_ROOT"/test_*.sh; do
        local filename
        filename=$(basename "$test_file")
        echo -n "  Checking $filename... "
        if bash -n "$test_file"; then
            echo "✓"
        else
            echo "❌"
            failed=1
        fi
    done

    echo "================================"
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✅ All syntax checks passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Some syntax checks failed${NC}"
        return 1
    fi
}

# Function to run CI security scan
ci_security_scan() {
    echo -e "${BLUE}🔒 Running CI security scan...${NC}"
    echo "================================"

    # Run shellcheck
    echo "Running shellcheck..."
    local shellcheck_failed=0
    for file in "$CLAUVER_SCRIPT" "$TEST_ROOT/test_framework.sh" "$TEST_ROOT"/test_*.sh; do
        echo -n "  Checking $(basename "$file")... "
        if shellcheck "$file" >/dev/null 2>&1; then
            echo "✓"
        else
            echo "⚠️ (issues found)"
            shellcheck_failed=1
        fi
    done

    # Check for potential secrets
    echo "Checking for potential secrets..."
    if grep -r "sk-[a-zA-Z0-9]" "$TEST_ROOT" 2>/dev/null | grep -v ".git" | head -5; then
        echo -e "${YELLOW}⚠️ Potential API keys found - review above${NC}"
    else
        echo -e "  ✓ No obvious API keys found"
    fi

    echo "================================"
    if [ $shellcheck_failed -eq 0 ]; then
        echo -e "${GREEN}✅ Security scan completed${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ Security scan completed with issues (review above)${NC}"
        return 0  # Don't fail CI for shellcheck issues
    fi
}

# Function to run CI workflow
ci_workflow() {
    echo -e "${BOLD}${BLUE}🚀 Clauver CI Workflow${NC}"
    echo "================================"
    echo "Script: $CLAUVER_SCRIPT"
    echo "Root: $TEST_ROOT"
    echo "Date: $(date)"
    echo

    local failed=0

    # Check dependencies
    check_dependencies || failed=1
    echo

    # Run syntax checks
    ci_syntax_checks || failed=1
    echo

    # Run security scan
    ci_security_scan
    echo

    # Run all tests
    run_all_tests
    echo

    # Generate report
    generate_test_report
    echo

    echo "================================"
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✅ CI workflow completed successfully${NC}"
    else
        echo -e "${RED}❌ CI workflow completed with failures${NC}"
        return 1
    fi
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
    echo "  ci_syntax_checks       Run CI syntax validation"
    echo "  ci_security_scan       Run security scanning"
    echo "  ci_workflow            Run complete CI workflow"
    echo "  check_deps             Check required dependencies"
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
    echo "  $0 ci_workflow            # Run complete CI workflow"
    echo "  $0 specific test_utilities.sh test_logging_functions"
    echo "  $0 check_deps             # Check dependencies only"
    echo
}

# Main execution
main() {
    case "${1:-all}" in
        "all")
            run_all_tests
            generate_test_report
            ;;
        "utilities"|"ui_module"|"encryption"|"security"|"security_hardening"|"providers"|"integration"|"error_handling"|"performance")
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
        "check_deps")
            check_dependencies
            ;;
        "ci_syntax_checks")
            ci_syntax_checks
            ;;
        "ci_security_scan")
            ci_security_scan
            ;;
        "ci_workflow")
            ci_workflow
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
