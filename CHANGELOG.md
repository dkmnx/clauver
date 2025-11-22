# Changelog

All notable changes to Clauver will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.10.0] - 2025-11-22

### Added

- **Comprehensive SHA256 release workflow** - automated release preparation with checksum generation and validation
- **GitHub release integration** - `--gh-release` flag to automatically create GitHub releases and upload artifacts
- **Individual SHA256 files** - separate .sha256 files for each release artifact alongside comprehensive SHA256SUMS
- **Release preparation script** - `scripts/release-prepare.sh` with dry-run support and version validation
- **Comprehensive release testing** - `tests/test_release.sh` with full test coverage for release functionality
- **Release process documentation** - detailed installation instructions and workflow integration

### Security

- **SHA256 checksum verification** - cryptographic integrity validation for all release artifacts
- **Version format validation** - enforced semantic versioning (v{major}.{minor}.{patch}) format
- **Security-focused release process** - automated artifact verification and validation

### Improved

- **CI/CD workflow integration** - enhanced GitHub Actions workflow with release artifact generation
- **Release artifact management** - improved organization and verification of distributed files
- **Development workflow cleanup** - removed AI-generated directories and files from version control
- **Documentation updates** - enhanced README with release process instructions
- **Shellcheck compliance** - resolved warnings in release test files

## [1.9.2] - 2025-11-22

### Fixed

- **Configuration cache reload** - resolved provider model configuration not taking effect immediately after changes
- **Provider banner display** - fixed model information not showing correctly in provider switching banners

### Refactored

- **Streamlined provider configuration system** - replaced hardcoded provider-specific configuration with
  dynamic generic function
- **Enhanced extensibility** - enabled easier addition of new providers through configuration metadata system
- **Reduced code duplication** - consolidated provider configuration logic into reusable components

### Improved

- **Dynamic model configuration** - ZAI, MiniMax, DeepSeek, and Kimi providers now support configurable models
- **Configuration cache management** - improved cache invalidation and reload logic for real-time configuration updates
- **Provider switching UX** - enhanced provider banners to display current model information

## [1.9.1] - 2025-11-22

### Fixed

- **Critical test framework fixes** - resolved CLAUVER_HOME initialization order causing mktemp permission errors
- **DeepSeek provider validation** - added "deepseek" to reserved provider names list to prevent conflicts
- **Test isolation improvements** - proper clauver.sh sourcing pattern for test environment setup
- **Utilities test framework** - fixed missing clauver.sh source causing validation function failures

### Improved

- **Test coverage** - comprehensive DeepSeek tests across all test categories
  (utilities, providers, security, integration, error handling)
- **Test reliability** - eliminated permission errors and initialization race conditions
- **Documentation formatting** - improved test README readability with better visual separation

### Added

- **DeepSeek test visibility** - DeepSeek-specific test output now appears in all relevant test suites
- **Performance constants validation** - DeepSeek API timeout settings validation
- **Provider defaults verification** - DeepSeek configuration defaults testing

## [1.9.0] - 2025-11-22

### Added

- **DeepSeek provider integration** with full API support and model compatibility
- DeepSeek-specific configuration and timeout settings
- DeepSeek command registration in main dispatcher
- Shell completion support for DeepSeek provider (bash, zsh, fish)
- Comprehensive changelog file for tracking version changes
- Markdownlint configuration for consistent documentation formatting

### Improved

- Enhanced security and UX for DeepSeek provider integration
- Updated provider documentation to include DeepSeek examples
- Consistent provider switching patterns for DeepSeek
- Better user clarity with available model information display

## [1.8.0] - 2025-11-15

### Added

- Comprehensive CI test suite with security and performance checks
- Local CI testing with enhanced workflow and dependency checks
- Performance benchmark job running in containerized environment
- CI workflow badge to README

### Fixed

