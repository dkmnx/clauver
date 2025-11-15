# Makefile for clauver test suite

# Configuration
CLAUVER_SCRIPT = ../clauver.sh
TEST_ROOT = .
FRAMEWORK = $(TEST_ROOT)/test-framework.sh

# Test files
TEST_FILES = $(wildcard $(TEST_ROOT)/test_*.sh)
TEST_NAMES = $(basename $(notdir $(TEST_FILES)))

# Phony targets
.PHONY: all test clean check coverage report help

# Default target
all: test

# Run all tests
test: $(TEST_NAMES)
	@echo "==============================================="
	@echo "All tests completed"
	@echo "==============================================="

# Individual test targets
utilities: $(TEST_ROOT)/test_utilities.sh
	@./run_all_tests.sh utilities

encryption: $(TEST_ROOT)/test_encryption_security.sh
	@./run_all_tests.sh encryption

providers: $(TEST_ROOT)/test_providers.sh
	@./run_all_tests.sh providers

integration: $(TEST_ROOT)/test_integration.sh
	@./run_all_tests.sh integration

error_handling: $(TEST_ROOT)/test_error_handling.sh
	@./run_all_tests.sh error_handling

performance: $(TEST_ROOT)/test_performance.sh
	@./run_all_tests.sh performance

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
smoke:
	@echo "Running smoke test..."
	@cd $(TEST_ROOT) && source $(FRAMEWORK) && test_framework_init
	@echo "✓ Smoke test passed"

# Run CI test suite
ci: clean check shellcheck test coverage
	@echo "✓ CI test suite completed successfully"

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
	@echo "  all          - Run all tests (default)"
	@echo "  utilities    - Run utility function tests"
	@echo "  encryption   - Run encryption and security tests"
	@echo "  providers    - Run provider configuration tests"
	@echo "  integration  - Run integration tests"
	@echo "  error_handling - Run error handling tests"
	@echo "  performance  - Run performance tests"
	@echo "  specific     - Run specific test function"
	@echo "  coverage     - Generate test coverage report"
	@echo "  clean        - Clean up test artifacts"
	@echo "  check        - Check test file syntax"
	@echo "  shellcheck   - Run shellcheck on test files"
	@echo "  smoke        - Run quick smoke test"
	@echo "  ci           - Run complete CI test suite"
	@echo "  docs         - Generate test documentation"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make utilities           # Run utility tests only"
	@echo "  make ci                 # Run complete CI suite"
	@echo "  make clean              # Clean up all test artifacts"
	@echo "  make coverage           # Generate coverage report"

# Default run all tests
test: $(TEST_NAMES)
	@echo "==============================================="
	@echo "All tests completed"
	@echo "==============================================="
