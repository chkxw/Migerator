#!/bin/bash

# Test script for the proxy module
# Tests all functionality of the proxy.sh module

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/modules/proxy.sh"

# Set DEBUG log level
set_log_level "DEBUG"

# Module name for testing
TEST_MODULE="proxy_test"

# Test data
TEST_HOST="squid.cs.wisc.edu"
TEST_PORT="3128"

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
    
    # Remove any proxy settings that might have been created
    if [ "$(id -u)" -eq 0 ]; then
        proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "env,apt,git,ssh,dconf" --remove >/dev/null 2>&1
        
        # Remove test files manually if they still exist
        rm -f /etc/profile.d/proxy.sh 2>/dev/null
        rm -f /etc/apt/apt.conf.d/proxy.conf 2>/dev/null
        rm -f /etc/dconf/db/local.d/00-proxy 2>/dev/null
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
    echo "Running in non-SUDO mode - will only test content generation functions"
fi

# Main test sequence
echo "🔍 Proxy Module Test Suite"
echo ""

# ----------- Basic Tests (No sudo required) -----------

# Test 1: Content Generation Functions
print_header "Content Generation Functions"

# Test environment variables content generation
env_content=$(proxy_generate_env_content "$TEST_HOST" "$TEST_PORT")
if [[ "$env_content" == *"export http_proxy="* && "$env_content" == *"$TEST_HOST:$TEST_PORT"* ]]; then
    report_result 0 "Environment variables content generation"
else
    report_result 1 "Environment variables content generation (Invalid content)"
fi

# Test apt proxy content generation
apt_content=$(proxy_generate_apt_content "$TEST_HOST" "$TEST_PORT")
if [[ "$apt_content" == *"Acquire::http::Proxy"* && "$apt_content" == *"$TEST_HOST:$TEST_PORT"* ]]; then
    report_result 0 "APT proxy content generation"
else
    report_result 1 "APT proxy content generation (Invalid content)"
fi

# Test git proxy content generation
git_content=$(proxy_generate_git_content "$TEST_HOST" "$TEST_PORT")
if [[ "$git_content" == *"[https]"* && "$git_content" == *"$TEST_HOST:$TEST_PORT"* ]]; then
    report_result 0 "Git proxy content generation"
else
    report_result 1 "Git proxy content generation (Invalid content)"
fi

# Test SSH GitHub proxy content generation
ssh_github_content=$(proxy_generate_ssh_github_content "$TEST_HOST" "$TEST_PORT")
if [[ "$ssh_github_content" == *"Host github.com"* && "$ssh_github_content" == *"ProxyCommand corkscrew $TEST_HOST $TEST_PORT"* ]]; then
    report_result 0 "SSH GitHub proxy content generation"
else
    report_result 1 "SSH GitHub proxy content generation (Invalid content)"
fi

# Test SSH Gitee proxy content generation
ssh_gitee_content=$(proxy_generate_ssh_gitee_content "$TEST_HOST" "$TEST_PORT")
if [[ "$ssh_gitee_content" == *"Host gitee.com"* && "$ssh_gitee_content" == *"ProxyCommand corkscrew $TEST_HOST $TEST_PORT"* ]]; then
    report_result 0 "SSH Gitee proxy content generation"
else
    report_result 1 "SSH Gitee proxy content generation (Invalid content)"
fi

# Test dconf proxy content generation
dconf_content=$(proxy_generate_dconf_content "$TEST_HOST" "$TEST_PORT")
if [[ "$dconf_content" == *"[system/proxy]"* && "$dconf_content" == *"host='$TEST_HOST'"* && "$dconf_content" == *"port=$TEST_PORT"* ]]; then
    report_result 0 "DConf proxy content generation"
else
    report_result 1 "DConf proxy content generation (Invalid content)"
fi

# Test dconf profile content generation
dconf_profile_content=$(proxy_generate_dconf_profile_content)
if [[ "$dconf_profile_content" == *"user-db:user"* && "$dconf_profile_content" == *"system-db:local"* ]]; then
    report_result 0 "DConf profile content generation"
else
    report_result 1 "DConf profile content generation (Invalid content)"
fi

# Test 2: Command Line Argument Parsing
print_header "Command Line Argument Parsing"

# Test help option
output=$(proxy_main --help 2>&1)
if [[ "$output" == *"Usage:"* && "$output" == *"--host HOST"* && "$output" == *"--port PORT"* ]]; then
    report_result 0 "Help option displays usage information"
else
    report_result 1 "Help option fails to display usage information"
fi

# Test invalid option
proxy_main --invalid-option >/dev/null 2>&1
if [ $? -ne 0 ]; then
    report_result 0 "Invalid option is rejected"
else
    report_result 1 "Invalid option is accepted"
fi

# ----------- Advanced Tests (Sudo required) -----------

