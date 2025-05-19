#!/bin/bash

# Level 2 abstraction: Batch Package Installation Module
# This module handles installation of predefined package groups with a single confirmation

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"
source "$PROJECT_ROOT/src/core/package_manager.sh"
source "$PROJECT_ROOT/src/modules/packages.sh"

# Log with hard-coded module name for initial loading
log_debug "Loading batch packages module" "batch_packages"

# Function to get all available package groups
# Usage: get_available_package_groups
# Returns: Space-separated list of available package group names
get_available_package_groups() {
    local groups=()
    local var_name
    
    # Get all environment variables and filter for BA_PKG_ prefix
    while read -r var_name; do
        if [[ "$var_name" == BA_PKG_* ]] && [[ "$(declare -p "$var_name" 2>/dev/null)" =~ "declare -a" ]]; then
            # Extract group name by removing the prefix
            local group_name=${var_name#BA_PKG_}
            # Convert to lowercase for user-friendliness
            group_name=$(echo "$group_name" | tr '[:upper:]' '[:lower:]')
            groups+=("$group_name")
        fi
    done < <(compgen -v | grep "^BA_PKG_" | sort)
    
    echo "${groups[*]}"
}

# Function to get package group variable name from group name
# Usage: get_package_group_var_name group_name
# Returns: Variable name containing the package list
get_package_group_var_name() {
    local group_name="$1"
    local var_name
    
    # Convert to uppercase for standard format
    var_name="BA_PKG_${group_name^^}"
    
    # Check if the variable exists
    if [[ "$(declare -p "$var_name" 2>/dev/null)" =~ "declare -a" ]]; then
        echo "$var_name"
        return 0
    fi
    
    # If not found, try case-insensitive search
    while read -r var_check; do
        if [[ "$var_check" == BA_PKG_* ]] && [[ "$(declare -p "$var_check" 2>/dev/null)" =~ "declare -a" ]]; then
            local check_name=${var_check#BA_PKG_}
            if [[ "${check_name,,}" == "${group_name,,}" ]]; then
                echo "$var_check"
                return 0
            fi
        fi
    done < <(compgen -v | grep "^BA_PKG_")
    
    log_error "Unknown package group: $group_name" "batch_packages"
    return 1
}

# Function to get the list of packages in a group
# Usage: get_package_group_list group_name
# Returns: Space-separated list of packages in the group
get_package_group_list() {
    local group_name="$1"
    local package_list=""
    
    # Get the variable name for the package group
    local var_name=$(get_package_group_var_name "$group_name")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Get the package list from the variable
    eval "package_list=\"\${$var_name[*]}\""
    
    echo "$package_list"
}

# Function to get package group description
# Usage: get_package_group_description group_name
# Returns: Human-readable description of the package group
get_package_group_description() {
    local group_name="$1"
    local description=""
    
    # Get the variable name for the package group
    local var_name=$(get_package_group_var_name "$group_name" 2>/dev/null)
    if [ $? -ne 0 ]; then
        # Generate a generic description if group not found
        description=$(echo "$group_name" | sed -r 's/(^|_)([a-z])/\1\u\2/g' | sed 's/_/ /g')
        description="$description Package Group"
        echo "$description"
        return 0
    fi
    
    # Try to get description from globals
    local desc_var_name="${var_name}_DESCRIPTION"
    if [[ "$(declare -p "$desc_var_name" 2>/dev/null)" =~ "declare" ]]; then
        # Description variable exists
        eval "description=\"\$$desc_var_name\""
    else
        # No description variable found, generate from group name
        local simple_group_name=${var_name#BA_PKG_}
        description=$(echo "$simple_group_name" | sed -r 's/(^|_)([a-z])/\1\u\2/g' | sed 's/_/ /g')
        description="$description Package Group"
    fi
    
    echo "$description"
}

# Function to install a predefined package group
# Usage: install_package_group group_name [--force]
# Returns: 0 on success, 1 on failure
install_package_group() {
    local group_name="$1"
    local force="false"
    
    # Check for force flag
    if [ "$2" = "--force" ]; then
        force="true"
    fi
    
    # Get package list for the specified group
    local package_list=$(get_package_group_list "$group_name")
    if [ -z "$package_list" ]; then
        return 1
    fi
    
    # Get description for the group
    local description=$(get_package_group_description "$group_name")
    
    log_info "Installing package group: $group_name ($description)" "batch_packages"
    log_info "Packages: $package_list" "batch_packages"
    
    # Confirm installation if not forced
    if [ "$force" = "false" ] && [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Install this package group?"; then
            log_warning "Installation of package group $group_name cancelled by user" "batch_packages"
            return 1
        fi
    fi
    
    # Update package lists
    log_debug "Updating package lists before installation" "batch_packages"
    Sudo apt update >/dev/null
    
    # Install packages
    log_info "Installing packages from group: $group_name" "batch_packages"
    
    Sudo apt install -y $package_list
    
    log_info "Successfully installed package group: $group_name" "batch_packages"
    return 0
}

# Function to remove a predefined package group
# Usage: remove_package_group group_name [--purge] [--force]
# Returns: 0 on success, 1 on failure
remove_package_group() {
    local group_name="$1"
    local purge="false"
    local force="false"
    
    # Process options
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --purge)
                purge="true"
                shift
                ;;
            --force)
                force="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1" "batch_packages"
                return 1
                ;;
        esac
    done
    
    # Get package list for the specified group
    local package_list=$(get_package_group_list "$group_name")
    if [ -z "$package_list" ]; then
        return 1
    fi
    
    # Get description for the group
    local description=$(get_package_group_description "$group_name")
    
    log_info "Removing package group: $group_name ($description)" "batch_packages"
    log_info "Packages: $package_list" "batch_packages"
    
    # Confirm removal if not forced
    if [ "$force" = "false" ] && [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        local confirm_message="Remove this package group?"
        if [ "$purge" = "true" ]; then
            confirm_message="Purge this package group? (This will also remove configuration files)"
        fi
        
        if ! confirm "$confirm_message"; then
            log_warning "Removal of package group $group_name cancelled by user" "batch_packages"
            return 1
        fi
    fi
    
    # Remove packages
    log_info "Removing packages from group: $group_name" "batch_packages"
    
    if [ "$purge" = "true" ]; then
        Sudo apt purge -y $package_list
    else
        Sudo apt remove -y $package_list
    fi
    
    # Run autoremove to clean up dependencies
    log_debug "Running autoremove to clean up dependencies" "batch_packages"
    Sudo apt autoremove -y
    
    log_info "Successfully removed package group: $group_name" "batch_packages"
    return 0
}

# Main function for batch package module to handle CLI
# Usage: batch_packages_main [command] [options]
# Commands:
#   install <group_name> [--force]  - Install a predefined package group
#   remove <group_name> [--purge] [--force] - Remove a predefined package group
#   list                            - List available package groups
# Returns: 0 on success, 1 on failure
batch_packages_main() {
    # Save previous module context
    local PREV_MODULE_NAME="$MODULE_NAME"
    local PREV_MODULE_DESCRIPTION="$MODULE_DESCRIPTION"
    local PREV_MODULE_VERSION="$MODULE_VERSION"
    
    # Set this module's context
    MODULE_NAME="batch_packages"
    MODULE_DESCRIPTION="Install predefined package groups with a single confirmation"
    MODULE_VERSION="1.0.0"
    
    log_debug "Batch packages module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local command=""
    local group_name=""
    local purge="false"
    local force="false"
    local show_help="false"
    
    # Check if first argument is -h or --help
    if [ $# -gt 0 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
        show_help="true"
        shift
    # No arguments - show help
    elif [ $# -eq 0 ]; then
        show_help="true"
    # First argument is the command
    elif [ $# -gt 0 ]; then
        command="$1"
        shift
    fi
    
    # Process command-specific arguments
    if [ "$command" = "install" ] || [ "$command" = "remove" ]; then
        if [ $# -gt 0 ]; then
            group_name="$1"
            shift
        else
            log_error "No group name specified" "$MODULE_NAME"
            show_help="true"
        fi
    fi
    
    # Process options
    while [ $# -gt 0 ]; do
        case "$1" in
            --purge)
                purge="true"
                shift
                ;;
            --force)
                force="true"
                shift
                ;;
            *)
                # Only report unknown option if we have a command
                if [ -n "$command" ]; then
                    log_error "Unknown option: $1" "$MODULE_NAME"
                fi
                show_help="true"
                shift
                ;;
        esac
    done
    
    # Show help message
    if [ "$show_help" = "true" ]; then
        cat <<EOF
Usage: batch_packages_main [command] [options]

Commands:
  install <group_name> [options]  - Install a predefined package group
  remove <group_name> [options]   - Remove a predefined package group
  list                            - List available package groups

Options:
  --purge                         - Purge packages when removing (implies --remove)
  --force                         - Skip confirmation prompts
  --help, -h                      - Show this help message

Available package groups:
EOF

        # Add dynamically generated package group list to help text
        for group in $(get_available_package_groups); do
            description=$(get_package_group_description "$group" 2>/dev/null)
            if [ -n "$description" ]; then
                printf "  %-20s - %s\n" "$group" "$description"
            fi
        done
        
        # Restore previous module context
        MODULE_NAME="$PREV_MODULE_NAME"
        MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
        MODULE_VERSION="$PREV_MODULE_VERSION"
        
        return 0
    fi
    
    # Execute the appropriate command
    local result=0
    case "$command" in
        install)
            local opts=()
            if [ "$force" = "true" ]; then
                opts+=("--force")
            fi
            install_package_group "$group_name" "${opts[@]}"
            result=$?
            ;;
            
        remove)
            local opts=()
            if [ "$purge" = "true" ]; then
                opts+=("--purge")
            fi
            if [ "$force" = "true" ]; then
                opts+=("--force")
            fi
            remove_package_group "$group_name" "${opts[@]}"
            result=$?
            ;;
            
        list)
            echo "Available package groups:"
            for group in $(get_available_package_groups); do
                description=$(get_package_group_description "$group" 2>/dev/null)
                if [ -n "$description" ]; then
                    printf "  %-20s - %s\n" "$group" "$description"
                    printf "                      Packages: %s\n" "$(get_package_group_list "$group")"
                fi
            done
            result=0
            ;;
            
        *)
            log_error "Unknown command: $command" "$MODULE_NAME"
            result=1
            ;;
    esac
    
    # Restore previous module context
    MODULE_NAME="$PREV_MODULE_NAME"
    MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
    MODULE_VERSION="$PREV_MODULE_VERSION"
    
    return $result
}

# Export only the necessary functions
export -f batch_packages_main

# Module metadata
MODULE_COMMANDS=(
    "batch_packages_main install:Install a predefined package group"
    "batch_packages_main remove:Remove a predefined package group"
    "batch_packages_main list:List available package groups"
)
export MODULE_COMMANDS

log_debug "Batch packages module loaded" "batch_packages"