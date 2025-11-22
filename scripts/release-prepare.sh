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
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
DRY_RUN=false
SKIP_TESTS=false
CREATE_GH_RELEASE=false

show_help() {
    cat << EOF
Usage: $(basename "$0") <version> [options]

Arguments:
    version    Version to prepare (e.g., v1.9.2)

Options:
    --dry-run     Show what would be done without executing
    --no-tests    Skip running tests (for CI environments)
    --gh-release  Create GitHub release and upload artifacts
    --help        Show this help message

Examples:
    $(basename "$0") v1.9.2
    $(basename "$0") v1.9.2 --dry-run
    $(basename "$0") v1.9.2 --no-tests
    $(basename "$0") v1.9.2 --gh-release
    $(basename "$0") v1.9.2 --dry-run --gh-release
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
            --gh-release)
                CREATE_GH_RELEASE=true
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

    if ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("gh")
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

    log "Generating SHA256 checksums for $version..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] Would generate clauver.sh.sha256"
        log "[DRY RUN] Would create source archives"
        log "[DRY RUN] Would generate individual .sha256 files for each artifact"
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

    # Generate individual .sha256 files for each artifact
    cd dist

    # Generate SHA256 for tar.gz
    sha256sum "clauver-${version}.tar.gz" > "clauver-${version}.tar.gz.sha256"
    log "Generated clauver-${version}.tar.gz.sha256"

    # Generate SHA256 for zip
    sha256sum "clauver-${version}.zip" > "clauver-${version}.zip.sha256"
    log "Generated clauver-${version}.zip.sha256"

    # Generate SHA256 for clauver.sh in dist
    sha256sum clauver.sh > clauver.sh.sha256
    log "Generated clauver.sh.sha256"

    # Also generate comprehensive SHA256SUMS for convenience
    sha256sum ./* > SHA256SUMS
    log "Generated comprehensive SHA256SUMS"

    cd ..

    success "Generated individual .sha256 files and SHA256SUMS in dist/"

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

# Create GitHub release and upload artifacts
create_github_release() {
    local version="$1"

    log "Creating GitHub release for $version..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] Would create GitHub release $version"
        log "[DRY RUN] Would upload artifacts to GitHub release"
        return 0
    fi

    # Check if gh is authenticated
    if ! gh auth status >/dev/null 2>&1; then
        warn "GitHub CLI not authenticated. Skipping GitHub release creation."
        warn "Run 'gh auth login' to authenticate and enable GitHub releases."
        return 0
    fi

    # Check if release already exists
    if gh release view "$version" >/dev/null 2>&1; then
        warn "GitHub release $version already exists"
        read -r -p "Overwrite existing release? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log "Skipping GitHub release creation"
            return 0
        fi
        # Delete existing release
        gh release delete "$version" --yes
        log "Deleted existing GitHub release $version"
    fi

    # Change to dist directory for artifact uploads
    cd dist

    # Create release with artifacts
    local artifacts=(
        "clauver-${version}.tar.gz"
        "clauver-${version}.tar.gz.sha256"
        "clauver-${version}.zip"
        "clauver-${version}.zip.sha256"
        "clauver.sh"
        "clauver.sh.sha256"
        "SHA256SUMS"
    )

    log "Uploading artifacts to GitHub release $version..."

    # Create release and upload artifacts
    gh release create "$version" \
        --title "Clauver $version" \
        --notes "Release $version of Clauver

## Changes
- Add SHA256 checksums for all release artifacts
- Enhanced release preparation automation

## Artifacts
- \`clauver-${version}.tar.gz\`: Source archive (tar.gz)
- \`clauver-${version}.zip\`: Source archive (zip)
- \`clauver.sh\`: Main script
- \`SHA256SUMS\`: Comprehensive checksums file
- Individual \`.sha256\` files for each artifact

## Installation
\`\`\`bash
# Install using curl
curl -fsSL https://raw.githubusercontent.com/$(gh repo view --json owner,name --template '{{.owner.login}}/{{.name}}')/main/clauver.sh | bash

# Or download the script directly
wget https://github.com/$(gh repo view --json owner,name --template '{{.owner.login}}/{{.name}}')/releases/download/${version}/clauver.sh
chmod +x clauver.sh
\`\`\`

## Verification
\`\`\`bash
# Verify SHA256 checksums
sha256sum -c SHA256SUMS
\`\`\`
" \
        "${artifacts[@]}"

    cd ..

    success "GitHub release $version created with artifacts"
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

    log "Release preparation complete for $version!"
    echo

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "=== DRY RUN COMPLETED ==="
        echo "No files were modified. To actually prepare the release, run:"
        echo
        echo "  ./scripts/release-prepare.sh $version"
        echo "  ./scripts/release-prepare.sh $version --gh-release  # with GitHub release"
        echo
        return 0
    fi

    echo "=== NEXT STEPS ==="
    echo "1. Review the generated files:"
    echo "   cat clauver.sh.sha256"
    echo "   cat dist/SHA256SUMS"
    echo

    if [[ "$CREATE_GH_RELEASE" == "true" ]]; then
        echo "2. GitHub release already created with artifacts!"
        echo "   View release at: https://github.com/$(gh repo view --json owner,name --template '{{.owner.login}}/{{.name}}')/releases/tag/$version"
        echo
        echo "3. Add the SHA256 files to git:"
    else
        echo "2. Add the SHA256 files to git:"
    fi

    echo "   git add clauver.sh.sha256 dist/SHA256SUMS dist/clauver-${version}.* dist/*.sha256"
    echo

    if [[ "$CREATE_GH_RELEASE" == "true" ]]; then
        echo "4. Commit with conventional commit:"
    else
        echo "3. Commit with conventional commit:"
    fi

    echo "   git commit -m \"chore: add SHA256 checksums for $version\""
    echo

    if [[ "$CREATE_GH_RELEASE" == "true" ]]; then
        echo "5. Push the commit and tag:"
    else
        echo "4. Push the commit and tag:"
    fi

    echo "   git push"
    echo "   git push --tags"
    echo

    if [[ "$CREATE_GH_RELEASE" == "true" ]]; then
        echo "6. Monitor CI for SHA256 validation"
        echo
        echo "=== GitHub Release Information ==="
        echo "✅ GitHub release created with artifacts"
        echo "📦 Artifacts uploaded:"
        echo "   - clauver-${version}.tar.gz"
        echo "   - clauver-${version}.zip"
        echo "   - clauver.sh"
        echo "   - All SHA256 checksum files"
        echo
    else
        echo "5. Monitor CI for SHA256 validation"
        echo
        echo "=== GitHub Release (Optional) ==="
        echo "To create a GitHub release with artifacts:"
        echo "./scripts/release-prepare.sh $version --gh-release"
        echo "# Or create manually:"
        echo "gh release create $version --title \"Clauver $version\" --generate-notes dist/*"
        echo
    fi
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

    # Create GitHub release if requested
    if [[ "$CREATE_GH_RELEASE" == "true" ]]; then
        create_github_release "$VERSION"
    fi

    show_instructions "$VERSION"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run completed successfully"
    else
        success "Release preparation completed successfully!"
    fi
}

# Run main function with all arguments
main "$@"
