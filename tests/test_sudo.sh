#!/bin/bash

# Test script for the Sudo function
# This tests the improved Sudo implementation that preserves environment variables

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"

# Set log level to DEBUG for testing
set_log_level "DEBUG"

log_info "Starting Sudo function tests" "test_sudo"

# Create test directories
TEST_DIR="/tmp/sudo_test_$(date +%s)"
ensure_directory "$TEST_DIR"

# Test function to check environment variable preservation
test_env_vars() {
    local test_var="$1"
    echo "Test environment variable: $test_var"
    env | grep "TEST_VAR"
}

# Test 1: Test simple command execution
log_info "Test 1: Simple command execution" "test_sudo"
if Sudo echo "Running as $(whoami)"; then
    log_info "Test 1 passed: Simple command execution works" "test_sudo"
else
    log_error "Test 1 failed: Simple command execution failed" "test_sudo"
fi

# Test 2: Test environment variable preservation
log_info "Test 2: Environment variable preservation" "test_sudo"
export TEST_VAR="This is a test value"
if Sudo bash -c 'echo "TEST_VAR=$TEST_VAR"'; then
    log_info "Test 2 passed: Environment variable was preserved" "test_sudo"
else
    log_error "Test 2 failed: Environment variable was not preserved" "test_sudo"
fi

# Test 3: Test function execution
log_info "Test 3: Function execution" "test_sudo"
test_function() {
    echo "This is output from a function running as $(whoami)"
    echo "Function argument: $1"
    return 0
}
export -f test_function

if Sudo test_function "test argument"; then
    log_info "Test 3 passed: Function execution works" "test_sudo"
else
    log_error "Test 3 failed: Function execution failed" "test_sudo"
fi

# Test 4: Test function with environment variables
log_info "Test 4: Function with environment variables" "test_sudo"
test_function_with_env() {
    echo "Function running as $(whoami) with TEST_VAR=$TEST_VAR"
    return 0
}
export -f test_function_with_env

if Sudo test_function_with_env; then
    log_info "Test 4 passed: Function with environment variables works" "test_sudo"
else
    log_error "Test 4 failed: Function with environment variables failed" "test_sudo"
fi

# Test 5: Test file creation and removal
log_info "Test 5: File creation and removal" "test_sudo"
test_file="$TEST_DIR/sudo_test_file"
test_file_content="This is a test file created by Sudo"

test_file_ops() {
    echo "$1" > "$2"
    cat "$2"
    rm "$2"
    return 0
}
export -f test_file_ops

if Sudo test_file_ops "$test_file_content" "$test_file"; then
    log_info "Test 5 passed: File operations work" "test_sudo"
else
    log_error "Test 5 failed: File operations failed" "test_sudo"
fi

# Test 6: Test error handling
log_info "Test 6: Error handling" "test_sudo"
test_error() {
    echo "This function will return an error"
    return 1
}
export -f test_error

if ! Sudo test_error; then
    log_info "Test 6 passed: Error handling works" "test_sudo"
else
    log_error "Test 6 failed: Error was not properly propagated" "test_sudo"
fi

# Clean up
rm -rf "$TEST_DIR"

log_info "Sudo function tests completed" "test_sudo"