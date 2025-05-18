#!/bin/bash

# Level 2 abstraction: Power module
# This module handles configuring power settings for the system

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"

# Module info
MODULE_NAME="power"
MODULE_DESCRIPTION="Configure system power settings"
MODULE_VERSION="1.0.0"

log_debug "Loading power module" "$MODULE_NAME"

# Function to generate dconf profile content
# Returns: configuration content as a string
power_generate_dconf_profile_content() {
    local content="user-db:user
system-db:local"

    echo "$content"
}

# Function to generate screen blank settings content
# Returns: configuration content as a string
power_generate_screen_blank_content() {
    local content="[org/gnome/desktop/session]
idle-delay=uint32 0"

    echo "$content"
}

# Function to generate automatic suspend settings content
# Returns: configuration content as a string
power_generate_suspend_content() {
    local content="[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'"

    echo "$content"
}

# Function to set power mode to performance
# Returns: 0 on success, 1 on failure
power_set_performance() {
    log_debug "Setting power mode to performance" "$MODULE_NAME"
    
    # Check if powerprofilesctl is available
    if ! command -v powerprofilesctl &>/dev/null; then
        log_warning "powerprofilesctl not found, installing power-profiles-daemon" "$MODULE_NAME"
        Sudo apt update >/dev/null
        Sudo apt install -y power-profiles-daemon
        if [ $? -ne 0 ]; then
            log_error "Failed to install power-profiles-daemon" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Check current power mode
    current_mode=$(powerprofilesctl get 2>/dev/null)
    
    if [ "$current_mode" = "performance" ]; then
        log_info "Power mode is already set to performance" "$MODULE_NAME"
        return 0
    fi
    
    # Set power mode to performance
    Sudo powerprofilesctl set performance
    if [ $? -eq 0 ]; then
        log_info "Power mode set to performance" "$MODULE_NAME"
        return 0
    else
        log_error "Failed to set power mode to performance" "$MODULE_NAME"
        return 1
    fi
}

# Function to configure dconf settings
# Args: $1 - setting type (screen_blank, suspend)
# Returns: 0 on success, 1 on failure
power_configure_dconf() {
    local setting_type="$1"
    log_debug "Configuring dconf for $setting_type" "$MODULE_NAME"
    
    # Ensure dconf directories exist
    Sudo ensure_directory "/etc/dconf/profile" "0755"
    Sudo ensure_directory "/etc/dconf/db/local.d" "0755"
    
    # Create dconf profile for system-wide settings if it doesn't exist
    local profile_content=$(power_generate_dconf_profile_content)
    local profile_file="/etc/dconf/profile/user"
    
    if ! Sudo safe_insert "Create dconf profile for system-wide settings" "$profile_file" "$profile_content"; then
        log_error "Failed to create dconf profile" "$MODULE_NAME"
        return 1
    fi
    
    # Configure specific settings based on type
    case "$setting_type" in
        screen_blank)
            local content=$(power_generate_screen_blank_content)
            local filename="/etc/dconf/db/local.d/00-screen_blank"
            
            if ! Sudo safe_insert "Disable screen blank (never turn off screen)" "$filename" "$content"; then
                log_error "Failed to configure screen blank settings" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        suspend)
            local content=$(power_generate_suspend_content)
            local filename="/etc/dconf/db/local.d/00-automatic_suspend"
            
            if ! Sudo safe_insert "Disable automatic suspend" "$filename" "$content"; then
                log_error "Failed to configure automatic suspend settings" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        *)
            log_error "Unknown dconf setting type: $setting_type" "$MODULE_NAME"
            return 1
            ;;
    esac
    
    # Update dconf database
    Sudo dconf update
    
    return 0
}

# Function to remove dconf settings
# Args: $1 - setting type (screen_blank, suspend)
# Returns: 0 on success, 1 on failure
power_remove_dconf() {
    local setting_type="$1"
    log_debug "Removing dconf configuration for $setting_type" "$MODULE_NAME"
    
    # Remove specific settings based on type
    case "$setting_type" in
        screen_blank)
            local content=$(power_generate_screen_blank_content)
            local filename="/etc/dconf/db/local.d/00-screen_blank"
            
            if ! Sudo safe_remove "Disable screen blank (never turn off screen)" "$filename" "$content"; then
                log_error "Failed to remove screen blank settings" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        suspend)
            local content=$(power_generate_suspend_content)
            local filename="/etc/dconf/db/local.d/00-automatic_suspend"
            
            if ! Sudo safe_remove "Disable automatic suspend" "$filename" "$content"; then
                log_error "Failed to remove automatic suspend settings" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        *)
            log_error "Unknown dconf setting type: $setting_type" "$MODULE_NAME"
            return 1
            ;;
    esac
    
    # Update dconf database
    Sudo dconf update
    
    return 0
}

# Main function for the power module
# Usage: power_main [options]
# Options:
#   --performance     Set power mode to performance
#   --no-blank        Disable screen blank/screen saver
#   --no-suspend      Disable automatic suspend
#   --all             Apply all power settings (default)
#   --remove          Remove power settings instead of adding them
#   --help            Display this help message
# Returns: 0 on success, 1 on failure
power_main() {
    log_debug "Power module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local performance=false
    local no_blank=false
    local no_suspend=false
    local all=true
    local remove=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --performance)
                performance=true
                all=false
                shift
                ;;
            --no-blank)
                no_blank=true
                all=false
                shift
                ;;
            --no-suspend)
                no_suspend=true
                all=false
                shift
                ;;
            --all)
                all=true
                performance=false
                no_blank=false
                no_suspend=false
                shift
                ;;
            --remove)
                remove=true
                shift
                ;;
            --help)
                # Display help message
                cat <<-EOF
Usage: power_main [options]
Options:
  --performance     Set power mode to performance
  --no-blank        Disable screen blank/screen saver
  --no-suspend      Disable automatic suspend
  --all             Apply all power settings (default)
  --remove          Remove power settings instead of adding them
  --help            Display this help message
EOF
                return 0
                ;;
            *)
                log_error "Unknown option: $1" "$MODULE_NAME"
                return 1
                ;;
        esac
    done
    
    # If all is selected, enable all options
    if $all; then
        performance=true
        no_blank=true
        no_suspend=true
    fi
    
    # Ask for confirmation if not in auto-confirm mode
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        local action="configure"
        [[ $remove == true ]] && action="remove"
        
        local settings=""
        $performance && settings+="performance power mode, "
        $no_blank && settings+="disable screen blank, "
        $no_suspend && settings+="disable auto suspend, "
        settings=${settings%, }
        
        if ! confirm "$action power settings ($settings)?"; then
            log_warning "Power settings $action cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Apply or remove each selected setting
    local result=0
    
    if $performance && [ "$remove" = false ]; then
        if ! power_set_performance; then
            log_error "Failed to set power mode to performance" "$MODULE_NAME"
            result=1
        fi
    fi
    
    if $no_blank; then
        if $remove; then
            if ! power_remove_dconf "screen_blank"; then
                log_error "Failed to remove screen blank settings" "$MODULE_NAME"
                result=1
            fi
        else
            if ! power_configure_dconf "screen_blank"; then
                log_error "Failed to configure screen blank settings" "$MODULE_NAME"
                result=1
            fi
        fi
    fi
    
    if $no_suspend; then
        if $remove; then
            if ! power_remove_dconf "suspend"; then
                log_error "Failed to remove automatic suspend settings" "$MODULE_NAME"
                result=1
            fi
        else
            if ! power_configure_dconf "suspend"; then
                log_error "Failed to configure automatic suspend settings" "$MODULE_NAME"
                result=1
            fi
        fi
    fi
    
    if [ $result -eq 0 ]; then
        if $remove; then
            log_info "Power settings removed successfully" "$MODULE_NAME"
        else
            log_info "Power settings configured successfully" "$MODULE_NAME"
        fi
    else
        if $remove; then
            log_error "Power settings removal completed with errors" "$MODULE_NAME"
        else
            log_error "Power settings configuration completed with errors" "$MODULE_NAME"
        fi
    fi
    
    return $result
}

# Export only the main function and necessary functions
export -f power_main

# Module metadata
MODULE_COMMANDS=(
    "power_main:Configure system power settings"
)
export MODULE_COMMANDS

log_debug "Power module loaded" "$MODULE_NAME"