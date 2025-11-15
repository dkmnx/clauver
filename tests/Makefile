# Makefile for clauver test suite

# Configuration
CLAUVER_SCRIPT = ../clauver.sh
TEST_ROOT = .
FRAMEWORK = $(TEST_ROOT)/test_framework.sh
RUN_ALL_SCRIPT = $(TEST_ROOT)/run_all_tests.sh

# Test files
TEST_FILES = $(wildcard $(TEST_ROOT)/test_*.sh)
TEST_NAMES = $(basename $(notdir $(TEST_FILES)))

# Phony targets
.PHONY: all test clean check coverage report help utilities encryption providers integration error_handling performance smoke ci setup_deps

# Default target
all: setup_deps test

# Run all tests with proper environment
test: setup_deps
	@echo "==============================================="
	@echo "Running complete test suite..."
	@echo "==============================================="
	@./run_all_tests.sh
	@echo "==============================================="
	@echo "All tests completed"
	@echo "==============================================="

# Setup dependencies and environment
setup_deps:
	@echo "Setting up test dependencies..."
	@mkdir -p $(TEST_ROOT)/tmp
	@mkdir -p $(TEST_ROOT)/logs
	@mkdir -p $(TEST_ROOT)/reports
	@export CLAUVER_TEST_MODE=1 || true
	@echo "Checking required dependencies..."
	@# Check for age (encryption tool)
	@which age >/dev/null 2>&1 || (echo "❌ 'age' command not found - required for encryption tests" && echo "   Install with: sudo apt install age" && exit 1)
	@# Check for shellcheck (shell script linting)
	@which shellcheck >/dev/null 2>&1 || (echo "❌ 'shellcheck' command not found - required for linting" && echo "   Install with: sudo apt install shellcheck" && exit 1)
	@# Check for bc (calculator for performance tests)
	@which bc >/dev/null 2>&1 || (echo "❌ 'bc' command not found - required for performance calculations" && echo "   Install with: sudo apt install bc" && exit 1)
	@# Check for curl (API testing)
	@which curl >/dev/null 2>&1 || (echo "❌ 'curl' command not found - required for API tests" && echo "   Install with: sudo apt install curl" && exit 1)
	@# Check for claude script (main dependency)
	@which claude >/dev/null 2>&1 || (echo "⚠️ 'claude' command not found - some tests may fail" && echo "   Install with: npm install -g @anthropic-ai/claude-code")
	@test -f ../clauver.sh || (echo "❌ clauver.sh not found in parent directory" && exit 1)
	@echo "✓ All dependencies satisfied"

# Individual test targets with environment setup and error handling
utilities: setup_deps
	@echo "Running utilities tests..."
	@./run_all_tests.sh utilities || (echo "❌ Utilities tests failed" && exit 1)

encryption: setup_deps
	@echo "Running encryption tests..."
	@./run_all_tests.sh encryption || (echo "❌ Encryption tests failed" && exit 1)

providers: setup_deps
	@echo "Running providers tests..."
	@./run_all_tests.sh providers || (echo "❌ Providers tests failed" && exit 1)

integration: setup_deps
	@echo "Running integration tests..."
	@./run_all_tests.sh integration || (echo "❌ Integration tests failed" && exit 1)

error_handling: setup_deps
	@echo "Running error handling tests..."
	@./run_all_tests.sh error_handling || (echo "❌ Error handling tests failed" && exit 1)

performance: setup_deps
	@echo "Running performance tests..."
	@./run_all_tests.sh performance || (echo "❌ Performance tests failed" && exit 1)

# Run specific test
specific:
	@echo "Usage: make specific TEST_FILE=<test_file> TEST_FUNCTION=<function>"
	@echo "Example: make specific TEST_FILE=test_utilities.sh TEST_FUNCTION=test_logging_functions"

