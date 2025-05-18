#!/bin/bash

# Test script for the CLI parser module
# Tests the functionality of the CLI parser and command dispatching

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/cli/parser.sh"

# Set DEBUG log level
set_log_level "DEBUG"

# Module name for testing
TEST_MODULE="cli_parser_test"

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

# Cleanup function to ensure we don't leave test artifacts
cleanup() {
    echo -e "\n🧹 Cleaning up test environment..."
    
    # Unset any global variables set during testing
    unset REGISTERED_COMMANDS
    unset COMMAND_DESCRIPTIONS
    unset MODULE_PATHS
    
    # Remove any temporary files
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    
    echo "Cleanup complete"
}

# Run cleanup if script is interrupted
trap 'cleanup' EXIT INT TERM

# Create a temporary directory for test modules
TEST_DIR=$(mktemp -d /tmp/cli_parser_test_XXXXXX)
TEST_MODULES_DIR="$TEST_DIR/modules"
mkdir -p "$TEST_MODULES_DIR"

# Define a success counter for summary
tests_passed=0
tests_total=0

# Function to increment test counts
increment_tests() {
    local result=$1
    ((tests_total++))
    if [ $result -eq 0 ]; then
        ((tests_passed++))
    fi
}

# Function to create a sample module file for testing
create_test_module() {
    local module_name="$1"
    local module_file="$TEST_MODULES_DIR/${module_name}.sh"
    
    cat > "$module_file" << EOF
#!/bin/bash

# Test module for CLI parser testing
MODULE_NAME="$module_name"
MODULE_DESCRIPTION="Test module for CLI parser"
MODULE_VERSION="1.0.0"

# Sample function
${module_name}_main() {
    echo "${module_name}_main called with args: \$@"
    
    # Check for help flag
    if [[ "\$1" == "--help" || "\$1" == "-h" ]]; then
        echo "Usage: ${module_name}_main [options]"
        echo "Options:"
        echo "  --param1 VALUE    Set parameter 1"
        echo "  --param2 VALUE    Set parameter 2"
        echo "  --flag            Enable flag"
        echo "  --help, -h        Show this help message"
        return 0
    fi
    
    # Process other arguments
    while [[ \$# -gt 0 ]]; do
        case "\$1" in
            --param1)
                echo "Parameter 1 set to: \$2"
                shift 2
                ;;
            --param2)
                echo "Parameter 2 set to: \$2"
                shift 2
                ;;
            --flag)
                echo "Flag enabled"
                shift
                ;;
            *)
                echo "Unknown argument: \$1"
                return 1
                ;;
        esac
    done
    
    return 0
}

# Sample subcommand function
${module_name}_main_subcommand() {
    echo "${module_name}_main_subcommand called with args: \$@"
    return 0
}

# Export the functions
export -f ${module_name}_main
export -f ${module_name}_main_subcommand

# Define commands
MODULE_COMMANDS=(
    "${module_name}_main:Main command for $module_name module"
    "${module_name}_main subcommand:Subcommand for $module_name module"
)
export MODULE_COMMANDS
EOF

    chmod +x "$module_file"
    echo "$module_file"
}

# Main test sequence
echo "🔍 Enhanced CLI Parser Test Suite"
echo ""

# Test 1: Module Discovery
print_header "Module Discovery with Real Modules"

# Create test modules
module1_file=$(create_test_module "test_module1")
module2_file=$(create_test_module "test_module2")

# Test if modules are discovered correctly with custom path
discover_modules "$TEST_MODULES_DIR"
result=$?

