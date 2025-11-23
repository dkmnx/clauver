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
COMMAND="release"  # Default command is 'release'
AUTO_UPDATE=false  # Auto-update version files when preparing release for new version
DRY_RUN=false
SKIP_TESTS=false
CREATE_GH_RELEASE=false
SHA256_MODE="full"

show_help() {
    cat << 'EOF'
Usage: ./scripts/release-prepare.sh [command] [version] [options]

Commands:
    release           Prepare a release (default command)
    update-version    Update version numbers in source files

Arguments:
    version           Version to prepare/update (e.g., v1.9.2)
                      Required for update-version command
                      Optional for release command when using --sha256-minimal

Options:
    --dry-run         Show what would be done without executing
    --no-tests        Skip running tests (for CI environments)
    --gh-release      Create GitHub release and upload artifacts (release command only)
    --sha256-minimal  Generate only clauver.sh.sha256 (default: full) (release command only)
    --help            Show this help message

Examples:
    ./scripts/release-prepare.sh v1.9.2                           # Prepare release
    ./scripts/release-prepare.sh v1.9.2 --dry-run                 # Dry run release
    ./scripts/release-prepare.sh update-version v1.9.3            # Update version numbers
    ./scripts/release-prepare.sh update-version v1.9.3 --dry-run  # Preview version updates
    ./scripts/release-prepare.sh --sha256-minimal                 # Auto-detect and prepare release
EOF
}

# Parse command line arguments
parse_args() {
    # Handle help flag regardless of position
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

    # Initialize variables
    local version_provided=false
    local sha256_minimal=false

    # Check for command as first argument
    if [[ $# -gt 0 ]]; then
        case "$1" in
            update-version)
                COMMAND="update-version"
                shift
                ;;
            release)
                COMMAND="release"
                shift
                ;;
            --*)  # Started with options, default to release
                ;;
            *)  # Started with version, default to release
                ;;
        esac
    fi

    # Parse options first to determine if --sha256-minimal is present
    local args=("$@")

    # First pass: check for options and version presence
    for arg in "${args[@]}"; do
        case $arg in
            --sha256-minimal)
                sha256_minimal=true
                ;;
            -*)
                # Skip other options for now
                ;;
            *)
                if [[ "$version_provided" == "false" ]]; then
                    VERSION="$arg"
                    version_provided=true
                fi
                ;;
        esac
    done

    # Handle version requirement based on command
    if [[ "$version_provided" == "false" ]]; then
        if [[ "$COMMAND" == "update-version" ]]; then
            error "Version argument is required for update-version command"
            show_help
            exit 1
        elif [[ "$sha256_minimal" == "true" ]]; then
            # Auto-detect version for minimal mode
            if ! VERSION=$(auto_detect_latest_version); then
                exit 1
            fi
            log "Using auto-detected version: $VERSION"
        else
            error "Version argument is required for release command"
            show_help
            exit 1
        fi
    fi

    # Second pass: process all options
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
                if [[ "$COMMAND" == "update-version" ]]; then
                    error "--gh-release is not supported with update-version command"
                    exit 1
                fi
                CREATE_GH_RELEASE=true
                shift
                ;;
            --sha256-minimal)
                if [[ "$COMMAND" == "update-version" ]]; then
                    error "--sha256-minimal is not supported with update-version command"
                    exit 1
                fi
                SHA256_MODE="minimal"
                shift
                ;;
            --)
                # End of options
                shift
                break
                ;;
            -*)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                # Skip version argument (already processed)
                shift
                ;;
        esac
    done
}

