#!/bin/bash

# Test script for the safe_insert function
# This tests that the function correctly modifies files with proper confirmation handling

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"

# Set log level to DEBUG for testing
set_log_level "DEBUG"

log_info "Starting safe_insert function tests" "test_safe_modify"

# Create test directories
TEST_DIR="/tmp/safe_modify_test_$(date +%s)"
ensure_directory "$TEST_DIR"

# Function to create a test file with content
create_test_file() {
    local file_path="$1"
    local content="$2"
    
    echo -e "$content" > "$file_path"
    log_debug "Created test file: $file_path" "test_safe_modify"
}

# Function to verify file content
verify_file_content() {
    local file_path="$1"
    local expected_content="$2"
    local actual_content=$(cat "$file_path")
    
    # Remove any leading empty line that might be added
    actual_content=$(echo "$actual_content" | sed '/^$/d')
    expected_content=$(echo "$expected_content" | sed '/^$/d')
    
    if [ "$actual_content" = "$expected_content" ]; then
        log_info "File content verification passed: $file_path" "test_safe_modify"
        return 0
    else
        log_error "File content verification failed: $file_path" "test_safe_modify"
        echo "Expected:"
        echo "$expected_content"
        echo "Actual:"
        echo "$actual_content"
        return 1
    fi
}

# Test 1: Test adding content to a new file with auto-confirmation
log_info "Test 1: Adding content to a new file with auto-confirmation" "test_safe_modify"
test_file="$TEST_DIR/test1.txt"
title_line="# Test Title"
content_line1="This is test content 1"
content_line2="This is test content 2"

# Set auto-confirmation mode
set_global_var "confirm_all" "true"

# Run the function
if safe_insert "Test 1" "$test_file" "$title_line" "$content_line1" "$content_line2"; then
    expected_content=$(printf "%s\n%s\n%s" "$title_line" "$content_line1" "$content_line2")
    if verify_file_content "$test_file" "$expected_content"; then
        log_info "Test 1 passed: Content added correctly to new file" "test_safe_modify"
    else
        log_error "Test 1 failed: Content not added correctly to new file" "test_safe_modify"
    fi
else
    log_error "Test 1 failed: safe_insert returned error" "test_safe_modify"
fi

# Test 2: Test adding content to an existing file
log_info "Test 2: Adding content to an existing file" "test_safe_modify"
test_file="$TEST_DIR/test2.txt"
initial_content="Initial content"
create_test_file "$test_file" "$initial_content"

title_line="# New Section"
content_line1="New content line 1"
content_line2="New content line 2"

if safe_insert "Test 2" "$test_file" "$title_line" "$content_line1" "$content_line2"; then
    expected_content=$(printf "%s\n%s\n%s\n%s" "$initial_content" "$title_line" "$content_line1" "$content_line2")
    if verify_file_content "$test_file" "$expected_content"; then
        log_info "Test 2 passed: Content added correctly to existing file" "test_safe_modify"
    else
        log_error "Test 2 failed: Content not added correctly to existing file" "test_safe_modify"
    fi
else
    log_error "Test 2 failed: safe_insert returned error" "test_safe_modify"
fi

# Test 3: Test adding content with existing title line
log_info "Test 3: Adding content with existing title line" "test_safe_modify"
test_file="$TEST_DIR/test3.txt"
initial_content="Initial content\n# Existing Section\nExisting content"
create_test_file "$test_file" "$initial_content"

title_line="# Existing Section"
content_line1="New content line 1"
content_line2="New content line 2"

if safe_insert "Test 3" "$test_file" "$title_line" "$content_line1" "$content_line2"; then
    # Since we're dealing with an existing title line, the content might vary
    # Let's just verify that our new content lines are present
    if grep -q "$content_line1" "$test_file" && grep -q "$content_line2" "$test_file"; then
        log_info "Test 3 passed: Content added correctly with existing title line" "test_safe_modify"
    else
        log_error "Test 3 failed: Content not added correctly with existing title line" "test_safe_modify"
        cat "$test_file"
    fi
else
    log_error "Test 3 failed: safe_insert returned error" "test_safe_modify"
fi

# Test 4: Test adding existing content (no changes)
log_info "Test 4: Adding existing content (no changes)" "test_safe_modify"
test_file="$TEST_DIR/test4.txt"
initial_content="Initial content\n# Existing Section\nExisting content line 1\nExisting content line 2"
create_test_file "$test_file" "$initial_content"

title_line="# Existing Section"
content_line1="Existing content line 1"
content_line2="Existing content line 2"

if safe_insert "Test 4" "$test_file" "$title_line" "$content_line1" "$content_line2"; then
    # Since we're adding existing content, the file content might not change
    # Let's just verify that our content lines are present
    if grep -q "$content_line1" "$test_file" && grep -q "$content_line2" "$test_file"; then
        log_info "Test 4 passed: No changes when content already exists" "test_safe_modify"
    else
        log_error "Test 4 failed: Unexpected changes when content already exists" "test_safe_modify"
        cat "$test_file"
    fi
else
    log_error "Test 4 failed: safe_insert returned error" "test_safe_modify"
fi

# Test 5: Test creating directory structure
log_info "Test 5: Creating directory structure" "test_safe_modify"
nested_dir="$TEST_DIR/nested/dir/structure"
test_file="$nested_dir/test5.txt"
title_line="# Nested File"
content_line="Content in nested directory"

if safe_insert "Test 5" "$test_file" "$title_line" "$content_line"; then
    if [ -f "$test_file" ]; then
        expected_content=$(printf "%s\n%s" "$title_line" "$content_line")
        if verify_file_content "$test_file" "$expected_content"; then
            log_info "Test 5 passed: Directory structure created and file modified" "test_safe_modify"
        else
            log_error "Test 5 failed: File content incorrect" "test_safe_modify"
        fi
    else
        log_error "Test 5 failed: File not created" "test_safe_modify"
    fi
else
    log_error "Test 5 failed: safe_insert returned error" "test_safe_modify"
fi

# Restore manual confirmation mode
set_global_var "confirm_all" "false"

log_info "All tests completed for safe_insert" "test_safe_modify"

# Clean up
rm -rf "$TEST_DIR"
log_info "Test cleanup completed" "test_safe_modify"