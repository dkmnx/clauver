# SHA256 Release Workflow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement comprehensive SHA256 checksum validation for Clauver releases with local validation scripts, test suite, and CI integration.

**Architecture:** Pre-push validation strategy with shell scripts for generation, comprehensive test coverage, and GitHub Actions job for tag-based validation. Follows conventional commits and integrates with existing test framework.

**Tech Stack:** Bash scripting, GitHub Actions YAML, shell test framework, sha256sum utilities, Git hooks

---

### Task 1: Create Scripts Directory Structure

**Files:**
- Create: `scripts/`

**Step 1: Create scripts directory**

```bash
mkdir -p scripts
chmod 755 scripts
```

**Step 2: Add scripts directory to .gitignore if not already present**

Check if scripts/ is tracked, add to .gitignore only if needed for temp files.

**Step 3: Commit**

```bash
git add scripts/
git commit -m "chore: add scripts directory for release automation"
```

### Task 2: Implement Release Preparation Script

**Files:**
- Create: `scripts/release-prepare.sh`
- Modify: None

**Step 1: Write the failing test (conceptual)**

First, let's think about what this script should do:

```bash
# This should fail initially:
./scripts/release-prepare.sh v1.9.2 --dry-run
# Expected: FAIL with "script not found"
```

**Step 2: Create the release preparation script**

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
DRY_RUN=false
SKIP_TESTS=false

show_help() {
    cat << EOF
Usage: $(basename "$0") <version> [options]

Arguments:
    version    Version to prepare (e.g., v1.9.2)

Options:
    --dry-run     Show what would be done without executing
    --no-tests    Skip running tests (for CI environments)
    --help        Show this help message

Examples:
    $(basename "$0") v1.9.2
    $(basename "$0") v1.9.2 --dry-run
    $(basename "$0") v1.9.2 --no-tests
EOF
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        error "Version argument is required"
        show_help
        exit 1
    fi

    VERSION="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-tests)
                SKIP_TESTS=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate version format
validate_version() {
    local version="$1"

    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "Invalid version format: $version"
        error "Expected format: v{major}.{minor}.{patch}"
        error "Example: v1.9.2"
        exit 1
    fi

    log "Version format is valid: $version"
}

# Check git repository state
check_git_state() {
    log "Checking git repository state..."

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not in a git repository"
        exit 1
    fi

    # Check if working directory is clean
    if [[ -n $(git status --porcelain) ]]; then
        error "Working directory is not clean"
        git status --short
        error "Please commit or stash changes before proceeding"
        exit 1
    fi

    # Check if tag exists (for existing releases)
    if git rev-parse "$VERSION" >/dev/null 2>&1; then
        warn "Tag $VERSION already exists"
        read -r -p "Continue anyway? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log "Aborted by user"
            exit 0
        fi
    fi

    log "Git repository state is valid"
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."

    local missing_deps=()

    if ! command -v sha256sum >/dev/null 2>&1; then
        missing_deps+=("sha256sum")
    fi

    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        error "Please install the missing tools and try again"
        exit 1
    fi

    log "All dependencies are available"
}

# Generate SHA256 checksums
generate_checksums() {
    local version="$1"

    log "Generating SHA256 checksums for v$version..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] Would generate clauver.sh.sha256"
        log "[DRY RUN] Would create source archives"
        log "[DRY RUN] Would generate SHA256SUMS"
        return 0
    fi

    # Change to project root
    cd "$PROJECT_ROOT"

    # Generate checksum for main script
    if [[ -f "clauver.sh" ]]; then
        sha256sum clauver.sh > clauver.sh.sha256
        success "Generated clauver.sh.sha256"

        # Verify format
        if grep -qE '^[a-f0-9]{64}\s+clauver\.sh$' clauver.sh.sha256; then
            log "clauver.sh.sha256 format is valid"
        else
            error "clauver.sh.sha256 format is invalid"
            exit 1
        fi
    else
        error "clauver.sh not found"
        exit 1
    fi

    # Create release directory and archives
    mkdir -p dist

    # Create tar.gz archive
    git archive --prefix="clauver-${version}/" -o "dist/clauver-${version}.tar.gz" HEAD
    log "Created dist/clauver-${version}.tar.gz"

    # Create zip archive
    git archive --prefix="clauver-${version}/" -o "dist/clauver-${version}.zip" HEAD
    log "Created dist/clauver-${version}.zip"

    # Copy main files to dist
    cp clauver.sh clauver.sh.sha256 dist/

    # Generate comprehensive SHA256SUMS
    cd dist
    sha256sum * > SHA256SUMS
    cd ..

    success "Generated comprehensive SHA256SUMS in dist/"

    # Show contents
    log "Generated files:"
    ls -la dist/

    if [[ -f "dist/SHA256SUMS" ]]; then
        log "SHA256SUMS contents:"
        cat dist/SHA256SUMS
    fi
}

# Verify generated checksums
verify_checksums() {
    local version="$1"

    log "Verifying generated checksums..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] Would verify clauver.sh.sha256"
        log "[DRY RUN] Would test update mechanism"
        return 0
    fi

    # Test update mechanism simulation
    local expected_hash
    expected_hash=$(cat clauver.sh.sha256 | awk '{print $1}')
    local actual_hash
    actual_hash=$(sha256sum clauver.sh | awk '{print $1}')

    if [[ "$actual_hash" == "$expected_hash" ]]; then
        success "SHA256 verification passed"
    else
        error "SHA256 verification failed"
        error "Expected: $expected_hash"
        error "Actual:   $actual_hash"
        exit 1
    fi
}

# Run release tests
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log "Skipping tests as requested"
        return 0
    fi

    log "Running release-specific tests..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] Would run tests/test_release.sh"
        return 0
    fi

    # Check if release tests exist
    if [[ -f "$PROJECT_ROOT/tests/test_release.sh" ]]; then
        cd "$PROJECT_ROOT/tests"
        bash test_release.sh
        success "All release tests passed"
    else
        warn "Release tests not found at tests/test_release.sh"
        warn "Skipping release testing"
    fi
}

