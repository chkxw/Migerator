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

# Module info
MODULE_NAME="batch_packages"
MODULE_DESCRIPTION="Install predefined package groups with a single confirmation"
MODULE_VERSION="1.0.0"

log_debug "Loading batch packages module" "$MODULE_NAME"

# Function to get all available package groups
# Usage: get_available_package_groups
# Returns: Space-separated list of available package group names
get_available_package_groups() {
    local groups=()
    local var_name
    
    # Get all environment variables and filter for BA_PKG_ prefix
    # Using compgen to list all variables is more reliable than env
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
    
    # Try exact match first
    var_name="BA_PKG_${group_name^^}"
    if [[ "$(declare -p "$var_name" 2>/dev/null)" =~ "declare -a" ]]; then
        echo "$var_name"
        return 0
    fi
    
    # If not found, try case-insensitive search
    while IFS='=' read -r var_check _; do
        if [[ "$var_check" == BA_PKG_* ]] && [[ "$(declare -p "$var_check" 2>/dev/null)" =~ "declare -a" ]]; then
            local check_name=${var_check#BA_PKG_}
            if [[ "${check_name,,}" == "${group_name,,}" ]]; then
                echo "$var_check"
                return 0
            fi
        fi
    done < <(env | sort)
    
    log_error "Unknown package group: $group_name" "$MODULE_NAME"
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
    local var_name=""
    
    # Get the variable name for the package group
    var_name=$(get_package_group_var_name "$group_name" 2>/dev/null)
    if [ $? -ne 0 ]; then
        # If group not found, generate a generic description
        # Convert snake_case to Title Case for description
        description=$(echo "$group_name" | sed -r 's/(^|_)([a-z])/\1\u\2/g' | sed 's/_/ /g')
        if [ -z "$description" ]; then
            description="$group_name package group"
        else
            description="$description Package Group"
        fi
        
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
        # Convert snake_case to Title Case for description
        description=$(echo "$simple_group_name" | sed -r 's/(^|_)([a-z])/\1\u\2/g' | sed 's/_/ /g')
        if [ -z "$description" ]; then
            description="$group_name package group"
        else
            description="$description Package Group"
        fi
    fi
    
    echo "$description"
}

# Function to print the details of a package group
# Usage: print_package_group_details group_name
# Returns: Human-readable description of the package group
print_package_group_details() {
    local group_name="$1"
    local description=""
    local packages=""
    
    # Get package list using the dynamic function
    packages=$(get_package_group_list "$group_name")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Get description from globals or generate one
    description=$(get_package_group_description "$group_name")
    
    echo "Package Group: $group_name"
    echo "Description: $description"
    echo "Packages: $packages"
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
    
    log_info "Installing package group: $group_name" "$MODULE_NAME"
    
    # Get package list for the specified group
    local package_list=$(get_package_group_list "$group_name")
    if [ -z "$package_list" ]; then
        return 1
    fi
    
    # Print package group details
    local group_details=$(print_package_group_details "$group_name")
    echo "$group_details"
    echo ""
    
    # Confirm installation if not forced
    if [ "$force" = "false" ] && [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Install this package group?"; then
            log_warning "Installation of package group $group_name cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Update package lists first
    log_debug "Updating package lists before installation" "$MODULE_NAME"
    Sudo apt update >/dev/null
    
    # Install packages
    log_info "Installing packages from group: $group_name" "$MODULE_NAME"
    Sudo apt install -y $package_list
    
    if [ $? -ne 0 ]; then
        log_error "Failed to install some packages from group: $group_name" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Successfully installed package group: $group_name" "$MODULE_NAME"
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
                log_error "Unknown option: $1" "$MODULE_NAME"
                return 1
                ;;
        esac
    done
    
    log_info "Removing package group: $group_name" "$MODULE_NAME"
    
    # Get package list for the specified group
    local package_list=$(get_package_group_list "$group_name")
    if [ -z "$package_list" ]; then
        return 1
    fi
    
    # Print package group details
    local group_details=$(print_package_group_details "$group_name")
    echo "$group_details"
    echo ""
    
    # Confirm removal if not forced
    if [ "$force" = "false" ] && [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        local confirm_message="Remove this package group?"
        if [ "$purge" = "true" ]; then
            confirm_message="Purge this package group? (This will also remove configuration files)"
        fi
        
        if ! confirm "$confirm_message"; then
            log_warning "Removal of package group $group_name cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Remove packages
    log_info "Removing packages from group: $group_name" "$MODULE_NAME"
    if [ "$purge" = "true" ]; then
        Sudo apt purge -y $package_list
    else
        Sudo apt remove -y $package_list
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Failed to remove some packages from group: $group_name" "$MODULE_NAME"
        return 1
    fi
    
    # Run autoremove to clean up dependencies
    log_debug "Running autoremove to clean up dependencies" "$MODULE_NAME"
    Sudo apt autoremove -y
    
    log_info "Successfully removed package group: $group_name" "$MODULE_NAME"
    return 0
}

# Function to install multiple package groups
# Usage: install_multiple_groups group1 [group2...]
# Returns: 0 on success, non-zero on any failure
install_multiple_groups() {
    local groups=("$@")
    local result=0
    
    if [ ${#groups[@]} -eq 0 ]; then
        log_error "No package groups specified for installation" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Installing ${#groups[@]} package groups: ${groups[*]}" "$MODULE_NAME"
    
    # Update package lists first
    log_debug "Updating package lists before installation" "$MODULE_NAME"
    Sudo apt update >/dev/null
    
    # Install each group
    for group in "${groups[@]}"; do
        log_debug "Installing group: $group" "$MODULE_NAME"
        if ! install_package_group "$group" "--force"; then
            log_error "Failed to install group: $group" "$MODULE_NAME"
            result=1
        else
            log_info "Successfully installed group: $group" "$MODULE_NAME"
        fi
    done
    
    if [ $result -eq 0 ]; then
        log_info "All package groups installed successfully" "$MODULE_NAME"
    else
        log_warning "Some package groups failed to install" "$MODULE_NAME"
    fi
    
    return $result
}

# Function to install packages for a specific development purpose
# Usage: install_purpose_packages purpose [--force]
# Returns: 0 on success, 1 on failure
install_purpose_packages() {
    local purpose="$1"
    local force="false"
    
    # Check for force flag
    if [ "$2" = "--force" ]; then
        force="true"
    fi
    
    log_info "Installing packages for purpose: $purpose" "$MODULE_NAME"
    
    # Define package groups for each purpose
    local groups=()
    case "$purpose" in
        badger_rl_dev)
            # For BadgerRL development
            groups=("common_deps" "utilities" "dev_tools" "badger_rl_deps")
            ;;
        general_dev)
            # For general development
            groups=("common_deps" "utilities" "dev_tools")
            ;;
        ml_dev)
            # For machine learning development
            groups=("common_deps" "utilities" "dev_tools" "ml_tools")
            ;;
        minimal)
            # Minimal install with just the essentials
            groups=("common_deps" "utilities")
            ;;
        all)
            # Everything - get all available groups
            groups=($(get_available_package_groups))
            ;;
        *)
            log_error "Unknown purpose: $purpose" "$MODULE_NAME"
            echo "Available purposes:"
            echo "  badger_rl_dev - BadgerRL development environment"
            echo "  general_dev   - General development environment"
            echo "  ml_dev        - Machine learning development environment"
            echo "  minimal       - Minimal installation with just essentials"
            echo "  all           - All package groups"
            return 1
            ;;
    esac
    
    # Display what will be installed
    echo "Installing packages for purpose: $purpose"
    echo "This will install the following package groups:"
    for group in "${groups[@]}"; do
        echo " - $group"
    done
    echo ""
    
    # Confirm installation if not forced
    if [ "$force" = "false" ] && [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Install packages for purpose: $purpose?"; then
            log_warning "Installation for purpose $purpose cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Install all the groups
    install_multiple_groups "${groups[@]}"
    return $?
}

# Function to install packages from the old setup script
# Usage: install_old_setup_packages [--force]
# Returns: 0 on success, 1 on failure
install_old_setup_packages() {
    local force="false"
    
    # Check for force flag
    if [ "$1" = "--force" ]; then
        force="true"
    fi
    
    log_info "Installing packages from old setup script" "$MODULE_NAME"
    
    # Install all the groups needed for a full setup
    local groups=("common_deps" "utilities" "badger_rl_deps")
    
    # Display what will be installed
    echo "This will install the following package groups:"
    for group in "${groups[@]}"; do
        echo " - $group"
    done
    echo ""
    
    # Additionally install special packages
    echo "Also installing the following special packages:"
    echo " - chrome"
    echo " - vscode"
    echo " - slack"
    echo " - virtualgl + turbovnc (if selected)"
    echo ""
    
    # Confirm installation if not forced
    if [ "$force" = "false" ] && [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Install all packages from old setup script?"; then
            log_warning "Installation cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # First install the package groups
    log_info "Installing package groups" "$MODULE_NAME"
    install_multiple_groups "${groups[@]}"
    
    # Then install special packages using the packages module
    log_info "Installing special packages" "$MODULE_NAME"
    
    # Install Chrome
    if ! is_package_installed "google-chrome-stable"; then
        if install_package_with_processing "chrome"; then
            log_info "Successfully installed Chrome" "$MODULE_NAME"
        else
            log_error "Failed to install Chrome" "$MODULE_NAME"
        fi
    else
        log_info "Chrome is already installed" "$MODULE_NAME"
    fi
    
    # Install VS Code
    if ! is_package_installed "code"; then
        if install_package_with_processing "vscode"; then
            log_info "Successfully installed VS Code" "$MODULE_NAME"
        else
            log_error "Failed to install VS Code" "$MODULE_NAME"
        fi
    else
        log_info "VS Code is already installed" "$MODULE_NAME"
    fi
    
    # Install Slack
    if ! is_package_installed "slack-desktop"; then
        if install_package_with_processing "slack"; then
            log_info "Successfully installed Slack" "$MODULE_NAME"
        else
            log_error "Failed to install Slack" "$MODULE_NAME"
        fi
    else
        log_info "Slack is already installed" "$MODULE_NAME"
    fi
    
    # Ask about VirtualGL and TurboVNC
    if [ "$force" = "false" ] && [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if confirm "Install VirtualGL and TurboVNC?"; then
            # Install VirtualGL
            if ! is_package_installed "virtualgl"; then
                if install_package_with_processing "virtualgl"; then
                    log_info "Successfully installed VirtualGL" "$MODULE_NAME"
                else
                    log_error "Failed to install VirtualGL" "$MODULE_NAME"
                fi
            else
                log_info "VirtualGL is already installed" "$MODULE_NAME"
            fi
            
            # Install TurboVNC
            if ! is_package_installed "turbovnc"; then
                if install_package_with_processing "turbovnc"; then
                    log_info "Successfully installed TurboVNC" "$MODULE_NAME"
                else
                    log_error "Failed to install TurboVNC" "$MODULE_NAME"
                fi
            else
                log_info "TurboVNC is already installed" "$MODULE_NAME"
            fi
        fi
    fi
    
    log_info "Old setup package installation completed" "$MODULE_NAME"
    return 0
}

# Main function for batch package module to handle CLI
# Usage: batch_packages_main [command] [options]
# Commands:
#   group [group_name] [options]  - Install/remove a predefined package group
#   purpose [purpose] [options]   - Install packages for a specific purpose
#   oldsetup [options]            - Install packages from old setup script
#   list                          - List available package groups and purposes
# Options:
#   --remove                      - Remove packages instead of installing
#   --purge                       - Purge packages when removing (implies --remove)
#   --force                       - Skip confirmation prompts
#   --help                        - Show help message
# Returns: 0 on success, 1 on failure
batch_packages_main() {
    log_debug "Batch packages module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local command=""
    local group_name=""
    local purpose=""
    local remove="false"
    local purge="false"
    local force="false"
    local show_help="false"
    
    # No arguments - show help
    if [ $# -eq 0 ]; then
        show_help="true"
    fi
    
    # First argument is the command
    if [ $# -gt 0 ]; then
        command="$1"
        shift
    fi
    
    # Process command-specific arguments
    case "$command" in
        group)
            if [ $# -gt 0 ]; then
                group_name="$1"
                shift
            else
                log_error "No group name specified" "$MODULE_NAME"
                show_help="true"
            fi
            ;;
        purpose)
            if [ $# -gt 0 ]; then
                purpose="$1"
                shift
            else
                log_error "No purpose specified" "$MODULE_NAME"
                show_help="true"
            fi
            ;;
        oldsetup)
            # No additional arguments needed
            ;;
        list)
            # No additional arguments needed
            ;;
        *)
            if [ -n "$command" ]; then
                log_error "Unknown command: $command" "$MODULE_NAME"
            fi
            show_help="true"
            ;;
    esac
    
    # Process options
    while [ $# -gt 0 ]; do
        case "$1" in
            --remove)
                remove="true"
                shift
                ;;
            --purge)
                purge="true"
                remove="true"  # Purge implies remove
                shift
                ;;
            --force)
                force="true"
                shift
                ;;
            --help|-h)
                show_help="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1" "$MODULE_NAME"
                show_help="true"
                shift
                ;;
        esac
    done
    
    # Show help message
    if [ "$show_help" = "true" ]; then
        help_text="Usage: batch_packages_main [command] [options]

