#!/bin/bash

# CLI Parser for the Ubuntu Setup Script
# Handles command-line argument parsing and command dispatching

# Source the required dependencies if not already sourced
if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
    source "$PROJECT_ROOT/src/core/logger.sh"
    source "$PROJECT_ROOT/src/core/utils.sh"
    source "$PROJECT_ROOT/src/core/globals.sh"
fi

# CLI parser information
MODULE_NAME="cli_parser"
MODULE_DESCRIPTION="CLI parser and command dispatcher"
MODULE_VERSION="1.0.0"

log_debug "Loading CLI parser module" "$MODULE_NAME"

# Associative arrays to store command information
declare -A REGISTERED_COMMANDS
declare -A COMMAND_DESCRIPTIONS
declare -A MODULE_PATHS

# Function to discover and load modules
# Usage: discover_modules [modules_dir]
# Returns: 0 on success, 1 on failure
discover_modules() {
    local modules_dir="${1:-$PROJECT_ROOT/src/modules}"
    
    log_debug "Discovering modules in: $modules_dir" "$MODULE_NAME"
    
    # Check if modules directory exists
    if [ ! -d "$modules_dir" ]; then
        log_error "Modules directory not found: $modules_dir" "$MODULE_NAME"
        return 1
    fi
    
    # Loop through each module in the directory
    local module_count=0
    local command_count=0
    
    for module_file in "$modules_dir"/*.sh; do
        if [ -f "$module_file" ]; then
            local module_name=$(basename "$module_file" .sh)
            
            log_debug "Loading module: $module_name" "$MODULE_NAME"
            
            # Source the module to access its functionality
            source "$module_file"
            
            # Check if module has exported MODULE_COMMANDS array
            local commands_var_name="MODULE_COMMANDS[@]"
            if [[ $(declare -p MODULE_COMMANDS 2>/dev/null) =~ "declare -a" ]]; then
                log_debug "Found MODULE_COMMANDS array in $module_name" "$MODULE_NAME"
                
                # Loop through each command in the module
                for command_info in "${MODULE_COMMANDS[@]}"; do
                    # Split by colon: "command:description"
                    local command_name=${command_info%%:*}
                    local command_description=${command_info#*:}
                    
                    log_debug "Registering command: $command_name" "$MODULE_NAME"
                    
                    # Store command information
                    REGISTERED_COMMANDS["$command_name"]="$command_name"
                    COMMAND_DESCRIPTIONS["$command_name"]="$command_description"
                    MODULE_PATHS["$command_name"]="$module_file"
                    
                    # If command has a space (e.g., "cmd subcommand"), also register the first part
                    if [[ "$command_name" == *" "* ]]; then
                        local main_cmd="${command_name%% *}"
                        log_debug "Also registering main command: $main_cmd" "$MODULE_NAME"
                        REGISTERED_COMMANDS["$main_cmd"]="$main_cmd"
                        if [ -z "${COMMAND_DESCRIPTIONS["$main_cmd"]}" ]; then
                            COMMAND_DESCRIPTIONS["$main_cmd"]="Parent command for ${command_name}"
                        fi
                        MODULE_PATHS["$main_cmd"]="$module_file"
                    fi
                    
                    ((command_count++))
                done
                
                ((module_count++))
            else
                log_warning "Module $module_name does not export MODULE_COMMANDS array" "$MODULE_NAME"
            fi
        fi
    done
    
    log_info "Discovered $module_count modules with $command_count commands" "$MODULE_NAME"
    
    if [ $module_count -eq 0 ]; then
        log_warning "No modules found in $modules_dir" "$MODULE_NAME"
        return 1
    fi
    
    return 0
}

# Function to print help message for all commands
# Usage: print_help [command]
# Returns: None
print_help() {
    local command="$1"
    
    if [ -n "$command" ] && [ -n "${REGISTERED_COMMANDS[$command]}" ]; then
        # Command-specific help
        echo "Command: $command"
        echo "Description: ${COMMAND_DESCRIPTIONS[$command]}"
        echo ""
        echo "To get detailed help for this command, run:"
        echo "  $0 $command --help"
    else
        # General help
        echo "Ubuntu Setup Script"
        echo "A systematic and modular setup script for Ubuntu systems"
        echo ""
        echo "Usage: $0 [global options] <command> [command options]"
        echo ""
        echo "Global options:"
        echo "  --debug            Enable debug logging"
        echo "  --quiet            Suppress all output except errors"
        echo "  --yes, -y          Automatically confirm all prompts"
        echo "  --help, -h         Display this help message"
        echo ""
        echo "Available commands:"
        
        # Sort commands alphabetically
        local sorted_commands=()
        for cmd in "${!REGISTERED_COMMANDS[@]}"; do
            sorted_commands+=("$cmd")
        done
        IFS=$'\n' sorted_commands=($(sort <<<"${sorted_commands[*]}"))
        unset IFS
        
        # Group commands by module
        local current_module=""
        for cmd in "${sorted_commands[@]}"; do
            local module_path="${MODULE_PATHS[$cmd]}"
            local module_basename=$(basename "$module_path")
            
            # If the module has changed, print the module name
            if [ "$module_basename" != "$current_module" ]; then
                current_module="$module_basename"
                echo ""
                echo "Module: ${current_module%.sh}"
                echo "--------------------------------------"
            fi
            
            # Print the command and description (formatted)
            printf "  %-20s %s\n" "$cmd" "${COMMAND_DESCRIPTIONS[$cmd]}"
        done
        
        echo ""
        echo "For detailed help on a specific command, run:"
        echo "  $0 <command> --help"
    fi
}

# Function to parse and execute a command
# Usage: parse_and_execute_command command [args...]
# Returns: Exit code from the command
parse_and_execute_command() {
    local command="$1"
    shift
    
    # Check if the command contains spaces, which indicates a subcommand
    if [[ "$command" == *" "* ]]; then
        # Extract the main command and subcommand
        local main_cmd="${command%% *}"
        local sub_cmd="${command#* }"
        
        # Call the main command with the subcommand and remaining arguments
        log_debug "Executing command with subcommand: $main_cmd $sub_cmd $*" "$MODULE_NAME"
        $main_cmd "$sub_cmd" "$@"
        return $?
    # Check if the command is registered
    elif [ -n "${REGISTERED_COMMANDS[$command]}" ]; then
        log_debug "Executing command: $command $*" "$MODULE_NAME"
        
        # Call the command with the remaining arguments
        $command "$@"
        return $?
    else
        log_error "Unknown command: $command" "$MODULE_NAME"
        print_help
        return 1
    fi
}

# Function to parse global options and execute commands
# Usage: parse_args [args...]
# Returns: Exit code from the last command or 1 on error
parse_args() {
    # Default global values
    local debug=false
    local quiet=false
    local yes=false
    local show_help=false
    local command=""
    
    # Convert arguments to array for easier processing
    local args=("$@")
    local i=0
    local args_count=${#args[@]}
    
    # Skip past global options
    while [ $i -lt $args_count ]; do
        case "${args[$i]}" in
            --debug)
                debug=true
                set_log_level "DEBUG"
                ((i++))
                ;;
            --quiet)
                quiet=true
                set_log_level "ERROR"
                ((i++))
                ;;
            --yes|-y)
                yes=true
                set_global_var "confirm_all" "true"
                ((i++))
                ;;
            --help|-h)
                show_help=true
                ((i++))
                ;;
            -*)
                log_error "Unknown option: ${args[$i]}" "$MODULE_NAME"
                print_help
                return 1
                ;;
            *)
                # Assume this is a command
                break
                ;;
        esac
    done
    
    # Number of global options processed
    local global_opts_count=$i
    
    # If only global options were provided, show help
    if [ $global_opts_count -eq $args_count ]; then
        if [ "$show_help" = "true" ]; then
            print_help
            return 0
        else
            log_error "No command specified" "$MODULE_NAME"
            print_help
            return 1
        fi
    fi
    
    # Find all commands in the arguments
    local cmd_positions=()
    
    # Start at the first non-global option
    while [ $i -lt $args_count ]; do
        local current="${args[$i]}"
        
        # Check if this argument is a registered command
        if [ -n "${REGISTERED_COMMANDS[$current]}" ]; then
            cmd_positions+=($i)
        fi
        
        ((i++))
    done
    
    # If no commands were found, treat the first non-global option as a command
    if [ ${#cmd_positions[@]} -eq 0 ]; then
        cmd_positions=($global_opts_count)
    fi
    
    # Add the end position as a sentinel
    cmd_positions+=(${#args[@]})
    
    # Execute each command separately
    local last_exit_code=0
    local prev_end=$global_opts_count
    
    for ((j=0; j<${#cmd_positions[@]}-1; j++)); do
        local cmd_start=${cmd_positions[$j]}
        local cmd_end=${cmd_positions[$j+1]}
        
        # Extract the command and its arguments
        command="${args[$cmd_start]}"
        local cmd_args=()
        
        # Add global options to each command
        for ((k=0; k<global_opts_count; k++)); do
            cmd_args+=("${args[$k]}")
        done
        
        # Add the command
        cmd_args+=("$command")
        
        # Add command arguments
        for ((k=cmd_start+1; k<cmd_end; k++)); do
            cmd_args+=("${args[$k]}")
        done
        
        if [ "$show_help" = "true" ]; then
            print_help "$command"
            last_exit_code=0
        else
            # Log what we're doing
            log_debug "Executing command: $command ${args[@]:cmd_start+1:cmd_end-cmd_start-1}" "$MODULE_NAME"
            
            # Execute the command with its arguments
            parse_and_execute_command "$command" "${args[@]:cmd_start+1:cmd_end-cmd_start-1}"
            last_exit_code=$?
        fi
    done
    
    return $last_exit_code
}

# Function to run the CLI
# Usage: run_cli [args...]
# Returns: Exit code from the command
run_cli() {
    log_debug "Running CLI with arguments: $*" "$MODULE_NAME"
    
    # Discover modules
    discover_modules
    
    if [ $? -ne 0 ]; then
        log_error "Failed to discover modules" "$MODULE_NAME"
        return 1
    fi
    
    # Parse arguments and execute commands
    parse_args "$@"
    return $?
}

# Export functions
export -f discover_modules
export -f print_help
export -f parse_and_execute_command
export -f parse_args
export -f run_cli

# Export variables
export REGISTERED_COMMANDS
export COMMAND_DESCRIPTIONS
export MODULE_PATHS

log_debug "CLI parser module loaded" "$MODULE_NAME"