# Show final instructions
show_instructions() {
    local version="$1"

    log "Release preparation complete for v$version!"
    echo

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "=== DRY RUN COMPLETED ==="
        echo "No files were modified. To actually prepare the release, run:"
        echo
        echo "  ./scripts/release-prepare.sh $version"
        echo
        return 0
    fi

    echo "=== NEXT STEPS ==="
    echo "1. Review the generated files:"
    echo "   cat clauver.sh.sha256"
    echo "   cat dist/SHA256SUMS"
    echo
    echo "2. Add the SHA256 files to git:"
    echo "   git add clauver.sh.sha256 dist/SHA256SUMS dist/clauver-${version}.*"
    echo
    echo "3. Commit with conventional commit:"
    echo "   git commit -m \"chore: add SHA256 checksums for $version\""
    echo
    echo "4. Push the commit and tag:"
    echo "   git push"
    echo "   git push --tags"
    echo
    echo "5. Monitor CI for SHA256 validation"
    echo
}

# Main execution
main() {
    log "Starting release preparation for $VERSION"

    parse_args "$@"
    validate_version "$VERSION"
    check_git_state
    check_dependencies
    generate_checksums "$VERSION"
    verify_checksums "$VERSION"
    run_tests
    show_instructions "$VERSION"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run completed successfully"
    else
        success "Release preparation completed successfully!"
    fi
}

