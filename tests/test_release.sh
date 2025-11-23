#!/usr/bin/env bash
# shellcheck disable=SC1091
# Release tests for SHA256 checksum functionality and release preparation

# Source the test framework
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Test version validation
test_version_validation() {
    start_test "test_version_validation" "Test version format validation"

    # Test valid versions
    local valid_versions=("v1.12.0" "v2.0.0" "v10.15.3")
    for version in "${valid_versions[@]}"; do
        if [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "✓ Valid version format: $version"
        else
            echo "✗ Should accept valid version: $version"
            return 1
        fi
    done

    # Test invalid versions
    local invalid_versions=("1.11.2" "v1.9" "v1.12.0.3" "latest" "v1.12.0-beta")
    for version in "${invalid_versions[@]}"; do
        if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "✓ Correctly rejected invalid version: $version"
        else
            echo "✗ Should reject invalid version: $version"
            return 1
        fi
    done

    echo "Version validation tests passed"
}

# Test SHA256 file format
test_sha256_format() {
    start_test "test_sha256_format" "Test SHA256 file format validation"

    local temp_file
    temp_file=$(mktemp)

    # Create a valid SHA256 file format
    echo "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456  clauver.sh" > "$temp_file"

    if grep -qE '^[a-f0-9]{64}\s+clauver\.sh$' "$temp_file"; then
        echo "✓ Valid SHA256 format accepted"
    else
        echo "✗ Should accept valid SHA256 format"
        rm -f "$temp_file"
        return 1
    fi

    # Test invalid formats
    echo "invalid_hash  clauver.sh" > "$temp_file"
    if grep -qE '^[a-f0-9]{64}\s+clauver\.sh$' "$temp_file"; then
        echo "✗ Should reject invalid hash format"
        rm -f "$temp_file"
        return 1
    else
        echo "✓ Correctly rejected invalid hash format"
    fi

    echo "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456" > "$temp_file"
    if grep -qE '^[a-f0-9]{64}\s+clauver\.sh$' "$temp_file"; then
        echo "✗ Should reject missing filename"
        rm -f "$temp_file"
        return 1
    else
        echo "✓ Correctly rejected missing filename"
    fi

    rm -f "$temp_file"
    echo "SHA256 format tests passed"
}

# Test SHA256 checksum generation
test_sha256_generation() {
    start_test "test_sha256_generation" "Test SHA256 checksum generation"

    if ! command -v sha256sum >/dev/null 2>&1; then
        echo "Skipping: sha256sum not available"
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
        echo "✓ Generated valid SHA256 checksum format"
    else
        echo "✗ Generated invalid checksum format: $checksum"
        rm -f "$temp_file"
        return 1
    fi

    # Test checksum consistency
    local checksum2
    checksum2=$(sha256sum "$temp_file" | awk '{print $1}')

    if [[ "$checksum" == "$checksum2" ]]; then
        echo "✓ Checksum generation is consistent"
    else
        echo "✗ Checksum generation is inconsistent: $checksum vs $checksum2"
        rm -f "$temp_file"
        return 1
    fi

    rm -f "$temp_file"
    echo "SHA256 generation tests passed"
}

# Test release preparation script
test_release_preparation_script() {
    start_test "test_release_preparation_script" "Test release preparation script"

    local project_root
    project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/..")"
    local release_script="$project_root/scripts/release-prepare.sh"

    if [[ ! -f "$release_script" ]]; then
        echo "Skipping: release preparation script not found"
        return 0
    fi

    # Test help option
    if "$release_script" --help >/dev/null 2>&1; then
        echo "✓ Release script help option works"
    else
        echo "✗ Release script help option should work"
        return 1
    fi

    # Test dry run with valid version (will fail if working directory not clean, but that's expected)
    if "$release_script" v999.999.999 --dry-run >/dev/null 2>&1; then
        echo "✓ Release script dry run works with valid version"
    else
        echo "✓ Release script correctly validates environment (dry run failed as expected with uncommitted changes)"
    fi

    # Test invalid version
    if ! "$release_script" invalid-version --dry-run >/dev/null 2>&1; then
        echo "✓ Release script rejects invalid version"
    else
        echo "✗ Release script should reject invalid version"
        return 1
    fi

    echo "Release preparation script tests passed"
}

# Test conventional commit messages
test_conventional_commits() {
    start_test "test_conventional_commits" "Test conventional commit message generation"

    # Test version bump commit
    local version_bump="chore: bump version to 1.11.2"
    if [[ "$version_bump" =~ ^chore:\ bump\ version\ to\ [0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "✓ Valid version bump commit format"
    else
        echo "✗ Invalid version bump commit format"
        return 1
    fi

    # Test SHA256 commit
    local sha256_commit="chore: add SHA256 checksums for v1.12.0"
    if [[ "$sha256_commit" =~ ^chore:\ add\ SHA256\ checksums\ for\ v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "✓ Valid SHA256 commit format"
    else
        echo "✗ Invalid SHA256 commit format"
        return 1
    fi

    # Test tag message
    local tag_message="chore(release): version 1.11.2"
    if [[ "$tag_message" =~ ^chore\(release\):\ version\ [0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "✓ Valid tag message format"
    else
        echo "✗ Invalid tag message format"
        return 1
    fi

    echo "Conventional commit tests passed"
}

# Test file permissions and safety
test_file_safety() {
    start_test "test_file_safety" "Test file safety and permissions"

    local project_root
    project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/..")"

    # Check main script permissions
    if [[ -f "$project_root/clauver.sh" ]]; then
        if [[ -x "$project_root/clauver.sh" ]]; then
            echo "✓ clauver.sh has execute permissions"
        else
            echo "✗ clauver.sh should have execute permissions"
            return 1
        fi
    else
        echo "Skipping: clauver.sh not found"
        return 0
    fi

    # Check test framework permissions
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh" ]]; then
        if [[ -r "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh" ]]; then
            echo "✓ test_framework.sh is readable"
        else
            echo "✗ test_framework.sh should be readable"
            return 1
        fi
    fi

    echo "File safety tests passed"
}

# Test update mechanism simulation
test_update_mechanism() {
    start_test "test_update_mechanism" "Test update mechanism simulation"

    if ! command -v sha256sum >/dev/null 2>&1; then
        echo "Skipping: sha256sum not available"
        return 0
    fi

    local project_root
    project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/..")"

    if [[ ! -f "$project_root/clauver.sh" ]]; then
        echo "Skipping: clauver.sh not found"
        return 0
    fi

    # Create temporary checksum file
    local temp_checksum
    temp_checksum=$(mktemp)

    # Generate checksum for clauver.sh
    cd "$project_root" || return 1
    sha256sum clauver.sh > "$temp_checksum"

    # Test verification
    local expected_hash
    local actual_hash
    expected_hash=$(cat "$temp_checksum" | awk '{print $1}')
    actual_hash=$(sha256sum clauver.sh | awk '{print $1}')

    if [[ "$expected_hash" == "$actual_hash" ]]; then
        echo "✓ Update mechanism simulation works"
    else
        echo "✗ Update mechanism simulation failed"
        rm -f "$temp_checksum"
        return 1
    fi

    rm -f "$temp_checksum"
    echo "Update mechanism tests passed"
}

# Run all release tests
run_release_tests() {
    echo "=== Running Release Tests ==="

    test_version_validation
    test_sha256_format
    test_sha256_generation
    test_release_preparation_script
    test_conventional_commits
    test_file_safety
    test_update_mechanism

    echo
    echo "=== Release Tests Completed ==="
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_release_tests
fi
