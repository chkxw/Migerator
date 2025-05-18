#!/bin/bash

# Sudo implementation for the setup script
# This addresses the issues mentioned in Review 3 from CLAUDE.MD

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/utils.sh"

log_debug "Loading Sudo implementation" "sudo"

# Function to execute a command with sudo privileges while preserving environment variables
# Usage: Sudo command_or_function [args...]
# Returns: The exit code of the command
Sudo() {
    local firstArg="$1"
    log_debug "Sudo executing: $firstArg ${*:2}" "sudo"
    
    # Check if the script is already running as root
    if [ "$(id -u)" -eq 0 ]; then
        log_debug "Already running as root, executing directly" "sudo"
        "$@"
        return $?
    fi
    
    # Check if the first argument is a function
    if [[ $(type -t "$firstArg") == "function" ]]; then
        log_debug "Executing function with sudo: $firstArg" "sudo"
        shift # Remove the first argument
        local params=("$@") # Capture all remaining arguments in an array
        
        # Create a temporary file to store function definitions and environment variables
        local tmpfile=$(mktemp)
        log_debug "Created temporary file for function definitions: $tmpfile" "sudo"
        
        # Save all environment variables to the file
        declare -px > "$tmpfile"
        
        # Save all function definitions to the file
        declare -f >> "$tmpfile"
        
        # Add the command to execute
        echo "$firstArg" "${params[@]@Q}" >> "$tmpfile"
        
        # Execute the command with sudo, preserving environment variables
        command sudo -E bash "$tmpfile"
        local result=$?
        
        # Clean up
        rm "$tmpfile"
        log_debug "Removed temporary file: $tmpfile" "sudo"
        
        return $result
    elif [[ $(type -t "$firstArg") == "alias" ]]; then
        log_debug "Executing alias with sudo: $firstArg" "sudo"
        # Handle alias execution
        alias sudo='\sudo '
        eval "sudo $*"
        return $?
    else
        log_debug "Executing command with sudo: $firstArg" "sudo"
        # Regular command execution with environment preservation
        command sudo -E "$@"
        return $?
    fi
}

# Export function for use in other scripts
export -f Sudo

log_debug "Sudo implementation loaded" "sudo"