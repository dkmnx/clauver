# Changelog

All notable changes to Clauver will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.12.5] - 2025-12-23

### Changed

- Provider models - Updated default models for improved compatibility:
  - Z.AI: `glm-4.6` → `glm-4.7` (retained `glm-4.5-air` for haiku model)
  - MiniMax: `MiniMax-M2` → `Minimax-M2.1`

## [1.12.4] - 2025-12-21

### Improved

- List command output - Enhanced `clauver list` command to hide "Not Configured:" section when all providers are
properly configured, resulting in cleaner output and improved user experience

## [1.12.3] - 2025-12-21

### Refactored

- Provider configuration - Consolidated provider configuration logic with metadata-driven approach using
  PROVIDER_METADATA and PROVIDER_ENV_VARS arrays
- Environment setup - Extracted common environment setup into setup_provider_environment() function to reduce code duplication
- Provider implementations - Replaced hardcoded switch cases with metadata-driven approach for zai, minimax, kimi,
  and deepseek providers while maintaining identical functionality

### Added

- Comprehensive test coverage - Added detailed tests for provider metadata functionality and
  setup_provider_environment function
- Enhanced provider environment tests - Added detailed assertions for each provider's specific configuration variables

## [1.12.2] - 2025-12-20

### Changed

- Test coverage - Enhanced validation test coverage with comprehensive test cases for API key validation
- Security validation - Improved dangerous character detection in content validation functions
- Code organization - Simplified content validation logic and removed redundant validation patterns
- Documentation - Reorganized changelog sections to maintain logical grouping of changes

### Fixed

- Test references - Updated version references from v1.12.0 to v1.12.1 in banner tests
- Validation testing - Fixed function name consistency in model validation tests
- API key validation - Ensured validation correctly handles keys containing 'rm' substring
- Version links - Fixed broken reference links by placing them after all changelog content

### Security

- Streamlined content validation and security checks:
  - Removed redundant MATCH_SHELL_PATTERNS array validation
  - Enhanced dangerous character detection in validate_decrypted_content
  - Simplified load_secrets decryption process using direct memory operations
  - Improved get_config function to use unified cache access pattern
  - Refined load_decrypted_content_safely with proper line-by-line processing
  - Removed temporary file usage in load_secrets for better security

## [1.12.1] - 2025-12-04

### Changed

- Enhanced model name compatibility - Now supports common model naming patterns:
  - Provider/model format (e.g., `openai/gpt-4`)
  - Model:tag format (e.g., `amazon/nova-2-lite-v1:free`)
  - Traditional model names (e.g., `glm-4.6`, `MiniMax-M2`)
- Updated version references across documentation and installation scripts

### Fixed

- Model name validation - Extended validation regex to support modern model identifier formats
- Removed restrictive character limitations that prevented using provider/model:tag formats
- Fixed validation for model names containing forward slashes (/) and colons (:)
- Cleaned up unused `validation_model_name()` function that contained outdated validation logic

## [1.12.0] - 2025-11-23

### Added

- Consistent naming conventions - All new module functions follow `module_function` naming pattern
- Enhanced test coverage - Added 4 new comprehensive test suites with 75+ additional test cases
- Improved security validation - Multi-layer security checks across all validation functions
- Automatic cache management - Intelligent cache invalidation prevents stale configuration issues
- Enhanced temp file handling - Secure temporary file creation with automatic cleanup
- Enhanced crypto operations - Convenient wrapper functions for encryption/decryption operations
- Comprehensive shellcheck compliance - All code passes shellcheck with zero warnings or errors

### Improved

- Code organization - Clear separation of concerns with well-defined module boundaries
- Maintainability - Modular architecture makes code easier to understand and modify
- Testability - Isolated module testing enables comprehensive test coverage
- Security - Centralized validation and crypto functions reduce security surface area
- Performance - Optimized caching and file management improve operational efficiency
- Developer experience - Consistent API patterns make the codebase easier to work with
- Backward compatibility - All existing function names continue to work without breaking changes

### Refactored

- Comprehensive module extraction with consistent naming conventions
- UI Module - Extracted user interface functions with `ui_` prefixes:
  - `ui_log()`, `ui_success()`, `ui_warn()`, `ui_error()`, `ui_banner()`
  - Consistent visual styling and enhanced output formatting
  - Backward compatibility with existing function names
