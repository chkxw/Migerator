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

# Test 2: Get Available Package Groups
print_header "Get Available Package Groups"

# Test the dynamic package group detection
available_groups=$(get_available_package_groups)
group_count=$(echo "$available_groups" | wc -w)

if [ $group_count -gt 0 ]; then
    report_result 0 "Successfully detected package groups dynamically: $available_groups"
else
    report_result 1 "Failed to detect package groups dynamically"
fi

# Test 3: Get Package Group Variable Name
print_header "Get Package Group Variable Name"

# Test with a valid group name
pkg_var_name=$(get_package_group_var_name "utilities" 2>/dev/null)
pkg_var_result=$?

if [ $pkg_var_result -eq 0 ] && [ -n "$pkg_var_name" ]; then
    report_result 0 "Successfully resolved variable name: $pkg_var_name"
else
    report_result 1 "Failed to resolve variable name for utilities"
fi

# Test with case-insensitive group name
mixed_case_var_name=$(get_package_group_var_name "DeV_tOOls" 2>/dev/null)
mixed_case_var_result=$?

if [ $mixed_case_var_result -eq 0 ] && [ -n "$mixed_case_var_name" ]; then
    report_result 0 "Successfully handled case-insensitive package group names: $mixed_case_var_name"
else
    report_result 1 "Failed to handle case-insensitive package group names"
fi

# Test with invalid group name
invalid_var_name=$(get_package_group_var_name "nonexistent_group" 2>/dev/null)
invalid_var_result=$?

if [ $invalid_var_result -ne 0 ] && [ -z "$invalid_var_name" ]; then
    report_result 0 "Correctly rejected invalid package group"
else
    report_result 1 "Failed to reject invalid package group"
fi

# Test 4: Get Package Group List
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

# Test case insensitivity in get_package_group_list
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

# Test 5: Get Package Group Description
print_header "Get Package Group Description"

# Test getting description for a valid group
badger_rl_desc=$(get_package_group_description "badger_rl_deps")
badger_rl_desc_result=$?

if [ $badger_rl_desc_result -eq 0 ] && [ -n "$badger_rl_desc" ]; then
    report_result 0 "Successfully retrieved BadgerRL Deps package description: $badger_rl_desc"
else
    report_result 1 "Failed to retrieve BadgerRL Deps package description"
fi

# Test for a group with description from global variable
if [ -n "$BA_PKG_BADGER_RL_DEPS_DESCRIPTION" ]; then
    desc_match=$( [ "$badger_rl_desc" = "$BA_PKG_BADGER_RL_DEPS_DESCRIPTION" ] && echo "true" || echo "false" )
    if [ "$desc_match" = "true" ]; then
        report_result 0 "Description matches global variable definition"
    else
        report_result 1 "Description does not match global variable definition"
        echo "Expected: $BA_PKG_BADGER_RL_DEPS_DESCRIPTION"
        echo "Got: $badger_rl_desc"
    fi
fi

# Test case insensitivity
mixed_case_desc=$(get_package_group_description "DeV_tOOls")
mixed_case_desc_result=$?

if [ $mixed_case_desc_result -eq 0 ] && [ -n "$mixed_case_desc" ]; then
    report_result 0 "Successfully handled case-insensitive group name for description"
else
    report_result 1 "Failed to handle case-insensitive group name for description"
fi

# Test generating description for non-existent group
nonexistent_desc=$(get_package_group_description "nonexistent_group")
nonexistent_desc_result=$?

if [ $nonexistent_desc_result -eq 0 ] && [ -n "$nonexistent_desc" ] && 
   [[ "$nonexistent_desc" == *"Package Group"* ]]; then
    report_result 0 "Successfully generated description for non-existent group: $nonexistent_desc"
else
    report_result 1 "Failed to generate description for non-existent group"
fi

# Test 6: Module Context Preservation
print_header "Module Context Preservation"

# Verify that MODULE_NAME is not set at the module level
if [ -z "$MODULE_NAME" ]; then
    report_result 0 "MODULE_NAME is not set at the module level"
else
    report_result 1 "MODULE_NAME is set at the module level: $MODULE_NAME"
fi

# Test setting module context in the main function
echo "Setting custom MODULE_NAME before calling batch_packages_main..."
MODULE_NAME="custom_module_name"
MODULE_DESCRIPTION="custom_description"
MODULE_VERSION="custom_version"

batch_packages_main list > /dev/null 2>&1

# Check if MODULE_NAME was restored
if [ "$MODULE_NAME" = "custom_module_name" ]; then
    report_result 0 "MODULE_NAME was properly restored after function call"
else
    report_result 1 "MODULE_NAME was not restored, current value: $MODULE_NAME"
fi

# Check if MODULE_DESCRIPTION was restored
if [ "$MODULE_DESCRIPTION" = "custom_description" ]; then
    report_result 0 "MODULE_DESCRIPTION was properly restored after function call"
else
    report_result 1 "MODULE_DESCRIPTION was not restored, current value: $MODULE_DESCRIPTION"
fi

# Check if MODULE_VERSION was restored
if [ "$MODULE_VERSION" = "custom_version" ]; then
    report_result 0 "MODULE_VERSION was properly restored after function call"
else
    report_result 1 "MODULE_VERSION was not restored, current value: $MODULE_VERSION"
fi

# Test 7: CLI Help Message
print_header "CLI Help Message"

# Test batch_packages_main help command (must pass no arguments to get help)
help_output=$(batch_packages_main)
help_result=$?