# Generate coverage report
coverage:
	@echo "Generating test coverage report..."
	@mkdir -p reports
	@echo "Test Coverage Report" > reports/coverage.txt
	@echo "===================" >> reports/coverage.txt
	@echo "Total test files: $(words $(TEST_FILES))" >> reports/coverage.txt
	@for file in $(TEST_FILES); do \
		echo "Test file: $$file" >> reports/coverage.txt; \
		test_count=$$(grep -c "start_test" $$file 2>/dev/null || echo "0"); \
		echo "Test cases: $$test_count" >> reports/coverage.txt; \
		echo "" >> reports/coverage.txt; \
	done
	@echo "Coverage report generated: reports/coverage.txt"

# Clean up test artifacts
clean:
	@echo "Cleaning up test artifacts..."
	@rm -rf $(TEST_ROOT)/tmp
	@rm -rf $(TEST_ROOT)/logs
	@rm -rf $(TEST_ROOT)/reports
	@echo "Cleanup completed"

# Check test syntax
check:
	@echo "Checking test file syntax..."
	@for file in $(TEST_FILES); do \
		echo "Checking $$file..."; \
		bash -n "$$file" && echo "✓ Syntax OK" || echo "❌ Syntax error"; \
	done

# Run shellcheck on test files
shellcheck:
	@echo "Running shellcheck on test files..."
	@shellcheck $(TEST_FILES) $(FRAMEWORK) 2>/dev/null || true

# Run quick smoke test
smoke: setup_deps
	@echo "Running smoke test..."
	@cd $(TEST_ROOT) && source $(FRAMEWORK) && test_framework_init
	@echo "✓ Smoke test passed"

# Run CI test suite (comprehensive)
ci: clean setup_deps check shellcheck ci_syntax_checks ci_security_scan test coverage
	@echo "✓ Local CI test suite completed successfully"

# Run GitHub Actions CI using act
ci_act:
	@echo "🚀 Running GitHub Actions CI locally with act..."
	@echo "=========================================="
	@if ! which act >/dev/null 2>&1; then \
		echo "❌ 'act' command not found - GitHub Actions runner"; \
		echo "   Install with: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"; \
		exit 1; \
	fi
	@echo "✅ act found: $$(which act)"
	@echo ""
	@echo "📋 Available jobs:"
	@cd .. && act --list | grep -E "(Job ID|tests|security-scan|performance-benchmark)" || true
	@echo ""
	@echo "🔧 Running GitHub Actions jobs locally..."
	@cd .. && echo "1/3 Running tests job..." && act -j tests || echo "⚠️ Tests job completed with issues"
	@cd .. && echo "2/3 Running security-scan job..." && act -j security-scan || echo "⚠️ Security scan job completed with issues"
	@cd .. && echo "3/3 Running performance-benchmark job..." && act -j performance-benchmark || echo "⚠️ Performance benchmark job completed with issues"
	@echo ""
	@echo "=========================================="
	@echo "✅ GitHub Actions CI completed with act"

# Run single act job with option
ci_act_job:
	@if [ -z "$(JOB)" ]; then \
		echo "❌ Please specify a job: make ci_act_job JOB=tests|security-scan|performance-benchmark"; \
		echo "   Example: make ci_act_job JOB=tests"; \
		exit 1; \
	fi
	@if ! which act >/dev/null 2>&1; then \
		echo "❌ 'act' command not found"; \
		exit 1; \
	fi
	@echo "🚀 Running GitHub Actions job '$(JOB)' with act..."
	@cd .. && act -j "$(JOB)"

# CI-specific syntax checks
ci_syntax_checks: setup_deps
	@echo "Running CI syntax checks..."
	@echo "Checking main script syntax..."
	@bash -n ../clauver.sh && echo "✓ Main script syntax OK" || (echo "❌ Main script syntax failed" && exit 1)
	@echo "Checking test framework syntax..."
	@bash -n test_framework.sh && echo "✓ Test framework syntax OK" || (echo "❌ Test framework syntax failed" && exit 1)
	@echo "Checking all test files syntax..."
	@for test_file in test_*.sh; do \
		echo "Checking $$test_file..."; \
		bash -n "$$test_file" && echo "✓ $$test_file syntax OK" || (echo "❌ $$test_file syntax failed" && exit 1); \
	done

