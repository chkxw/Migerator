#!/bin/bash

# Level 2 abstraction: Symlinks module
# This module handles creating and managing symbolic links for configuration files

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"

# Log with hard-coded module name for initial loading
log_debug "Loading symlinks module" "symlinks"

# Function to generate example configuration for globals.sh
# Returns: example configuration as a string
symlinks_generate_example_config() {
    local content="
# Symlink Configuration
# Add these lines to your globals.sh file:

# Example configuration file
SYMLINK_SOURCE[myconfig]=\"/path/to/source/config\"
SYMLINK_TARGET[myconfig]=\"\$HOME/.myconfig\"

# Example system service
SYMLINK_SOURCE[myservice]=\"/path/to/source/service.service\"
SYMLINK_TARGET[myservice]=\"/etc/systemd/system/myservice.service\"
"
    
    echo "$content"
}

# Function to create a single symbolic link
# Args: $1 - symlink key, $2 - force (optional)
# Returns: 0 on success, 1 on failure, 2 if skipped
symlinks_create_single() {
    local symlink_key="$1"
    local force="${2:-false}"
    
    local source_path="${SYMLINK_SOURCE[$symlink_key]}"
    local target_path="${SYMLINK_TARGET[$symlink_key]}"
    
    if [[ -z "$source_path" ]] || [[ -z "$target_path" ]]; then
        log_error "Incomplete configuration for symlink: $symlink_key" "$MODULE_NAME"
        return 1
    fi
    
    # Expand variables in paths
    source_path=$(eval echo "$source_path")
    target_path=$(eval echo "$target_path")
    
    log_info "Processing symlink: $symlink_key ($source_path -> $target_path)" "$MODULE_NAME"
    
    # Check if source exists
    if [[ ! -e "$source_path" ]]; then
        log_error "Source file/directory does not exist: $source_path" "$MODULE_NAME"
        return 1
    fi
    
    # Handle wildcard targets (like Thunderbird paths)
    if [[ "$target_path" == *"*"* ]]; then
        # For wildcard paths, we need to handle directory patterns and filename patterns differently
        local dir_pattern=$(dirname "$target_path")
        local filename=$(basename "$target_path")
        
        # If the filename contains wildcards, expand directories and use original filename
        # If only directories contain wildcards, expand directories and append filename
        local expanded_dirs
        if [[ "$filename" == *"*"* ]]; then
            # Both directory and filename have wildcards - expand the full path
            expanded_dirs=$(ls -d $target_path 2>/dev/null || true)
        else
            # Only directory has wildcards - expand directory and append filename
            expanded_dirs=$(ls -d $dir_pattern 2>/dev/null || true)
            if [[ -n "$expanded_dirs" ]]; then
                local temp_targets=""
                for dir in $expanded_dirs; do
                    temp_targets="$temp_targets $dir/$filename"
                done
                expanded_dirs="$temp_targets"
            fi
        fi
        
        if [[ -z "$expanded_dirs" ]]; then
            log_warning "No matching directories found for wildcard target: $target_path" "$MODULE_NAME"
            return 2
        fi
        
        local success=0
        local failed=0
        for target in $expanded_dirs; do
            log_debug "Creating wildcard symlink: $target" "$MODULE_NAME"
            if symlinks_create_link_with_sudo "$source_path" "$target" "$force"; then
                ((success++))
            else
                ((failed++))
            fi
        done
        
        log_info "Wildcard symlink results: $success succeeded, $failed failed" "$MODULE_NAME"
        [[ $failed -eq 0 ]] && return 0 || return 1
    else
        # Single target
        symlinks_create_link_with_sudo "$source_path" "$target_path" "$force"
        return $?
    fi
}