- Validation Module - Extracted input validation functions with `validation_` prefixes:
  - `validation_api_key()`, `validation_url()`, `validation_provider_name()`, `validation_model_name()`, `validation_decrypted_content()`
  - Enhanced security validation with SSRF protection and injection attack prevention
  - Provider-specific validation rules with customizable security policies
- Configuration Module - Extracted configuration management with `config_` prefixes:
  - `config_get_value()`, `config_set_value()`, `config_cache_load()`, `config_cache_invalidate()`
  - `config_load_secrets()`, `config_get_secret()` with improved secret loading
  - Automatic cache invalidation on configuration changes for real-time updates
- Crypto Module - Extracted cryptographic operations with `crypto_` prefixes:
  - `crypto_create_temp_file()`, `crypto_ensure_key()`, `crypto_show_age_help()`
  - `crypto_cleanup_temp_files()`, `crypto_encrypt_file()`, `crypto_decrypt_file()`
  - Enhanced temporary file management with automatic cleanup on script exit
- Modular test architecture - Created comprehensive test suites for each module:
  - `test_ui_module.sh` - UI functionality testing
  - `test_validation_module.sh` - Input validation security testing
  - `test_config_module.sh` - Configuration management testing
  - `test_crypto_module.sh` - Cryptographic operations testing

## [1.11.2] - 2025-11-23

### Added

- Comprehensive security test suite - Added extensive security testing coverage with:
  - Command injection prevention tests
  - SSRF protection validation
  - Secure temporary file handling tests
  - Safe environment loading verification
  - Background cleanup security tests
  - Path sanitization validation
  - Comprehensive secret validation tests
  - Integration security testing
- New test files:
  - `test_security_hardening.sh` - 301 lines of comprehensive security tests
  - Enhanced `test_security.sh` - 214 lines of additional security validations
- Enhanced test infrastructure - Updated test framework to support security test categories

### Fixed

- Command injection vulnerability - Prevented command injection through malicious input validation
- Path disclosure vulnerability - Sanitized error messages to prevent information disclosure
- Insecure temporary file creation - Implemented secure temporary file handling with proper permissions
- Unsafe environment loading - Replaced dangerous `source()` usage with secure alternatives
- Background process cleanup - Fixed PID validation and enhanced process termination security

### Security

- Critical security hardening - Added comprehensive protection against command injection and path disclosure vulnerabilities
- Path sanitization - Implemented robust input sanitization to prevent information disclosure in error messages
- SSRF protection - Added Server-Side Request Forgery protection for URL validation to block internal network access
- Secure temporary file handling - Enhanced temporary file creation with proper permissions and validation
- Safe environment loading - Replaced unsafe `source()` calls with secure environment variable loading mechanisms
- Background process security - Improved background process cleanup with PID validation and enhanced signal handling
- API key validation hardening - Strengthened API key and URL validation against injection attacks
- Enhanced trap management - Improved signal handling and process cleanup security

## [1.11.1] - 2025-11-23

### Added

- Comprehensive security test suite - 40+ test assertions covering all attack vectors:
  - `test_decrypted_content_validation()` with 21 unit tests
  - `test_load_secrets_malicious_content()` with 7 integration tests
  - Protection against injection attacks, error message corruption, and format violations
- Enhanced test coverage - Security validation tests integrated into existing test framework
- End-to-end security validation - Complete testing of `load_secrets()` function with malicious content

### Fixed

- Security vulnerability - Previously decrypted content could be executed without proper validation
- False positive prevention - Improved error detection patterns to avoid false positives with valid variable names
- Comprehensive input sanitization - Multi-layer validation prevents various attack vectors

### Security

- Critical security enhancement - Added comprehensive validation for decrypted secrets content to prevent
  execution of malicious code
