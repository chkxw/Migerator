#!/bin/bash

# Comprehensive test script for user management functions
# This script can run in two modes:
# 1. Basic mode (without sudo): Tests data structures and non-system functions
# 2. Full mode (with sudo): Tests actual system user creation and management

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/modules/lab_users.sh"

# Set DEBUG log level
set_log_level "DEBUG"

# Test user info
TEST_USER_ID="test_user"
TEST_USER_NAME="Test User"
TEST_USER_YEAR="2023"
TEST_USER_SUPERUSER="false"
TEST_USERNAME="test2023"  # First name (test) + year (2023)

# Function to add a test user to the global data structure
add_test_user_to_globals() {
    USER_FULLNAME[$TEST_USER_ID]="$TEST_USER_NAME"
    USER_JOIN_YEAR[$TEST_USER_ID]="$TEST_USER_YEAR"
    USER_IS_SUPERUSER[$TEST_USER_ID]="$TEST_USER_SUPERUSER"
    echo "Added test user to globals: $TEST_USER_ID ($TEST_USER_NAME, $TEST_USER_YEAR, superuser: $TEST_USER_SUPERUSER)"
}

# Function to remove a test user from the global data structure
remove_test_user_from_globals() {
    unset USER_FULLNAME[$TEST_USER_ID]
    unset USER_JOIN_YEAR[$TEST_USER_ID]
    unset USER_IS_SUPERUSER[$TEST_USER_ID]
    echo "Removed test user from globals: $TEST_USER_ID"
}

