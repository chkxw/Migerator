#!/bin/bash

# Test script for git_repos module

# Source test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/git_ops.sh"
source "$PROJECT_ROOT/src/modules/git_repos.sh"

# Test configuration
TEST_DIR="/tmp/test_git_repos_$$"
TEST_REPO_DIR="$TEST_DIR/repos"

# Initialize globals
SCRIPT_CONFIG[confirm_all]="true"
SCRIPT_CONFIG[safe_remove_all]="true"

# Test results
TEST_PASSED=0
TEST_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Function to report test results
report_result() {
    local status=$1
    local test_name="$2"
    
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TEST_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        ((TEST_FAILED++))
    fi
}

# Setup test environment
setup_test() {
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_REPO_DIR"
}

# Cleanup test environment
cleanup_test() {
    rm -rf "$TEST_DIR"
}

# Test example config generation
test_example_config_generation() {
    echo "Testing example config generation..."
    
    local content=$(git_repos_generate_example_config)
    
    if [[ "$content" == *"GIT_REPO_URL[myproject]"* ]] && 
       [[ "$content" == *"GIT_REPO_DIR[myproject]"* ]] &&
       [[ "$content" == *"Add these lines to your globals.sh"* ]]; then
        report_result 0 "Example config generation creates proper guide"
    else
        report_result 1 "Example config generation failed"
    fi
}

# Test globals configuration
test_globals_config() {
    echo "Testing globals configuration..."
    
    # Set up test repositories in globals
    GIT_REPO_URL[test_repo]="https://github.com/test/repo.git"
    GIT_REPO_DIR[test_repo]="$TEST_REPO_DIR/test_repo"
    GIT_REPO_BRANCH[test_repo]="main"
    GIT_REPO_SSH_KEY[test_repo]=""
    
    GIT_REPO_URL[test_private]="git@github.com:test/private.git"
    GIT_REPO_DIR[test_private]="$TEST_REPO_DIR/test_private"
    GIT_REPO_BRANCH[test_private]="develop"
    GIT_REPO_SSH_KEY[test_private]="~/.ssh/id_rsa"
    
    # Export arrays
    export GIT_REPO_URL
    export GIT_REPO_DIR
    export GIT_REPO_BRANCH
    export GIT_REPO_SSH_KEY
    
    # Test retrieving repository list
    local repo_list=$(global_vars git_repos)
    if [[ "$repo_list" == *"test_repo"* ]] && [[ "$repo_list" == *"test_private"* ]]; then
        report_result 0 "Globals configuration retrieval"
    else
        report_result 1 "Failed to retrieve git repos from globals"
    fi
    
    # Clean up
    unset GIT_REPO_URL[test_repo]
    unset GIT_REPO_DIR[test_repo]
    unset GIT_REPO_BRANCH[test_repo]
    unset GIT_REPO_SSH_KEY[test_repo]
    
    unset GIT_REPO_URL[test_private]
    unset GIT_REPO_DIR[test_private]
    unset GIT_REPO_BRANCH[test_private]
    unset GIT_REPO_SSH_KEY[test_private]
}

# Test single repository clone
test_single_clone() {
    echo "Testing single repository clone..."
    
    # Create a test repository to clone
    local test_repo="$TEST_DIR/source_repo"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init >/dev/null 2>&1
    echo "test" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    cd - >/dev/null
    
    # Test cloning
    local target_dir="$TEST_REPO_DIR/cloned_repo"
    if git_repos_clone_single "file://$test_repo" "$target_dir" "master" "" "false"; then
        if [[ -d "$target_dir/.git" ]] && [[ -f "$target_dir/README.md" ]]; then
            report_result 0 "Single repository clone successful"
        else
            report_result 1 "Single repository clone incomplete"
        fi
    else
        report_result 1 "Single repository clone failed"
    fi
    
    # Cleanup
    rm -rf "$test_repo" "$target_dir"
}

# Test clone with empty globals
test_clone_empty_globals() {
    echo "Testing clone with empty globals..."
    
    # Ensure no repositories configured
    unset GIT_REPO_URL
    unset GIT_REPO_DIR
    unset GIT_REPO_BRANCH
    unset GIT_REPO_SSH_KEY
    
    # Run clone without any repos configured
    cd "$TEST_DIR"
    if git_repos_main clone 2>&1 | grep -q "No git repositories configured"; then
        report_result 0 "Empty globals warning shown"
    else
        report_result 1 "Empty globals warning not shown"
    fi
    cd - >/dev/null
}

