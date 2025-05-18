#!/bin/bash

# Test script for the power management module
# Tests all functionality of the power.sh module

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/modules/power.sh"

# Set DEBUG log level
set_log_level "DEBUG"

# Module name for testing
TEST_MODULE="power_test"

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

# Cleanup function to ensure we don't leave test artifacts
cleanup() {
    echo -e "\n🧹 Cleaning up test environment..."
    
    # Remove any dconf settings that might have been created
    if [ "$(id -u)" -eq 0 ]; then
        power_main --all --remove >/dev/null 2>&1
        
        # Remove test files manually if they still exist
        rm -f /etc/dconf/db/local.d/00-screen_blank 2>/dev/null
        rm -f /etc/dconf/db/local.d/00-automatic_suspend 2>/dev/null
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
    echo "Running in non-SUDO mode - will only test module functions"
fi

# Main test sequence
echo "🔍 Power Management Module Test Suite"
echo ""

# ----------- Basic Tests (No sudo required) -----------

# Test 1: Content Generation Functions
print_header "Content Generation Functions"

# Test dconf profile content generation
dconf_profile_content=$(power_generate_dconf_profile_content)
if [[ "$dconf_profile_content" == *"user-db:user"* && "$dconf_profile_content" == *"system-db:local"* ]]; then
    report_result 0 "DConf profile content generation"
else
    report_result 1 "DConf profile content generation (Invalid content)"
fi

# Test screen blank content generation
screen_blank_content=$(power_generate_screen_blank_content)
if [[ "$screen_blank_content" == *"[org/gnome/desktop/session]"* && "$screen_blank_content" == *"idle-delay=uint32 0"* ]]; then
    report_result 0 "Screen blank settings content generation"
else
    report_result 1 "Screen blank settings content generation (Invalid content)"
fi

# Test suspend content generation
suspend_content=$(power_generate_suspend_content)
if [[ "$suspend_content" == *"[org/gnome/settings-daemon/plugins/power]"* && "$suspend_content" == *"sleep-inactive-ac-type='nothing'"* ]]; then
    report_result 0 "Suspend settings content generation"
else
    report_result 1 "Suspend settings content generation (Invalid content)"
fi

# Test 2: Command Line Argument Parsing
print_header "Command Line Argument Parsing"

# Test help option
output=$(power_main --help 2>&1)
if [[ "$output" == *"Usage:"* && "$output" == *"--performance"* && "$output" == *"--no-blank"* ]]; then
    report_result 0 "Help option displays usage information"
else
    report_result 1 "Help option fails to display usage information"
fi

# Test invalid option
power_main --invalid-option >/dev/null 2>&1
if [ $? -ne 0 ]; then
    report_result 0 "Invalid option is rejected"
else
    report_result 1 "Invalid option is accepted"
fi

# ----------- Advanced Tests (Sudo required) -----------

if [ "$SUDO_MODE" = true ]; then
    # Test 3: DConf Configuration
    print_header "DConf Configuration"
    
    # Remove existing settings first
    power_main --all --remove >/dev/null 2>&1
    
    # Test screen blank configuration
    power_main --no-blank >/dev/null 2>&1
    result=$?
    
    if [ -f "/etc/dconf/profile/user" ] && check_file_with_content "/etc/dconf/db/local.d/00-screen_blank" "idle-delay=uint32 0"; then
        report_result 0 "Screen blank configuration"
    else
        report_result 1 "Screen blank configuration failed"
    fi
    
    # Test suspend configuration
    power_main --no-suspend >/dev/null 2>&1
    result=$?
    
    if check_file_with_content "/etc/dconf/db/local.d/00-automatic_suspend" "sleep-inactive-ac-type='nothing'"; then
        report_result 0 "Suspend configuration"
    else
        report_result 1 "Suspend configuration failed"
    fi
    
    # Test 4: DConf Removal
    print_header "DConf Removal"
    
    # Remove screen blank settings
    power_main --no-blank --remove >/dev/null 2>&1
    result=$?
    
    if [ ! -f "/etc/dconf/db/local.d/00-screen_blank" ] || ! check_file_with_content "/etc/dconf/db/local.d/00-screen_blank" "idle-delay=uint32 0"; then
        report_result 0 "Screen blank configuration removal"
    else
        report_result 1 "Screen blank configuration removal failed"
    fi
    
    # Remove suspend settings
    power_main --no-suspend --remove >/dev/null 2>&1
    result=$?
    
    if [ ! -f "/etc/dconf/db/local.d/00-automatic_suspend" ] || ! check_file_with_content "/etc/dconf/db/local.d/00-automatic_suspend" "sleep-inactive-ac-type='nothing'"; then
        report_result 0 "Suspend configuration removal"
    else
        report_result 1 "Suspend configuration removal failed"
    fi
    
    # Test 5: Apply All Settings
    print_header "Apply All Settings"
    
    # Apply all settings at once
    power_main --all >/dev/null 2>&1
    result=$?
    
    # Check if both files exist with the correct content
    screen_blank_exists=false
    suspend_exists=false
    
    if check_file_with_content "/etc/dconf/db/local.d/00-screen_blank" "idle-delay=uint32 0"; then
        screen_blank_exists=true
    fi
    
    if check_file_with_content "/etc/dconf/db/local.d/00-automatic_suspend" "sleep-inactive-ac-type='nothing'"; then
        suspend_exists=true
    fi
    
    if $screen_blank_exists && $suspend_exists; then
        report_result 0 "All settings applied successfully"
    else
        report_result 1 "Failed to apply all settings"
    fi
    
    # Test 6: Remove All Settings
    print_header "Remove All Settings"
    
    # Remove all settings at once
    power_main --all --remove >/dev/null 2>&1
    result=$?
    
    # Check if both files have been removed or cleared
    screen_blank_removed=true
    suspend_removed=true
    
    if [ -f "/etc/dconf/db/local.d/00-screen_blank" ] && check_file_with_content "/etc/dconf/db/local.d/00-screen_blank" "idle-delay=uint32 0"; then
        screen_blank_removed=false
    fi
    
    if [ -f "/etc/dconf/db/local.d/00-automatic_suspend" ] && check_file_with_content "/etc/dconf/db/local.d/00-automatic_suspend" "sleep-inactive-ac-type='nothing'"; then
        suspend_removed=false
    fi
    
    if $screen_blank_removed && $suspend_removed; then
        report_result 0 "All settings removed successfully"
    else
        report_result 1 "Failed to remove all settings"
    fi
    
    # Performance test would try to install power-profiles-daemon if not present
    # We'll skip testing this with an actual system command to avoid modifying the system
    # Let's verify the function exists but not execute it
    if declare -f power_set_performance >/dev/null; then
        report_result 0 "Performance mode function exists"
    else
        report_result 1 "Performance mode function does not exist"
    fi
fi

echo "🏁 Power Management Module Test Suite Completed"
echo ""
if [ "$SUDO_MODE" = true ]; then
    echo "All tests completed in SUDO mode"
else
    echo "Basic tests completed in non-SUDO mode"
    echo "Run with sudo for complete testing: sudo $0"
fi