#!/bin/bash

# Level 2 abstraction: SSH Server module
# This module handles SSH server setup and configuration

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"
source "$PROJECT_ROOT/src/core/package_manager.sh"

# Log with hard-coded module name for initial loading
log_debug "Loading SSH server module" "ssh_server"

# Function to generate SSH server configuration content
# Usage: ssh_server_generate_config [port]
# Returns: Configuration content as a string
ssh_server_generate_config() {
    local port="${1:-22}"
    
    local content="# SSH Server Configuration
Port $port
PermitRootLogin no
PasswordAuthentication yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server"

    echo "$content"
}

# Function to set up SSH server 
# Usage: ssh_server_setup [port]
# Returns: 0 on success, 1 on failure
ssh_server_setup() {
    local port="${1:-22}"
    local config_file="/etc/ssh/sshd_config.d/custom.conf"
    
    log_debug "Setting up SSH server with port $port" "$MODULE_NAME"
    
    # Check if OpenSSH server is installed
    if ! command -v sshd &>/dev/null; then
        log_warning "OpenSSH server is not installed, installing now" "$MODULE_NAME"
        Sudo apt update >/dev/null
        Sudo apt install -y openssh-server
        
        if [ $? -ne 0 ]; then
            log_error "Failed to install OpenSSH server" "$MODULE_NAME"
            return 1
        fi
    else
        log_info "OpenSSH server is already installed" "$MODULE_NAME"
    fi
    
    # Generate and apply configuration
    local config_content=$(ssh_server_generate_config "$port")
    
    # Safely add configuration with sudo
    if ! Sudo safe_insert "Configure SSH server" "$config_file" "$config_content"; then
        log_error "Failed to configure SSH server" "$MODULE_NAME"
        return 1
    fi
    
    # Enable and start SSH service
    log_info "Enabling and starting SSH service" "$MODULE_NAME"
    Sudo systemctl enable ssh
    Sudo systemctl start ssh
    
    if [ $? -ne 0 ]; then
        log_error "Failed to enable/start SSH service" "$MODULE_NAME"
        return 1
    fi
    
    # Configure firewall if ufw is installed
    if command -v ufw &>/dev/null; then
        log_info "Allowing SSH through firewall on port $port" "$MODULE_NAME"
        if [ "$port" -eq 22 ]; then
            Sudo ufw allow ssh
        else
            Sudo ufw allow "$port/tcp"
        fi
        
        if [ $? -ne 0 ]; then
            log_warning "Failed to configure firewall for SSH" "$MODULE_NAME"
            # Not returning error as firewall configuration is optional
        fi
    else
        log_info "UFW firewall is not installed, skipping firewall configuration" "$MODULE_NAME"
    fi
    
    log_info "SSH server setup completed successfully" "$MODULE_NAME"
    return 0
}

# Function to remove SSH server configuration
# Usage: ssh_server_cleanup [port]
# Returns: 0 on success, 1 on failure
ssh_server_cleanup() {
    local port="${1:-22}"
    local config_file="/etc/ssh/sshd_config.d/custom.conf"
    
    log_debug "Removing SSH server configuration" "$MODULE_NAME"
    
    # Generate content to remove
    local config_content=$(ssh_server_generate_config "$port")
    
    # Safely remove configuration with sudo
    if ! Sudo safe_remove "Remove SSH server configuration" "$config_file" "$config_content"; then
        log_error "Failed to remove SSH server configuration" "$MODULE_NAME"
        return 1
    fi
    
    # Disable and stop SSH service if requested
    log_info "Disabling and stopping SSH service" "$MODULE_NAME"
    Sudo systemctl disable ssh
    Sudo systemctl stop ssh
    
    if [ $? -ne 0 ]; then
        log_error "Failed to disable/stop SSH service" "$MODULE_NAME"
        return 1
    fi
    
    log_info "SSH server cleanup completed successfully" "$MODULE_NAME"
    return 0
}

# Main function for SSH server module
# Usage: ssh_server_main [options]
# Options:
#   --port PORT       Set SSH port number (default: 22)
#   --cleanup         Remove SSH server configuration and disable service
#   --help            Display this help message
# Returns: 0 on success, 1 on failure
ssh_server_main() {
    # Save previous module context
    local PREV_MODULE_NAME="$MODULE_NAME"
    local PREV_MODULE_DESCRIPTION="$MODULE_DESCRIPTION"
    local PREV_MODULE_VERSION="$MODULE_VERSION"
    
    # Set this module's context
    MODULE_NAME="ssh_server"
    MODULE_DESCRIPTION="Setup and configure SSH server"
    MODULE_VERSION="1.0.0"
    
    log_debug "SSH server module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local port=22
    local cleanup=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port)
                port="$2"
                shift 2
                ;;
            --cleanup)
                cleanup=true
                shift
                ;;
            --help)
                # Display help message
                cat <<-EOF
Usage: ssh_server_main [options]
Options:
  --port PORT       Set SSH port number (default: 22)
  --cleanup         Remove SSH server configuration and disable service
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
    
    # Ask for confirmation if needed
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if $cleanup; then
            if ! confirm "Remove SSH server configuration and disable service?"; then
                log_warning "SSH server cleanup cancelled by user" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        else
            if ! confirm "Set up SSH server with port $port?"; then
                log_warning "SSH server setup cancelled by user" "$MODULE_NAME"
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
    if $cleanup; then
        if ! ssh_server_cleanup "$port"; then
            log_error "SSH server cleanup failed" "$MODULE_NAME"
            result=1
        fi
    else
        if ! ssh_server_setup "$port"; then
            log_error "SSH server setup failed" "$MODULE_NAME"
            result=1
        fi
    fi
    
    # Restore previous module context
    MODULE_NAME="$PREV_MODULE_NAME"
    MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
    MODULE_VERSION="$PREV_MODULE_VERSION"
    
    return $result
}

# Export only the main function and necessary functions
export -f ssh_server_main
export -f ssh_server_setup
export -f ssh_server_cleanup
export -f ssh_server_generate_config

# Module metadata
MODULE_COMMANDS=(
    "ssh_server_main:Setup and configure SSH server"
)
export MODULE_COMMANDS

log_debug "SSH server module loaded" "ssh_server"