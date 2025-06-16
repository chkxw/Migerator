#!/bin/bash

# Test script for the personal setup module
# Tests all functionality of the personal_setup.sh module

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/modules/personal_setup.sh"

# Set DEBUG log level
set_log_level "DEBUG"

# Module name for testing
TEST_MODULE="personal_setup_test"

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

# Function to check if file exists with specific content
check_file_with_content() {
    local file="$1"
    local expected_content="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    if grep -q "$expected_content" "$file"; then
        return 0
    else
        return 1
    fi
}

# Function to get current permissions of a directory
get_permissions() {
    local dir="$1"
    stat -c "%a" "$dir" 2>/dev/null
}

# Test variables

# Initialize test environment
init_test_env() {
    log_info "Initializing test environment" "$TEST_MODULE"
    
    # Store original /usr/local permissions if they exist
    if [ -d "/usr/local" ]; then
        ORIGINAL_USR_LOCAL_PERMS=$(get_permissions "/usr/local")
    fi
}

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment" "$TEST_MODULE"
    
    # Restore original /usr/local permissions if we changed them
    if [ -n "$ORIGINAL_USR_LOCAL_PERMS" ] && [ -d "/usr/local" ]; then
        sudo chmod "$ORIGINAL_USR_LOCAL_PERMS" /usr/local 2>/dev/null || true
    fi
}

# Test 1: Test module loading
test_module_loading() {
    print_header "Testing module loading"
    
    if [[ "$MODULE_NAME" == "personal_setup" ]]; then
        report_result 0 "Module loaded with correct name"
    else
        report_result 1 "Module name incorrect: $MODULE_NAME"
    fi
}

# Test 2: Test argument parsing in main function
test_main_function_help() {
    print_header "Testing main function help output"
    
    local help_output=$(personal_setup_main --help 2>&1)
    
    if [[ "$help_output" == *"Usage: personal_setup_main"* ]] && 
       [[ "$help_output" == *"setup"* ]] && 
       [[ "$help_output" == *"install-claude"* ]] &&
       [[ "$help_output" == *"remove"* ]] &&
       [[ "$help_output" == *"/usr/local permissions"* ]]; then
        report_result 0 "Help output contains expected information"
    else
        report_result 1 "Help output is missing expected information"
        echo "Help output: $help_output"
    fi
}

# Test 3: Test invalid argument handling
test_main_function_invalid_args() {
    print_header "Testing main function invalid argument handling"
    
    # Redirect both stdout and stderr to capture all output
    local output=$(personal_setup_main invalid_arg 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ] && [[ "$output" == *"Unknown argument"* ]]; then
        report_result 0 "Invalid arguments handled correctly"
    else
        report_result 1 "Invalid argument handling failed"
        echo "Exit code: $exit_code"
        echo "Output: $output"
    fi
}

# Test 4: Test /usr/local permissions (requires sudo)
test_usr_local_permissions() {
    print_header "Testing /usr/local permissions modification"
    
    if [ ! -d "/usr/local" ]; then
        report_result 1 "/usr/local directory does not exist, skipping permissions test"
        return
    fi
    
    # Test permission change function
    if personal_setup_configure_usr_local; then
        local new_perms=$(get_permissions "/usr/local")
        if [ "$new_perms" = "777" ]; then
            report_result 0 "/usr/local permissions changed to 777 successfully"
            
            # Test restoration
            if personal_setup_restore_usr_local; then
                local restored_perms=$(get_permissions "/usr/local")
                if [ "$restored_perms" = "755" ]; then
                    report_result 0 "/usr/local permissions restored to 755 successfully"
                else
                    report_result 1 "/usr/local permissions restoration failed (got $restored_perms, expected 755)"
                fi
            else
                report_result 1 "/usr/local permissions restoration function failed"
            fi
        else
            report_result 1 "/usr/local permissions change failed (got $new_perms, expected 777)"
        fi
    else
        report_result 1 "/usr/local permissions change function failed"
    fi
}