# Test main function with help
test_main_help() {
    echo "Testing main function help..."
    
    local help_output=$(git_repos_main --help 2>&1)
    
    if [[ "$help_output" == *"Usage: git_repos_main"* ]] &&
       [[ "$help_output" == *"Commands:"* ]] &&
       [[ "$help_output" == *"Options:"* ]]; then
        report_result 0 "Main function help output"
    else
        report_result 1 "Main function help incomplete"
    fi
}

# Test main function with single clone
test_main_single_clone() {
    echo "Testing main function single clone..."
    
    # Create a test repository
    local test_repo="$TEST_DIR/main_test_repo"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init >/dev/null 2>&1
    echo "main test" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    cd - >/dev/null
    
    # Test single clone via main
    local target_dir="$TEST_REPO_DIR/main_cloned"
    if git_repos_main clone --url "file://$test_repo" --dir "$target_dir" --branch master; then
        if [[ -d "$target_dir/.git" ]]; then
            report_result 0 "Main function single clone"
        else
            report_result 1 "Main function clone incomplete"
        fi
    else
        report_result 1 "Main function clone failed"
    fi
    
    # Cleanup
    rm -rf "$test_repo" "$target_dir"
}

# Test skip behavior when directory exists
test_skip_existing_directory() {
    echo "Testing skip behavior for existing directories..."
    
    # Create existing directory
    local target_dir="$TEST_REPO_DIR/existing_dir"
    mkdir -p "$target_dir"
    echo "existing content" > "$target_dir/test.txt"
    
    # Create a test repository
    local test_repo="$TEST_DIR/skip_test_repo"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init >/dev/null 2>&1
    echo "new content" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    cd - >/dev/null
    
    # Test skipping existing directory (should return 2)
    local result
    git_repos_clone_single "file://$test_repo" "$target_dir" "master" "" "false"
    result=$?
    
    if [[ $result -eq 2 ]] && [[ -f "$target_dir/test.txt" ]] && [[ ! -f "$target_dir/README.md" ]]; then
        report_result 0 "Skip existing directory behavior"
    else
        report_result 1 "Skip existing directory failed (result: $result)"
    fi
    
    # Cleanup
    rm -rf "$test_repo" "$target_dir"
}

# Test force behavior when directory exists
test_force_existing_directory() {
    echo "Testing force behavior for existing directories..."
    
    # Create existing directory
    local target_dir="$TEST_REPO_DIR/force_dir"
    mkdir -p "$target_dir"
    echo "existing content" > "$target_dir/test.txt"
    
    # Create a test repository
    local test_repo="$TEST_DIR/force_test_repo"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init >/dev/null 2>&1
    echo "new content" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    cd - >/dev/null
    
    # Test forcing overwrite of existing directory (should return 0)
    local result
    git_repos_clone_single "file://$test_repo" "$target_dir" "master" "" "true"
    result=$?
    
    if [[ $result -eq 0 ]] && [[ -f "$target_dir/README.md" ]] && [[ ! -f "$target_dir/test.txt" ]]; then
        report_result 0 "Force existing directory behavior"
    else
        report_result 1 "Force existing directory failed (result: $result)"
    fi
    
    # Cleanup
    rm -rf "$test_repo" "$target_dir"
}

# Test main function force flag
test_main_force_flag() {
    echo "Testing main function force flag..."
    
    local help_output=$(git_repos_main --help 2>&1)
    
    if [[ "$help_output" == *"--force"* ]] &&
       [[ "$help_output" == *"Force overwrite existing directories"* ]]; then
        report_result 0 "Main function force flag in help"
    else
        report_result 1 "Main function force flag missing from help"
    fi
}

# Test module context preservation
test_module_context() {
    echo "Testing module context preservation..."
    
    # Set initial context
    MODULE_NAME="test_module"
    MODULE_DESCRIPTION="Test description"
    MODULE_VERSION="0.0.1"
    
    # Call main function
    git_repos_main --help >/dev/null 2>&1
    
    # Check context restored
    if [[ "$MODULE_NAME" == "test_module" ]] &&
       [[ "$MODULE_DESCRIPTION" == "Test description" ]] &&
       [[ "$MODULE_VERSION" == "0.0.1" ]]; then
        report_result 0 "Module context preservation"
    else
        report_result 1 "Module context not preserved"
    fi
}

# Main test execution
main() {
    echo "Running git_repos module tests..."
    echo "================================"
    
    setup_test
    
    test_example_config_generation
    test_globals_config
    test_single_clone
    test_skip_existing_directory
    test_force_existing_directory
    test_clone_empty_globals
    test_main_help
    test_main_single_clone
    test_main_force_flag
    test_module_context
    
    cleanup_test
    
    echo "================================"
    echo "Tests passed: $TEST_PASSED"
    echo "Tests failed: $TEST_FAILED"
    
    if [ $TEST_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
fi