# Test if the help message contains the expected sections
if [[ "$help_output" == *"Commands:"* ]] && 
   [[ "$help_output" == *"Options:"* ]] && 
   [[ "$help_output" == *"Available package groups:"* ]]; then
    report_result 0 "CLI help message contains expected sections"
else
    report_result 1 "CLI help message is missing expected sections"
    echo "Help output: $help_output"
fi

# Test -h option for help command
help_h_output=$(batch_packages_main -h)
help_h_result=$?

# Test if -h option produces the same help message
if [ "$help_h_output" = "$help_output" ]; then
    report_result 0 "CLI help message with -h option works correctly"
else
    report_result 1 "CLI help message with -h option does not match default help message"
    echo "Help -h output differs from standard help output"
fi

# Test if help contains a list of available package groups
if [[ "$help_output" == *"utilities"* ]] && 
   [[ "$help_output" == *"dev_tools"* ]] && 
   [[ "$help_output" == *"badger_rl_deps"* ]]; then
    report_result 0 "CLI help message lists available package groups"
else
    report_result 1 "CLI help message is missing package group listing"
fi

# Test 8: List Command
print_header "List Command"

# Test the list command
list_output=$(batch_packages_main list)
list_result=$?

if [ $list_result -eq 0 ] && 
   [[ "$list_output" == *"Available package groups:"* ]] && 
   [[ "$list_output" == *"Packages:"* ]]; then
    report_result 0 "List command shows groups and their packages"
else
    report_result 1 "List command output is incorrect"
    echo "List output: $list_output"
fi

# Test 9: Installation Simulation
print_header "Installation Simulation"

# Override real package installation functions for simulation
install_package_group_original="$(declare -f install_package_group)"
remove_package_group_original="$(declare -f remove_package_group)"

# Override installation function to simulate without actually installing
install_package_group() {
    local group_name="$1"
    local force="$2"
    
    # Get package list for the specified group
    local package_list=$(get_package_group_list "$group_name")
    if [ -z "$package_list" ]; then
        return 1
    fi
    
    echo "SIMULATION: Would install package group: $group_name"
    echo "SIMULATION: Packages: $package_list"
    echo "SIMULATION: Force flag: $force"
    return 0
}
export -f install_package_group

# Override removal function to simulate without actually removing
remove_package_group() {
    local group_name="$1"
    shift
    
    # Get package list for the specified group
    local package_list=$(get_package_group_list "$group_name")
    if [ -z "$package_list" ]; then
        return 1
    fi
    
    echo "SIMULATION: Would remove package group: $group_name"
    echo "SIMULATION: Packages: $package_list"
    echo "SIMULATION: Options: $@"
    return 0
}
export -f remove_package_group

# Set auto-confirmation for testing
set_global_var "confirm_all" "true"

# Test install command with a valid group
if [ $group_count -gt 0 ]; then
    first_group=$(echo "$available_groups" | awk '{print $1}')
    install_output=$(batch_packages_main install "$first_group" --force)
    install_result=$?
    
    if [ $install_result -eq 0 ] && [[ "$install_output" == *"SIMULATION: Would install package group: $first_group"* ]]; then
        report_result 0 "Install command works correctly with: $first_group"
    else
        report_result 1 "Install command failed with: $first_group"
        echo "Install output: $install_output"
    fi
    
    # Test remove command with the same group
    remove_output=$(batch_packages_main remove "$first_group" --purge --force)
    remove_result=$?
    
    if [ $remove_result -eq 0 ] && [[ "$remove_output" == *"SIMULATION: Would remove package group: $first_group"* ]]; then
        report_result 0 "Remove command works correctly with: $first_group"
    else
        report_result 1 "Remove command failed with: $first_group"
        echo "Remove output: $remove_output"
    fi
fi

# Test 10: Error Handling
print_header "Error Handling"

# Test with invalid command
invalid_cmd_output=$(batch_packages_main invalid_command 2>&1 || echo "Command failed")

if [[ "$invalid_cmd_output" == *"Unknown command"* || "$invalid_cmd_output" == *"Command failed"* ]]; then
    report_result 0 "Invalid command is rejected properly"
else
    report_result 1 "Invalid command is not rejected properly"
    echo "Output: $invalid_cmd_output"
fi

# Test install with invalid group
invalid_install_output=$(batch_packages_main install nonexistent_group 2>&1 || echo "Command failed")

if [[ "$invalid_install_output" == *"Unknown package group"* || "$invalid_install_output" == *"Command failed"* ]]; then
    report_result 0 "Install with invalid group is rejected properly"
else
    report_result 1 "Install with invalid group is not rejected properly"
    echo "Output: $invalid_install_output"
fi

# Test remove with invalid group
invalid_remove_output=$(batch_packages_main remove nonexistent_group 2>&1 || echo "Command failed")

if [[ "$invalid_remove_output" == *"Unknown package group"* || "$invalid_remove_output" == *"Command failed"* ]]; then
    report_result 0 "Remove with invalid group is rejected properly"
else
    report_result 1 "Remove with invalid group is not rejected properly"
    echo "Output: $invalid_remove_output"
fi

# Test install without group name
missing_group_output=$(batch_packages_main install 2>&1 || echo "Command failed")

if [[ "$missing_group_output" == *"No group name specified"* || "$missing_group_output" == *"Command failed"* ]]; then
    report_result 0 "Install without group name is rejected properly"
else
    report_result 1 "Install without group name is not rejected properly"
    echo "Output: $missing_group_output"
fi

# Restore original functions
eval "$install_package_group_original"
eval "$remove_package_group_original"

echo "🏁 Batch Package Management Test Suite Completed"
echo ""