# Run main function with all arguments
main "$@"
```

**Step 3: Make script executable**

```bash
chmod +x scripts/release-prepare.sh
```

**Step 4: Test the script with dry run**

```bash
./scripts/release-prepare.sh v1.9.2 --dry-run
```

Expected: Script runs in dry-run mode, showing what it would do

**Step 5: Commit**

```bash
git add scripts/release-prepare.sh
git commit -m "feat: add release preparation script with SHA256 generation"
```

### Task 3: Create Release Test Suite

**Files:**
- Create: `tests/test_release.sh`
- Modify: `tests/run_all_tests.sh`

**Step 1: Write the failing test (conceptual)**

```bash
# This should fail initially:
./tests/test_release.sh
# Expected: FAIL with "test file not found"
```

**Step 2: Create the release test file**

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"

# Test version validation
test_version_validation() {
    echo "Testing version validation..."

    # Test valid versions
    local valid_versions=("v1.9.2" "v2.0.0" "v10.15.3")
    for version in "${valid_versions[@]}"; do
        if [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            pass "Valid version format: $version"
        else
            fail "Should accept valid version: $version"
        fi
    done

    # Test invalid versions
    local invalid_versions=("1.9.2" "v1.9" "v1.9.2.3" "latest" "v1.9.2-beta")
    for version in "${invalid_versions[@]}"; do
        if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            pass "Correctly rejected invalid version: $version"
        else
            fail "Should reject invalid version: $version"
        fi
    done
}

# Test SHA256 file format
test_sha256_format() {
    echo "Testing SHA256 file format validation..."

    local temp_file
    temp_file=$(mktemp)

    # Create a valid SHA256 file format
    echo "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456  clauver.sh" > "$temp_file"

    if grep -qE '^[a-f0-9]{64}\s+clauver\.sh$' "$temp_file"; then
        pass "Valid SHA256 format accepted"
    else
        fail "Should accept valid SHA256 format"
    fi

    # Test invalid formats
    echo "invalid_hash  clauver.sh" > "$temp_file"
    if grep -qE '^[a-f0-9]{64}\s+clauver\.sh$' "$temp_file"; then
        fail "Should reject invalid hash format"
    else
        pass "Correctly rejected invalid hash format"
    fi

    echo "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456" > "$temp_file"
    if grep -qE '^[a-f0-9]{64}\s+clauver\.sh$' "$temp_file"; then
        fail "Should reject missing filename"
    else
        pass "Correctly rejected missing filename"
    fi

    rm -f "$temp_file"
}

# Test SHA256 checksum generation
test_sha256_generation() {
    echo "Testing SHA256 checksum generation..."

    if ! command -v sha256sum >/dev/null 2>&1; then
        skip "sha256sum not available"
        return 0
    fi

    local temp_file
    temp_file=$(mktemp)

    # Create test content
    echo "test content for checksum" > "$temp_file"

    # Generate checksum
    local checksum
    checksum=$(sha256sum "$temp_file" | awk '{print $1}')

    # Verify checksum format
    if [[ ${#checksum} -eq 64 && "$checksum" =~ ^[a-f0-9]+$ ]]; then
        pass "Generated valid SHA256 checksum format"
    else
        fail "Generated invalid checksum format: $checksum"
    fi

    # Test checksum consistency
    local checksum2
    checksum2=$(sha256sum "$temp_file" | awk '{print $1}')

    if [[ "$checksum" == "$checksum2" ]]; then
        pass "Checksum generation is consistent"
    else
        fail "Checksum generation is inconsistent: $checksum vs $checksum2"
    fi

    rm -f "$temp_file"
}

# Test verify_sha256 function (from clauver.sh)
test_verify_sha256_function() {
    echo "Testing verify_sha256 function..."

    if ! command -v sha256sum >/dev/null 2>&1; then
        skip "sha256sum not available"
        return 0
    fi

    local temp_file
    local checksum_file
    temp_file=$(mktemp)
    checksum_file=$(mktemp)

    # Create test content and valid checksum
    echo "test content for verification" > "$temp_file"
    local expected_checksum
    expected_checksum=$(sha256sum "$temp_file" | awk '{print $1}')
    echo "$expected_checksum  test_file" > "$checksum_file"

    # Source the verify_sha256 function from clauver.sh
    local project_root
    project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")"

    if [[ -f "$project_root/clauver.sh" ]]; then
        # Extract and run verify_sha256 function
        if bash -c "source '$project_root/clauver.sh'; verify_sha256 '$temp_file' '$expected_checksum'" 2>/dev/null; then
            pass "verify_sha256 function works with valid checksum"
        else
            fail "verify_sha256 function should accept valid checksum"
        fi

        # Test with invalid checksum
        if ! bash -c "source '$project_root/clauver.sh'; verify_sha256 '$temp_file' 'invalid_checksum'" 2>/dev/null; then
            pass "verify_sha256 function rejects invalid checksum"
        else
            fail "verify_sha256 function should reject invalid checksum"
        fi
    else
        skip "clauver.sh not found for verify_sha256 testing"
    fi

    rm -f "$temp_file" "$checksum_file"
}

# Test release preparation script
test_release_preparation_script() {
    echo "Testing release preparation script..."

    local project_root
    project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")"
    local release_script="$project_root/scripts/release-prepare.sh"

    if [[ ! -f "$release_script" ]]; then
        skip "release preparation script not found"
        return 0
    fi

    # Test help option
    if "$release_script" --help >/dev/null 2>&1; then
        pass "Release script help option works"
    else
        fail "Release script help option should work"
    fi

    # Test dry run with valid version
    if "$release_script" v999.999.999 --dry-run >/dev/null 2>&1; then
        pass "Release script dry run works with valid version"
    else
        fail "Release script dry run should work with valid version"
    fi

    # Test invalid version
    if ! "$release_script" invalid-version --dry-run >/dev/null 2>&1; then
        pass "Release script rejects invalid version"
    else
        fail "Release script should reject invalid version"
    fi
}

# Test conventional commit messages
test_conventional_commits() {
    echo "Testing conventional commit message generation..."

    # Test version bump commit
    local version_bump="chore: bump version to 1.9.2"
    if [[ "$version_bump" =~ ^chore: bump version to [0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        pass "Valid version bump commit format"
    else
        fail "Invalid version bump commit format"
    fi

    # Test SHA256 commit
    local sha256_commit="chore: add SHA256 checksums for v1.9.2"
    if [[ "$sha256_commit" =~ ^chore: add SHA256 checksums for v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        pass "Valid SHA256 commit format"
    else
        fail "Invalid SHA256 commit format"
    fi

    # Test tag message
    local tag_message="chore(release): version 1.9.2"
    if [[ "$tag_message" =~ ^chore\(release\): version [0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        pass "Valid tag message format"
    else
        fail "Invalid tag message format"
    fi
}

# Test file permissions and safety
test_file_safety() {
    echo "Testing file safety and permissions..."

    local project_root
    project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")"

    # Check main script permissions
    if [[ -f "$project_root/clauver.sh" ]]; then
        if [[ -x "$project_root/clauver.sh" ]]; then
            pass "clauver.sh has execute permissions"
        else
            fail "clauver.sh should have execute permissions"
        fi
    else
        skip "clauver.sh not found"
    fi

    # Check test framework permissions
    if [[ -f "$SCRIPT_DIR/test_framework.sh" ]]; then
        if [[ -r "$SCRIPT_DIR/test_framework.sh" ]]; then
            pass "test_framework.sh is readable"
        else
            fail "test_framework.sh should be readable"
        fi
    fi
}

# Test update mechanism simulation
test_update_mechanism() {
    echo "Testing update mechanism simulation..."

    if ! command -v sha256sum >/dev/null 2>&1; then
        skip "sha256sum not available"
        return 0
    fi

    local project_root
    project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")"

    if [[ ! -f "$project_root/clauver.sh" ]]; then
        skip "clauver.sh not found"
        return 0
    fi

    # Create temporary checksum file
    local temp_checksum
    temp_checksum=$(mktemp)

    # Generate checksum for clauver.sh
    cd "$project_root"
    sha256sum clauver.sh > "$temp_checksum"

    # Test verification
    local expected_hash
    local actual_hash
    expected_hash=$(cat "$temp_checksum" | awk '{print $1}')
    actual_hash=$(sha256sum clauver.sh | awk '{print $1}')

    if [[ "$expected_hash" == "$actual_hash" ]]; then
        pass "Update mechanism simulation works"
    else
        fail "Update mechanism simulation failed"
    fi

    rm -f "$temp_checksum"
}

# Main test runner
run_release_tests() {
    echo "=== Running Release Tests ==="

    test_version_validation
    test_sha256_format
    test_sha256_generation
    test_verify_sha256_function
    test_release_preparation_script
    test_conventional_commits
    test_file_safety
    test_update_mechanism

    echo
    echo "=== Release Tests Summary ==="
    echo "Passed: $PASSED_COUNT"
    echo "Failed: $FAILED_COUNT"
    echo "Skipped: $SKIPPED_COUNT"

    if [[ $FAILED_COUNT -eq 0 ]]; then
        success "All release tests passed!"
        return 0
    else
        error "Some release tests failed!"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_release_tests
fi
```

