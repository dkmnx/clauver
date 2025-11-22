# Clauver Test Suite

A comprehensive test suite for the clauver bash-based CLI tool that manages
multiple Claude Code API providers. This test suite includes unit tests,
integration tests, security tests, and performance benchmarks.

## Test Architecture

The test suite is organized into several categories:

### 🧪 Core Test Categories

1. **Utility Tests** (`test_utilities.sh`)
   - Core utility functions (logging, banner, masking)
   - Configuration management
   - Input validation
   - Performance constants and provider defaults

2. **Encryption & Security Tests** (`test_encryption_security.sh`)
   - Age encryption/decryption functionality
   - Secrets management and caching
   - Configuration file security
   - Input validation and security
   - Migration from plaintext to encrypted storage

3. **Provider Tests** (`test_providers.sh`)
   - Provider switching and configuration
   - Custom provider setup
   - Default provider management
   - Provider status and listing
   - Environment variable setup

4. **Integration Tests** (`test_integration.sh`)
   - End-to-end workflows
   - Setup to usage scenarios
   - Secrets migration workflow
   - Provider switching workflow
   - Error recovery workflows

5. **Error Handling Tests** (`test_error_handling.sh`)
   - Dependency failure handling
   - File permission errors
   - Network error scenarios
   - Memory and resource limits
   - Concurrent access handling
   - Invalid input scenarios

6. **Performance Tests** (`test_performance.sh`)
   - Encryption performance
   - Configuration caching
   - Provider switching performance
   - Memory and disk usage
   - Concurrent operations
   - Large input handling

## Test Framework

The test suite uses a custom test framework (`test_framework.sh`)
that provides:

- **Assertion Functions**: `assert_equals`, `assert_contains`,
  `assert_file_exists`, etc.
- **Mocking System**: `mock_command`, `unmock_command` for external dependencies
- **Environment Management**: `setup_test_environment`, `cleanup_test_environment`
- **Progress Indicators**: Real-time test progress and feedback
- **Test Reporting**: Comprehensive test reports and summaries
- **Color-coded Output**: Easy-to-read test results

## Running Tests

### Quick Start

```bash
# Run all tests
./run_all_tests.sh all

# Run specific test category
./run_all_tests.sh utilities
./run_all_tests.sh encryption
./run_all_tests.sh providers

# Run specific test function
./run_all_tests.sh specific test_utilities.sh test_logging_functions

# Run CI workflow
./run_all_tests.sh ci_workflow

# Run CI-specific checks
./run_all_tests.sh ci_syntax_checks
./run_all_tests.sh ci_security_scan

# Check dependencies
./run_all_tests.sh check_deps

# Clean up test artifacts
./run_all_tests.sh clean

# Generate test report
./run_all_tests.sh report
```

### Using Make

```bash
# Run all tests
make all

# Run specific category
make utilities
make encryption
make providers

# Run CI suite
make ci

# Run GitHub Actions CI locally with act
make ci_act

# Run specific GitHub Actions job
make ci_act_job JOB=tests

# Generate coverage report
make coverage

# Clean up
make clean

# Check syntax
make check

# Run shellcheck
make shellcheck

# Run CI-specific syntax checks
make ci_syntax_checks

# Run security scanning
make ci_security_scan

# Run CI workflow locally
make ci_workflow
```

### Manual Test Execution

```bash
# Test individual files
bash test_framework.sh
source test_framework.sh && test_framework_init && source test_utilities.sh

# Run specific test functions
source test_framework.sh && source test_utilities.sh && test_logging_functions

# Check dependencies before running tests
./run_all_tests.sh check_deps
```

### Dependency Checking

The test suite includes comprehensive dependency checking:

```bash
# Check all required dependencies
make check_deps

# Manual dependency check
./run_all_tests.sh check_deps
```

**Required Dependencies:**

- `age` - Encryption tool for secret management
- `shellcheck` - Shell script linting and analysis
- `bc` - Calculator for performance tests
- `curl` - HTTP client for API testing

**Optional Dependencies:**

- `claude` - Claude CLI (for integration tests)

## Test Configuration

### Environment Variables

The test suite uses several environment variables for configuration:

- `CLAUVER_HOME`: Base directory for test artifacts
- `TEST_ROOT`: Root directory for test files
- `TEST_TEMP_DIR`: Temporary directory for test operations
- `TEST_LOGS_DIR`: Directory for test logs
- `TEST_REPORTS_DIR`: Directory for test reports

### Mock Dependencies

The test framework provides mocking for external dependencies:

- **age**: Encryption/decryption tool
- **claude**: Claude CLI tool
- **curl**: Network requests
- **python3**: JSON parsing for version checks
- **sha256sum**: File integrity verification

### Test Artifacts

Tests generate several artifacts:

- **Logs**: `logs/` directory contains detailed test execution logs
- **Reports**: `reports/` directory contains JSON and text test reports
- **Temp Files**: `tmp/` directory contains temporary test data
- **Coverage**: Test coverage metrics and summaries

## Security Testing

### Test Coverage

The security tests cover:

- **Encryption Security**: Age encryption key management and file permissions
- **Input Validation**: API keys, URLs, provider names, model names
- **Configuration Security**: File permissions and injection prevention
- **Secrets Management**: Secure storage and caching mechanisms
- **Error Handling**: Graceful failure without information leakage

### Security Scenarios

Tests simulate various security scenarios:

