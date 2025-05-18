#!/bin/bash

# Main script to run all tests for the setup script

# Set the current directory to the script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Source the required dependencies
PROJECT_ROOT=$(dirname "$(pwd)")
source "$PROJECT_ROOT/src/core/logger.sh"

# Set log level to INFO for test output
set_log_level "INFO"

log_info "Starting test suite for setup script" "test_suite"

# List of test scripts to run
TEST_SCRIPTS=(
    "test_sudo.sh"
    "test_safe_insert.sh"
    "test_safe_remove.sh"
    "test_package_manager.sh"
    "test_user_management.sh"
    "test_power.sh"
    "test_proxy.sh"
    "test_cli_parser.sh"
    "test_batch_packages.sh"
)

# Run each test script
for test_script in "${TEST_SCRIPTS[@]}"; do
    log_info "Running test script: $test_script" "test_suite"
    echo "================================================================================"
    echo "Running: $test_script"
    echo "================================================================================"
    
    # Make the script executable if it's not already
    if [ ! -x "$test_script" ]; then
        chmod +x "$test_script"
    fi
    
    # Run the test script
    if ./"$test_script"; then
        log_info "Test script passed: $test_script" "test_suite"
    else
        log_error "Test script failed: $test_script" "test_suite"
    fi
    
    echo ""
done

log_info "All tests completed" "test_suite"