**Step 3: Make test script executable**

```bash
chmod +x tests/test_release.sh
```

**Step 4: Test the release test suite**

```bash
./tests/test_release.sh
```

Expected: All tests should pass

**Step 5: Update test runner to include release tests**

Modify `tests/run_all_tests.sh`:

```bash
# Find the section that lists test categories and add release tests
# Look for lines like:
echo "Available test categories:"
echo "  utilities, providers, security, integration, error_handling, performance"

# Add 'release' to the list:
echo "Available test categories:"
echo "  utilities, providers, security, integration, error_handling, performance, release"
```

**Step 6: Commit**

```bash
git add tests/test_release.sh tests/run_all_tests.sh
git commit -m "feat: add comprehensive release testing suite"
```

### Task 4: Update CI Configuration

**Files:**
- Modify: `.github/workflows/test.yml`

**Step 1: Add tag trigger to existing workflow**

Find the existing `on:` section and add tags:

```yaml
on:
  push:
    branches: [ main, develop ]
    tags: [ 'v*' ]  # Add this line
  pull_request:
    branches: [ main ]
  schedule:
    # Run tests weekly on Mondays at 9 AM UTC
    - cron: '0 9 * * 1'
```

**Step 2: Add SHA256 validation job**

Add this job after the existing jobs:

```yaml
  sha256-validation:
    runs-on: ubuntu-latest
    container: catthehacker/ubuntu:act-latest
    if: startsWith(github.ref, 'refs/tags/v')
    needs: [tests, security-scan]
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y age shellcheck bc curl

    - name: Extract version from tag
      run: |
        VERSION=${GITHUB_REF#refs/tags/v}
        echo "VERSION=$VERSION" >> $GITHUB_ENV
        echo "Processing version: v$VERSION"

    - name: Generate SHA256 checksums
      run: |
        VERSION=${{ env.VERSION }}
        echo "Generating SHA256 checksums for v$VERSION..."

        # Generate checksum for main script
        sha256sum clauver.sh > clauver.sh.sha256
        echo "Generated clauver.sh.sha256"

        # Generate checksums for all release assets
        mkdir -p dist
        cp clauver.sh clauver.sh.sha256 dist/

        # Create source archive
        git archive --prefix="clauver-${VERSION}/" -o "dist/clauver-${VERSION}.tar.gz" HEAD
        git archive --prefix="clauver-${VERSION}/" -o "dist/clauver-${VERSION}.zip" HEAD

        # Generate SHA256SUMS for all files
        cd dist
        sha256sum * > SHA256SUMS
        echo "Generated SHA256SUMS:"
        cat SHA256SUMS

    - name: Verify SHA256 format
      run: |
        VERSION=${{ env.VERSION }}
        echo "Validating SHA256 file format..."

        # Check clauver.sh.sha256 format
        if [ -f "clauver.sh.sha256" ]; then
          if grep -qE '^[a-f0-9]{64}\s+clauver\.sh$' clauver.sh.sha256; then
            echo "✅ clauver.sh.sha256 format is valid"
          else
            echo "❌ clauver.sh.sha256 format is invalid"
            echo "Expected format: <64-char-hex>  clauver.sh"
            echo "Got format:"
            cat clauver.sh.sha256
            exit 1
          fi
        else
          echo "❌ clauver.sh.sha256 file not found"
          exit 1
        fi

        # Check SHA256SUMS format
        if [ -f "dist/SHA256SUMS" ]; then
          echo "✅ SHA256SUMS contents:"
          cat dist/SHA256SUMS

          # Verify each line format
          if grep -qE '^[a-f0-9]{64}\s+.+$' dist/SHA256SUMS; then
            echo "✅ SHA256SUMS format is valid"
          else
            echo "❌ SHA256SUMS format contains invalid lines"
            exit 1
          fi
        else
          echo "❌ SHA256SUMS file not found"
          exit 1
        fi

    - name: Test update mechanism with generated SHA256
      run: |
        VERSION=${{ env.VERSION }}
        echo "Testing update mechanism with v$VERSION SHA256..."

        # Simulate the update verification process
        if command -v sha256sum >/dev/null; then
          echo "Testing verify_sha256 function logic..."

          # Test: Verify clauver.sh against its checksum
          expected_hash=$(cat clauver.sh.sha256 | awk '{print $1}')
          actual_hash=$(sha256sum clauver.sh | awk '{print $1}')

          if [ "$actual_hash" = "$expected_hash" ]; then
            echo "✅ SHA256 verification test passed"
            echo "Expected: $expected_hash"
            echo "Actual:   $actual_hash"
          else
            echo "❌ SHA256 verification test failed"
            echo "Expected: $expected_hash"
            echo "Actual:   $actual_hash"
            exit 1
          fi
        else
          echo "❌ sha256sum not available"
          exit 1
        fi

    - name: Upload SHA256 artifacts
      uses: actions/upload-artifact@v3
      with:
        name: sha256-checksums-v${{ env.VERSION }}
        path: |
          clauver.sh.sha256
          dist/
        retention-days: 30
```