if [ $result -eq 0 ] && [ ${#REGISTERED_COMMANDS[@]} -ge 4 ]; then
    report_result 0 "Module discovery found ${#REGISTERED_COMMANDS[@]} commands from test modules"
else
    report_result 1 "Module discovery failed or found unexpected number of commands: ${#REGISTERED_COMMANDS[@]}"
fi
increment_tests $?

# Test 2: Command Registration with Subcommands
print_header "Command Registration with Subcommands"

# Check if both main commands and subcommands are registered
has_main1=$([ -n "${REGISTERED_COMMANDS[test_module1_main]}" ] && echo "yes" || echo "no")
has_main2=$([ -n "${REGISTERED_COMMANDS[test_module2_main]}" ] && echo "yes" || echo "no")
has_sub1=$([ -n "${REGISTERED_COMMANDS[test_module1_main subcommand]}" ] && echo "yes" || echo "no")
has_sub2=$([ -n "${REGISTERED_COMMANDS[test_module2_main subcommand]}" ] && echo "yes" || echo "no")

if [ "$has_main1" = "yes" ] && [ "$has_main2" = "yes" ] && 
   [ "$has_sub1" = "yes" ] && [ "$has_sub2" = "yes" ]; then
    report_result 0 "All main commands and subcommands registered correctly"
else
    report_result 1 "Failed to register all commands: main1=$has_main1, main2=$has_main2, sub1=$has_sub1, sub2=$has_sub2"
fi
increment_tests $?

# Test 3: Command Metadata
print_header "Command Metadata Verification"

# Check if commands have proper descriptions
all_have_descriptions=true
missing_descriptions=()

for cmd in "${!REGISTERED_COMMANDS[@]}"; do
    if [ -z "${COMMAND_DESCRIPTIONS[$cmd]}" ]; then
        all_have_descriptions=false
        missing_descriptions+=("$cmd")
    fi
done

if $all_have_descriptions; then
    report_result 0 "All commands have descriptions"
else
    report_result 1 "Missing descriptions for commands: ${missing_descriptions[*]}"
fi
increment_tests $?

# Test 4: Module Paths
print_header "Module Paths Verification"

# Check if all commands have correct module paths
all_have_paths=true
wrong_paths=()

for cmd in "${!REGISTERED_COMMANDS[@]}"; do
    module_path="${MODULE_PATHS[$cmd]}"
    if [ -z "$module_path" ] || [ ! -f "$module_path" ]; then
        all_have_paths=false
        wrong_paths+=("$cmd: $module_path")
    fi
done

if $all_have_paths; then
    report_result 0 "All commands have valid module paths"
else
    report_result 1 "Invalid paths for commands: ${wrong_paths[*]}"
fi
increment_tests $?

# Test 5: Help Message Generation
print_header "Help Message Generation"

# Test if help message is generated correctly
help_output=$(print_help)
result=$?

if [[ "$help_output" == *"Available commands"* ]] && 
   [[ "$help_output" == *"test_module1"* ]] && 
   [[ "$help_output" == *"test_module2"* ]]; then
    report_result 0 "General help message generation"
else
    report_result 1 "General help message generation failed or missing expected content"
fi
increment_tests $?

# Test 6: Command-Specific Help
print_header "Command-Specific Help"

# Test for a main command
test_module1_help=$(print_help "test_module1_main")
if [[ "$test_module1_help" == *"Command: test_module1_main"* ]] && 
   [[ "$test_module1_help" == *"Description:"* ]]; then
    report_result 0 "Main command help message"
else
    report_result 1 "Main command help message failed"
fi
increment_tests $?

# Test for a subcommand
test_module1_sub_help=$(print_help "test_module1_main subcommand")
if [[ "$test_module1_sub_help" == *"Command: test_module1_main subcommand"* ]] && 
   [[ "$test_module1_sub_help" == *"Description:"* ]]; then
    report_result 0 "Subcommand help message"
else
    report_result 1 "Subcommand help message failed"
fi
increment_tests $?

# Test 7: Global Options Parsing
print_header "Global Options Parsing"

# Test different combinations of global options
debug_output=$(parse_args --debug test_module1_main --param1 value1 2>&1)
debug_code=$?

quiet_output=$(parse_args --quiet test_module1_main --param1 value1 2>&1)
quiet_code=$?

yes_output=$(parse_args --yes test_module1_main --param1 value1 2>&1)
yes_code=$?

multi_opts=$(parse_args --debug --yes --quiet test_module1_main --param1 value1 2>&1)
multi_code=$?

if [ $debug_code -eq 0 ] && [[ "$debug_output" == *"Parameter 1 set to: value1"* ]]; then
    report_result 0 "Debug option parsing"
else
    report_result 1 "Debug option parsing failed"
fi
increment_tests $?

if [ $quiet_code -eq 0 ] && [[ "$quiet_output" == *"Parameter 1 set to: value1"* ]]; then
    report_result 0 "Quiet option parsing"
else
    report_result 1 "Quiet option parsing failed"
fi
increment_tests $?

if [ $yes_code -eq 0 ] && [[ "$yes_output" == *"Parameter 1 set to: value1"* ]]; then
    report_result 0 "Yes option parsing"
else
    report_result 1 "Yes option parsing failed"
fi
increment_tests $?

if [ $multi_code -eq 0 ] && [[ "$multi_opts" == *"Parameter 1 set to: value1"* ]]; then
    report_result 0 "Multiple global options parsing"
else
    report_result 1 "Multiple global options parsing failed"
fi
increment_tests $?

# Test 8: Command Execution
print_header "Command Execution"

# Test executing a main command
main_cmd_output=$(parse_args test_module1_main --param1 value1 --param2 value2 2>&1)
main_cmd_code=$?

if [ $main_cmd_code -eq 0 ] && 
   [[ "$main_cmd_output" == *"Parameter 1 set to: value1"* ]] && 
   [[ "$main_cmd_output" == *"Parameter 2 set to: value2"* ]]; then
    report_result 0 "Main command execution with parameters"
else
    report_result 1 "Main command execution failed"
fi
increment_tests $?

# Test executing a main command with flag
flag_cmd_output=$(parse_args test_module1_main --flag 2>&1)
flag_cmd_code=$?

if [ $flag_cmd_code -eq 0 ] && [[ "$flag_cmd_output" == *"Flag enabled"* ]]; then
    report_result 0 "Command execution with flag"
else
    report_result 1 "Command execution with flag failed"
fi
increment_tests $?

# Test executing a subcommand
subcmd_output=$(parse_args "test_module1_main subcommand" 2>&1)
subcmd_code=$?

if [ $subcmd_code -eq 0 ] && [[ "$subcmd_output" == *"test_module1_main_subcommand called with args"* ]]; then
    report_result 0 "Subcommand execution"
else
    report_result 1 "Subcommand execution failed"
fi
increment_tests $?

# Test 9: Command Help Execution
print_header "Command Help Execution"

# Test command-specific help
cmd_help_output=$(parse_args test_module1_main --help 2>&1)
cmd_help_code=$?

if [ $cmd_help_code -eq 0 ] && 
   [[ "$cmd_help_output" == *"Usage: test_module1_main"* ]] && 
   [[ "$cmd_help_output" == *"Options:"* ]]; then
    report_result 0 "Command help execution"
else
    report_result 1 "Command help execution failed"
fi
increment_tests $?

# Test 10: Error Handling
print_header "Error Handling"

# Test with invalid command
invalid_cmd=$(parse_args nonexistent_command 2>&1)
invalid_cmd_code=$?

if [ $invalid_cmd_code -ne 0 ] && [[ "$invalid_cmd" == *"Unknown command"* ]]; then
    report_result 0 "Invalid command rejection"
else
    report_result 1 "Invalid command was accepted"
fi
increment_tests $?

# Test with missing command
missing_cmd=$(parse_args --debug 2>&1)
missing_cmd_code=$?

if [ $missing_cmd_code -ne 0 ] && [[ "$missing_cmd" == *"No command specified"* ]]; then
    report_result 0 "Missing command detection"
else
    report_result 1 "Missing command was accepted"
fi
increment_tests $?

# Test with invalid option to a valid command
invalid_opt=$(parse_args test_module1_main --invalid-option 2>&1)
invalid_opt_code=$?

if [ $invalid_opt_code -ne 0 ] && [[ "$invalid_opt" == *"Unknown argument"* ]]; then
    report_result 0 "Invalid option rejection"
else
    report_result 1 "Invalid option was accepted"
fi
increment_tests $?

# Test 11: Edge Cases
print_header "Edge Cases"

# Test with command name collision
# Create a function with the same name as one of our commands
test_module1_main() {
    echo "Overridden function called with args: $@"
    return 42
}
export -f test_module1_main

# Try to execute the command via the parser
collision_output=$(parse_args test_module1_main 2>&1)
collision_code=$?

# Check if the original function was called (from the module) not our override
if [ $collision_code -eq 0 ] && [[ "$collision_output" != *"Overridden function called"* ]]; then
    report_result 0 "Command name collision handling"
else
    report_result 1 "Command name collision not properly handled"
fi
increment_tests $?

# Unset our override
unset -f test_module1_main

# Test with empty MODULE_COMMANDS array
# Create a test module with no commands
empty_module_file="$TEST_MODULES_DIR/empty_module.sh"
cat > "$empty_module_file" << EOF
#!/bin/bash
MODULE_NAME="empty_module"
MODULE_DESCRIPTION="Module with no commands"
# Empty MODULE_COMMANDS array
MODULE_COMMANDS=()
export MODULE_COMMANDS
EOF
chmod +x "$empty_module_file"

# Test discovery with the empty module
old_command_count=${#REGISTERED_COMMANDS[@]}
discover_modules "$TEST_MODULES_DIR"
new_command_count=${#REGISTERED_COMMANDS[@]}

# Command count should not decrease (might increase if we re-registered other commands)
if [ $new_command_count -ge $old_command_count ]; then
    report_result 0 "Empty module commands handling"
else
    report_result 1 "Empty module affected existing commands"
fi
increment_tests $?

# Test 12: Non-existent Module Directory
print_header "Non-existent Module Directory"

# Test discovery with a non-existent directory
nonexist_dir="$TEST_DIR/nonexistent_dir"
discover_modules "$nonexist_dir" >/dev/null 2>&1
nonexist_code=$?

if [ $nonexist_code -ne 0 ]; then
    report_result 0 "Non-existent module directory handling"
else
    report_result 1 "Non-existent module directory should have failed"
fi
increment_tests $?

# Test 13: Multiple Command Parsing
print_header "Multiple Command Parsing"

# Test the ability to execute multiple commands in a single invocation
# We'll monitor the debug logs to verify that both commands are executed

# Reset the log level to ensure we capture debug messages
set_log_level "DEBUG"

# Execute two commands in a single command line
multiple_cmd_output=$(parse_args test_module1_main --param1 value1 test_module2_main --param2 value2 2>&1)
multiple_cmd_code=$?

# Check if both commands were executed by looking for their outputs in the log
if [[ "$multiple_cmd_output" == *"Parameter 1 set to: value1"* ]] && 
   [[ "$multiple_cmd_output" == *"Parameter 2 set to: value2"* ]]; then
    report_result 0 "Multiple command parsing works correctly"
else
    report_result 1 "Multiple command parsing failed"
    echo "Output: $multiple_cmd_output"
fi
increment_tests $?

# Output summary
print_header "Test Summary"
echo "Tests passed: $tests_passed / $tests_total"

if [ $tests_passed -eq $tests_total ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi