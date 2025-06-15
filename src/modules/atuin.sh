#!/bin/bash

# Level 2 abstraction: Atuin module
# This module handles installing and configuring Atuin shell history manager

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"

# Log with hard-coded module name for initial loading
log_debug "Loading atuin module" "atuin"

# Function to generate Atuin bash integration content
# Returns: configuration content as a string
atuin_generate_bash_init_content() {
    local content='. "$HOME/.atuin/bin/env"
[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
eval "$(atuin init bash)"'
    echo "$content"
}

# Function to generate Atuin zsh integration content
# Returns: configuration content as a string
atuin_generate_zsh_init_content() {
    local content='. "$HOME/.atuin/bin/env"
eval "$(atuin init zsh)"'

    echo "$content"
}

atuin_generate_profile_init_content(){
    local content='. "$HOME/.atuin/bin/env"'
    echo "$content"
}

# Function to generate Atuin config content with sync settings
# Args: $1 - sync enabled (true/false)
# Returns: configuration content as a string
atuin_generate_config_content() {
    local sync_enabled="$1"
    
    local content="## Atuin configuration
## See https://docs.atuin.sh/configuration/config/ for more details

# How often to sync history with the server
auto_sync = true
sync_frequency = \"10s\"

# Enable/disable sync
sync_enabled = $sync_enabled

# Which search mode to use
search_mode = \"fuzzy\"

# Style of the interactive search UI
style = \"compact\"

# Show preview of command
show_preview = true

# Filter duplicates in search results
filter_mode = \"global\"

# Exit search on execution
exit_on_exec = true"

    echo "$content"
}

# Function to check if Atuin is installed
# Returns: 0 if installed, 1 if not
atuin_is_installed() {
    if [ -f "$HOME/.atuin/bin/atuin" ] && [ -x "$HOME/.atuin/bin/atuin" ]; then
        return 0
    else
        return 1
    fi
}

# Function to install Atuin
# Returns: 0 on success, 1 on failure
atuin_install() {
    log_debug "Installing Atuin" "$MODULE_NAME"
    
    # Check if Atuin is already installed
    if atuin_is_installed; then
        log_info "Atuin is already installed" "$MODULE_NAME"
        return 0
    fi
    
    # Check if atuin is installed elsewhere
    if command -v atuin &>/dev/null; then
        local existing_atuin=$(which atuin)
        log_warning "Atuin is already installed in a different location: $existing_atuin" "$MODULE_NAME"
        return 0
    fi
    
    # Download and run the installer
    log_info "Downloading and installing Atuin" "$MODULE_NAME"
    local installer_url="https://setup.atuin.sh"
    
    # Check if curl is available
    if ! command -v curl &>/dev/null; then
        log_error "curl is required for Atuin installation" "$MODULE_NAME"
        return 1
    fi
    
    # Run installer (it installs to ~/.atuin by default)
    if curl --proto '=https' --tlsv1.2 -LsSf "$installer_url" | sh; then
        log_info "Atuin installed successfully" "$MODULE_NAME"
        return 0
    else
        log_error "Failed to install Atuin" "$MODULE_NAME"
        return 1
    fi
}

# Function to configure shell integration
# Args: $1 - shell type (bash, zsh, profile, all)
# Returns: 0 on success, 1 on failure
atuin_configure_shell() {
    local shell_type="$1"
    log_debug "Configuring Atuin for $shell_type" "$MODULE_NAME"
    
    # Check if Atuin is installed
    if ! atuin_is_installed; then
        log_error "Atuin is not installed" "$MODULE_NAME"
        return 1
    fi
    
    local result=0
    
    # Configure for bash
    if [ "$shell_type" = "bash" ] || [ "$shell_type" = "all" ]; then
        local bashrc="$HOME/.bashrc"
        if [ -f "$bashrc" ]; then
            local bash_content=$(atuin_generate_bash_init_content)
            if ! safe_insert "Atuin shell integration" "$bashrc" "$bash_content"; then
                log_error "Failed to configure Atuin for bash" "$MODULE_NAME"
                result=1
            else
                log_info "Atuin configured for bash" "$MODULE_NAME"
            fi
        else
            log_warning "Bash config file not found: $bashrc" "$MODULE_NAME"
        fi
    fi
    
    # Configure for zsh
    if [ "$shell_type" = "zsh" ] || [ "$shell_type" = "all" ]; then
        local zshrc="$HOME/.zshrc"
        if [ -f "$zshrc" ]; then
            local zsh_content=$(atuin_generate_zsh_init_content)
            if ! safe_insert "Atuin shell integration" "$zshrc" "$zsh_content"; then
                log_error "Failed to configure Atuin for zsh" "$MODULE_NAME"
                result=1
            else
                log_info "Atuin configured for zsh" "$MODULE_NAME"
            fi
        else
            log_warning "Zsh config file not found: $zshrc" "$MODULE_NAME"
        fi
    fi
    
    # Configure for profile
    if [ "$shell_type" = "profile" ] || [ "$shell_type" = "all" ]; then
        local profile="$HOME/.profile"
        if [ -f "$profile" ]; then
            local profile_content=$(atuin_generate_profile_init_content)
            if ! safe_insert "Atuin environment setup" "$profile" "$profile_content"; then
                log_error "Failed to configure Atuin for profile" "$MODULE_NAME"
                result=1
            else
                log_info "Atuin configured for profile" "$MODULE_NAME"
            fi
        else
            log_warning "Profile config file not found: $profile" "$MODULE_NAME"
        fi
    fi

    
    return $result
}

# Function to configure Atuin settings
# Args: $1 - sync enabled (true/false)
# Returns: 0 on success, 1 on failure
atuin_configure_settings() {
    local sync_enabled="${1:-true}"
    log_debug "Configuring Atuin settings (sync: $sync_enabled)" "$MODULE_NAME"
    
    # Ensure config directory exists
    local config_dir="$HOME/.config/atuin"
    if ! ensure_directory "$config_dir" "0700"; then
        log_error "Failed to create Atuin config directory" "$MODULE_NAME"
        return 1
    fi
    
    # Generate and write config
    local config_file="$config_dir/config.toml"
    local config_content=$(atuin_generate_config_content "$sync_enabled")
    
    if ! safe_insert "Atuin configuration" "$config_file" "$config_content"; then
        log_error "Failed to write Atuin configuration" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Atuin settings configured" "$MODULE_NAME"
    return 0
}

# Function to login to Atuin sync service
# Args: $1 - username, $2 - password, $3 - key (optional)
# Returns: 0 on success, 1 on failure
atuin_login() {
    local username="$1"
    local password="$2"
    local key="$3"
    
    log_debug "Logging in to Atuin sync service" "$MODULE_NAME"
    
    # Check if Atuin is installed
    if ! atuin_is_installed; then
        log_error "Atuin is not installed" "$MODULE_NAME"
        return 1
    fi
    
    # Check if already logged in (source environment first)
    local sync_output
    sync_output=$(source "$HOME/.atuin/bin/env" 2>/dev/null && "$HOME/.atuin/bin/atuin" sync 2>&1)
    if echo "$sync_output" | grep -q -E "(You are not logged in|not logged in)"; then
        log_debug "Not currently logged in to Atuin" "$MODULE_NAME"
    else
        log_info "Already logged in to Atuin" "$MODULE_NAME"
        return 0
    fi
    
    # Login with provided credentials
    log_debug "Attempting login for username: $username (password length: ${#password})" "$MODULE_NAME"
    if [ -n "$key" ]; then
        # Login with encryption key
        log_debug "Using encryption key (length: ${#key})" "$MODULE_NAME"
        "$HOME/.atuin/bin/atuin" login --username "$username" --password "$password" --key "$key"
    else
        # Login without encryption key (will generate one)
        log_debug "No encryption key provided" "$MODULE_NAME"
        "$HOME/.atuin/bin/atuin" login --username "$username" --password "$password"
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Successfully logged in to Atuin as $username" "$MODULE_NAME"
        
        # Show the encryption key for backup
        local encryption_key=$("$HOME/.atuin/bin/atuin" key)
        log_warning "IMPORTANT: Save your encryption key: $encryption_key" "$MODULE_NAME"
        log_warning "Store this key in a password manager - you'll need it to access your history on other machines" "$MODULE_NAME"
        
        return 0
    else
        log_error "Failed to login to Atuin" "$MODULE_NAME"
        return 1
    fi
}

# Function to register a new Atuin account
# Args: $1 - username, $2 - email, $3 - password
# Returns: 0 on success, 1 on failure
atuin_register() {
    local username="$1"
    local email="$2"
    local password="$3"
    
    log_debug "Registering new Atuin account" "$MODULE_NAME"
    
    # Check if Atuin is installed
    if ! atuin_is_installed; then
        log_error "Atuin is not installed" "$MODULE_NAME"
        return 1
    fi
    
    # Register new account
    "$HOME/.atuin/bin/atuin" register --username "$username" --email "$email" --password "$password"
    
    if [ $? -eq 0 ]; then
        log_info "Successfully registered Atuin account for $username" "$MODULE_NAME"
        
        # Show the encryption key for backup
        local encryption_key=$("$HOME/.atuin/bin/atuin" key)
        log_warning "IMPORTANT: Save your encryption key: $encryption_key" "$MODULE_NAME"
        log_warning "Store this key in a password manager - you'll need it to access your history on other machines" "$MODULE_NAME"
        
        return 0
    else
        log_error "Failed to register Atuin account" "$MODULE_NAME"
        return 1
    fi
}

# Function to import existing shell history
# Returns: 0 on success, 1 on failure
atuin_import_history() {
    log_debug "Importing existing shell history" "$MODULE_NAME"
    
    # Check if Atuin is installed
    if ! atuin_is_installed; then
        log_error "Atuin is not installed" "$MODULE_NAME"
        return 1
    fi
    
    # Import history based on current shell
    local current_shell=$(basename "$SHELL")
    
    if "$HOME/.atuin/bin/atuin" import auto; then
        log_info "Successfully imported shell history" "$MODULE_NAME"
        
        # Sync if logged in
        if ! "$HOME/.atuin/bin/atuin" sync 2>&1 | grep -q "You are not logged in"; then
            log_info "Syncing imported history..." "$MODULE_NAME"
            "$HOME/.atuin/bin/atuin" sync
        fi
        
        return 0
    else
        log_error "Failed to import shell history" "$MODULE_NAME"
        return 1
    fi
}

# Function to sync Atuin history
# Returns: 0 on success, 1 on failure
atuin_sync_history() {
    log_debug "Syncing Atuin history" "$MODULE_NAME"
    
    # Check if Atuin is installed
    if ! atuin_is_installed; then
        log_error "Atuin is not installed" "$MODULE_NAME"
        return 1
    fi
    
    # Source environment and run sync
    log_info "Syncing Atuin history with server..." "$MODULE_NAME"
    local sync_output
    sync_output=$(source "$HOME/.atuin/bin/env" 2>/dev/null && "$HOME/.atuin/bin/atuin" sync 2>&1)
    
    if [ $? -eq 0 ]; then
        log_info "Atuin sync completed successfully" "$MODULE_NAME"
        # Show sync summary if available
        echo "$sync_output" | grep -E "(Sync complete|Downloading|Uploading)" | while read -r line; do
            log_info "$line" "$MODULE_NAME"
        done
        return 0
    else
        log_error "Failed to sync Atuin history: $sync_output" "$MODULE_NAME"
        return 1
    fi
}

# Function to remove Atuin
# Returns: 0 on success, 1 on failure
atuin_remove() {
    log_debug "Removing Atuin installation and configuration" "$MODULE_NAME"
    
    # Remove shell integrations
    if [ -f "$HOME/.bashrc" ]; then
        local bash_content=$(atuin_generate_bash_init_content)
        safe_remove "Atuin shell integration" "$HOME/.bashrc" "$bash_content" || true
    fi
    
    if [ -f "$HOME/.zshrc" ]; then
        local zsh_content=$(atuin_generate_zsh_init_content)
        safe_remove "Atuin shell integration" "$HOME/.zshrc" "$zsh_content" || true
    fi
    
    if [ -f "$HOME/.profile" ]; then
        local profile_content=$(atuin_generate_profile_init_content)
        safe_remove "Atuin environment setup" "$HOME/.profile" "$profile_content" || true
    fi
    
    # Remove Atuin directory
    if [ -d "$HOME/.atuin" ]; then
        log_info "Removing Atuin installation directory" "$MODULE_NAME"
        rm -rf "$HOME/.atuin"
    fi
    
    # Remove config directory
    if [ -d "$HOME/.config/atuin" ]; then
        log_info "Removing Atuin configuration directory" "$MODULE_NAME"
        rm -rf "$HOME/.config/atuin"
    fi
    
    # Remove data directory
    if [ -d "$HOME/.local/share/atuin" ]; then
        log_info "Removing Atuin data directory" "$MODULE_NAME"
        rm -rf "$HOME/.local/share/atuin"
    fi
    
    log_info "Atuin removed successfully" "$MODULE_NAME"
    return 0
}

# Main function for the atuin module
# Usage: atuin_main [options]
# Options:
#   --shell SHELL     Configure for specific shell (bash, zsh, profile, all)
#   --no-sync         Disable sync in configuration
#   --login           Login to existing account (requires --username and --password)
#   --register        Register new account (requires --username, --email, and --password)
#   --username USER   Username for login/registration
#   --email EMAIL     Email for registration
#   --password PASS   Password for login/registration
#   --key KEY         Encryption key for login (optional)
#   --import          Import existing shell history
#   --sync            Sync history with server after setup
#   --remove          Remove Atuin installation
#   --help            Display this help message
# Returns: 0 on success, 1 on failure
atuin_main() {
    # Save previous module context
    local PREV_MODULE_NAME="$MODULE_NAME"
    local PREV_MODULE_DESCRIPTION="$MODULE_DESCRIPTION"
    local PREV_MODULE_VERSION="$MODULE_VERSION"
    
    # Set this module's context
    MODULE_NAME="atuin"
    MODULE_DESCRIPTION="Install and configure Atuin shell history manager"
    MODULE_VERSION="1.0.0"
    
    log_debug "Atuin module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local shell_type="all"
    local sync_enabled="true"
    local do_login=false
    local do_register=false
    local do_import=false
    local do_sync=false
    local remove=false
    local username=""
    local email=""
    local password=""
    local key=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --shell)
                shell_type="$2"
                shift 2
                ;;
            --no-sync)
                sync_enabled="false"
                shift
                ;;
            --login)
                do_login=true
                shift
                ;;
            --register)
                do_register=true
                shift
                ;;
            --username)
                username="$2"
                shift 2
                ;;
            --email)
                email="$2"
                shift 2
                ;;
            --password)
                password="$2"
                shift 2
                ;;
            --key)
                key="$2"
                shift 2
                ;;
            --import)
                do_import=true
                shift
                ;;
            --sync)
                do_sync=true
                shift
                ;;
            --remove)
                remove=true
                shift
                ;;
            --help)
                # Display help message
                cat <<-EOF