- Decrypted content validation - New `validate_decrypted_content()` function performs multiple security checks:
  - Detection of error indicators and corruption patterns
  - Rejection of dangerous bash constructs (`$,`, (), [], {}, ;, &, |, <, >`)
  - Strict validation of environment variable format (`KEY=value`)
  - Prevention of command injection and substitution attacks
- Enhanced error handling - Detailed recovery instructions when validation fails
- Memory-only security - Secrets are only decrypted in memory and validated before execution

## [1.11.0] - 2025-11-22

### Improved

- File permissions consistency - updated all test scripts to have executable permissions
- README organization - moved credits section to the end for better documentation flow
- GitHub Actions workflow - upgraded to actions/upload-artifact v4 for improved reliability

### Refactored

- Enhanced command completion - improved shell completion scripts (bash, zsh, fish) with custom options support
- Code cleanup and validation - improved error handling and cleanup processes in clauver.sh
- Release script improvements - enhanced validation, better error handling, and improved project root detection

### Fixed

- CI/CD workflow efficiency - removed redundant SHA256 validation job and optimized artifact upload process
- Release process documentation - cleaned up outdated release steps and streamlined release notes generation
- Security clarification - emphasized that secrets are only decrypted in memory and never written to disk

## [1.10.0] - 2025-11-22

### Added

- Comprehensive SHA256 release workflow - automated release preparation with checksum generation and validation
- GitHub release integration - `--gh-release` flag to automatically create GitHub releases and upload artifacts
- Individual SHA256 files - separate .sha256 files for each release artifact alongside comprehensive SHA256SUMS
- Release preparation script - `scripts/release-prepare.sh` with dry-run support and version validation
- Comprehensive release testing - `tests/test_release.sh` with full test coverage for release functionality
- Release process documentation - detailed installation instructions and workflow integration

### Improved

- CI/CD workflow integration - enhanced GitHub Actions workflow with release artifact generation
- Release artifact management - improved organization and verification of distributed files
- Development workflow cleanup - removed AI-generated directories and files from version control
- Documentation updates - enhanced README with release process instructions
- Shellcheck compliance - resolved warnings in release test files

### Security

- SHA256 checksum verification - cryptographic integrity validation for all release artifacts
- Version format validation - enforced semantic versioning (v{major}.{minor}.{patch}) format
- Security-focused release process - automated artifact verification and validation

## [1.9.2] - 2025-11-22

### Improved

- Dynamic model configuration - ZAI, MiniMax, DeepSeek, and Kimi providers now support configurable models
- Configuration cache management - improved cache invalidation and reload logic for real-time configuration updates
- Provider switching UX - enhanced provider banners to display current model information

### Refactored

- Streamlined provider configuration system - replaced hardcoded provider-specific configuration with
  dynamic generic function
- Enhanced extensibility - enabled easier addition of new providers through configuration metadata system
- Reduced code duplication - consolidated provider configuration logic into reusable components

### Fixed

- Configuration cache reload - resolved provider model configuration not taking effect immediately after changes
- Provider banner display - fixed model information not showing correctly in provider switching banners

## [1.9.1] - 2025-11-22

### Added

- DeepSeek test visibility - DeepSeek-specific test output now appears in all relevant test suites
- Performance constants validation - DeepSeek API timeout settings validation
- Provider defaults verification - DeepSeek configuration defaults testing

### Improved

- Test coverage - comprehensive DeepSeek tests across all test categories
  (utilities, providers, security, integration, error handling)
- Test reliability - eliminated permission errors and initialization race conditions
- Documentation formatting - improved test README readability with better visual separation

### Fixed

- Critical test framework fixes - resolved CLAUVER_HOME initialization order causing mktemp permission errors
- DeepSeek provider validation - added "deepseek" to reserved provider names list to prevent conflicts
- Test isolation improvements - proper clauver.sh sourcing pattern for test environment setup
- Utilities test framework - fixed missing clauver.sh source causing validation function failures

## [1.9.0] - 2025-11-22

### Added

- DeepSeek provider integration with full API support and model compatibility
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

### Improved

- Enhanced testing documentation
- Removed report job from test workflow for cleaner CI output

### Fixed

- Test reliability improvements and environment setup
- Shellcheck warnings in test files resolved
- Variable assignment clarity in syntax checks
- Makefile output improvements with graceful error handling

## [1.7.0] - 2025-11-15

### Added

- Comprehensive testing documentation to README
- Shell completion updates with new commands and options
- Troubleshooting guide extraction and documentation reorganization

### Improved

- Provider configuration and performance defaults
- Configuration and provider switching logic modularization
- Security scanning with manual gitleaks installation
- Test framework renamed for consistency (test-framework.sh → test_framework.sh)

### Removed

- Deprecated KAT-Coder provider from install script
- Legacy encryption validation suite
- Windows test job (focused on Linux compatibility)

### Fixed

- Critical security issues including injection attack prevention
- Unused variables in test scripts
- Shellcheck warnings across test files
- Sensitive test artifacts tracking (improved .gitignore)

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

- Age encryption for secure secret storage
- Secrets migration functionality to transition from plaintext to encrypted storage
- Encryption key management with backup and recovery features
- Comprehensive encryption and key management documentation

### Security

- API keys now encrypted at rest using age (X25519)
- Memory-only decryption via process substitution
- No plaintext secrets written to disk
- Automatic key generation and migration support

## [1.5.0] - 2025-11-09

### Added

- Version check functionality to display current version
- Auto-update capability to update to latest version
- Comprehensive version and update commands documentation

### Improved

- README formatting and content clarity

## [1.4.1] - 2025-11-07

### Fixed

- Default provider fallback for unknown commands

## [1.4.0] - 2025-11-07

### Added

- Configurable base URL support for Kimi provider
- Configurable model support for Kimi provider

### Improved

- Enhanced installation guide with default provider workflow
- Installer script references updated in README
- Installer script renamed to `install.sh` for clarity

## [1.3.1] - 2025-11-03

### Fixed

- Default provider selection for unknown commands

## [1.3.0] - 2025-11-03

### Added

- Default provider feature - Set and use a preferred default provider
- Automatic provider selection with configurable defaults
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

- Version command to display current version information

## [1.1.0] - 2025-11-02

### Added

- Remote installation support via curl
- Enhanced installation script with improved script source detection
- Updated installation instructions for clarity and consistency

### Improved

- Shell completion scripts with normalized whitespace and spacing
- README formatting improvements

## [1.0.1] - 2025-11-02

### Added

- Credits to clother repository for inspiration

### Fixed

- Duplicate checkmark symbols in success messages removed

## [1.0.0] - 2025-11-02

### Added

- Clauver installer for automated setup
- Shell completions for bash, zsh, and fish
- Core clauver.sh script with provider management functionality
- Support for multiple AI providers:
  - Native Anthropic Claude
  - Z.AI (Zhipu AI GLM models)
  - MiniMax (MiniMax-M2 model)
  - Kimi (Moonshot AI Kimi K2 model)
  - Custom providers
- Encrypted API key management
- Configuration testing and status monitoring
- Quick setup wizard for beginners

[1.12.4]: https://github.com/dkmnx/clauver/compare/v1.12.3...v1.12.4
[1.12.3]: https://github.com/dkmnx/clauver/compare/v1.12.2...v1.12.3
[1.12.2]: https://github.com/dkmnx/clauver/compare/v1.12.1...v1.12.2
[1.12.1]: https://github.com/dkmnx/clauver/compare/v1.12.0...v1.12.1
[1.12.0]: https://github.com/dkmnx/clauver/compare/v1.11.2...v1.12.0
[1.11.2]: https://github.com/dkmnx/clauver/compare/v1.11.1...v1.11.2
[1.11.1]: https://github.com/dkmnx/clauver/compare/v1.11.0...v1.11.1
[1.11.0]: https://github.com/dkmnx/clauver/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/dkmnx/clauver/compare/v1.9.2...v1.10.0
[1.9.2]: https://github.com/dkmnx/clauver/compare/v1.9.1...v1.9.2
[1.9.1]: https://github.com/dkmnx/clauver/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/dkmnx/clauver/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/dkmnx/clauver/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/dkmnx/clauver/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/dkmnx/clauver/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/dkmnx/clauver/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/dkmnx/clauver/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/dkmnx/clauver/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/dkmnx/clauver/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/dkmnx/clauver/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/dkmnx/clauver/compare/v1.2.3...v1.3.0
[1.2.3]: https://github.com/dkmnx/clauver/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/dkmnx/clauver/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/dkmnx/clauver/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/dkmnx/clauver/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/dkmnx/clauver/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/dkmnx/clauver/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/dkmnx/clauver/releases/tag/v1.0.0
