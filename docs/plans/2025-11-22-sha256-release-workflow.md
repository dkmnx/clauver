# SHA256 Release Workflow Design

## Overview

This document outlines the comprehensive design for integrating SHA256 checksum validation into the Clauver release process, ensuring secure and verifiable releases.

## Problem Statement

The `clauver.sh` update mechanism expects SHA256 checksum files to be available at:
```
https://raw.githubusercontent.com/dkmnx/clauver/v{version}/clauver.sh.sha256
```

Currently, these files are not systematically generated or validated, creating potential security vulnerabilities and update failures.

## Requirements

- **Generate**: SHA256 files for every release tag
- **Store**: Committed to repository as part of release tag
- **Validate**: CI should fail if SHA256 files missing/invalid
- **Test**: Comprehensive testing of the release workflow

## Solution Architecture

### 1. Pre-push Validation Workflow

**Primary Strategy**: Local validation before pushing tags, with CI as safety net.

#### Release Process Flow

```bash
# 1. Version bump
git commit -m "chore: bump version to 1.9.2"

# 2. Tag creation (scoped conventional commit)
git tag v1.9.2 -m "chore(release): version 1.9.2"

# 3. Generate SHA256 files with testing
./scripts/release-prepare.sh v1.9.2

# 4. Commit checksums
git add clauver.sh.sha256 SHA256SUMS
git commit -m "chore: add SHA256 checksums for v1.9.2"

# 5. Push with CI validation
git push && git push --tags
```

#### Conventional Commit Pattern

- **Version bump**: `chore: bump version to 1.9.2`
- **Tag creation**: `chore(release): version 1.9.2`
- **SHA256 addition**: `chore: add SHA256 checksums for v1.9.2`

### 2. Release Preparation Script

**File**: `scripts/release-prepare.sh`

#### Phases

1. **Validation**
   - Check git state (clean working directory)
   - Validate version format and tag existence
   - Verify dependencies (`sha256sum`, etc.)

2. **Generation**
   - Generate `clauver.sh.sha256` for main script
   - Create source archives (tar.gz, zip)
   - Generate comprehensive `SHA256SUMS` file

3. **Verification**
   - Validate SHA256 file formats (64-char hex + filename)
   - Verify checksum accuracy
   - Test conventional commit message generation

4. **Testing**
   - Run release-specific tests (`tests/test_release.sh`)
   - Test update mechanism with generated files
   - Simulate CI validation logic

5. **Final Validation**
   - Confirm all files ready for commit
   - Provide git commands for final steps

#### Usage Options

```bash
./scripts/release-prepare.sh v1.9.2          # Full workflow
./scripts/release-prepare.sh v1.9.2 --dry-run  # Preview only
./scripts/release-prepare.sh v1.9.2 --no-tests  # Skip testing (CI mode)
```

### 3. Enhanced Test Suite

**File**: `tests/test_release.sh`

#### Test Categories

1. **Unit Tests**
   - Test `verify_sha256()` function with valid/invalid inputs
   - Test SHA256 file format validation
   - Test checksum generation for various file types

2. **Integration Tests**
   - Test complete release preparation process
   - Validate conventional commit generation
   - Test tag creation and validation

3. **Update Mechanism Tests**
   - Test update mechanism with generated SHA256 files
   - Simulate CI validation logic
   - Test failure scenarios and recovery

4. **Format Validation**
   - Verify SHA256 file format compliance
   - Test checksum accuracy across different files
   - Validate file permissions and ownership

#### Test Integration

- Uses existing `test_framework.sh` utilities
- Integrates with `run_all_tests.sh` execution
- Compatible with CI test matrix

### 4. CI Integration

**File**: `.github/workflows/test.yml`

#### New Job: `sha256-validation`

- **Trigger**: Only on version tags (`v*`)
- **Dependencies**: Runs after `tests` and `security-scan` jobs
- **Validation**:
  - Check for `clauver.sh.sha256` file existence
  - Validate SHA256 file format
  - Verify checksum matches file content
  - Test update mechanism with generated files

#### Failure Behavior

- CI fails if SHA256 validation fails
- Clear error messages for debugging
- Artifacts uploaded for inspection

### 5. File Format Specifications

#### clauver.sh.sha256 Format
```
<64-char-hex>  clauver.sh
```

Example:
```
a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456  clauver.sh
```

#### SHA256SUMS Format
```
<64-char-hex>  filename1
<64-char-hex>  filename2
...
```

## Implementation Plan

### Phase 1: Core Infrastructure
1. Create `scripts/release-prepare.sh`
2. Create `tests/test_release.sh`
3. Update `.github/workflows/test.yml`

### Phase 2: Integration
1. Update `run_all_tests.sh` to include release tests
2. Update documentation (README.md, TROUBLESHOOTING.md)
3. Add Makefile targets for release testing

### Phase 3: Validation
1. Test complete workflow on development branch
2. Validate CI integration
3. Perform end-to-end release testing

## Security Considerations

- SHA256 checksums prevent tampering during updates
- Local validation ensures no invalid releases reach GitHub
- CI provides additional security layer
- Fail-fast approach prevents compromised releases

## Error Handling

### Common Scenarios

1. **Missing `sha256sum` command**
   - Clear error message with installation instructions
   - Alternative methods suggested if available

2. **Git working directory not clean**
   - Error message with git status output
   - Instructions to commit or stash changes

3. **Invalid version format**
   - Expected format: `v{major}.{minor}.{patch}`
   - Examples of valid versions provided

4. **SHA256 validation failure**
   - Clear mismatch display
   - Regeneration instructions provided

## Rollback Procedures

### If CI Fails After Tag Push
1. Delete the problematic tag: `git tag -d v1.9.2`
2. Fix the SHA256 issues
3. Recreate the tag: `git tag v1.9.2`
4. Push corrected tag: `git push --tags`

### If Invalid Release Gets Pushed
1. Generate correct SHA256 files
2. Commit them with conventional commit message
3. Push correction: `git push`

## Maintenance

### Regular Tasks
- Keep SHA256 generation logic up to date
- Update test cases as release process evolves
- Monitor CI for new edge cases

### Future Enhancements
- Automatic release artifact generation
- GPG signature integration
- Release workflow automation

## Success Metrics

- Zero releases without SHA256 validation
- All releases pass CI SHA256 validation
- No update failures due to missing/invalid checksums
- Developer adoption of pre-push workflow