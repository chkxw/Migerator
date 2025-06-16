#!/bin/bash

# Level 2 abstraction: Personal computer setup module
# This module handles personal computer configurations including:
# - Setting /usr/local permissions to 777
# - Installing Claude CLI via npm

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"

# Module info
MODULE_NAME="personal_setup"
MODULE_DESCRIPTION="Personal computer setup including /usr/local permissions and Claude CLI installation"
MODULE_VERSION="1.0.0"

# Log with module name for initial loading
log_debug "Loading personal setup module" "$MODULE_NAME"


# Function to setup /usr/local permissions
personal_setup_configure_usr_local() {
    log_info "Configuring /usr/local permissions to 777" "$MODULE_NAME"
    
    # Check if /usr/local exists
    if [ ! -d "/usr/local" ]; then
        log_error "/usr/local directory does not exist" "$MODULE_NAME"
        return 1
    fi
    
    # Change permissions to 777
    if ! Sudo chmod 777 /usr/local; then
        log_error "Failed to change /usr/local permissions" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Successfully set /usr/local permissions to 777" "$MODULE_NAME"
    return 0
}

# Function to restore /usr/local permissions
personal_setup_restore_usr_local() {
    log_info "Restoring /usr/local permissions to default (755)" "$MODULE_NAME"
    
    # Check if /usr/local exists
    if [ ! -d "/usr/local" ]; then
        log_warning "/usr/local directory does not exist, nothing to restore" "$MODULE_NAME"
        return 0
    fi
    
    # Restore default permissions (755)
    if ! Sudo chmod 755 /usr/local; then
        log_error "Failed to restore /usr/local permissions" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Successfully restored /usr/local permissions to 755" "$MODULE_NAME"
    return 0
}

# Function to install Claude CLI
personal_setup_install_claude() {
    log_info "Installing Claude CLI via npm" "$MODULE_NAME"
    
    # Check if npm is available
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm is not installed or not in PATH" "$MODULE_NAME"
        return 1
    fi
    
    # Install Claude CLI globally
    if ! npm install -g @anthropic-ai/claude-code; then
        log_error "Failed to install Claude CLI" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Successfully installed Claude CLI" "$MODULE_NAME"
    return 0
}

# Function to remove Claude CLI
personal_setup_remove_claude() {
    log_info "Removing Claude CLI" "$MODULE_NAME"
    
    # Check if npm is available
    if ! command -v npm >/dev/null 2>&1; then
        log_warning "npm is not installed, Claude CLI may not be installed" "$MODULE_NAME"
        return 0
    fi
    
    # Check if Claude CLI is installed
    if ! npm list -g @anthropic-ai/claude-code >/dev/null 2>&1; then
        log_info "Claude CLI is not installed, nothing to remove" "$MODULE_NAME"
        return 0
    fi
    
    # Remove Claude CLI
    if ! npm uninstall -g @anthropic-ai/claude-code; then
        log_error "Failed to remove Claude CLI" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Successfully removed Claude CLI" "$MODULE_NAME"
    return 0
}



# Function to setup personal computer configuration
personal_setup_setup() {
    log_info "Setting up personal computer configuration" "$MODULE_NAME"
    
    # Configure /usr/local permissions
    if ! personal_setup_configure_usr_local; then
        log_error "Failed to configure /usr/local permissions" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Personal computer setup completed successfully" "$MODULE_NAME"
    return 0
}

# Function to remove personal computer configuration
personal_setup_remove() {
    local force="$1"
    log_info "Removing personal computer configuration" "$MODULE_NAME"
    
    # Remove Claude CLI
    if ! personal_setup_remove_claude; then
        log_error "Failed to remove Claude CLI" "$MODULE_NAME"
        return 1
    fi
    
    # Restore /usr/local permissions
    if ! personal_setup_restore_usr_local; then
        log_error "Failed to restore /usr/local permissions" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Personal computer configuration removed successfully" "$MODULE_NAME"
    return 0
}

# Main function for the personal setup module
personal_setup_main() {
    log_debug "Personal setup main function called with args: $*" "$MODULE_NAME"
    
    # Default values
    local setup=false
    local remove=false
    local install_claude=false
    local force=false
    local show_help=false
    
    # Process arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            setup)
                setup=true
                shift
                ;;
            remove)
                remove=true
                shift
                ;;
            install-claude)
                install_claude=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --help|-h)
                show_help=true
                shift
                ;;
            *)
                log_error "Unknown argument: $1" "$MODULE_NAME"
                show_help=true
                shift
                ;;
        esac
    done
    
    # Show help
    if [ "$show_help" = "true" ]; then
        echo "Usage: personal_setup_main [command] [options]"
        echo ""
        echo "Commands:"
        echo "  setup                  Setup personal computer configuration"
        echo "                         - Set /usr/local permissions to 777"
        echo "  install-claude         Install Claude CLI via npm"
        echo "  remove [--force]       Remove personal computer configuration"
        echo "                         - Restore /usr/local permissions to 755"
        echo "                         - Remove Claude CLI if installed"
        echo ""
        echo "Options:"
        echo "  --force                Force operation without confirmation"
        echo "  --help, -h             Show this help message"
        # Return 1 if help was shown due to invalid arguments
        local invalid_arg=false
        for arg in "$@"; do
            if [[ "$arg" != "help" && "$arg" != "--help" && "$arg" != "-h" ]]; then
                invalid_arg=true
                break
            fi
        done
        if [ "$invalid_arg" = "true" ]; then
            return 1
        else
            return 0
        fi
    fi
    
    # Execute commands
    if [ "$setup" = "true" ]; then
        personal_setup_setup
        return $?
    elif [ "$install_claude" = "true" ]; then
        personal_setup_install_claude
        return $?
    elif [ "$remove" = "true" ]; then
        if [ "$force" = "true" ]; then
            personal_setup_remove "force"
        else
            personal_setup_remove
        fi
        return $?
    else
        log_error "No command specified. Use --help for usage information." "$MODULE_NAME"
        return 1
    fi
}

# Module metadata for CLI dispatcher
MODULE_COMMANDS=(
    "personal_setup_main setup:Setup personal computer configuration (/usr/local permissions)"
    "personal_setup_main install-claude:Install Claude CLI via npm"
    "personal_setup_main remove:Remove personal computer configuration (args: [--force])"
)

# Export only the main function and metadata
export -f personal_setup_main
export MODULE_COMMANDS