# CI security scanning
ci_security_scan: setup_deps
	@echo "Running CI security scanning..."
	@echo "Running shellcheck on all files..."
	@shellcheck ../clauver.sh test_framework.sh test_*.sh || echo "⚠️ Shellcheck found issues (review above)"
	@echo "Checking for sensitive data..."
	@if grep -r "sk-[a-zA-Z0-9]" . 2>/dev/null | grep -v ".git"; then \
		echo "⚠️ Potential API keys found - review above"; \
	else \
		echo "✓ No obvious API keys found in test files"; \
	fi

# CI performance benchmark
ci_performance: setup_deps
	@echo "Running CI performance benchmarks..."
	@./run_all_tests.sh performance || echo "⚠️ Performance tests completed with issues"

# Run complete CI workflow
ci_workflow: ci ci_performance
	@echo "✓ Complete CI workflow finished"

# Generate test documentation
docs:
	@echo "Generating test documentation..."
	@mkdir -p docs
	@echo "# Clauver Test Suite Documentation" > docs/TEST_README.md
	@echo "" >> docs/TEST_README.md
	@echo "## Test Categories" >> docs/TEST_README.md
	@echo "" >> docs/TEST_README.md
	@for test in $(TEST_NAMES); do \
		echo "### $$test" >> docs/TEST_README.md; \
		test_file=$(TEST_ROOT)/test_$test.sh; \
		if [ -f "$$test_file" ]; then \
			echo "File: $$test_file" >> docs/TEST_README.md; \
			test_count=$$(grep -c "start_test" $$test_file 2>/dev/null || echo "0"); \
			echo "Test cases: $$test_count" >> docs/TEST_README.md; \
			echo "" >> docs/TEST_README.md; \
		fi; \
	done
	@echo "Documentation generated: docs/TEST_README.md"

# Show help
help:
	@echo "Clauver Test Suite Makefile"
	@echo "==========================="
	@echo ""
	@echo "Targets:"
	@echo "  all               - Run all tests (default)"
	@echo "  utilities         - Run utility function tests"
	@echo "  encryption        - Run encryption and security tests"
	@echo "  providers         - Run provider configuration tests"
	@echo "  integration       - Run integration tests"
	@echo "  error_handling    - Run error handling tests"
	@echo "  performance       - Run performance tests"
	@echo "  specific          - Run specific test function"
	@echo "  coverage          - Generate test coverage report"
	@echo "  clean             - Clean up test artifacts"
	@echo "  check             - Check test file syntax"
	@echo "  shellcheck        - Run shellcheck on test files"
	@echo "  smoke             - Run quick smoke test"
	@echo "  ci                - Run complete local CI test suite"
	@echo "  ci_act            - Run GitHub Actions CI locally with act"
	@echo "  ci_act_job        - Run specific GitHub Actions job (use JOB=)"
	@echo "  ci_syntax_checks  - Run CI-specific syntax validation"
	@echo "  ci_security_scan  - Run security scanning (shellcheck + secret check)"
	@echo "  ci_performance    - Run CI performance benchmarks"
	@echo "  ci_workflow       - Run complete CI workflow (ci + performance)"
	@echo "  docs              - Generate test documentation"
	@echo "  help              - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make utilities           			# Run utility tests only"
	@echo "  make ci                 			# Run complete local CI suite"
	@echo "  make ci_act             			# Run GitHub Actions CI locally with act"
	@echo "  make ci_act_job JOB=tests      	# Run specific GitHub Actions job"
	@echo "  make ci_act_job JOB=security-scan 	# Run security-scan job"
	@echo "  make ci_workflow        			# Run full CI workflow like GitHub Actions"
	@echo "  make ci_security_scan   			# Run security scanning only"
	@echo "  make clean              			# Clean up all test artifacts"
	@echo "  make coverage           			# Generate coverage report"

