#!/bin/bash

# Test script for git operations functions
# Tests git clone, update, and remove operations with and without SSH keys

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/git_ops.sh"

# Set log level to DEBUG for testing
set_log_level "DEBUG"

log_info "Starting git operations tests" "test_git"

# Create test directory
TEST_BASE_DIR="/tmp/git_ops_test_$(date +%s)"
mkdir -p "$TEST_BASE_DIR"

# Test repository (using a small public repository)
TEST_REPO_URL="https://github.com/octocat/Hello-World.git"
TEST_REPO_SSH="git@github.com:octocat/Hello-World.git"

# Test 1: Basic git clone with HTTPS
log_info "Test 1: Basic git clone with HTTPS" "test_git"
TEST_DIR_1="$TEST_BASE_DIR/test1"

if git_clone "$TEST_REPO_URL" "$TEST_DIR_1"; then
    log_info "✓ Successfully cloned repository via HTTPS" "test_git"
    
    # Verify it's a git repository
    if is_git_repo "$TEST_DIR_1"; then
        log_info "✓ Directory is a valid git repository" "test_git"
    else
        log_error "✗ Directory is not a valid git repository" "test_git"
    fi
    
    # Check current branch
    branch=$(git_current_branch "$TEST_DIR_1")
    log_info "Current branch: $branch" "test_git"
    
    # Check remote URL
    remote_url=$(git_remote_url "$TEST_DIR_1")
    log_info "Remote URL: $remote_url" "test_git"
else
    log_error "✗ Failed to clone repository via HTTPS" "test_git"
fi

# Test 2: Clone with specific branch and depth
log_info "Test 2: Clone with specific branch and depth" "test_git"
TEST_DIR_2="$TEST_BASE_DIR/test2"

if git_clone "$TEST_REPO_URL" "$TEST_DIR_2" --branch master --depth 1; then
    log_info "✓ Successfully cloned with branch and depth options" "test_git"
    
    # Verify shallow clone
    pushd "$TEST_DIR_2" > /dev/null
    commit_count=$(git rev-list --count HEAD)
    popd > /dev/null
    
    if [ "$commit_count" -eq 1 ]; then
        log_info "✓ Shallow clone verified (1 commit)" "test_git"
    else
        log_error "✗ Shallow clone failed (found $commit_count commits)" "test_git"
    fi
else
    log_error "✗ Failed to clone with options" "test_git"
fi

# Test 3: Clone to existing directory (should fail)
log_info "Test 3: Clone to existing directory (should fail)" "test_git"

if ! git_clone "$TEST_REPO_URL" "$TEST_DIR_1" 2>/dev/null; then
    log_info "✓ Correctly rejected cloning to existing directory" "test_git"
else
    log_error "✗ Should have failed cloning to existing directory" "test_git"
fi

# Test 4: Clone with --force to existing directory
log_info "Test 4: Clone with --force to existing directory" "test_git"

if git_clone "$TEST_REPO_URL" "$TEST_DIR_1" --force; then
    log_info "✓ Successfully cloned with --force option" "test_git"
else
    log_error "✗ Failed to clone with --force option" "test_git"
fi

# Test 5: Update repository
log_info "Test 5: Update repository" "test_git"

# Create a file to simulate local changes
echo "test" > "$TEST_DIR_1/test_file.txt"

if git_update "$TEST_DIR_1"; then
    log_info "✓ Successfully updated repository" "test_git"
else
    log_warning "Update may have failed due to local changes (expected)" "test_git"
fi

# Test 6: Update with reset
log_info "Test 6: Update with reset" "test_git"

if git_update "$TEST_DIR_1" --reset; then
    log_info "✓ Successfully updated repository with reset" "test_git"
    
    # Verify test file was removed
    if [ ! -f "$TEST_DIR_1/test_file.txt" ]; then
        log_info "✓ Local changes were reset" "test_git"
    else
        log_error "✗ Local changes were not reset" "test_git"
    fi
else
    log_error "✗ Failed to update repository with reset" "test_git"
fi

# Test 7: Remove repository
log_info "Test 7: Remove repository" "test_git"

if git_remove "$TEST_DIR_2"; then
    log_info "✓ Successfully removed repository" "test_git"
    
    # Verify directory was removed
    if [ ! -d "$TEST_DIR_2" ]; then
        log_info "✓ Directory was removed" "test_git"
    else
        log_error "✗ Directory still exists" "test_git"
    fi
else
    log_error "✗ Failed to remove repository" "test_git"
fi

# Test 8: Remove with backup
log_info "Test 8: Remove with backup" "test_git"
BACKUP_DIR="$TEST_BASE_DIR/backup"

if git_remove "$TEST_DIR_1" --backup "$BACKUP_DIR"; then
    log_info "✓ Successfully removed repository with backup" "test_git"
    
    # Verify backup was created
    if [ -d "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR/.git" ]; then
        log_info "✓ Backup was created successfully" "test_git"
    else
        log_error "✗ Backup was not created" "test_git"
    fi
else
    log_error "✗ Failed to remove repository with backup" "test_git"
fi

# Test 9: SSH key validation (negative test)
log_info "Test 9: SSH key validation" "test_git"
TEST_DIR_9="$TEST_BASE_DIR/test9"
FAKE_SSH_KEY="/tmp/nonexistent_key"

if ! git_clone "$TEST_REPO_SSH" "$TEST_DIR_9" --ssh-key "$FAKE_SSH_KEY" 2>/dev/null; then
    log_info "✓ Correctly rejected non-existent SSH key" "test_git"
else
    log_error "✗ Should have failed with non-existent SSH key" "test_git"
fi

# Test 10: Helper functions
log_info "Test 10: Helper functions" "test_git"

# Test with non-git directory
if ! is_git_repo "$TEST_BASE_DIR"; then
    log_info "✓ Correctly identified non-git directory" "test_git"
else
    log_error "✗ Incorrectly identified directory as git repo" "test_git"
fi

# Test with non-existent directory
if ! git_current_branch "/tmp/nonexistent_dir_12345" 2>/dev/null; then
    log_info "✓ Correctly handled non-existent directory" "test_git"
else
    log_error "✗ Should have failed with non-existent directory" "test_git"
fi

# Cleanup
log_info "Cleaning up test directories" "test_git"
rm -rf "$TEST_BASE_DIR"

log_info "Git operations tests completed" "test_git"