# Function to check if the test user exists in the system
test_user_exists_in_system() {
    if id "$TEST_USERNAME" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

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

# Cleanup function to ensure we don't leave test artifacts
cleanup() {
    echo -e "\n🧹 Cleaning up test environment..."
    
    # Remove test user from globals
    remove_test_user_from_globals
    
    # If running as root, also clean up system resources
    if [ "$(id -u)" -eq 0 ]; then
        # Remove test user from system if it exists
        if test_user_exists_in_system; then
            echo "Removing test user from system..."
            lab_users_main remove "$TEST_USER_ID" >/dev/null 2>&1
        fi
    fi
    
    echo "Cleanup complete"
}

# Run cleanup if script is interrupted
trap 'cleanup' EXIT INT TERM

# Check for sudo mode
SUDO_MODE=false
if [ "$(id -u)" -eq 0 ]; then
    SUDO_MODE=true
    # Set confirm_all to true for automated testing in sudo mode
    set_global_var "confirm_all" "true"
    echo "Running in SUDO mode - will test system modifications"
else
    echo "Running in non-SUDO mode - will only test data structures"
fi

# Main test sequence
echo "🔍 User Management System Test Suite"
echo ""

# ----------- Basic Tests (No sudo required) -----------

# Test 1: User data structure
print_header "User Data Structure"

# Add test user to globals
add_test_user_to_globals

# Check if user was added correctly
if [[ "${USER_FULLNAME[$TEST_USER_ID]}" == "$TEST_USER_NAME" ]]; then
    report_result 0 "User added to globals"
else
    report_result 1 "Failed to add user to globals"
fi

# Test 2: Username generation
print_header "Username Generation"
generated_username=$(get_username "$TEST_USER_ID")
if [ "$generated_username" = "$TEST_USERNAME" ]; then
    report_result 0 "Username generation ($generated_username)"
else
    report_result 1 "Username generation (Expected: $TEST_USERNAME, Got: $generated_username)"
fi

# Test 3: User list functions
print_header "User List Functions"

# Check user lists are properly filtered
regular_users=$(global_vars "users")
super_users=$(global_vars "super_users")
all_users=$(global_vars "all_users")

# Verify test user is in the regular users list
if echo "$regular_users" | grep -q "$TEST_USER_ID"; then
    report_result 0 "Test user found in regular users list"
else
    report_result 1 "Test user NOT found in regular users list"
fi

# Verify test user is NOT in super users list
if ! echo "$super_users" | grep -q "$TEST_USER_ID"; then
    report_result 0 "Test user NOT found in super users list (correct)"
else
    report_result 1 "Test user found in super users list (incorrect)"
fi

# Verify test user is in all users list
if echo "$all_users" | grep -q "$TEST_USER_ID"; then
    report_result 0 "Test user found in all users list"
else
    report_result 1 "Test user NOT found in all users list"
fi

# Test 4: Check shared resources function
print_header "Shared Resources Check"
lab_users_main check > /dev/null
result=$?
if [ $result -eq 0 ]; then
    report_result 0 "Shared resources check (resources exist)"
else
    report_result 0 "Shared resources check (resources do not exist)"
fi

# ----------- Advanced Tests (Sudo required) -----------

if [ "$SUDO_MODE" = true ]; then
    # Test 5: Individual User Management
    print_header "System User Management"
    
    # Remove the test user if it already exists
    if test_user_exists_in_system; then
        echo "Test user already exists, removing..."
        lab_users_main remove "$TEST_USER_ID" >/dev/null 2>&1
    fi
    
    # Create the test user
    echo "Adding test user to system..."
    lab_users_main add "$TEST_USER_ID"
    result=$?
    report_result $result "Add system user"
    
    # Check if user was created correctly
    if test_user_exists_in_system; then
        
        # Verify user attributes
        # Check home directory
        if [ -d "/home/$TEST_USERNAME" ]; then
            report_result 0 "User home directory created"
        else
            report_result 1 "User home directory NOT created"
        fi
        
        # Check shared folder symlink
        if [ -L "/home/$TEST_USERNAME/Shared" ] && [ -d "/home/$TEST_USERNAME/Shared" ]; then
            report_result 0 "Shared folder symlink created and valid"
        else
            report_result 1 "Shared folder symlink NOT created or invalid"
        fi
        
        # Check group membership
        if id -Gn "$TEST_USERNAME" | grep -q "${USER_CONFIG[shared_group]}"; then
            report_result 0 "User is in shared group"
        else
            report_result 1 "User is NOT in shared group"
        fi
        
        # Remove the test user
        echo "Removing test user from system..."
        lab_users_main remove "$TEST_USER_ID"
        result=$?
        
        if ! test_user_exists_in_system; then
            report_result 0 "User removed successfully"
        else
            report_result 1 "User removal failed"
        fi
    else
        report_result 1 "User creation failed"
    fi
    
    # Test 6: Full System Setup and Teardown
    if [ "$1" = "full" ] || [ "$1" = "[full]" ]; then
        print_header "Full System Setup and Teardown"
        
        # First clean up any existing setup
        echo "Running lab_users_main teardown to clean environment..."
        lab_users_main teardown --force
        
        # Verify resources are gone
        lab_users_main check >/dev/null
        if [ $? -ne 0 ]; then
            report_result 0 "Teardown removed shared resources"
        else
            report_result 1 "Teardown failed to remove shared resources"
        fi
        
        # Run setup to create everything
        echo "Running lab_users_main setup to create all users and resources..."
        lab_users_main setup
        result=$?
        report_result $result "Setup operation completed"
        
        # Verify shared resources were created
        lab_users_main check >/dev/null
        result=$?
        report_result $result "Setup created shared resources"
        
        # Count how many users were created
        user_count=0
        expected_count=$(echo $(global_vars "all_users") | wc -w)
        for user_id in $(global_vars "all_users"); do
            username=$(get_username "$user_id")
            if id "$username" &>/dev/null; then
                user_count=$((user_count + 1))
            fi
        done
        
        if [ $user_count -eq $expected_count ]; then
            report_result 0 "Setup created all users ($user_count of $expected_count)"
        else
            report_result 1 "Setup created only $user_count of $expected_count users"
        fi
        
        # Clean up
        echo "Running lab_users_main teardown to clean up..."
        lab_users_main teardown --force
        result=$?
        report_result $result "Final teardown completed"
    fi
fi

echo "🏁 User Management System Test Suite Completed"
echo ""
if [ "$SUDO_MODE" = true ]; then
    echo "All tests completed in SUDO mode"
else
    echo "Basic tests completed in non-SUDO mode"
    echo "Run with sudo for complete testing: sudo $0 [full]"
fi