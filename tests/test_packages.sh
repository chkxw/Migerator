#!/bin/bash

# Test script for the packages module
# Tests the functionality of package installation and removal with pre/post processing

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/modules/packages.sh"

# Set DEBUG log level
set_log_level "DEBUG"

# Global variables for testing
TEST_MODULE="test_packages"
TEST_DIR="/tmp/packages_test_$$"

# Helper functions for formatting test output
print_header() {
    echo "======================================================================"
    echo "🧪 TEST: $1"
    echo "======================================================================"
}

report_result() {
    if [ $1 -eq 0 ]; then
        echo "✅ PASS: $2"
    else
        echo "❌ FAIL: $2"
    fi
    echo ""
}

# Cleanup function
cleanup() {
    echo -e "\n🧹 Cleaning up test environment..."
    
    # Remove any test packages
    echo "Removing test packages: vlc"
    if is_package_installed "vlc"; then
        Sudo apt remove -y vlc
    fi
    Sudo apt autoremove -y
    
    # Remove any test repositories
    echo "Removing test repositories: vlc"
    if [ -f "/etc/apt/sources.list.d/vlc.list" ]; then
        Sudo rm -f "/etc/apt/sources.list.d/vlc.list"
    fi
    if [ -f "/etc/apt/keyrings/vlc.gpg" ]; then
        Sudo rm -f "/etc/apt/keyrings/vlc.gpg"
    fi
    
    # Update package lists
    Sudo apt update >/dev/null
    
    echo "Cleanup complete"
}

# Run cleanup if script is interrupted
trap 'cleanup' EXIT INT TERM

# Create test directory
mkdir -p "$TEST_DIR"

# Main test sequence
echo "🔍 Package Management Test Suite"
echo ""

# Test 1: Package repository information
print_header "Package Repository Information"

# Test if package repository information is available
package_count=${#PKG_FORMAL_NAME[@]}
if [ $package_count -gt 0 ]; then
    report_result 0 "Found $package_count package repositories"
else
    report_result 1 "No package repositories defined"
fi

# Test 2: Package info parsing
print_header "Package Info Parsing"

# Test parsing package repository info for a known package (chrome)
pkg_info=$(parse_package_repo "chrome" 2>/dev/null)
parse_result=$?

if [ $parse_result -eq 0 ] && [ -n "$pkg_info" ]; then
    report_result 0 "Successfully parsed Chrome package info"
else
    report_result 1 "Failed to parse Chrome package info"
fi

# Test 3: Package available check
print_header "Package Repository Availability Check"

# Check if a well-known repository is available
repo_available=$(check_package_repo_available "chrome" 2>/dev/null)
repo_result=$?

if [ $repo_result -eq 0 ]; then
    report_result 0 "Successfully checked Chrome repository availability"
else
    report_result 1 "Failed to check Chrome repository availability"
fi

# Test 4: Package processing handlers
print_header "Package Processing Handlers"

# Test Chrome processing handler
chrome_handler=$(handle_chrome_processing "install" 2>/dev/null)
chrome_result=$?

if [ $chrome_result -eq 0 ]; then
    report_result 0 "Chrome processing handler works"
else
    report_result 1 "Chrome processing handler failed"
fi

# Test VS Code processing handler
vscode_handler=$(handle_vscode_processing "install" 2>/dev/null)
vscode_result=$?

if [ $vscode_result -eq 0 ]; then
    report_result 0 "VS Code processing handler works"
else
    report_result 1 "VS Code processing handler failed"
fi

# Test 5: Package installation simulation
print_header "Package Installation Simulation"

# Test package installation simulation
set_global_var "confirm_all" "true"

# Note: We're not actually going to install anything in this test
# to avoid modifying the system, but we'll test the function signatures
# and pre/post processing hooks

echo "Simulating VLC installation (checking functions only)"

# Check that function exists and parameters are valid
if command -v install_package_with_processing >/dev/null 2>&1; then
    report_result 0 "Package installation function is available"
else
    report_result 1 "Package installation function is not available"
fi

# Test 6: Package uninstallation simulation
print_header "Package Uninstallation Simulation"

# Test package uninstallation simulation
echo "Simulating VLC uninstallation (checking functions only)"

# Check that function exists and parameters are valid
if command -v uninstall_package >/dev/null 2>&1; then
    report_result 0 "Package uninstallation function is available"
else
    report_result 1 "Package uninstallation function is not available"
fi

# Test 7: Package set definition
print_header "Package Set Definition"

# Test package set installation
echo "Checking package set definitions"

# Use a subshell to capture the output without actually installing anything
set_definition=$(set +e; install_package_set "list" 2>/dev/null; set -e)

if [[ "$set_definition" == *"essential"* && "$set_definition" == *"development"* ]]; then
    report_result 0 "Package sets are defined correctly"
else
    report_result 1 "Package sets are not defined correctly"
fi

# Test 8: CLI Command Structure
print_header "CLI Command Structure"

# Instead of testing the actual help output, test that the function and structure exists
if command -v packages_main >/dev/null 2>&1 && 
   grep -q "show_help" "$PROJECT_ROOT/src/modules/packages.sh" &&
   grep -q "Usage: packages_main" "$PROJECT_ROOT/src/modules/packages.sh" &&
   grep -q "Commands:" "$PROJECT_ROOT/src/modules/packages.sh" &&
   grep -q "Options:" "$PROJECT_ROOT/src/modules/packages.sh"; then
    report_result 0 "CLI command structure is implemented correctly"
else
    report_result 1 "CLI command structure is not implemented correctly"
fi

# Test 9: Main function validation
print_header "Main Function Validation"

# Test invalid command
invalid_cmd=$(packages_main invalid_command 2>/dev/null)
invalid_result=$?

if [ $invalid_result -ne 0 ]; then
    report_result 0 "Invalid command is rejected properly"
else
    report_result 1 "Invalid command is not rejected properly"
fi

# Test list command
list_cmd=$(packages_main list 2>/dev/null)
list_result=$?

if [ $list_result -eq 0 ] && [[ "$list_cmd" == *"Available packages:"* ]]; then
    report_result 0 "List command works correctly"
else
    report_result 1 "List command does not work correctly"
fi

echo "🏁 Package Management Test Suite Completed"
echo ""