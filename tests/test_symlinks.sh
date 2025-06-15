#!/bin/bash

# Test script for symlinks module

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Source required files
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"
source "$PROJECT_ROOT/src/modules/symlinks.sh"

# Enable debug mode for testing
set_log_level "DEBUG"

# Test counter
test_count=0
passed_count=0

# Function to report test results
report_result() {
    local result=$1
    local description="$2"
    
    ((test_count++))
    
    if [ $result -eq 0 ]; then
        echo "✓ Test $test_count PASSED: $description"
        ((passed_count++))
    else
        echo "✗ Test $test_count FAILED: $description"
    fi
}

echo "Starting symlinks module tests..."
echo "================================"

# Test 1: Help message
echo -e "\n1. Testing help message:"
symlinks_main --help > /dev/null 2>&1
report_result $? "Help message displays without errors"

# Test 2: List available symlinks
echo -e "\n2. Testing available symlinks:"
available_symlinks=$(global_vars symlinks)
if [[ -n "$available_symlinks" ]]; then
    echo "Available symlinks: $available_symlinks"
    report_result 0 "Global symlinks configuration found"
else
    report_result 1 "No symlinks configured in globals.sh"
fi

# Test 3: Example configuration generation
echo -e "\n3. Testing example configuration generation:"
example_config=$(symlinks_generate_example_config)
if [[ "$example_config" == *"SYMLINK_SOURCE"* ]] && [[ "$example_config" == *"SYMLINK_TARGET"* ]]; then
    report_result 0 "Example configuration generates expected content"
else
    report_result 1 "Example configuration does not contain expected content"
fi

# Test 4: Test creating symlinks with --only (dry run check)
echo -e "\n4. Testing selective symlink creation (argument parsing):"
# We'll test this by checking if the function accepts the arguments without creating actual links
# This is a safe test that won't modify the system

# Create a temporary test environment
TEST_DIR="/tmp/symlinks_test_$$"
mkdir -p "$TEST_DIR/source"
mkdir -p "$TEST_DIR/target"

# Create a test source file
echo "test content" > "$TEST_DIR/source/test_config"

# Override the symlink arrays for testing
declare -A TEST_SYMLINK_SOURCE
declare -A TEST_SYMLINK_TARGET
TEST_SYMLINK_SOURCE[test_config]="$TEST_DIR/source/test_config"
TEST_SYMLINK_TARGET[test_config]="$TEST_DIR/target/test_config"

# Temporarily replace the global arrays
backup_source=("${SYMLINK_SOURCE[@]}")
backup_target=("${SYMLINK_TARGET[@]}")
SYMLINK_SOURCE=()
SYMLINK_TARGET=()
for key in "${!TEST_SYMLINK_SOURCE[@]}"; do
    SYMLINK_SOURCE[$key]="${TEST_SYMLINK_SOURCE[$key]}"
    SYMLINK_TARGET[$key]="${TEST_SYMLINK_TARGET[$key]}"
done

# Test creating the test symlink
symlinks_create_single "test_config" "false"
result=$?

if [[ $result -eq 0 ]] && [[ -L "$TEST_DIR/target/test_config" ]]; then
    report_result 0 "Single symlink creation works"
    
    # Test removing the symlink
    symlinks_remove_single "test_config"
    if [[ ! -L "$TEST_DIR/target/test_config" ]]; then
        report_result 0 "Single symlink removal works"
    else
        report_result 1 "Single symlink removal failed"
    fi
else
    report_result 1 "Single symlink creation failed"
fi

# Restore original arrays
SYMLINK_SOURCE=()
SYMLINK_TARGET=()
for key in "${!backup_source[@]}"; do
    SYMLINK_SOURCE[$key]="${backup_source[$key]}"
    SYMLINK_TARGET[$key]="${backup_target[$key]}"
done

# Cleanup test directory
rm -rf "$TEST_DIR"

# Test 5: Test module context preservation
echo -e "\n5. Testing module context preservation:"
old_module_name="$MODULE_NAME"
symlinks_main --help > /dev/null 2>&1
if [[ "$MODULE_NAME" == "$old_module_name" ]]; then
    report_result 0 "Module context is properly preserved"
else
    report_result 1 "Module context was not restored properly"
fi

# Test 6: Test argument parsing
echo -e "\n6. Testing argument parsing (error handling):"
output=$(symlinks_main invalid_command 2>&1)
result=$?
if [[ $result -ne 0 ]]; then
    report_result 0 "Invalid command properly rejected"
else
    report_result 1 "Invalid command should have been rejected"
fi

