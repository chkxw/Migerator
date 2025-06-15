#!/bin/bash

# Test script for the Atuin module
# Tests Atuin installation, configuration, and removal operations

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"
source "$PROJECT_ROOT/src/modules/atuin.sh"

# Set log level to DEBUG for testing
set_log_level "DEBUG"

# Test results tracking
TEST_PASSED=0
TEST_FAILED=0

# Function to report test results
report_result() {
    local exit_code="$1"
    local test_description="$2"
    
    if [ "$exit_code" -eq 0 ]; then
        log_info "✓ $test_description" "test_atuin"
        ((TEST_PASSED++))
    else
        log_error "✗ $test_description" "test_atuin"
        ((TEST_FAILED++))
    fi
}

log_info "Starting Atuin module tests" "test_atuin"

# Create test directories
TEST_DIR="/tmp/atuin_test_$(date +%s)"
mkdir -p "$TEST_DIR"

# Backup original shell configs if they exist
BACKUP_BASHRC=""
BACKUP_ZSHRC=""
if [ -f "$HOME/.bashrc" ]; then
    BACKUP_BASHRC="$TEST_DIR/bashrc.backup"
    cp "$HOME/.bashrc" "$BACKUP_BASHRC"
fi
if [ -f "$HOME/.zshrc" ]; then
    BACKUP_ZSHRC="$TEST_DIR/zshrc.backup"
    cp "$HOME/.zshrc" "$BACKUP_ZSHRC"
fi

# Test 1: Test content generation functions
log_info "Test 1: Testing content generation functions" "test_atuin"

# Test bash init content generation
bash_content=$(atuin_generate_bash_init_content)
if [[ "$bash_content" =~ "atuin init bash" ]]; then
    report_result 0 "Bash init content generation works"
else
    report_result 1 "Bash init content generation failed"
fi

# Test zsh init content generation
zsh_content=$(atuin_generate_zsh_init_content)
if [[ "$zsh_content" =~ "atuin init zsh" ]]; then
    report_result 0 "Zsh init content generation works"
else
    report_result 1 "Zsh init content generation failed"
fi

# Test config content generation
config_content=$(atuin_generate_config_content "true")
if [[ "$config_content" =~ "sync_enabled = true" ]]; then
    report_result 0 "Config content generation works"
else
    report_result 1 "Config content generation failed"
fi

# Test 2: Test installation detection
log_info "Test 2: Testing installation detection" "test_atuin"

# Before installation, should return false
if ! atuin_is_installed; then
    report_result 0 "Correctly detected Atuin is not installed"
else
    report_result 1 "Incorrectly detected Atuin as installed"
fi

# Test 3: Test help functionality
log_info "Test 3: Testing help functionality" "test_atuin"

if atuin_main --help > /dev/null 2>&1; then
    report_result 0 "Help functionality works"
else
    report_result 1 "Help functionality failed"
fi

# Test 4: Test argument validation
log_info "Test 4: Testing argument validation" "test_atuin"

# Test invalid shell type
if ! atuin_main --shell invalid 2>/dev/null; then
    report_result 0 "Correctly rejected invalid shell type"
else
    report_result 1 "Failed to reject invalid shell type"
fi

# Test login without required args
if ! atuin_main --login 2>/dev/null; then
    report_result 0 "Correctly rejected login without credentials"
else
    report_result 1 "Failed to reject login without credentials"
fi

# Test register without required args
if ! atuin_main --register --username test 2>/dev/null; then
    report_result 0 "Correctly rejected register without all required fields"
else
    report_result 1 "Failed to reject register without all required fields"
fi

# Test 5: Test shell configuration functions (dry run)
log_info "Test 5: Testing shell configuration (without actual installation)" "test_atuin"

# Create test shell config files
TEST_BASHRC="$TEST_DIR/test_bashrc"
TEST_ZSHRC="$TEST_DIR/test_zshrc"
echo "# Test bashrc" > "$TEST_BASHRC"
echo "# Test zshrc" > "$TEST_ZSHRC"

# Test content insertion
bash_init_content=$(atuin_generate_bash_init_content)
if safe_insert "Test Atuin integration" "$TEST_BASHRC" "$bash_init_content"; then
    if grep -q "atuin init bash" "$TEST_BASHRC"; then
        report_result 0 "Bash configuration insertion works"
    else
        report_result 1 "Bash configuration not found after insertion"
    fi
else
    report_result 1 "Bash configuration insertion failed"
fi

# Test content removal
if safe_remove "Test Atuin integration" "$TEST_BASHRC" "$bash_init_content"; then
    if ! grep -q "atuin init bash" "$TEST_BASHRC"; then
        report_result 0 "Bash configuration removal works"
    else
        report_result 1 "Bash configuration still found after removal"
    fi
else
    report_result 1 "Bash configuration removal failed"
fi

# Test 6: Test configuration generation
log_info "Test 6: Testing configuration file generation" "test_atuin"

# Test config with sync enabled
config_with_sync=$(atuin_generate_config_content "true")
if [[ "$config_with_sync" =~ "sync_enabled = true" ]] && [[ "$config_with_sync" =~ "auto_sync = true" ]]; then
    report_result 0 "Config generation with sync enabled works"
else
    report_result 1 "Config generation with sync enabled failed"
fi

# Test config with sync disabled
config_without_sync=$(atuin_generate_config_content "false")
if [[ "$config_without_sync" =~ "sync_enabled = false" ]]; then
    report_result 0 "Config generation with sync disabled works"
else
    report_result 1 "Config generation with sync disabled failed"
fi

# Test 7: Test module integration
log_info "Test 7: Testing module registration" "test_atuin"

# Check if module commands are exported
if [[ " ${MODULE_COMMANDS[@]} " =~ " atuin_main:Install and configure Atuin shell history manager " ]]; then
    report_result 0 "Module commands are properly exported"
else
    report_result 1 "Module commands not properly exported"
fi

# Test 8: Test error conditions
log_info "Test 8: Testing error handling" "test_atuin"

# Test unknown option
if ! atuin_main --unknown-option 2>/dev/null; then
    report_result 0 "Correctly handled unknown option"
else
    report_result 1 "Failed to handle unknown option"
fi

# Cleanup
log_info "Cleaning up test artifacts" "test_atuin"

# Restore original shell configs if they existed
if [ -n "$BACKUP_BASHRC" ] && [ -f "$BACKUP_BASHRC" ]; then
    cp "$BACKUP_BASHRC" "$HOME/.bashrc"
fi
if [ -n "$BACKUP_ZSHRC" ] && [ -f "$BACKUP_ZSHRC" ]; then
    cp "$BACKUP_ZSHRC" "$HOME/.zshrc"
fi

# Remove test directory
rm -rf "$TEST_DIR"

# Print test summary
log_info "===== Atuin Module Test Summary =====" "test_atuin"
log_info "Tests passed: $TEST_PASSED" "test_atuin"
log_info "Tests failed: $TEST_FAILED" "test_atuin"
log_info "Total tests: $((TEST_PASSED + TEST_FAILED))" "test_atuin"

if [ $TEST_FAILED -eq 0 ]; then
    log_info "All tests passed!" "test_atuin"
    exit 0
else
    log_error "$TEST_FAILED test(s) failed!" "test_atuin"
    exit 1
fi