- **Injection Attacks**: Command injection, SQL injection, XSS
- **Permission Issues**: Unwritable files, permission errors
- **Corruption Handling**: Corrupted files, invalid keys
- **Network Attacks**: Timeout failures, malicious responses

## Performance Testing

### Performance Metrics

The performance suite measures:

- **Encryption Speed**: Time to encrypt/decrypt secrets
- **Configuration Access**: Cache hit vs. cache miss performance
- **Provider Switching**: Time to switch between providers
- **Memory Usage**: Memory consumption during operations
- **Disk Usage**: Storage space requirements
- **Concurrency**: Performance under concurrent access

### Performance Scenarios

Tests include various performance scenarios:

- **Large Inputs**: Handling large API keys and configuration values
- **Concurrent Operations**: Multiple simultaneous test operations
- **Memory Limits**: Memory usage with many environment variables
- **Disk Constraints**: Storage usage with many configuration entries

## Integration with CI/CD

### GitHub Actions

The test suite includes a comprehensive GitHub Actions workflow (`.github/workflows/test.yml`):

- **Platform Testing**: Ubuntu (optimized for act local testing)
- **Multiple Python Versions**: 3.9, 3.10, 3.11
- **Security Scanning**: Shellcheck, bashate, gitleaks
- **Performance Benchmarking**: Performance tracking and metrics
- **Local Testing**: Full support for act (GitHub Actions runner)

### CI Features

- **Automated Testing**: Runs on push, pull request, and weekly schedule
- **Quality Checks**: Syntax validation, shellcheck, security scanning
- **Local Development**: Same workflow runs locally with act
- **Performance Tracking**: Baseline performance metrics
- **Docker-based**: Uses catthehacker/ubuntu:act-latest for consistency

### Local CI with act

Run the exact same GitHub Actions workflow locally:

```bash
# Install act (GitHub Actions runner)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run complete GitHub Actions CI locally
make ci_act

# Run specific jobs
make ci_act_job JOB=tests
make ci_act_job JOB=security-scan
make ci_act_job JOB=performance-benchmark
```

## Test Data Management

### Test Secrets

The test suite uses synthetic test data:

- **API Keys**: Synthetic keys like `sk-test-123456789`
- **Configuration**: Test configurations for all provider types
- **Age Keys**: Test encryption keys for testing encryption
- **Environment Variables**: Test-specific environment setup

### Test Isolation

Each test runs in isolation:

- **Temporary Directories**: Unique test environment for each test
- **Cleanup**: Automatic cleanup after test completion
- **Environment Reset**: Proper restoration of environment variables
- **No Side Effects**: Tests don't affect the host system

## Test Reporting

### Reports Generated

1. **JSON Reports**: Detailed machine-readable test results
2. **Text Reports**: Human-readable summaries
3. **Coverage Reports**: Test coverage metrics
4. **Performance Reports**: Performance benchmarking results
5. **Security Reports**: Security test results

### Report Features

- **Success Rates**: Pass/fail percentages and trends
- **Error Details**: Detailed error messages and stack traces
- **Performance Metrics**: Timing and resource usage data
- **Security Metrics**: Security test coverage and findings
- **Historical Data**: Performance and trend tracking

## Contributing to Tests

### Adding New Tests

1. **Create Test File**: Add new `test_*.sh` file in the tests directory
2. **Use Framework**: Import and use the test framework functions
3. **Follow Patterns**: Follow existing test patterns and naming conventions
4. **Add Documentation**: Document new test cases and scenarios
5. **Update CI**: Ensure CI/CD pipeline includes new tests

### Test Patterns

```bash
# Standard test pattern
start_test "test_name" "Test description"
setup_test_environment "test_environment"

# Test code here
assert_equals "expected" "actual" "Test message"

cleanup_test_environment "test_environment"
end_test
```

### Mocking External Dependencies

```bash
# Mock a command
mock_command "age" "echo 'mock age output'" 0

# Test using mocked command
# Test cleanup
unmock_command "age"
```

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure test files have execute permissions
2. **Missing Dependencies**: Install age, shellcheck, bc dependencies
3. **Path Issues**: Ensure clauver.sh is in the correct location
4. **Memory Issues**: Clean up temp files between runs

### Debug Mode

Enable debug output by setting environment variables:

```bash
bash -x ./run_all_tests.sh all
```

### Test Isolation Issues

If tests interfere with each other:

1. Clean up artifacts: `make clean`
2. Run tests individually: `make utilities`
3. Check for environment pollution
4. Verify cleanup functions work properly

## Future Enhancements

### Planned Improvements

1. **Property-Based Testing**: Generate random test inputs
2. **Fuzz Testing**: Test with malformed and edge case inputs
3. **Load Testing**: High-concurrency and stress testing
4. **Memory Profiling**: Detailed memory usage analysis
5. **Cross-Version Testing**: Test with multiple clauver versions

### Integration Enhancements

1. **GitHub Actions Integration**: Full local testing with act
2. **Container Testing**: Docker-based testing environment
3. **Automated Updates**: Self-updating test suite
4. **Performance Regression Detection**: Automatic performance issue detection
5. **Security Regression Detection**: Automated security scanning
6. **CI/CD Pipeline**: Complete CI workflow locally and in production

## License

The clauver test suite follows the same license as the main clauver project.

---

For issues, questions, or contributions, please refer to the main clauver
project repository.