# Helper function to create symlink with sudo if needed
# Args: $1 - source, $2 - target, $3 - force
# Returns: 0 on success, 1 on failure
symlinks_create_link_with_sudo() {
    local source_path="$1"
    local target_path="$2"
    local force="$3"
    
    # Check if target requires sudo (system paths)
    if [[ "$target_path" == /etc/* ]] || [[ "$target_path" == /usr/* ]] || [[ "$target_path" == /opt/* ]]; then
        log_debug "Creating system symlink with sudo: $target_path" "$MODULE_NAME"
        if [[ "$force" == "true" ]]; then
            Sudo create_symlink "$source_path" "$target_path" force
        else
            Sudo create_symlink "$source_path" "$target_path"
        fi
    else
        log_debug "Creating user symlink: $target_path" "$MODULE_NAME"
        if [[ "$force" == "true" ]]; then
            create_symlink "$source_path" "$target_path" force
        else
            create_symlink "$source_path" "$target_path"
        fi
    fi
}

# Function to remove a single symbolic link
# Args: $1 - symlink key
# Returns: 0 on success, 1 on failure
symlinks_remove_single() {
    local symlink_key="$1"
    
    local target_path="${SYMLINK_TARGET[$symlink_key]}"
    
    if [[ -z "$target_path" ]]; then
        log_error "No target configured for symlink: $symlink_key" "$MODULE_NAME"
        return 1
    fi
    
    log_debug "Removing symlink: $symlink_key with pattern: $target_path" "$MODULE_NAME"
    
    # Handle wildcard targets
    if [[ "$target_path" == *"*"* ]]; then
        # Expand variables in path for wildcard handling
        target_path=$(eval echo "$target_path")
        # Use the same logic as creation for wildcard expansion
        local dir_pattern=$(dirname "$target_path")
        local filename=$(basename "$target_path")
        
        local expanded_targets
        if [[ "$filename" == *"*"* ]]; then
            # Both directory and filename have wildcards - expand the full path
            expanded_targets=$(ls -d $target_path 2>/dev/null || true)
        else
            # Only directory has wildcards - find existing files that match the pattern
            expanded_targets=$(ls -d $target_path 2>/dev/null || true)
        fi
        
        if [[ -z "$expanded_targets" ]]; then
            log_debug "No matching paths found for wildcard target: $target_path" "$MODULE_NAME"
            return 0
        fi
        
        local success=0
        local failed=0
        for target in $expanded_targets; do
            log_debug "Removing wildcard symlink: $target" "$MODULE_NAME"
            if symlinks_remove_link_with_sudo "$target"; then
                ((success++))
            else
                ((failed++))
            fi
        done
        
        log_info "Wildcard symlink removal results: $success succeeded, $failed failed" "$MODULE_NAME"
        [[ $failed -eq 0 ]] && return 0 || return 1
    else
        # Single target - expand variables for non-wildcard paths
        target_path=$(eval echo "$target_path")
        symlinks_remove_link_with_sudo "$target_path"
        return $?
    fi
}

# Helper function to remove symlink with sudo if needed
# Args: $1 - target path
# Returns: 0 on success, 1 on failure
symlinks_remove_link_with_sudo() {
    local target_path="$1"
    
    if [[ ! -L "$target_path" ]]; then
        log_debug "Target is not a symlink, skipping: $target_path" "$MODULE_NAME"
        return 0
    fi
    
    # Check if target requires sudo (system paths)
    if [[ "$target_path" == /etc/* ]] || [[ "$target_path" == /usr/* ]] || [[ "$target_path" == /opt/* ]]; then
        log_debug "Removing system symlink with sudo: $target_path" "$MODULE_NAME"
        Sudo rm -f "$target_path"
    else
        log_debug "Removing user symlink: $target_path" "$MODULE_NAME"
        rm -f "$target_path"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_info "Successfully removed symlink: $target_path" "$MODULE_NAME"
        return 0
    else
        log_error "Failed to remove symlink: $target_path" "$MODULE_NAME"
        return 1
    fi
}

# Function to create symlinks from globals
# Args: $1 - force (optional), $2 - space-separated list of symlink keys (optional)
# Returns: 0 on success, 1 on failure
symlinks_create_from_globals() {
    local force="${1:-false}"
    local selected_symlinks="$2"
    local symlink_list=$(global_vars symlinks)
    
    if [[ -z "$symlink_list" ]]; then
        log_warning "No symlinks configured in globals.sh" "$MODULE_NAME"
        log_info "Add symlink configurations to globals.sh. Example:" "$MODULE_NAME"
        symlinks_generate_example_config
        return 1
    fi
    
    local failed=0
    local success=0
    local skipped=0
    
    # Filter symlink list if specific symlinks are selected
    if [[ -n "$selected_symlinks" ]]; then
        local filtered_list=""
        for symlink_key in $symlink_list; do
            for selected in $selected_symlinks; do
                if [[ "$symlink_key" == "$selected" ]]; then
                    filtered_list="$filtered_list $symlink_key"
                    break
                fi
            done
        done
        symlink_list="$filtered_list"
        
        if [[ -z "$symlink_list" ]]; then
            log_warning "No matching symlinks found for: $selected_symlinks" "$MODULE_NAME"
            log_info "Available symlinks: $(global_vars symlinks)" "$MODULE_NAME"
            return 1
        fi
        
        log_info "Creating selected symlinks: $symlink_list" "$MODULE_NAME"
    fi
    
    for symlink_key in $symlink_list; do
        local result
        symlinks_create_single "$symlink_key" "$force"
        result=$?
        
        case $result in
            0) ((success++)) ;;
            1) ((failed++)) ;;
            2) ((skipped++)) ;;
        esac
    done
    
    log_info "Symlink creation summary: $success succeeded, $failed failed, $skipped skipped" "$MODULE_NAME"
    
    [[ $failed -eq 0 ]] && return 0 || return 1
}

# Function to remove symlinks from globals
# Args: $1 - space-separated list of symlink keys (optional)
# Returns: 0 on success, 1 on failure
symlinks_remove_from_globals() {
    local selected_symlinks="$1"
    local symlink_list=$(global_vars symlinks)
    
    if [[ -z "$symlink_list" ]]; then
        log_warning "No symlinks configured in globals.sh" "$MODULE_NAME"
        return 1
    fi
    
    local failed=0
    local success=0
    
    # Filter symlink list if specific symlinks are selected
    if [[ -n "$selected_symlinks" ]]; then
        local filtered_list=""
        for symlink_key in $symlink_list; do
            for selected in $selected_symlinks; do
                if [[ "$symlink_key" == "$selected" ]]; then
                    filtered_list="$filtered_list $symlink_key"
                    break
                fi
            done
        done
        symlink_list="$filtered_list"
        
        if [[ -z "$symlink_list" ]]; then
            log_warning "No matching symlinks found for: $selected_symlinks" "$MODULE_NAME"
            log_info "Available symlinks: $(global_vars symlinks)" "$MODULE_NAME"
            return 1
        fi
        
        log_info "Removing selected symlinks: $symlink_list" "$MODULE_NAME"
    fi
    
    for symlink_key in $symlink_list; do
        if symlinks_remove_single "$symlink_key"; then
            ((success++))
        else
            ((failed++))
        fi
    done
    
    log_info "Symlink removal summary: $success succeeded, $failed failed" "$MODULE_NAME"
    
    [[ $failed -eq 0 ]] && return 0 || return 1
}

# Main function for the symlinks module
# Usage: symlinks_main [command] [options]
# Commands:
#   create        Create symlinks defined in globals
#   remove        Remove symlinks
# Options:
#   --only        Create/remove only specific symlinks (space-separated list)
#   --force       Force overwrite existing files when creating
#   --help        Display this help message
# Returns: 0 on success, 1 on failure
symlinks_main() {
    # Save previous module context
    local PREV_MODULE_NAME="$MODULE_NAME"
    local PREV_MODULE_DESCRIPTION="$MODULE_DESCRIPTION"
    local PREV_MODULE_VERSION="$MODULE_VERSION"
    
    # Set this module's context
    MODULE_NAME="symlinks"
    MODULE_DESCRIPTION="Create and manage symbolic links for configuration files"
    MODULE_VERSION="1.0.0"
    
    log_debug "Symlinks module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local command=""
    local force=false
    local show_help=false
    local selected_symlinks=""
    local help_due_to_error=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            create|remove)
                command="$1"
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --only)
                # Collect all symlink names until next option or end
                shift
                while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                    selected_symlinks="$selected_symlinks $1"
                    shift
                done
                ;;
            --help)
                show_help=true
                shift
                ;;
            *)
                log_error "Unknown option: $1" "$MODULE_NAME"
                show_help=true
                help_due_to_error=true
                shift
                ;;
        esac
    done
    
    # Show help if requested or no command specified
    if [[ "$show_help" = "true" ]] || [[ -z "$command" ]]; then
        cat <<-EOF
Usage: symlinks_main [command] [options]

Commands:
  create        Create symlinks defined in globals.sh
  remove        Remove symlinks

Options:
  --only        Create/remove only specific symlinks (space-separated list)
  --force       Force overwrite existing files when creating
  --help        Display this help message

Symlink Configuration:
  Symlinks are configured in globals.sh using these arrays:
  - SYMLINK_SOURCE[name]    Source file/directory path
  - SYMLINK_TARGET[name]    Target symlink path

Examples:
  # Create all symlinks from globals
  symlinks_main create

  # Create all symlinks from globals (force overwrite)
  symlinks_main create --force

  # Create only specific symlinks
  symlinks_main create --only bash_aliases gitconfig

  # Remove specific symlinks
  symlinks_main remove --only bash_aliases

  # Remove all symlinks
  symlinks_main remove

Available symlinks: $(global_vars symlinks 2>/dev/null || echo "none configured")
EOF
        # Restore previous module context
        MODULE_NAME="$PREV_MODULE_NAME"
        MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
        MODULE_VERSION="$PREV_MODULE_VERSION"
        
        # Return error if help was shown due to an error
        if [[ "$help_due_to_error" = "true" ]]; then
            return 1
        fi
        return 0
    fi
    
    # Execute command
    local result=0
    
    case "$command" in
        create)
            if ! symlinks_create_from_globals "$force" "$selected_symlinks"; then
                result=1
            fi
            ;;
            
        remove)
            if [[ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]] && [[ -z "$selected_symlinks" ]]; then
                if ! confirm "Remove all configured symlinks?"; then
                    log_warning "Symlink removal cancelled by user" "$MODULE_NAME"
                    result=1
                else
                    if ! symlinks_remove_from_globals "$selected_symlinks"; then
                        result=1
                    fi
                fi
            else
                if ! symlinks_remove_from_globals "$selected_symlinks"; then
                    result=1
                fi
            fi
            ;;
    esac
    
    if [[ $result -eq 0 ]]; then
        log_info "Symlinks $command completed successfully" "$MODULE_NAME"
    else
        log_error "Symlinks $command completed with errors" "$MODULE_NAME"
    fi
    
    # Restore previous module context
    MODULE_NAME="$PREV_MODULE_NAME"
    MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
    MODULE_VERSION="$PREV_MODULE_VERSION"
    
    return $result
}

# Export only the main function
export -f symlinks_main

# Module metadata
MODULE_COMMANDS=(
    "symlinks_main:Create and manage symbolic links for configuration files"
)
export MODULE_COMMANDS

log_debug "Symlinks module loaded" "symlinks"