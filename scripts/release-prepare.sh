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
    # Check for help flag first
    if [[ $# -eq 0 ]]; then
        error "Version argument is required"
        show_help
        exit 1
    fi

    # Handle help flag regardless of position
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

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
    parse_args "$@"
    log "Starting release preparation for $VERSION"
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