# Auto-detect latest version from git or changelog
auto_detect_latest_version() {
    local changelog_file="$PROJECT_ROOT/CHANGELOG.md"

    log "Auto-detecting latest version..." >&2

    # Try to get latest version from changelog first
    if [[ -f "$changelog_file" ]]; then
        local changelog_version
        changelog_version=$(grep '## \[' "$changelog_file" | head -1 | sed 's/.*## \[\([^]]*\)\].*/\1/')

        if [[ -n "$changelog_version" ]]; then
            # Add 'v' prefix if not present
            [[ "$changelog_version" =~ ^v ]] || changelog_version="v$changelog_version"
            echo "$changelog_version"
            success "Auto-detected version from changelog: $changelog_version" >&2
            return 0
        fi
    fi

    # Fallback to git tags
    local git_version
    git_version=$(git tag --sort=-version:refname | head -1)

    if [[ -n "$git_version" ]]; then
        success "Auto-detected version from git tags: $git_version" >&2
        echo "$git_version"
        return 0
    fi

    error "Could not auto-detect version. No changelog entry found and no git tags available." >&2
    return 1
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

# Validate tag consistency with git and changelog
validate_tag_consistency() {
    local version="$1"
    local changelog_file="$PROJECT_ROOT/CHANGELOG.md"

    log "Validating tag consistency for $version..."

    # Check if tag exists in git
    if ! git rev-parse "$version" >/dev/null 2>&1; then
        # Tag doesn't exist - check if it's a newer version
        local latest_tag
        latest_tag=$(git tag --sort=-version:refname | head -1 2>/dev/null || echo "")

        if [[ -z "$latest_tag" ]]; then
            error "No existing git tags found and tag $version doesn't exist"
            error "This appears to be the first release - please create the tag first:"
            error "  git tag $version"
            return 1
        fi

        local latest_version_no_prefix="${latest_tag#v}"
        local version_no_prefix="${version#v}"

        # Check if the requested version is newer than the latest tag
        if [[ "$(printf '%s\n' "$latest_version_no_prefix" "$version_no_prefix" | sort -V | head -1)" == "$latest_version_no_prefix" && "$latest_version_no_prefix" != "$version_no_prefix" ]]; then
            # This is a newer version - enable auto-update mode
            warn "Tag $version does not exist but is newer than latest tag $latest_tag"
            warn "Will auto-update version files and prepare for new release"
            AUTO_UPDATE=true
            return 0
        else
            # This is not a newer version - show error
            error "Tag $version does not exist in git repository"
            error ""
            error "Available tags (latest first):"
            git tag --sort=-version:refname | head -5 | sed 's/^/  - /'
            error ""
            error "Please check the latest release tag and try again."
            error "You can also create a new release by:"
            error "  1. Running: git tag $version"
            error "  2. Running: git push --tags"
            error ""
            error "Or use a newer version (higher than $latest_tag)"
            return 1
        fi
    fi

    # Get latest tag from git
    local latest_git_tag
    latest_git_tag=$(git tag --sort=-version:refname | head -1)

    if [[ "$version" != "$latest_git_tag" ]]; then
        error "Tag $version is not the latest tag"
        error "Latest tag: $latest_git_tag"
        error "Specified tag: $version"
        error ""
        error "Please use the latest tag or create a newer one."
        return 1
    fi

    # Check if version exists in changelog
    if [[ ! -f "$changelog_file" ]]; then
        error "CHANGELOG.md not found at $changelog_file"
        error "Please ensure the changelog exists and is up to date."
        return 1
    fi

    local changelog_version
    changelog_version=$(grep '## \[' "$changelog_file" | head -1 | sed 's/.*## \[\([^]]*\)\].*/\1/')

    if [[ -z "$changelog_version" ]]; then
        error "No version entries found in CHANGELOG.md"
        error "Please ensure the changelog has proper version entries."
        return 1
    fi

    # Remove 'v' prefix from changelog version for comparison if it exists
    changelog_version=${changelog_version#v}
    local version_no_prefix
    version_no_prefix=${version#v}

    if [[ "$version_no_prefix" != "$changelog_version" ]]; then
        error "Version mismatch between tag and changelog"
        error "Tag version: $version"
        error "Changelog version: v$changelog_version"
        error ""
        error "Please ensure the CHANGELOG.md has an entry for version $version"
        error "Update the changelog to match the tag, or use the correct tag."
        return 1
    fi

    success "Tag validation passed: $version exists and is the latest"
    success "Changelog consistency verified: v$changelog_version"
    return 0
}

# Check if working directory has changes that affect release
check_working_directory_changes() {
    local changes
    changes=$(git status --porcelain)

    if [[ -z "$changes" ]]; then
        log "Working directory is clean"
        return 0
    fi

    # Define files that are critical for release and must be clean
    local critical_files=(
        "clauver.sh"
        "CHANGELOG.md"
        "scripts/"
        "tests/"
        "README.md"
        "install.sh"
    )

    local has_critical_changes=false
    local has_other_changes=false
    local critical_changes_list=""
    local other_changes_list=""

    # Process each changed file
    while IFS= read -r line; do
        local file_path="${line:3}"

        local is_critical=false
        for critical_file in "${critical_files[@]}"; do
            if [[ "$file_path" == "$critical_file" || "$file_path" == "$critical_file"/* ]]; then
                is_critical=true
                break
            fi
        done

        if [[ "$is_critical" == "true" ]]; then
            has_critical_changes=true
            critical_changes_list="${critical_changes_list}\n  ${line}"
        else
            has_other_changes=true
            other_changes_list="${other_changes_list}\n  ${line}"
        fi
    done <<< "$changes"

    if [[ "$has_critical_changes" == "true" ]]; then
        error "Critical changes detected that could affect release"
        error "Please commit or stash these changes before proceeding:"
        echo -e "$critical_changes_list"
        error ""
        exit 1
    fi

    if [[ "$has_other_changes" == "true" ]]; then
        warn "Working directory has changes not related to clauver.sh:"
        echo -e "$other_changes_list"
        warn "These changes will be ignored for release preparation"
        warn "Consider committing them before creating the final release"
    fi
}

# Check git repository state
check_git_state() {
    log "Checking git repository state..."

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not in a git repository"
        exit 1
    fi

    # Check if working directory has changes that affect release
    check_working_directory_changes

    # Validate tag exists and is the latest
    if ! validate_tag_consistency "$VERSION"; then
        error "Git repository state validation failed"
        exit 1
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

    log "Generating SHA256 checksums for $version (mode: $SHA256_MODE)..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] Would generate clauver.sh.sha256"
        if [[ "$SHA256_MODE" == "full" ]]; then
            log "[DRY RUN] Full mode enabled - release artifacts will be generated during GitHub release"
        fi
        return 0
    fi

    # Change to project root
    cd "$PROJECT_ROOT"

    # Generate checksum for main script (always needed)
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

    if [[ "$SHA256_MODE" == "minimal" ]]; then
        success "Minimal SHA256 generation completed"
        log "Generated: clauver.sh.sha256"
    else
        success "SHA256 generation completed"
        log "Generated: clauver.sh.sha256"
        log "Release artifacts will be generated during GitHub release creation"
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

# Generate release notes from changelog
generate_release_notes() {
    local version="$1"
    local changelog_file="$PROJECT_ROOT/CHANGELOG.md"

    # Extract changelog content for this version
    local changelog_content
    changelog_content=$(extract_changelog_for_version "$version" "$changelog_file")

    if [[ -z "$changelog_content" ]]; then
        warn "No changelog entry found for $version, using generic release notes"
        changelog_content="## Changes
- Release preparation and validation"
    fi

    # Generate complete release notes
    local release_notes
    release_notes=$changelog_content

    echo "$release_notes"
}

# Extract changelog content for specific version
extract_changelog_for_version() {
    local version="$1"
    local changelog_file="$2"
    local version_no_prefix=${version#v}

    # Use awk to extract content between version headers
    awk -v target="$version_no_prefix" '
    /^## \[/ {
        # Extract version from current line
        current_version = $0
        gsub(/.*## \[|].*/, "", current_version)
        gsub(/^v/, "", current_version)

        if (current_version == target) {
            in_target = 1
            # Skip the header line since it will be in the title
            next
        } else if (in_target) {
            # We have reached the next version section
            exit
        }
    }

    in_target && NF {
        print $0
    }
    ' "$changelog_file"
}

# Generate release artifacts (clean dist and create all files)
generate_release_artifacts() {
    local version="$1"

    log "Generating release artifacts for $version..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] Would clean dist directory"
        log "[DRY RUN] Would create release artifacts in dist/"
        return 0
    fi

    # Change to project root
    cd "$PROJECT_ROOT"

    # Clean dist directory if it exists
    if [[ -d "dist" ]]; then
        log "Cleaning existing dist directory..."
        rm -rf dist
    fi

    # Create fresh dist directory
    mkdir -p dist
    log "Created clean dist directory"

    # Create tar.gz archive
    git archive --prefix="clauver-${version}/" -o "dist/clauver-${version}.tar.gz" HEAD
    log "Created dist/clauver-${version}.tar.gz"

    # Create zip archive
    git archive --prefix="clauver-${version}/" -o "dist/clauver-${version}.zip" HEAD
    log "Created dist/clauver-${version}.zip"

    # Copy main files to dist
    cp clauver.sh clauver.sh.sha256 dist/
    log "Copied clauver.sh and clauver.sh.sha256 to dist"

    # Generate individual .sha256 files for each artifact
    cd dist

    # Generate SHA256 for tar.gz
    sha256sum "clauver-${version}.tar.gz" > "clauver-${version}.tar.gz.sha256"
    log "Generated clauver-${version}.tar.gz.sha256"

    # Generate SHA256 for zip
    sha256sum "clauver-${version}.zip" > "clauver-${version}.zip.sha256"
    log "Generated clauver-${version}.zip.sha256"

    # Regenerate SHA256 for clauver.sh in dist (ensures consistency)
    sha256sum clauver.sh > clauver.sh.sha256
    log "Regenerated clauver.sh.sha256 in dist"

    # Generate comprehensive SHA256SUMS for convenience
    sha256sum ./* > SHA256SUMS
    log "Generated comprehensive SHA256SUMS"

    cd ..

    success "All release artifacts generated in dist/"
    log "Generated files:"
    ls -la dist/

    if [[ -f "dist/SHA256SUMS" ]]; then
        log "SHA256SUMS contents:"
        cat dist/SHA256SUMS
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

    # Generate release artifacts (cleans dist and creates all files)
    generate_release_artifacts "$version"

    # Change to dist directory for upload
    cd "$PROJECT_ROOT/dist"

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

    # Generate release notes from changelog
    local release_notes
    release_notes=$(generate_release_notes "$version")

    # Create release and upload artifacts
    gh release create "$version" \
        --title "$version" \
        --notes "$release_notes" \
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

# Get latest changelog entry for commit message
get_latest_changelog_entry() {
    local changelog_file="$PROJECT_ROOT/CHANGELOG.md"

    if [[ ! -f "$changelog_file" ]]; then
        echo "chore: add SHA256 checksums"
        return
    fi

    # Extract version from first version entry
    local version_line
    version_line=$(grep '## \[' "$changelog_file" | head -1)

    if [[ -z "$version_line" ]]; then
        echo "chore: add SHA256 checksums"
        return
    fi

    # Extract version number using cut
    local version
    version=$(echo "$version_line" | cut -d'[' -f2 | cut -d']' -f1)

    if [[ -z "$version" ]]; then
        echo "chore: add SHA256 checksums"
        return
    fi

    # Get first added feature for context (simple approach)
    local feature
    feature=$(awk '/^### Added/{found=1; next} found && /^### [A-Za-z]/{exit} found && /^- \*\*/{gsub(/^- \*\*[^*]*\*\* */, ""); gsub(/^- /, ""); print; exit}' "$changelog_file")

    if [[ -n "$feature" ]]; then
        echo "chore: release $version - $feature"
    else
        echo "chore: release $version"
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

    local commit_message
    commit_message=$(get_latest_changelog_entry)
    echo "   git commit -m \"$commit_message\""
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

# Compare version for update-version command
compare_version_for_update() {
    local new_version="$1"
    local new_version_no_prefix="${new_version#v}"

    log "Comparing version with current release..."

    # Get the latest git tag
    local latest_tag
    latest_tag=$(git tag --sort=-version:refname | head -1 2>/dev/null || echo "")

    if [[ -z "$latest_tag" ]]; then
        warn "No existing git tags found"
        return 0
    fi

    local latest_version_no_prefix="${latest_tag#v}"

    # Compare versions using sort -V for proper version comparison
    if [[ "$(printf '%s\n' "$latest_version_no_prefix" "$new_version_no_prefix" | sort -V | head -1)" == "$new_version_no_prefix" && "$latest_version_no_prefix" != "$new_version_no_prefix" ]]; then
        error "New version $new_version is lower than current latest version $latest_tag"
        error "Version update must be greater than or equal to the latest release"
        exit 1
    elif [[ "$new_version_no_prefix" == "$latest_version_no_prefix" ]]; then
        warn "New version $new_version is the same as current latest version $latest_tag"
        warn "This will update files but the version number won't change"
        return 0
    else
        log "Version update $latest_tag -> $new_version is valid"
        return 0
    fi
}

# Update version numbers in source files
update_version_files() {
    local new_version="$1"
    local version_no_prefix="${new_version#v}"

    log "Updating version numbers to $new_version..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] Would update version numbers in the following files:"
        log "[DRY RUN] - clauver.sh (line 6): VERSION=\"$version_no_prefix\""
        log "[DRY RUN] - install.sh (line 7): VERSION=\"$version_no_prefix\""
        log "[DRY RUN] - README.md (line 14): version badge to $version_no_prefix"
        return 0
    fi

    # Update clauver.sh
    local clauver_file="$PROJECT_ROOT/clauver.sh"
    if [[ -f "$clauver_file" ]]; then
        if sed -i 's/^VERSION=".*"/VERSION="'"$version_no_prefix"'"/' "$clauver_file"; then
            success "Updated VERSION in clauver.sh"
        else
            error "Failed to update VERSION in clauver.sh"
            return 1
        fi
    else
        error "clauver.sh not found at $clauver_file"
        return 1
    fi

    # Update install.sh
    local install_file="$PROJECT_ROOT/install.sh"
    if [[ -f "$install_file" ]]; then
        if sed -i 's/^VERSION=".*"/VERSION="'"$version_no_prefix"'"/' "$install_file"; then
            success "Updated VERSION in install.sh"
        else
            error "Failed to update VERSION in install.sh"
            return 1
        fi
    else
        warn "install.sh not found at $install_file (skipping)"
    fi

    # Update README.md version badge
    local readme_file="$PROJECT_ROOT/README.md"
    if [[ -f "$readme_file" ]]; then
        if sed -i 's/badge/version-[^)]*-blue/badge/version-'"$version_no_prefix"'-blue/' "$readme_file"; then
            success "Updated version badge in README.md"
        else
            warn "Failed to update version badge in README.md (may need manual update)"
        fi
    else
        warn "README.md not found at $readme_file (skipping)"
    fi

    success "Version numbers updated to $new_version"
    log "Remember to commit these changes and create a git tag:"
    log "  git add ."
    log "  git commit -m \"chore: bump version to $version_no_prefix\""
    log "  git tag $new_version"
}

# Main execution
main() {
    parse_args "$@"

    case "$COMMAND" in
        update-version)
            log "Starting version update to $VERSION"
            validate_version "$VERSION"
            compare_version_for_update "$VERSION"
            update_version_files "$VERSION"

            if [[ "$DRY_RUN" == "true" ]]; then
                log "Dry run completed successfully"
            else
                success "Version update completed successfully!"
            fi
            ;;
        release)
            log "Starting release preparation for $VERSION"
            validate_version "$VERSION"
            check_git_state
            check_dependencies

            # Handle auto-update mode for new versions
            if [[ "$AUTO_UPDATE" == "true" ]]; then
                log "Auto-update mode enabled: updating version files for new release"
                update_version_files "$VERSION"
            fi

            generate_checksums "$VERSION"
            verify_checksums "$VERSION"
            run_tests

            # Create GitHub release if requested
            if [[ "$CREATE_GH_RELEASE" == "true" ]]; then
                if [[ "$AUTO_UPDATE" == "true" ]]; then
                    warn "Creating GitHub release for new version $VERSION"
                    warn "Note: Make sure to commit version changes and create the git tag first:"
                    warn "  git add ."
                    warn "  git commit -m \"chore: bump version to ${VERSION#v}\""
                    warn "  git tag $VERSION"
                    read -r -p "Continue with GitHub release creation? [y/N]: " confirm
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        log "Skipping GitHub release creation"
                    else
                        create_github_release "$VERSION"
                    fi
                else
                    create_github_release "$VERSION"
                fi
            fi

            show_instructions "$VERSION"

            if [[ "$DRY_RUN" == "true" ]]; then
                log "Dry run completed successfully"
            else
                if [[ "$AUTO_UPDATE" == "true" ]]; then
                    success "Release preparation completed successfully!"
                    success "Version files updated. Don't forget to commit and create the git tag:"
                    success "  git add ."
                    success "  git commit -m \"chore: bump version to ${VERSION#v}\""
                    success "  git tag $VERSION"
                else
                    success "Release preparation completed successfully!"
                fi
            fi
            ;;
        *)
            error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