if [ "$SUDO_MODE" = true ]; then
    # Test 3: Environment Variables Configuration
    print_header "Environment Variables Configuration"
    
    # Remove existing settings first
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "env" --remove >/dev/null 2>&1
    
    # Configure environment variables
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "env" >/dev/null 2>&1
    result=$?
    
    if [ -f "/etc/profile.d/proxy.sh" ] && check_file_with_content "/etc/profile.d/proxy.sh" "export http_proxy=\"http://$TEST_HOST:$TEST_PORT/\""; then
        report_result 0 "Environment variables configuration"
    else
        report_result 1 "Environment variables configuration failed"
    fi
    
    # Test 4: APT Configuration
    print_header "APT Configuration"
    
    # Remove existing settings first
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "apt" --remove >/dev/null 2>&1
    
    # Configure APT
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "apt" >/dev/null 2>&1
    result=$?
    
    if [ -f "/etc/apt/apt.conf.d/proxy.conf" ] && check_file_with_content "/etc/apt/apt.conf.d/proxy.conf" "Acquire::http::Proxy \"http://$TEST_HOST:$TEST_PORT\""; then
        report_result 0 "APT configuration"
    else
        report_result 1 "APT configuration failed"
    fi
    
    # Test 5: Git Configuration
    print_header "Git Configuration"
    
    # Remove existing settings first
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "git" --remove >/dev/null 2>&1
    
    # Configure Git
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "git" >/dev/null 2>&1
    result=$?
    
    if [ -f "/etc/gitconfig" ] && check_file_with_content "/etc/gitconfig" "proxy = http://$TEST_HOST:$TEST_PORT"; then
        report_result 0 "Git configuration"
    else
        report_result 1 "Git configuration failed"
    fi
    
    # Test 6: DConf Configuration
    print_header "DConf Configuration"
    
    # Remove existing settings first
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "dconf" --remove >/dev/null 2>&1
    
    # Configure DConf
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "dconf" >/dev/null 2>&1
    result=$?
    
    if [ -f "/etc/dconf/db/local.d/00-proxy" ] && check_file_with_content "/etc/dconf/db/local.d/00-proxy" "host='$TEST_HOST'"; then
        report_result 0 "DConf configuration"
    else
        report_result 1 "DConf configuration failed"
    fi
    
    # Test 7: Multiple Services Configuration
    print_header "Multiple Services Configuration"
    
    # Remove existing settings first
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "env,apt,git,dconf" --remove >/dev/null 2>&1
    
    # Configure multiple services at once
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "env,apt,git,dconf" >/dev/null 2>&1
    result=$?
    
    env_ok=false
    apt_ok=false
    git_ok=false
    dconf_ok=false
    
    if [ -f "/etc/profile.d/proxy.sh" ] && check_file_with_content "/etc/profile.d/proxy.sh" "export http_proxy=\"http://$TEST_HOST:$TEST_PORT/\""; then
        env_ok=true
    fi
    
    if [ -f "/etc/apt/apt.conf.d/proxy.conf" ] && check_file_with_content "/etc/apt/apt.conf.d/proxy.conf" "Acquire::http::Proxy \"http://$TEST_HOST:$TEST_PORT\""; then
        apt_ok=true
    fi
    
    if [ -f "/etc/gitconfig" ] && check_file_with_content "/etc/gitconfig" "proxy = http://$TEST_HOST:$TEST_PORT"; then
        git_ok=true
    fi
    
    if [ -f "/etc/dconf/db/local.d/00-proxy" ] && check_file_with_content "/etc/dconf/db/local.d/00-proxy" "host='$TEST_HOST'"; then
        dconf_ok=true
    fi
    
    if $env_ok && $apt_ok && $git_ok && $dconf_ok; then
        report_result 0 "Multiple services configuration"
    else
        report_result 1 "Multiple services configuration failed"
    fi
    
    # Test 8: Configuration Removal
    print_header "Configuration Removal"
    
    # Remove all configuration
    proxy_main --host "$TEST_HOST" --port "$TEST_PORT" --services "env,apt,git,dconf" --remove >/dev/null 2>&1
    result=$?
    
    env_removed=true
    apt_removed=true
    git_removed=true
    dconf_removed=true
    
    if [ -f "/etc/profile.d/proxy.sh" ] && check_file_with_content "/etc/profile.d/proxy.sh" "export http_proxy=\"http://$TEST_HOST:$TEST_PORT/\""; then
        env_removed=false
    fi
    
    if [ -f "/etc/apt/apt.conf.d/proxy.conf" ] && check_file_with_content "/etc/apt/apt.conf.d/proxy.conf" "Acquire::http::Proxy \"http://$TEST_HOST:$TEST_PORT\""; then
        apt_removed=false
    fi
    
    if [ -f "/etc/gitconfig" ] && check_file_with_content "/etc/gitconfig" "proxy = http://$TEST_HOST:$TEST_PORT"; then
        git_removed=false
    fi
    
    if [ -f "/etc/dconf/db/local.d/00-proxy" ] && check_file_with_content "/etc/dconf/db/local.d/00-proxy" "host='$TEST_HOST'"; then
        dconf_removed=false
    fi
    
    if $env_removed && $apt_removed && $git_removed && $dconf_removed; then
        report_result 0 "Configuration removal"
    else
        report_result 1 "Configuration removal failed"
    fi
    
    # Skip testing SSH configurations as it would try to install corkscrew
    # We'll verify the function exists but not execute it with SSH
    if declare -f proxy_setup_service >/dev/null; then
        report_result 0 "Proxy setup service function exists"
    else
        report_result 1 "Proxy setup service function does not exist"
    fi
fi

echo "🏁 Proxy Module Test Suite Completed"
echo ""
if [ "$SUDO_MODE" = true ]; then
    echo "All tests completed in SUDO mode"
else
    echo "Basic tests completed in non-SUDO mode"
    echo "Run with sudo for complete testing: sudo $0"
fi