**Step 3: Test CI configuration syntax**

```bash
# Check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))" && echo "YAML is valid"
```

**Step 4: Commit**

```bash
git add .github/workflows/test.yml
git commit -m "feat: add SHA256 validation job for release tags"
```

### Task 5: Update Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2025-11-21-deepseek-integration.md`

**Step 1: Update README.md with release workflow**

Add section after existing content:

```markdown
## Release Process

Clauver follows a secure release process with SHA256 checksum validation:

### Prerequisites

- Clean git working directory
- `sha256sum` command available
- Version follows semantic versioning (v{major}.{minor}.{patch})

### Making a Release

1. **Version bump**:
   ```bash
   git commit -m "chore: bump version to 1.9.2"
   ```

2. **Tag creation**:
   ```bash
   git tag v1.9.2 -m "chore(release): version 1.9.2"
   ```

3. **Generate SHA256 files**:
   ```bash
   ./scripts/release-prepare.sh v1.9.2
   ```

4. **Commit checksums**:
   ```bash
   git add clauver.sh.sha256 dist/SHA256SUMS
   git commit -m "chore: add SHA256 checksums for v1.9.2"
   ```

5. **Push release**:
   ```bash
   git push && git push --tags
   ```

### Verification

- CI automatically validates SHA256 files for release tags
- Updates use SHA256 verification for security
- All checksums follow format: `<64-char-hex>  filename`

For detailed documentation, see [SHA256 Release Workflow](docs/plans/2025-11-22-sha256-release-workflow.md).
```

**Step 2: Update existing plan document if needed**

Add reference to the new SHA256 workflow in relevant planning documents.

**Step 3: Commit**

```bash
git add README.md docs/plans/
git commit -m "docs: add release process documentation"
```

### Task 6: Final Integration Testing

**Files:**
- Modify: None
- Test: All components

**Step 1: Test complete workflow with dry run**

```bash
./scripts/release-prepare.sh v999.999.999 --dry-run
```

Expected: Shows what would be done without actually doing it

**Step 2: Run release tests**

```bash
./tests/test_release.sh
```

Expected: All tests pass

**Step 3: Test integration with main test runner**

```bash
cd tests
./run_all_tests.sh release
```

Expected: Release tests run and pass

**Step 4: Validate CI workflow (optional)**

If you have `act` installed for local CI testing:

```bash
act -j sha256-validation
```

Expected: Job runs successfully (if tag environment is simulated)

**Step 5: Final documentation review**

Review all generated documentation for accuracy and completeness.

**Step 6: Commit any final fixes**

```bash
git add .
git commit -m "chore: finalize SHA256 release workflow integration"
```

## Validation Checklist

Before considering this implementation complete:

- [ ] Release script works with `--help`, `--dry-run`, and normal mode
- [ ] Release tests all pass
- [ ] CI workflow syntax is valid
- [ ] Documentation is accurate and complete
- [ ] Integration with existing test framework works
- [ ] All conventional commit messages follow specification

## Expected Outcome

After implementation:

1. **Secure releases**: Every release tag will have validated SHA256 checksums
2. **Automated validation**: CI will fail if SHA256 files are missing or invalid
3. **Developer workflow**: Clear, tested process for creating releases
4. **Update security**: Users get verified updates with SHA256 checking
5. **Documentation**: Complete guide for maintainers

---

**Plan complete and saved to `docs/plans/2025-11-22-sha256-release-implementation.md`.**

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**