Commands:
  group [group_name] [options]  - Install/remove a predefined package group
  purpose [purpose] [options]   - Install packages for a specific purpose
  oldsetup [options]            - Install packages from old setup script
  list                          - List available package groups and purposes

Options:
  --remove                      - Remove packages instead of installing
  --purge                       - Purge packages when removing (implies --remove)
  --force                       - Skip confirmation prompts
  --help, -h                    - Show this help message

Available package groups:
"

# Add dynamically generated package group list to help text
for group in $(get_available_package_groups); do
    local description=$(get_package_group_description "$group" 2>/dev/null)
    if [ -n "$description" ]; then
        help_text+="  $(printf "%-12s - %s\n" "$group" "$description")"
    fi
done

help_text+="
Available purposes:
  badger_rl_dev - BadgerRL development environment
  general_dev   - General development environment
  ml_dev        - Machine learning development environment
  minimal       - Minimal installation with just essentials
  all           - All package groups"
        echo "$help_text"
        return 0
    fi
    
    # Execute the appropriate command
    case "$command" in
        group)
            if [ "$remove" = "true" ]; then
                # Remove package group
                local opts=()
                if [ "$purge" = "true" ]; then
                    opts+=("--purge")
                fi
                if [ "$force" = "true" ]; then
                    opts+=("--force")
                fi
                remove_package_group "$group_name" "${opts[@]}"
            else
                # Install package group
                local opts=()
                if [ "$force" = "true" ]; then
                    opts+=("--force")
                fi
                install_package_group "$group_name" "${opts[@]}"
            fi
            return $?
            ;;
        purpose)
            if [ "$remove" = "true" ]; then
                log_error "Removal by purpose is not supported" "$MODULE_NAME"
                return 1
            else
                # Install packages for purpose
                local opts=()
                if [ "$force" = "true" ]; then
                    opts+=("--force")
                fi
                install_purpose_packages "$purpose" "${opts[@]}"
            fi
            return $?
            ;;
        oldsetup)
            if [ "$remove" = "true" ]; then
                log_error "Removal of old setup packages is not supported" "$MODULE_NAME"
                return 1
            else
                # Install old setup packages
                local opts=()
                if [ "$force" = "true" ]; then
                    opts+=("--force")
                fi
                install_old_setup_packages "${opts[@]}"
            fi
            return $?
            ;;
        list)
            # List available package groups
            echo "Available package groups:"
            
            # Get all available package groups and list them with descriptions
            for group in $(get_available_package_groups); do
                # Get description for each group
                local description=$(get_package_group_description "$group" 2>/dev/null)
                if [ -n "$description" ]; then
                    printf "  %-12s - %s\n" "$group" "$description"
                fi
            done
            
            echo ""
            echo "Available purposes:"
            echo "  badger_rl_dev - BadgerRL development environment"
            echo "  general_dev   - General development environment"
            echo "  ml_dev        - Machine learning development environment"
            echo "  minimal       - Minimal installation with just essentials"
            echo "  all           - All package groups"
            return 0
            ;;
        *)
            log_error "Unknown command: $command" "$MODULE_NAME"
            return 1
            ;;
    esac
}

# Define commands
MODULE_COMMANDS=(
    "batch_packages_main group:Install/remove a predefined package group"
    "batch_packages_main purpose:Install packages for a specific purpose"
    "batch_packages_main oldsetup:Install packages from old setup script"
    "batch_packages_main list:List available package groups and purposes"
)
export MODULE_COMMANDS

# Export functions for use in other scripts
export -f get_available_package_groups
export -f get_package_group_var_name
export -f get_package_group_list
export -f get_package_group_description
export -f print_package_group_details
export -f batch_packages_main
export -f install_package_group
export -f remove_package_group
export -f install_purpose_packages
export -f install_old_setup_packages

log_debug "Batch packages module loaded" "$MODULE_NAME"