Usage: atuin_main [options]
Options:
  --shell SHELL     Configure for specific shell (bash, zsh, profile, all)
  --no-sync         Disable sync in configuration
  --login           Login to existing account (requires --username and --password)
  --register        Register new account (requires --username, --email, and --password)
  --username USER   Username for login/registration
  --email EMAIL     Email for registration
  --password PASS   Password for login/registration
  --key KEY         Encryption key for login (optional)
  --import          Import existing shell history
  --sync            Sync history with server after setup
  --remove          Remove Atuin installation
  --help            Display this help message
EOF
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 0
                ;;
            *)
                log_error "Unknown option: $1" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
                ;;
        esac
    done
    
    # Validate shell type
    if [ "$shell_type" != "bash" ] && [ "$shell_type" != "zsh" ] && [ "$shell_type" != "profile" ] && [ "$shell_type" != "all" ]; then
        log_error "Invalid shell type: $shell_type. Must be 'bash', 'zsh', 'profile', or 'all'" "$MODULE_NAME"
        # Restore previous module context
        MODULE_NAME="$PREV_MODULE_NAME"
        MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
        MODULE_VERSION="$PREV_MODULE_VERSION"
        return 1
    fi
    
    # Handle interactive input for login/register if needed
    if $do_login && [ -z "$username" -o -z "$password" ]; then
        echo ""
        echo "=== Atuin Login ==="
        echo "Please provide your Atuin account credentials to sync shell history."
        echo ""
        
        # Prompt for username if not provided
        if [ -z "$username" ]; then
            username=$(prompt_input "Atuin username")
            if [ -z "$username" ]; then
                log_error "Username is required for login" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        fi
        
        # Prompt for password if not provided
        if [ -z "$password" ]; then
            password=$(prompt_password "Atuin password (hidden)")
            if [ -z "$password" ]; then
                log_error "Password is required for login" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        fi
        
        # Prompt for encryption key if not provided
        if [ -z "$key" ]; then
            echo ""
            echo "=== Encryption Key (Optional) ==="
            echo "If you're syncing from another machine, enter the same encryption key."
            echo "You can find it by running 'atuin key' on the other machine."
            echo "Leave blank to generate a new key (for first-time setup)."
            echo ""
            key=$(prompt_input "Encryption key (or press Enter to skip)")
            # If user just pressed enter, key will be empty which is fine
        fi

    fi
    
    if $do_register && [ -z "$username" -o -z "$email" -o -z "$password" ]; then
        echo ""
        echo "=== Atuin Registration ==="
        echo "Create a new Atuin account to sync your shell history across devices."
        echo "Your history is end-to-end encrypted and only you can read it."
        echo ""
        
        # Prompt for username if not provided
        if [ -z "$username" ]; then
            username=$(prompt_input "Choose a username")
            if [ -z "$username" ]; then
                log_error "Username is required for registration" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        fi
        
        # Prompt for email if not provided
        if [ -z "$email" ]; then
            email=$(prompt_input "Email address (for account recovery)")
            if [ -z "$email" ]; then
                log_error "Email is required for registration" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        fi
        
        # Prompt for password if not provided
        if [ -z "$password" ]; then
            echo ""
            echo "Choose a strong password for your account."
            password=$(prompt_password "Password (hidden)")
            if [ -z "$password" ]; then
                log_error "Password is required for registration" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
            
            # Confirm password
            local password_confirm=$(prompt_password "Confirm password (hidden)")
            if [ "$password" != "$password_confirm" ]; then
                log_error "Passwords do not match" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        fi
    fi
    
    # Ask for confirmation if not in auto-confirm mode
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if $remove; then
            if ! confirm "Remove Atuin installation and all data?"; then
                log_warning "Atuin removal cancelled by user" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        else
            if ! confirm "Install and configure Atuin?"; then
                log_warning "Atuin installation cancelled by user" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        fi
    fi
    
    # Execute requested operation
    local result=0
    
    if $remove; then
        if ! atuin_remove; then
            log_error "Failed to remove Atuin" "$MODULE_NAME"
            result=1
        fi
    else
        # Install Atuin
        if ! atuin_install; then
            log_error "Failed to install Atuin" "$MODULE_NAME"
            result=1
        else
            # Configure shell integration
            if ! atuin_configure_shell "$shell_type"; then
                log_error "Failed to configure shell integration" "$MODULE_NAME"
                result=1
            fi
            
            # Configure settings
            if ! atuin_configure_settings "$sync_enabled"; then
                log_error "Failed to configure Atuin settings" "$MODULE_NAME"
                result=1
            fi
            
            # Register new account if requested
            if $do_register && [ $result -eq 0 ]; then
                if ! atuin_register "$username" "$email" "$password"; then
                    log_error "Failed to register Atuin account" "$MODULE_NAME"
                    result=1
                fi
            fi
            
            # Login if requested
            if $do_login && [ $result -eq 0 ]; then
                if ! atuin_login "$username" "$password" "$key"; then
                    log_error "Failed to login to Atuin" "$MODULE_NAME"
                    result=1
                fi
            fi
            
            # Import history if requested
            if $do_import && [ $result -eq 0 ]; then
                if ! atuin_import_history; then
                    log_error "Failed to import shell history" "$MODULE_NAME"
                    result=1
                fi
            fi
            
            # Sync history if requested
            if $do_sync && [ $result -eq 0 ]; then
                if ! atuin_sync_history; then
                    log_error "Failed to sync history" "$MODULE_NAME"
                    result=1
                fi
            fi
        fi
    fi
    
    if [ $result -eq 0 ]; then
        if $remove; then
            log_info "Atuin removal completed successfully" "$MODULE_NAME"
        else
            log_info "Atuin setup completed successfully" "$MODULE_NAME"
            log_info "Restart your shell or run 'source ~/.bashrc' to start using Atuin" "$MODULE_NAME"
        fi
    else
        log_error "Atuin operation completed with errors" "$MODULE_NAME"
    fi
    
    # Restore previous module context
    MODULE_NAME="$PREV_MODULE_NAME"
    MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
    MODULE_VERSION="$PREV_MODULE_VERSION"
    
    return $result
}

# Export only the main function
export -f atuin_main

# Module metadata
MODULE_COMMANDS=(
    "atuin_main:Install and configure Atuin shell history manager"
)
export MODULE_COMMANDS

log_debug "Atuin module loaded" "atuin"