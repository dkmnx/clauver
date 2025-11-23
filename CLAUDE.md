# CLAUDE.md

## Project Analysis

**Purpose**: Clauver is a CLI tool that manages and switches between multiple Claude Code API
providers, including Native Anthropic, Z.AI, MiniMax, Kimi, DeepSeek, and custom providers.
It features encrypted API key storage, provider testing, default provider management, and
auto-completion.

**Structure**:

- **Key directories**:
  - `tests/` - Comprehensive test suite with 6 test categories
  - `.github/workflows/` - CI/CD pipeline with security scanning
  - `completion/` - Shell auto-completion scripts
  - `scripts/` - Release and utility scripts
  - `dist/` - Distribution files

- **Main files**:
  - `clauver.sh` - Core Bash script (57KB, 1847 lines)
  - `install.sh` - Quick installer
  - `README.md` - Comprehensive documentation (11KB)
  - `TROUBLESHOOTING.md` - Troubleshooting guide
  - `CHANGELOG.md` - Version history (10KB)

- **File count**: ~25 files including tests, docs, and CI configuration

**Tech Stack**:

- **Languages**: Bash (primary), Python (version checking), YAML (CI/CD)
- **Frameworks**: GitHub Actions for CI/CD, Make for test orchestration
- **Dependencies**: age (encryption), shellcheck (linting), curl (API calls), claude CLI
- **Platform**: Linux-focused (tested on Ubuntu), with macOS compatibility notes

**Current State**:

- **Last update**: Recently modified files include clauver.sh, tests, and documentation
- **Repository type**: Git repository with active development (v1.11.0)
- **Documentation status**: Excellent - comprehensive README, detailed troubleshooting,
  and test documentation
- **Issues/Status**: Recent commit shows version bump to v1.11.0 with merged refactor branch.
  All test scripts are executable and recent.

## Guardrails

- **No unapproved actions**: Always get confirmation before making destructive changes
- **Protect sensitives**: Never expose API keys, encryption keys, or sensitive configuration
- **Admit limits/redirect**: Clearly state when something is beyond scope or requires expertise
- **Suggest enhancements**: Propose improvements within reason
- **Decline harmful activities**: Refuse to assist with malicious code or security vulnerabilities

## Best Practices

- **YAGNI, SOLID, DRY, KISS**: Keep code simple, focused, and maintainable
- **1-3-1 Framework**: 1 core problem, 3 solution options, 1 recommended approach
- **Clean code**: Comment complex logic, use meaningful variable names
- **Security**: No hardcoded secrets, implement threat modeling, use encryption properly
- **80%+ test coverage**: Comprehensive test suite with unit, integration, security, and performance tests
- **Comprehensive docs**: README, docstrings, and troubleshooting guides
- **Pinned dependencies**: Use specific versions and validate integrity
- **Fix all warnings**: Use ReAct analysis (logs, code, causes) and confirm fixes

## Debugging

**Scientific Method + Minimal Repro + 3 Strategic Prints + Binary Search**:

1. **Observe**: Gather symptoms, error messages, and environmental context
2. **Hypothesize**: Form specific, testable explanations
3. **Predict**: State expected outcomes for validation
4. **Test**: Use minimal reproduction cases and targeted logging
5. **Analyze**: Compare results with predictions
6. **Iterate**: Refine hypothesis or proceed to fix

**Three Strategic Prints**:

- Entry point: Verify function invocation and parameters
- Critical state: Check variable values at decision points
- Exit condition: Confirm function completion and return values

**Binary Search**: Isolate issues by dividing and conquering - comment out half the code, test, repeat.

## Project-Specific Guidelines

### Code Style

- **Shell Script**: Use `set -euo pipefail`, `IFS=$'\n\t'`, proper quoting, and shellcheck compliance
- **Security**: Encrypt secrets with age, validate inputs, prevent injection attacks
- **Error Handling**: Use specific error messages, proper exit codes, and cleanup traps
- **Testing**: Use the provided test framework with `start_test`, `assert_equals`, etc.

### File Organization

- **Main script**: `clauver.sh` - single file with clear function separation
- **Configuration**: `~/.clauver/` directory with encrypted secrets and config
- **Tests**: Organized by category (utilities, encryption, providers, integration, error handling, performance)
- **Documentation**: README for users, TROUBLESHOOTING.md for issues, CHANGELOG.md for history

### Development Workflow

- **Testing**: Run `make test` or `make ci` for comprehensive testing
- **Linting**: Use shellcheck and bashate for code quality
- **Security**: Regular scans with gitleaks and dependency checks
- **Release**: Use `scripts/release-prepare.sh` and update CHANGELOG.md

### Key Architectural Patterns

- **Provider abstraction**: `switch_to_provider()` function with environment variable setup
- **Encrypted storage**: Age encryption with memory-only decryption
- **Configuration caching**: `CONFIG_CACHE` array for performance
- **Background processing**: Progress indicators with cleanup traps
- **Input validation**: Comprehensive validation framework for API keys, URLs, and provider names

## Testing Strategy

### Test Categories

1. **Utilities**: Core functions, logging, validation
2. **Encryption**: Age key management, secret encryption/decryption
3. **Providers**: Configuration, switching, API testing
4. **Integration**: End-to-end workflows
5. **Error Handling**: Edge cases and failure modes
6. **Performance**: Speed and resource usage benchmarks

### Test Framework

- Use the provided `test_framework.sh` with standardized test functions
- Follow naming conventions: `test_function_name_description`
- Include setup/teardown with `setup_test()` and `teardown_test()`
- Use `start_test`, `end_test`, `assert_equals`, etc.

### CI/CD Pipeline

- **GitHub Actions**: Multi-OS testing with Python matrix
- **Security scanning**: gitleaks for secrets, shellcheck for code quality
- **Performance benchmarks**: Resource usage and timing validation
- **Coverage reporting**: Test coverage analysis and documentation generation

## Quality Assurance

### Pre-commit Checklist

- [ ] Syntax check: `bash -n clauver.sh`
- [ ] Shellcheck: `shellcheck clauver.sh`
- [ ] Tests pass: `make test`
- [ ] Documentation updated: README.md, CHANGELOG.md
- [ ] No hardcoded secrets: `grep -r "sk-" .`
- [ ] Version bump: Update VERSION constant in clauver.sh

### Release Process

1. Update version in `clauver.sh` (VERSION constant)
2. Update CHANGELOG.md with new features/fixes
3. Run full test suite: `make ci`
4. Tag release: `git tag v1.x.x`
5. Push tag: `git push origin v1.x.x`
6. GitHub Actions will handle distribution

This file provides guidance for coding agents working in this repository, ensuring consistency
with the project's architecture, security practices, and quality standards.
