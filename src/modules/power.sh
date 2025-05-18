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

# Function to set power mode to performance
set_power_mode_performance() {
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
    
    # Ask for confirmation
    log_info "Current power mode: $current_mode" "$MODULE_NAME"
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Set power mode to performance?"; then
            log_warning "Power mode change cancelled by user" "$MODULE_NAME"
            return 1
        fi
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

# Function to disable screen blank (screen saver)
disable_screen_blank() {
    log_debug "Disabling screen blank/screen saver" "$MODULE_NAME"
    
    # Ensure dconf directories exist
    Sudo ensure_directory "/etc/dconf/profile" "0755"
    Sudo ensure_directory "/etc/dconf/db/local.d" "0755"
    
    # Create dconf profile for system-wide settings if it doesn't exist
    local filename="/etc/dconf/profile/user"
    local title_line="user-db:user"
    local content=(
        "system-db:local"
    )
    
    Sudo safe_insert "Create dconf profile for system-wide settings" "$filename" "$title_line" "${content[@]}"
    
    # Configure screen blank settings in dconf
    filename="/etc/dconf/db/local.d/00-screen_blank"
    title_line="[org/gnome/desktop/session]"
    content=(
        "idle-delay=uint32 0"
    )
    
    Sudo safe_insert "Disable screen blank (never turn off screen)" "$filename" "$title_line" "${content[@]}"
    
    # Update dconf database
    Sudo dconf update
    
    log_info "Screen blank disabled" "$MODULE_NAME"
    return 0
}

# Function to disable automatic suspend
disable_automatic_suspend() {
    log_debug "Disabling automatic suspend" "$MODULE_NAME"
    
    # Ensure dconf directories exist
    Sudo ensure_directory "/etc/dconf/profile" "0755"
    Sudo ensure_directory "/etc/dconf/db/local.d" "0755"
    
    # Create dconf profile for system-wide settings if it doesn't exist
    local filename="/etc/dconf/profile/user"
    local title_line="user-db:user"
    local content=(
        "system-db:local"
    )
    
    Sudo safe_insert "Create dconf profile for system-wide settings" "$filename" "$title_line" "${content[@]}"
    
    # Configure automatic suspend settings in dconf
    filename="/etc/dconf/db/local.d/00-automatic_suspend"
    title_line="[org/gnome/settings-daemon/plugins/power]"
    content=(
        "sleep-inactive-ac-type='nothing'"
    )
    
    Sudo safe_insert "Disable automatic suspend" "$filename" "$title_line" "${content[@]}"
    
    # Update dconf database
    Sudo dconf update
    
    log_info "Automatic suspend disabled" "$MODULE_NAME"
    return 0
}

# Main function to set up all power settings
setup_power_settings() {
    log_info "Setting up system power settings" "$MODULE_NAME"
    
    # Set up each power setting
    set_power_mode_performance
    disable_screen_blank
    disable_automatic_suspend
    
    log_info "Power settings setup completed" "$MODULE_NAME"
    return 0
}

# Export the main function
export -f setup_power_settings
export -f set_power_mode_performance
export -f disable_screen_blank
export -f disable_automatic_suspend

# Module metadata
MODULE_COMMANDS=(
    "setup_power_settings:Setup all power settings"
    "set_power_mode_performance:Set power mode to performance"
    "disable_screen_blank:Disable screen blank/screen saver"
    "disable_automatic_suspend:Disable automatic suspend"
)
export MODULE_COMMANDS

log_debug "Power module loaded" "$MODULE_NAME"