- Test reliability improvements and environment setup
- Shellcheck warnings in test files resolved
- Variable assignment clarity in syntax checks
- Makefile output improvements with graceful error handling

### Improved

- Enhanced testing documentation
- Removed report job from test workflow for cleaner CI output

## [1.7.0] - 2025-11-15

### Added

- Comprehensive testing documentation to README
- Shell completion updates with new commands and options
- Troubleshooting guide extraction and documentation reorganization

### Removed

- Deprecated KAT-Coder provider from install script
- Legacy encryption validation suite
- Windows test job (focused on Linux compatibility)

### Fixed

- Critical security issues including injection attack prevention
- Unused variables in test scripts
- Shellcheck warnings across test files
- Sensitive test artifacts tracking (improved .gitignore)

### Improved

- Provider configuration and performance defaults
- Configuration and provider switching logic modularization
- Security scanning with manual gitleaks installation
- Test framework renamed for consistency (test-framework.sh → test_framework.sh)

## [1.6.1] - 2025-11-15

### Added

- Comprehensive security improvements
- Enhanced input validation and sanitization
- Better protection against injection attacks

### Fixed

- Version check simplification in cmd_version function
- Security vulnerabilities in API key and model name handling

## [1.6.0] - 2025-11-09

### Added

- **Age encryption** for secure secret storage
- **Secrets migration functionality** to transition from plaintext to encrypted storage
- **Encryption key management** with backup and recovery features
- Comprehensive **encryption and key management documentation**

### Security

- API keys now encrypted at rest using age (X25519)
- Memory-only decryption via process substitution
- No plaintext secrets written to disk
- Automatic key generation and migration support

## [1.5.0] - 2025-11-09

### Added

- **Version check functionality** to display current version
- **Auto-update capability** to update to latest version
- Comprehensive version and update commands documentation

### Improved

- README formatting and content clarity

## [1.4.1] - 2025-11-07

### Fixed

- Default provider fallback for unknown commands

## [1.4.0] - 2025-11-07

### Added

- **Configurable base URL support** for Kimi provider
- **Configurable model support** for Kimi provider

### Improved

- Enhanced installation guide with default provider workflow
- Installer script references updated in README
- Installer script renamed to `install.sh` for clarity

## [1.3.1] - 2025-11-03

### Fixed

- Default provider selection for unknown commands

## [1.3.0] - 2025-11-03

### Added

- **Default provider feature** - Set and use a preferred default provider
- **Automatic provider selection** with configurable defaults
- Default provider command completion support
- Comprehensive usage examples in README

### Improved

- README formatting with enhanced project title and description placement

## [1.2.3] - 2025-11-03

### Added

- ASCII art Clauver logo to introduction section

## [1.2.2] - 2025-11-02

### Added

- Caution warning for custom providers in documentation

## [1.2.1] - 2025-11-02

### Improved

- Italic formatting applied to product name references
- Clarified references to Claude Code API providers

## [1.2.0] - 2025-11-02

### Added

- **Version command** to display current version information

## [1.1.0] - 2025-11-02

### Added

- **Remote installation support** via curl
- Enhanced installation script with improved script source detection
- Updated installation instructions for clarity and consistency

### Improved

- Shell completion scripts with normalized whitespace and spacing
- README formatting improvements

## [1.0.1] - 2025-11-02

### Added

- **Credits** to clother repository for inspiration

### Fixed

- Duplicate checkmark symbols in success messages removed

## [1.0.0] - 2025-11-02

### Added

- **Clauver installer** for automated setup
- **Shell completions** for bash, zsh, and fish
- **Core clauver.sh script** with provider management functionality
- Support for multiple AI providers:
  - Native Anthropic Claude
  - Z.AI (Zhipu AI GLM models)
  - MiniMax (MiniMax-M2 model)
  - Kimi (Moonshot AI Kimi K2 model)
  - Custom providers
- Encrypted API key management
- Configuration testing and status monitoring
- Quick setup wizard for beginners