# Test 5: Test setup and remove functions (dry run)
test_setup_remove_functions() {
    print_header "Testing setup and remove functions (dry run)"
    
    # Test that functions exist and are callable
    if declare -F personal_setup_configure_usr_local > /dev/null; then
        report_result 0 "personal_setup_configure_usr_local function exists"
    else
        report_result 1 "personal_setup_configure_usr_local function missing"
    fi
    
    if declare -F personal_setup_restore_usr_local > /dev/null; then
        report_result 0 "personal_setup_restore_usr_local function exists"
    else
        report_result 1 "personal_setup_restore_usr_local function missing"
    fi
    
    if declare -F personal_setup_setup > /dev/null; then
        report_result 0 "personal_setup_setup function exists"
    else
        report_result 1 "personal_setup_setup function missing"
    fi
    
    if declare -F personal_setup_remove > /dev/null; then
        report_result 0 "personal_setup_remove function exists"
    else
        report_result 1 "personal_setup_remove function missing"
    fi
    
    if declare -F personal_setup_install_claude > /dev/null; then
        report_result 0 "personal_setup_install_claude function exists"
    else
        report_result 1 "personal_setup_install_claude function missing"
    fi
    
    if declare -F personal_setup_remove_claude > /dev/null; then
        report_result 0 "personal_setup_remove_claude function exists"
    else
        report_result 1 "personal_setup_remove_claude function missing"
    fi
}

# Test 6: Test Claude installation command parsing
test_claude_installation_command() {
    print_header "Testing Claude installation command parsing"
    
    # Test that the install-claude command is recognized (without actually installing)
    # We'll test this by checking if the argument parsing works correctly
    
    # Capture the debug output to see that the command was parsed
    local output=$(personal_setup_main install-claude 2>&1)
    local exit_code=$?
    
    # The command should fail because npm might not be available or configured properly,
    # but it should recognize the install-claude command and attempt to run it
    if [[ "$output" == *"Installing Claude CLI via npm"* ]] || [[ "$output" == *"npm is not installed"* ]]; then
        report_result 0 "install-claude command is recognized and processed"
    else
        report_result 1 "install-claude command not recognized properly"
        echo "Output: $output"
        echo "Exit code: $exit_code"
    fi
}

# Test 7: Test complete module integration
test_module_integration() {
    print_header "Testing module integration and exports"
    
    # Check if main function is exported
    if declare -F personal_setup_main > /dev/null; then
        report_result 0 "Main function is properly exported"
    else
        report_result 1 "Main function is not exported"
    fi
    
    # Check if MODULE_COMMANDS is exported
    if [[ -n "${MODULE_COMMANDS[@]}" ]]; then
        local found_setup=false
        local found_remove=false
        
        local found_install_claude=false
        
        for cmd in "${MODULE_COMMANDS[@]}"; do
            if [[ "$cmd" == *"setup"* ]]; then
                found_setup=true
            fi
            if [[ "$cmd" == *"install-claude"* ]]; then
                found_install_claude=true
            fi
            if [[ "$cmd" == *"remove"* ]]; then
                found_remove=true
            fi
        done
        
        if [ "$found_setup" = true ] && [ "$found_install_claude" = true ] && [ "$found_remove" = true ]; then
            report_result 0 "MODULE_COMMANDS contains expected commands"
        else
            report_result 1 "MODULE_COMMANDS missing expected commands"
            echo "MODULE_COMMANDS: ${MODULE_COMMANDS[*]}"
        fi
    else
        report_result 1 "MODULE_COMMANDS is not exported or empty"
    fi
}

# Main test execution
main() {
    echo "🚀 Starting Personal Setup Module Tests"
    echo "======================================================================"
    
    # Initialize test environment
    init_test_env
    
    # Run all tests
    test_module_loading
    test_main_function_help
    test_main_function_invalid_args
    test_usr_local_permissions
    test_setup_remove_functions
    test_claude_installation_command
    test_module_integration
    
    # Cleanup
    cleanup_test_env
    
    echo "======================================================================"
    echo "🏁 Personal Setup Module Tests Complete"
    echo "======================================================================"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi