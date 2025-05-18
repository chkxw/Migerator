#!/bin/bash

# Test script for the safe_remove function
# This tests that the function correctly removes content from files with proper confirmation handling

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

log_info "Starting safe_remove function tests" "test_safe_remove"

# Create test directories
TEST_DIR="/tmp/safe_remove_test_$(date +%s)"
ensure_directory "$TEST_DIR"

# Function to create a test file with content
create_test_file() {
    local file_path="$1"
    local content="$2"
    
    echo -e "$content" > "$file_path"
    log_debug "Created test file: $file_path" "test_safe_remove"
}

# Function to verify file content
verify_file_content() {
    local file_path="$1"
    local expected_content="$2"
    
    # Normalize expected content (replace \n with actual newlines)
    expected_content=$(echo -e "$expected_content")
    
    # Read file content
    local actual_content=""
    if [ -f "$file_path" ]; then
        actual_content=$(cat "$file_path")
    fi
    
    # Remove any trailing newlines from both strings for comparison
    actual_content="${actual_content%"${actual_content##*[![:space:]]}"}"
    expected_content="${expected_content%"${expected_content##*[![:space:]]}"}"
    
    if [ "$actual_content" = "$expected_content" ]; then
        log_info "File content verification passed: $file_path" "test_safe_remove"
        return 0
    else
        log_error "File content verification failed: $file_path" "test_safe_remove"
        echo "Expected:"
        echo "$expected_content"
        echo "Actual:"
        echo "$actual_content"
        return 1
    fi
}

# Set auto-confirmation mode for tests
set_global_var "confirm_all" "true"

# Test 1: Test removing content from a file with title line and content
log_info "Test 1: Removing content from a file with title line and content" "test_safe_remove"
test_file="$TEST_DIR/test1.txt"
initial_content="Initial content\n# Test Title\nThis is test content 1\nThis is test content 2\nOther content"
create_test_file "$test_file" "$initial_content"

title_line="# Test Title"
content_line1="This is test content 1"
content_line2="This is test content 2"

if safe_remove "Test 1" "$test_file" "$title_line" "$content_line1" "$content_line2"; then
    # The content was removed but the title line still exists
    # This is correct behavior since other content exists after the section
    expected_content="Initial content\n# Test Title\nOther content"
    if verify_file_content "$test_file" "$expected_content"; then
        log_info "Test 1 passed: Content removed correctly" "test_safe_remove"
    else
        log_error "Test 1 failed: Content not removed correctly" "test_safe_remove"
    fi
else
    log_error "Test 1 failed: safe_remove returned error" "test_safe_remove"
fi

# Test 2: Test removing content when title line should also be removed
log_info "Test 2: Removing content when title line should also be removed" "test_safe_remove"
test_file="$TEST_DIR/test2.txt"
# Create a file where the title line should be removed (has no content after removing the specified content)
initial_content="Initial content\n# Test Title\nThis is test content 1\nThis is test content 2\n# Another Section\nOther content"
create_test_file "$test_file" "$initial_content"

title_line="# Test Title"
content_line1="This is test content 1"
content_line2="This is test content 2"

# Remove all content lines, title line should be removed too
if safe_remove "Test 2" "$test_file" "$title_line" "$content_line1" "$content_line2"; then
    expected_content="Initial content\n# Another Section\nOther content"
    if verify_file_content "$test_file" "$expected_content"; then
        log_info "Test 2 passed: Content and title line removed correctly" "test_safe_remove"
    else
        log_error "Test 2 failed: Content and title line not removed correctly" "test_safe_remove"
    fi
else
    log_error "Test 2 failed: safe_remove returned error" "test_safe_remove"
fi

# Test 3: Test removing some content lines but not others
log_info "Test 3: Removing some content lines but not others" "test_safe_remove"
test_file="$TEST_DIR/test3.txt"
initial_content="Initial content\n# Test Title\nThis is test content 1\nThis is test content 2\nThis should stay\nOther content"
create_test_file "$test_file" "$initial_content"

title_line="# Test Title"
content_line1="This is test content 1"

# Remove only one line, title line should remain
if safe_remove "Test 3" "$test_file" "$title_line" "$content_line1"; then
    expected_content="Initial content\n# Test Title\nThis is test content 2\nThis should stay\nOther content"
    if verify_file_content "$test_file" "$expected_content"; then
        log_info "Test 3 passed: Only specified content removed" "test_safe_remove"
    else
        log_error "Test 3 failed: Content not removed correctly" "test_safe_remove"
    fi
else
    log_error "Test 3 failed: safe_remove returned error" "test_safe_remove"
fi

# Test 4: Test removing content from a file that doesn't have that content
log_info "Test 4: Removing content from a file that doesn't have that content" "test_safe_remove"
test_file="$TEST_DIR/test4.txt"
initial_content="Initial content\n# Other Title\nThis is other content\nMore content"
create_test_file "$test_file" "$initial_content"

title_line="# Test Title"
content_line="This is test content"

# Shouldn't make any changes
if safe_remove "Test 4" "$test_file" "$title_line" "$content_line"; then
    expected_content="Initial content\n# Other Title\nThis is other content\nMore content"
    if verify_file_content "$test_file" "$expected_content"; then
        log_info "Test 4 passed: No changes when content doesn't exist" "test_safe_remove"
    else
        log_error "Test 4 failed: File was modified when it shouldn't be" "test_safe_remove"
    fi
else
    log_error "Test 4 failed: safe_remove returned error" "test_safe_remove"
fi

# Test 5: Test removing content from a non-existent file
log_info "Test 5: Removing content from a non-existent file" "test_safe_remove"
test_file="$TEST_DIR/nonexistent.txt"

title_line="# Test Title"
content_line="This is test content"

# Should return success but not create the file
if safe_remove "Test 5" "$test_file" "$title_line" "$content_line"; then
    if [ ! -f "$test_file" ]; then
        log_info "Test 5 passed: No file created" "test_safe_remove"
    else
        log_error "Test 5 failed: File was created when it shouldn't be" "test_safe_remove"
    fi
else
    log_error "Test 5 failed: safe_remove returned error" "test_safe_remove"
fi

# Test 6: Test removing content with multiple title lines (only remove after correct title)
log_info "Test 6: Test removing content with multiple title lines" "test_safe_remove"
test_file="$TEST_DIR/test6.txt"
initial_content="Initial content\n# Title 1\nContent for title 1\n# Title 2\nContent for title 2\nThis is test content\n# Title 3\nContent for title 3"
create_test_file "$test_file" "$initial_content"

title_line="# Title 2"
content_line="This is test content"

if safe_remove "Test 6" "$test_file" "$title_line" "$content_line"; then
    expected_content="Initial content\n# Title 1\nContent for title 1\n# Title 2\nContent for title 2\n# Title 3\nContent for title 3"
    if verify_file_content "$test_file" "$expected_content"; then
        log_info "Test 6 passed: Only removed content after correct title" "test_safe_remove"
    else
        log_error "Test 6 failed: Content not removed correctly" "test_safe_remove"
    fi
else
    log_error "Test 6 failed: safe_remove returned error" "test_safe_remove"
fi

# Test 7: Test removing content where title line is the last line
log_info "Test 7: Test removing content where title line is at the end of file" "test_safe_remove"
test_file="$TEST_DIR/test7.txt"
initial_content="Initial content\n# Title"
create_test_file "$test_file" "$initial_content"

title_line="# Title"

# Should remove the title line since it's at the end
if safe_remove "Test 7" "$test_file" "$title_line"; then
    expected_content="Initial content"
    if verify_file_content "$test_file" "$expected_content"; then
        log_info "Test 7 passed: Title line at end of file removed" "test_safe_remove"
    else
        log_error "Test 7 failed: Title line not removed" "test_safe_remove"
    fi
else
    log_error "Test 7 failed: safe_remove returned error" "test_safe_remove"
fi

# Test 8: Test removing content with a title line followed by another title
log_info "Test 8: Test removing content with a title line followed by another title" "test_safe_remove"
test_file="$TEST_DIR/test8.txt"
initial_content="Initial content\n# Title 1\n# Title 2\nContent for title 2"
create_test_file "$test_file" "$initial_content"

title_line="# Title 1"

# Should remove the title line since it's followed by another title
if safe_remove "Test 8" "$test_file" "$title_line"; then
    expected_content="Initial content\n# Title 2\nContent for title 2"
    if verify_file_content "$test_file" "$expected_content"; then
        log_info "Test 8 passed: Empty title section removed" "test_safe_remove"
    else
        log_error "Test 8 failed: Empty title section not removed" "test_safe_remove"
    fi
else
    log_error "Test 8 failed: safe_remove returned error" "test_safe_remove"
fi

# Test 9: Comprehensive test - Insert content then remove it to verify complete undo
log_info "Test 9: Comprehensive test - Verify safe_remove completely undoes safe_insert" "test_safe_remove"
test_file="$TEST_DIR/test9.txt"

# Start with a complex file with multiple sections
initial_content="# Section 1\nThis is section 1 content\n\n# Section 2\nThis is section 2 content\nMore section 2 content\n\n# Section 3\nThis is section 3 content"
create_test_file "$test_file" "$initial_content"

# Save original content for later comparison
original_content=$(cat "$test_file")

# Add a complex section with multiple lines
title_line="# Test Section"
content_line1="This is test content line 1"
content_line2="This is test content line 2"
content_line3="This is test content line 3 with special chars: !@#$%^&*()"

# Insert content using safe_insert
if safe_insert "Test 9 Insert" "$test_file" "$title_line" "$content_line1" "$content_line2" "$content_line3"; then
    log_info "Test 9: Content inserted successfully" "test_safe_remove"
    
    # Now remove the content we just added using safe_remove
    if safe_remove "Test 9 Remove" "$test_file" "$title_line" "$content_line1" "$content_line2" "$content_line3"; then
        log_info "Test 9: Content removed successfully" "test_safe_remove"
        
        # Verify the file is exactly back to its original state
        current_content=$(cat "$test_file")
        if [ "$current_content" = "$original_content" ]; then
            log_info "Test 9 passed: safe_remove completely undid safe_insert changes" "test_safe_remove"
        else
            log_error "Test 9 failed: File not restored to original state" "test_safe_remove"
            echo "Original content:"
            echo "$original_content"
            echo "Current content:"
            echo "$current_content"
        fi
    else
        log_error "Test 9 failed: safe_remove returned error" "test_safe_remove"
    fi
else
    log_error "Test 9 failed: safe_insert returned error" "test_safe_remove"
fi

# Test 10: Edge case - Add content to an empty file then remove it
log_info "Test 10: Edge case - Add content to empty file then remove it" "test_safe_remove"
test_file="$TEST_DIR/test10.txt"

# Start with an empty file
create_test_file "$test_file" ""

# Add content
title_line="# Empty File Test"
content_line1="This is content in a previously empty file"
content_line2="Another line of content"

# Insert content
if safe_insert "Test 10 Insert" "$test_file" "$title_line" "$content_line1" "$content_line2"; then
    log_info "Test 10: Content inserted into empty file" "test_safe_remove"
    
    # Remove the content
    if safe_remove "Test 10 Remove" "$test_file" "$title_line" "$content_line1" "$content_line2"; then
        log_info "Test 10: Content removed" "test_safe_remove"
        
        # Verify the file is empty or contains only whitespace
        file_content=$(cat "$test_file" | tr -d '\n\r\t ')
        if [ -z "$file_content" ]; then
            log_info "Test 10 passed: File is effectively empty (may contain whitespace)" "test_safe_remove"
        else
            log_error "Test 10 failed: File should be empty but contains content" "test_safe_remove"
            echo "File content:"
            cat -A "$test_file"  # Show all characters including invisible ones
        fi
    else
        log_error "Test 10 failed: safe_remove returned error" "test_safe_remove"
    fi
else
    log_error "Test 10 failed: safe_insert returned error" "test_safe_remove"
fi

# Restore manual confirmation mode
set_global_var "confirm_all" "false"

log_info "All tests completed for safe_remove" "test_safe_remove"

# Clean up
rm -rf "$TEST_DIR"
log_info "Test cleanup completed" "test_safe_remove"