# Test 7: Test wildcard symlink creation
echo -e "\n7. Testing wildcard symlink creation:"
# Create a test environment that simulates the Thunderbird structure
WILDCARD_TEST_DIR="/tmp/wildcard_symlinks_test_$$"
mkdir -p "$WILDCARD_TEST_DIR/source"
mkdir -p "$WILDCARD_TEST_DIR/.thunderbird/profile1/ImapMail/account1"
mkdir -p "$WILDCARD_TEST_DIR/.thunderbird/profile2/ImapMail/account2"

# Create a test source file
echo "filter rules content" > "$WILDCARD_TEST_DIR/source/msgFilterRules.dat"

# Set up test arrays for wildcard testing
declare -A WILDCARD_SYMLINK_SOURCE
declare -A WILDCARD_SYMLINK_TARGET
WILDCARD_SYMLINK_SOURCE[wildcard_test]="$WILDCARD_TEST_DIR/source/msgFilterRules.dat"
WILDCARD_SYMLINK_TARGET[wildcard_test]="$WILDCARD_TEST_DIR/.thunderbird/*/ImapMail/*/msgFilterRules.dat"

# Backup current arrays
backup_source=("${SYMLINK_SOURCE[@]}")
backup_target=("${SYMLINK_TARGET[@]}")
SYMLINK_SOURCE=()
SYMLINK_TARGET=()
SYMLINK_SOURCE[wildcard_test]="${WILDCARD_SYMLINK_SOURCE[wildcard_test]}"
SYMLINK_TARGET[wildcard_test]="${WILDCARD_SYMLINK_TARGET[wildcard_test]}"

# Create placeholder files to make the directories match the glob pattern
touch "$WILDCARD_TEST_DIR/.thunderbird/profile1/ImapMail/account1/placeholder"
touch "$WILDCARD_TEST_DIR/.thunderbird/profile2/ImapMail/account2/placeholder"

# Verify the glob pattern matches
echo "  Testing glob pattern: $WILDCARD_TEST_DIR/.thunderbird/*/ImapMail/*/"
ls -d $WILDCARD_TEST_DIR/.thunderbird/*/ImapMail/*/ 2>/dev/null || echo "  No matches found for glob pattern"

# Test wildcard symlink creation
symlinks_create_single "wildcard_test" "false"
result=$?

# Check if symlinks were created in all matching locations
success=true
expected_links=(
    "$WILDCARD_TEST_DIR/.thunderbird/profile1/ImapMail/account1/msgFilterRules.dat"
    "$WILDCARD_TEST_DIR/.thunderbird/profile2/ImapMail/account2/msgFilterRules.dat"
)

for link in "${expected_links[@]}"; do
    if [[ ! -L "$link" ]]; then
        success=false
        echo "  Missing symlink: $link"
    else
        echo "  ✓ Created symlink: $link"
        # Verify it points to the correct source
        link_target=$(readlink "$link")
        if [[ "$link_target" == "$WILDCARD_TEST_DIR/source/msgFilterRules.dat" ]]; then
            echo "    Points to correct source: $link_target"
        else
            echo "    ERROR: Points to wrong source: $link_target"
            success=false
        fi
    fi
done

if [[ $result -eq 0 ]] && [[ "$success" == true ]]; then
    report_result 0 "Wildcard symlink creation works for multiple targets"
    
    # Test wildcard symlink removal
    symlinks_remove_single "wildcard_test"
    remove_success=true
    for link in "${expected_links[@]}"; do
        if [[ -L "$link" ]]; then
            remove_success=false
        fi
    done
    
    if [[ "$remove_success" == true ]]; then
        report_result 0 "Wildcard symlink removal works for multiple targets"
    else
        report_result 1 "Wildcard symlink removal failed"
    fi
else
    report_result 1 "Wildcard symlink creation failed"
fi

# Restore original arrays
SYMLINK_SOURCE=()
SYMLINK_TARGET=()
for key in "${!backup_source[@]}"; do
    SYMLINK_SOURCE[$key]="${backup_source[$key]}"
    SYMLINK_TARGET[$key]="${backup_target[$key]}"
done

# Cleanup wildcard test directory
rm -rf "$WILDCARD_TEST_DIR"

# Test 8: Test global variables function
echo -e "\n8. Testing global variables function:"
symlinks_from_globals=$(global_vars symlinks)
if [[ -n "$symlinks_from_globals" ]]; then
    report_result 0 "Global vars function returns symlinks list"
else
    report_result 1 "Global vars function failed to return symlinks"
fi

echo -e "\n================================"
echo "Test Summary:"
echo "Total tests: $test_count"
echo "Passed: $passed_count"
echo "Failed: $((test_count - passed_count))"

if [ $passed_count -eq $test_count ]; then
    echo -e "\n🎉 All tests passed!"
    exit 0
else
    echo -e "\n❌ Some tests failed."
    exit 1
fi