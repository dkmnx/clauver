# CLAUDE.md

## Comprehensive Project Analysis

**Purpose**: Clauver enables seamless switching between multiple Claude Code API providers.
Features include encrypted API key storage, interactive setup, provider testing, and cross-platform support.

**Structure**:

- **Key directories**:
  - `./` - Root directory with main bash script (2,389 lines)
  - `completion/` - Shell auto-completion scripts (bash, fish, zsh)
  - `scripts/` - Release preparation and build automation
  - `tests/` - Comprehensive test suite with 13 test files
  - `docs/` - Documentation and detailed Go rewrite implementation plan

- **Main files**:
  - `clauver.sh` - Core bash script (2,389 lines)
  - `install.sh` - Quick installation script
  - `README.md` - Comprehensive user documentation
  - `TROUBLESHOOTING.md` - Debugging guide
  - `LICENSE` - MIT license

- **File count**: 31 files tracked in git

**Tech Stack**:

- **Languages**: Bash (primary), with planned Go rewrite in progress
- **Frameworks**: Native bash with age encryption, planned Cobra CLI framework
- **Dependencies**:
  - `claude` CLI tool (npm package)
  - `age` for encryption
  - Standard Unix tools (curl, jq, etc.)
- **Build tools**: Make, goreleaser (planned), GitHub Actions CI/CD

**Current State**:

- **Last update**: Recent commits show active development (v1.12.1)
- **Repository type**: Mature bash project with comprehensive testing
- **Documentation status**: Excellent - detailed README, troubleshooting, and Go rewrite plan
- **Issues/Status**:
  - Production-ready bash implementation
  - Comprehensive test suite covering security, performance, integration
  - Active development with Go rewrite planned for better cross-platform support

## Guardrails

- No unapproved actions, protect sensitives, admit limits/redirect
- Suggest enhancements, decline harmful activities
- Focus on defensive security analysis and authorized testing

## Best Practices

- **YAGNI**: Implement only essential features, avoid over-engineering
- **SOLID**: Single responsibility in script modules, open for extension with new providers
- **DRY**: Reusable functions for common operations
- **KISS**: Simple bash implementation focused on core functionality
- **1-3-1 Framework**: For issues: identify 1 core problem, explore 3 solutions, recommend 1
- **Clean code**: Well-commented bash script with modular functions
- **Security**: Age encryption for API keys, threat modeling considered
- **80%+ test coverage**: Comprehensive test suite with unit, integration, security tests
- **Pinned dependencies**: Version-specific installation requirements
- **Fix all warnings**: Shellcheck passing, rigorous error handling

## Debugging

**Scientific Method + Minimal Repro + Strategic Analysis:**

1. **Observe**: Gather error details, check environment, reproduce issue
2. **Hypothesize**: Form theories about root cause based on symptoms
3. **Test**: Verify hypotheses with targeted tests
4. **Analyze**: Examine logs, code paths, and system state
5. **Fix**: Implement minimal change to address root cause

**Binary Search Approach**: For complex issues, use binary search to isolate problematic code sections.

## Critical Implementation Rules

**NO SHORTCUTS RULE**: All submitted code undergoes rigorous review with zero tolerance for incomplete work.

The following are explicitly forbidden and will cause immediate rejection + full rewrite:

- Placeholders, stubs, "TODO", or commented-out pseudocode
- Dummy/simplified implementations or mock data used as shortcuts
- Hardcoded values instead of proper configuration/abstraction
- Incomplete functions, classes, or control flows
- Fake APIs, simulated responses, or fallback behaviors
- Any assumption that "this will be fixed later"

Every line must be production-ready, fully implemented, conceptually tested, and defensible.
Partial submissions waste time and will be rejected.

## Project-Specific Guidelines

### Security Requirements

- All API keys must be encrypted using age
- No plaintext storage of sensitive information
- Secure file permissions (0600) for config files
- Input validation for all user inputs
- Memory-only decryption of secrets

### Testing Requirements

- Must pass entire test suite: `cd tests/ && make test`
- Shellcheck must pass without warnings
- Cross-platform compatibility testing
- Security validation for encryption/decryption

### Code Quality Standards

- Follow bash best practices (set -euo pipefail)
- Use functions for modularity and reusability
- Comprehensive error handling with meaningful messages
- Consistent coding style throughout
- Documentation for all public functions

### Release Process

- Version updates must follow semantic versioning
- Checksum generation for release artifacts
- Update version badges in README
- Comprehensive testing before release

**CRITICAL**: Don't add `CLAUDE.md`, `ai_docs`, `docs/plan` in git commits/pushes.
- If porting or rewriting the @clauver.sh into other language, always check the @clauver.sh for the actual implementation when issues arises during the development