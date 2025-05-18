#!/bin/bash

# Test script for the batch packages module
# Tests the functionality of batch package installation and removal

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/modules/batch_packages.sh"

# Set DEBUG log level
set_log_level "DEBUG"

# Global variables for testing
TEST_MODULE="test_batch_packages"

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
    echo "Cleanup complete"
}

# Run cleanup if script is interrupted
trap 'cleanup' EXIT INT TERM

# Main test sequence
echo "🔍 Batch Package Management Test Suite"
echo ""

# Test 1: Package Group Definitions
print_header "Package Group Definitions"

# Test if package groups are defined with BA_PKG_ prefix
ba_pkg_badger_rl_count=${#BA_PKG_BADGER_RL_DEPS[@]}
ba_pkg_common_deps_count=${#BA_PKG_COMMON_DEPS[@]}
ba_pkg_utilities_count=${#BA_PKG_UTILITIES[@]}
ba_pkg_dev_tools_count=${#BA_PKG_DEV_TOOLS[@]}
ba_pkg_ml_tools_count=${#BA_PKG_ML_TOOLS[@]}

if [ $ba_pkg_badger_rl_count -gt 0 ] && [ $ba_pkg_common_deps_count -gt 0 ] && 
   [ $ba_pkg_utilities_count -gt 0 ] && [ $ba_pkg_dev_tools_count -gt 0 ] && 
   [ $ba_pkg_ml_tools_count -gt 0 ]; then
    report_result 0 "All package groups are defined with BA_PKG_ prefix and contain packages"
else
    report_result 1 "Some package groups are not defined properly with BA_PKG_ prefix"
    echo "BA_PKG_BADGER_RL_DEPS: $ba_pkg_badger_rl_count packages"
    echo "BA_PKG_COMMON_DEPS: $ba_pkg_common_deps_count packages"
    echo "BA_PKG_UTILITIES: $ba_pkg_utilities_count packages"
    echo "BA_PKG_DEV_TOOLS: $ba_pkg_dev_tools_count packages"
    echo "BA_PKG_ML_TOOLS: $ba_pkg_ml_tools_count packages"
fi

# Test the dynamic package group detection
available_groups=$(get_available_package_groups)
group_count=$(echo "$available_groups" | wc -w)

if [ $group_count -gt 0 ]; then
    report_result 0 "Successfully detected package groups dynamically: $available_groups"
else
    report_result 1 "Failed to detect package groups dynamically"
fi

# Test 2: Get Package Group List
print_header "Get Package Group List"

# Test getting package lists for different groups
badger_rl_list=$(get_package_group_list "badger_rl_deps")
badger_rl_result=$?

if [ $badger_rl_result -eq 0 ] && [ -n "$badger_rl_list" ]; then
    report_result 0 "Successfully retrieved BadgerRL Deps package list"
else
    report_result 1 "Failed to retrieve BadgerRL Deps package list"
fi

common_deps_list=$(get_package_group_list "common_deps")
common_deps_result=$?

if [ $common_deps_result -eq 0 ] && [ -n "$common_deps_list" ]; then
    report_result 0 "Successfully retrieved Common Dependencies package list"
else
    report_result 1 "Failed to retrieve Common Dependencies package list"
fi

# Test case insensitivity
mixed_case_list=$(get_package_group_list "DeV_tOOls")
mixed_case_result=$?

if [ $mixed_case_result -eq 0 ] && [ -n "$mixed_case_list" ]; then
    report_result 0 "Successfully handled case-insensitive package group names"
else
    report_result 1 "Failed to handle case-insensitive package group names"
fi

# Test with invalid group name
invalid_group_list=$(get_package_group_list "nonexistent_group" 2>/dev/null)
invalid_group_result=$?

if [ $invalid_group_result -ne 0 ] && [ -z "$invalid_group_list" ]; then
    report_result 0 "Correctly rejected invalid package group"
else
    report_result 1 "Failed to reject invalid package group"
fi

# Test with variable name directly
pkg_var_name=$(get_package_group_var_name "utilities" 2>/dev/null)
pkg_var_result=$?

if [ $pkg_var_result -eq 0 ] && [ -n "$pkg_var_name" ]; then
    report_result 0 "Successfully resolved variable name: $pkg_var_name"
else
    report_result 1 "Failed to resolve variable name for utilities"
fi

# Test 3: Package Group Details
print_header "Package Group Details"

# Test getting package group details
badger_rl_details=$(print_package_group_details "badger_rl_deps")
badger_rl_details_result=$?

if [ $badger_rl_details_result -eq 0 ] && [[ "$badger_rl_details" == *"Package Group: badger_rl_deps"* ]]; then
    report_result 0 "Successfully printed BadgerRL Deps package group details"
else
    report_result 1 "Failed to print BadgerRL Deps package group details"
fi

# Test with a dynamic group name from our detected list
if [ $group_count -gt 0 ]; then
    # Get the first group from our available groups
    first_group=$(echo "$available_groups" | awk '{print $1}')
    first_group_details=$(print_package_group_details "$first_group")
    first_group_details_result=$?
    
    if [ $first_group_details_result -eq 0 ] && [[ "$first_group_details" == *"Package Group: $first_group"* ]]; then
        report_result 0 "Successfully printed dynamically detected group details: $first_group"
    else
        report_result 1 "Failed to print dynamically detected group details: $first_group"
    fi
fi

# Test with invalid group name
invalid_group_details=$(print_package_group_details "nonexistent_group" 2>/dev/null)
invalid_group_details_result=$?

if [ $invalid_group_details_result -ne 0 ]; then
    report_result 0 "Correctly rejected invalid package group for details"
else
    report_result 1 "Failed to reject invalid package group for details"
fi

# Test 4: CLI Help Message
print_header "CLI Help Message"

# Test batch_packages module CLI help
help_output=$(batch_packages_main --help 2>/dev/null)
help_result=$?

# Debug: show help output
echo "DEBUG: Help output length: ${#help_output} characters"
echo "DEBUG: First 50 characters: ${help_output:0:50}"

# Test if the help message contains the expected sections
if [[ "$help_output" == *"Commands:"* ]] && 
   [[ "$help_output" == *"Options:"* ]] && 
   [[ "$help_output" == *"Available package groups:"* ]] && 
   [[ "$help_output" == *"Available purposes:"* ]]; then
    report_result 0 "CLI help message is generated correctly"
else
    report_result 1 "CLI help message is not generated correctly"
fi

# Test 5: List Command
print_header "List Command"

# Test the list command
list_output=$(batch_packages_main list 2>/dev/null)
list_result=$?

if [ $list_result -eq 0 ] && 
   [[ "$list_output" == *"Available package groups:"* ]] && 
   [[ "$list_output" == *"Available purposes:"* ]]; then
    report_result 0 "List command works correctly"
else
    report_result 1 "List command does not work correctly"
fi

# Test 6: Installation Simulation
print_header "Installation Simulation"

# Set auto-confirmation for testing
set_global_var "confirm_all" "true"

# Test installation simulation by running in "fake" mode
# This is just testing the function signature and structure
# without actually installing anything

echo "Testing group installation function signature"
if command -v install_package_group &>/dev/null; then
    report_result 0 "Group installation function is available"
else
    report_result 1 "Group installation function is not available"
fi

echo "Testing purpose installation function signature"
if command -v install_purpose_packages &>/dev/null; then
    report_result 0 "Purpose installation function is available"
else
    report_result 1 "Purpose installation function is not available"
fi

echo "Testing old setup installation function signature"
if command -v install_old_setup_packages &>/dev/null; then
    report_result 0 "Old setup installation function is available"
else
    report_result 1 "Old setup installation function is not available"
fi

# Test 7: Invalid Commands and Options
print_header "Invalid Commands and Options"

# Test invalid command
invalid_cmd_output=$(batch_packages_main invalid_command 2>&1 || echo "Command failed")
invalid_cmd_result=$?

if [[ "$invalid_cmd_output" == *"Unknown command"* || "$invalid_cmd_output" == *"Command failed"* ]]; then
    report_result 0 "Invalid command is rejected properly"
else
    report_result 1 "Invalid command is not rejected properly: Result=$invalid_cmd_result, Output=$invalid_cmd_output"
fi

# Test invalid group
invalid_group_output=$(batch_packages_main group nonexistent_group 2>&1)
invalid_group_result=$?

if [ $invalid_group_result -ne 0 ]; then
    report_result 0 "Invalid group is rejected properly"
else
    report_result 1 "Invalid group is not rejected properly"
fi

# Test valid group (using one of our dynamically detected groups)
if [ $group_count -gt 0 ]; then
    first_group=$(echo "$available_groups" | awk '{print $1}')
    # Just check if the group command is accepted (don't actually install)
    # We'll override the install_package_group function to avoid any real installation
    install_package_group() {
        echo "Would install package group: $1"
        return 0
    }
    export -f install_package_group
    
    valid_group_output=$(batch_packages_main group "$first_group" --force 2>&1)
    valid_group_result=$?
    
    if [ $valid_group_result -eq 0 ] && [[ "$valid_group_output" == *"Would install package group: $first_group"* ]]; then
        report_result 0 "Valid group is accepted properly: $first_group"
    else
        report_result 1 "Valid group is not accepted properly: $first_group"
    fi
fi

# Test invalid purpose
invalid_purpose_output=$(batch_packages_main purpose nonexistent_purpose 2>&1)
invalid_purpose_result=$?

if [ $invalid_purpose_result -ne 0 ]; then
    report_result 0 "Invalid purpose is rejected properly"
else
    report_result 1 "Invalid purpose is not rejected properly"
fi

echo "🏁 Batch Package Management Test Suite Completed"
echo ""