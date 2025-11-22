# CLAUDE.md

## Clauver Project Guidelines & Best Practices

## Project Overview

Clauver is a mature Bash CLI tool (v1.9.2) that manages multiple Claude Code API providers
with encrypted storage. This file provides guidance for coding agents working on this repository.

## Guardrails

- **No unapproved actions**: Always validate destructive operations, confirm file overwrites
- **Protect sensitives**: Never expose API keys or encryption data in logs or outputs
- **Admit limits/redirect**: If a task requires external services beyond scope, ask for clarification
- **Suggest enhancements**: When fixing issues, consider security and usability improvements
- **Decline harm**: Never assist with bypassing encryption or security features

## Best Practices

### Development Principles

- **YAGNI**: Implement only what's needed - Clauver is a focused CLI tool
- **SOLID**: Single responsibility functions in shell scripting
- **DRY**: Reuse existing provider patterns when adding new providers
- **KISS**: Keep shell scripts simple and readable

### 1-3-1 Framework

- **1 problem**: Clearly identify the issue or feature requirement
- **3 solutions**: Consider provider pattern, security impact, and user experience
- **1 recommendation**: Choose the most maintainable approach following existing patterns

### Code Quality

- **Clean code**: Use descriptive function names, comment complex shell logic
- **Security**: Validate all inputs, handle secrets properly, maintain encryption integrity
- **80%+ test coverage**: Comprehensive tests already exist - maintain this standard
- **Comprehensive docs**: Update README, TROUBLESHOOTING.md, and test docs as needed
- **Pinned dependencies**: Use specific versions when external tools are required

### Shell Scripting Standards

- **Start with**: `#!/usr/bin/env bash`, `set -euo pipefail`, `IFS=$'\n\t'`
- **Error handling**: Use proper exit codes, implement cleanup functions
- **Security**: Avoid eval, validate user input, use parameter expansion
- **Portability**: Target bash 4.0+ compatibility, avoid platform-specific features

## Architecture Patterns

### Provider Pattern

When adding new providers, follow the established pattern:

```bash
# Add to PROVIDER_DEFAULTS array
["new_provider_base_url"]="https://api.example.com/anthropic"
["new_provider_default_model"]="model-name"

# Implement provider configuration
config_new_provider() {
    # Follow existing config_* function patterns
}

# Implement provider switching
switch_to_new_provider() {
    # Follow established switch_to_* function patterns
}
```

### Encryption & Security

- **Age encryption**: Always encrypt API keys at rest using `secrets.env.age`
- **Memory-only decryption**: Never write plaintext secrets to disk
- **File permissions**: Use `umask 077`, enforce 600 permissions on sensitive files
- **Input validation**: Validate API keys, URLs, provider names rigorously

### Testing Framework

- **Use existing framework**: `test_framework.sh` provides comprehensive test utilities
- **Mock external dependencies**: Use provided mocking system for external tools
- **Test isolation**: Each test should run independently with proper cleanup
- **Coverage areas**: Unit, integration, security, performance tests

## Debugging Methodology

### Scientific Method + ReAct Analysis

1. **Observe**: Gather logs, error messages, system state
2. **Hypothesize**: Identify likely root causes based on evidence
3. **Test**: Run specific tests to confirm/deny hypothesis
4. **Analyze**: Review results, compare with expected behavior
5. **Iterate**: Refine hypothesis and repeat

### Minimal Reproducible

- Create minimal test cases for issues
- Use existing test framework patterns
- Isolate variables and dependencies
- Document reproduction steps clearly

### 3 Strategic Prints

1. **Entry point**: Log function entry with key parameters
2. **Critical state**: Log important variable states before key operations
3. **Exit point**: Log function completion with result status

### Binary Search Debugging

- Comment out half the code to isolate issues
- Use existing test suite to validate changes
- Reintroduce code incrementally to identify problem lines
- Leverage `bash -x` for detailed execution tracing

## Build System & CI/CD

### Make Targets

```bash
make all          # Run all tests
make ci           # Run CI workflow locally
make shellcheck   # Lint shell scripts
make clean        # Clean test artifacts
make check        # Syntax and dependency validation
```

### GitHub Actions

- **CI pipeline**: Ubuntu-based with Docker container
- **Multi-Python**: Test with Python 3.9-3.11
- **Security scanning**: Shellcheck, bashate, gitleaks
- **Local testing**: Full support for `act` (GitHub Actions runner)

### Quality Gates

- All tests must pass before merging
- Shellcheck must report zero issues
- Security scans must be clean
- Documentation must be updated for API changes

## Key Configuration Files

- **`clauver.sh`**: Main application (1,685 lines)
- **`~/.clauver/config`**: Provider configurations
- **`~/.clauver/secrets.env.age`**: Encrypted API keys
- **`~/.clauver/age.key`**: Encryption key (CRITICAL: backup required)
- **`tests/test_framework.sh`**: Custom test framework
- **`.github/workflows/test.yml`**: CI/CD pipeline

## Common Workflows

### Adding a New Provider

1. Update `PROVIDER_DEFAULTS` array in `clauver.sh`
2. Create `config_<provider>()` and `switch_to_<provider>()` functions
3. Add provider to completion scripts
4. Update documentation and tests
5. Run full test suite and CI validation

### Debugging Issues

1. Run `clauver status` to check system state
2. Use `bash -x clauver.sh <command>` for detailed tracing
3. Check logs in `~/.clauver/` if present
4. Run relevant test categories: `make utilities`, `make providers`

### Security Response

1. Immediately validate encryption integrity
2. Check file permissions on sensitive files
3. Review recent changes for security regressions
4. Run security tests: `make ci_security_scan`
5. Update documentation if needed

Remember: Clauver handles sensitive API keys and encryption - always prioritize security
and follow the established patterns for safe credential management.
