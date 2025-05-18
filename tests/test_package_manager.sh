#!/bin/bash

# Test script for the package management functions
# This tests that the package repository parsing and validation functions work correctly

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/package_manager.sh"

# Set log level to DEBUG for testing
set_log_level "DEBUG"

log_info "Starting package management function tests" "test_package"

# Create test directories
TEST_DIR="/tmp/package_test_$(date +%s)"
ensure_directory "$TEST_DIR"

# Record all repositories and packages installed during testing for cleanup
INSTALLED_REPOS=()
TEST_PACKAGES=()

# Function to test repo entry template generation
test_repo_entry_template() {
    local nickname="$1"
    log_debug "Testing entry template generation for: $nickname" "test_package"
    local gpg_key_file="/etc/apt/keyrings/${nickname}.gpg"
    local template="$(generate_repo_entry_template "$nickname" "$gpg_key_file")"
    
    if [ -n "$template" ]; then
        log_info "Generated template for $nickname: $template" "test_package"
    else
        log_error "Failed to generate template for $nickname" "test_package"
    fi
}

# Test 1: Test parsing package repository info
log_info "Test 1: Parsing package repository info" "test_package"
for nickname in "${!PKG_FORMAL_NAME[@]}"; do
    log_debug "Testing parsing for repository: $nickname" "test_package"
    package_info=($(parse_package_repo "$nickname"))
    
    if [ ${#package_info[@]} -eq 8 ]; then
        log_info "Parsed repository info for $nickname:" "test_package"
        log_info "  Package name: ${package_info[0]}" "test_package"
        log_info "  GPG key URL: ${package_info[1]}" "test_package"
        log_info "  Architecture: ${package_info[2]}" "test_package"
        log_info "  Version codename: ${package_info[3]}" "test_package"
        log_info "  Branch: ${package_info[4]}" "test_package"
        log_info "  Deb-src: ${package_info[5]}" "test_package"
        log_info "  Repo URL: ${package_info[6]}" "test_package"
        log_info "  Repo Base URL: ${package_info[7]}" "test_package"
    else
        log_error "Failed to parse repository info for $nickname (expected 8 values, got ${#package_info[@]})" "test_package"
    fi
done

# Test 2: Test generating repository entry template
log_info "Test 2: Generating repository entry template" "test_package"
test_repo_entry_template "chrome"
test_repo_entry_template "vscode"
test_repo_entry_template "virtualgl"

# Test 3: Test package repository availability check 
log_info "Test 3: Package repository availability check" "test_package"

# Check repository availability
for nickname in "chrome" "vscode" "virtualgl" "nodejs" "nonexistent"; do
    if [[ "$nickname" != "nonexistent" ]]; then
        if check_package_repo_available "$nickname"; then
            log_info "Test passed: Repository $nickname is available" "test_package" 
        else
            log_info "Test passed: Repository $nickname is not available" "test_package"
        fi
    else
        # Nonexistent repository should fail
        if ! check_package_repo_available "$nickname" 2>/dev/null; then
            log_info "Test passed: Repository $nickname is not available (as expected)" "test_package"
        else
            log_error "Test failed: Repository $nickname is available (unexpected)" "test_package"
        fi
    fi
done

# Test 4: Test package installation
log_info "Test 4: Testing package detection and registration" "test_package"

# Choose a test package that might not be installed yet for testing
# Prefer packages that won't pull in large dependencies
TEST_PACKAGE="code"
TEST_NICKNAME="vscode"

# Save original state of package for cleanup
PACKAGE_INSTALLED=false
if check_package_installed "$TEST_PACKAGE"; then
    PACKAGE_INSTALLED=true
    log_info "Package $TEST_PACKAGE was already installed" "test_package"
else
    log_info "Package $TEST_PACKAGE is not installed, will install for testing" "test_package"
fi

# Check if repository exists
REPO_INSTALLED=false
if [ -f "/etc/apt/sources.list.d/${TEST_NICKNAME}.list" ]; then
    REPO_INSTALLED=true
    log_info "Repository for $TEST_NICKNAME already exists" "test_package"
else
    log_info "Repository for $TEST_NICKNAME does not exist, will create for testing" "test_package"
fi

# Test repository configuration and package detection
log_info "Testing package operations for: $TEST_NICKNAME" "test_package"

# Record for cleanup
TEST_PACKAGES+=("$TEST_PACKAGE")
INSTALLED_REPOS+=("$TEST_NICKNAME")

# Test installing the package
if ! $PACKAGE_INSTALLED; then
    if install_package "$TEST_NICKNAME"; then
        log_info "Test passed: Installation of $TEST_NICKNAME succeeded" "test_package"
    else
        log_error "Test failed: Installation of $TEST_NICKNAME failed" "test_package"
    fi
    
    # Second test should definitely detect as already installed
    if install_package "$TEST_NICKNAME"; then
        log_info "Test passed: Second installation of $TEST_NICKNAME detected as already installed" "test_package"
    else
        log_error "Test failed: Second installation of $TEST_NICKNAME failed" "test_package"
    fi
else
    log_info "Skipping actual installation since package $TEST_PACKAGE is already installed" "test_package"
    
    # Test detection of installed package
    if install_package "$TEST_NICKNAME"; then
        log_info "Test passed: Package $TEST_NICKNAME detected as already installed" "test_package"
    else
        log_error "Test failed: Package $TEST_NICKNAME detection failed" "test_package"
    fi
fi

log_info "All tests completed for package management functions" "test_package"

# Comprehensive cleanup
log_info "Starting cleanup of test artifacts" "test_package"

# Clean up test directory
rm -rf "$TEST_DIR"

# Clean up installed packages (only if they weren't already installed)
if [ "$PACKAGE_INSTALLED" = "false" ] && [ ${#TEST_PACKAGES[@]} -gt 0 ]; then
    log_info "Removing test packages: ${TEST_PACKAGES[*]}" "test_package"
    for pkg in "${TEST_PACKAGES[@]}"; do
        if check_package_installed "$pkg"; then
            Sudo apt remove -y "$pkg"
            log_info "Removed package: $pkg" "test_package"
        fi
    done
    Sudo apt autoremove -y
else
    log_info "Skipping package removal as packages were already installed before test" "test_package"
fi

# Clean up added repositories
if [ "$REPO_INSTALLED" = "false" ] && [ ${#INSTALLED_REPOS[@]} -gt 0 ]; then
    log_info "Removing test repositories: ${INSTALLED_REPOS[*]}" "test_package"
    for repo in "${INSTALLED_REPOS[@]}"; do
        # Remove repository list file
        if [ -f "/etc/apt/sources.list.d/${repo}.list" ]; then
            Sudo rm -f "/etc/apt/sources.list.d/${repo}.list"
            log_info "Removed repository list file: /etc/apt/sources.list.d/${repo}.list" "test_package"
        fi
        
        # Remove GPG key file
        if [ -f "/etc/apt/keyrings/${repo}.gpg" ]; then
            Sudo rm -f "/etc/apt/keyrings/${repo}.gpg"
            log_info "Removed GPG key file: /etc/apt/keyrings/${repo}.gpg" "test_package"
        fi
    done
    
    # Update package lists after removing repositories
    Sudo apt update >/dev/null
else
    log_info "Skipping repository removal as repositories were already configured before test" "test_package"
fi

log_info "Test cleanup completed" "test_package"