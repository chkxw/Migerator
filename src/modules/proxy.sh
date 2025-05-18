#!/bin/bash

# Level 2 abstraction: Proxy module
# This module handles setting up proxy for various services

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"

# Module info
MODULE_NAME="proxy"
MODULE_DESCRIPTION="Configure system-wide proxy settings"
MODULE_VERSION="1.0.0"

log_debug "Loading proxy module" "$MODULE_NAME"

# Function to configure proxy settings in environment for both login and non-login shells
setup_proxy_env() {
    log_debug "Setting up proxy environment variables" "$MODULE_NAME"
    
    local host="${PROXY_CONFIG[host]}"
    local port="${PROXY_CONFIG[port]}"
    
    # Check if proxy settings are valid
    if [ -z "$host" ] || [ -z "$port" ]; then
        log_error "Invalid proxy settings: host=$host, port=$port" "$MODULE_NAME"
        return 1
    fi
    
    # Format the proxy URLs
    local http_proxy="http://${host}:${port}/"
    local https_proxy="http://${host}:${port}/"
    local ftp_proxy="ftp://${host}:${port}/"
    
    log_info "Configuring proxy settings:" "$MODULE_NAME"
    log_info "  HTTP_PROXY: $http_proxy" "$MODULE_NAME"
    log_info "  HTTPS_PROXY: $https_proxy" "$MODULE_NAME"
    log_info "  FTP_PROXY: $ftp_proxy" "$MODULE_NAME"
    
    # Confirm proxy settings if not in auto-confirm mode
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Are these proxy settings correct?"; then
            log_warning "Proxy setup cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Configure proxy for login shells
    local filename="/etc/profile.d/proxy.sh"
    local title_line="# Proxy settings for WISC CS Building"
    local content=(
        "export http_proxy=\"${http_proxy}\""
        "export https_proxy=\"${https_proxy}\""
        "export ftp_proxy=\"${ftp_proxy}\""
        "export no_proxy=\"localhost,127.0.0.1,::1\""
        "#For curl"
        "export HTTP_PROXY=\"${http_proxy}\""
        "export HTTPS_PROXY=\"${https_proxy}\""
        "export FTP_PROXY=\"${ftp_proxy}\""
        "export NO_PROXY=\"localhost,127.0.0.1,::1\""
    )
    
    Sudo safe_insert "Login shells proxy" "$filename" "$title_line" "${content[@]}"
    
    # Configure proxy for non-login shells
    filename="/etc/bash.bashrc"
    title_line="# Proxy settings for WISC CS Building"
    content=(
        "source /etc/profile.d/proxy.sh"
    )
    
    Sudo safe_insert "Non-login shells proxy" "$filename" "$title_line" "${content[@]}"
    
    log_info "Proxy environment variables configured" "$MODULE_NAME"
    return 0
}

# Function to configure apt proxy settings
setup_proxy_apt() {
    log_debug "Setting up apt proxy settings" "$MODULE_NAME"
    
    local host="${PROXY_CONFIG[host]}"
    local port="${PROXY_CONFIG[port]}"
    
    # Format the proxy URLs
    local http_proxy="http://${host}:${port}"
    local https_proxy="http://${host}:${port}"
    local ftp_proxy="ftp://${host}:${port}"
    
    # Configure APT proxy
    local filename="/etc/apt/apt.conf.d/proxy.conf"
    local title_line="# Proxy settings for WISC CS Building"
    local content=(
        "Acquire::http::Proxy \"${http_proxy}\";"
        "Acquire::https::Proxy \"${https_proxy}\";"
        "Acquire::ftp::Proxy \"${ftp_proxy}\";"
    )
    
    Sudo safe_insert "Apt proxy" "$filename" "$title_line" "${content[@]}"
    
    log_info "APT proxy configured" "$MODULE_NAME"
    return 0
}

# Function to configure git proxy settings
setup_proxy_git() {
    log_debug "Setting up git proxy settings" "$MODULE_NAME"
    
    local host="${PROXY_CONFIG[host]}"
    local port="${PROXY_CONFIG[port]}"
    
    # Configure GIT proxy
    local filename="/etc/gitconfig"
    local title_line="[https]"
    local content=(
        "    proxy = http://${host}:${port}"
        "[http]"
        "    proxy = http://${host}:${port}"
    )
    
    Sudo safe_insert "Configure Git settings" "$filename" "$title_line" "${content[@]}"
    
    log_info "Git proxy configured" "$MODULE_NAME"
    return 0
}

# Function to configure SSH proxy for GitHub/GitLab access
setup_proxy_ssh() {
    log_debug "Setting up SSH proxy for GitHub/GitLab access" "$MODULE_NAME"
    
    local host="${PROXY_CONFIG[host]}"
    local port="${PROXY_CONFIG[port]}"
    
    # Check if corkscrew is installed
    if ! check_package_installed "corkscrew"; then
        log_warning "corkscrew package is not installed, installing now" "$MODULE_NAME"
        Sudo apt update >/dev/null
        Sudo apt install -y corkscrew
        if [ $? -ne 0 ]; then
            log_error "Failed to install corkscrew package" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Configure GitHub.com proxy for SSH access
    local filename="/etc/ssh/ssh_config"
    local title_line="# Proxy settings to use SSH over HTTPS to access GitHub"
    local content=(
        "Host github.com"
        "    User git"
        "    Port 443"
        "    Hostname ssh.github.com"
        "    IdentitiesOnly yes"
        "    TCPKeepAlive yes"
        "    ProxyCommand corkscrew ${host} ${port} %h %p"
        "Host ssh.github.com"
        "    User git"
        "    Port 443"
        "    Hostname ssh.github.com"
        "    IdentitiesOnly yes"
        "    TCPKeepAlive yes"
        "    ProxyCommand corkscrew ${host} ${port} %h %p"
    )
    
    Sudo safe_insert "GitHub.com proxy for SSH access" "$filename" "$title_line" "${content[@]}"
    
    # Configure Gitee.com proxy for SSH access
    title_line="# Proxy settings to use SSH over HTTPS to access Gitee"
    content=(
        "Host gitee.com"
        "    User git"
        "    Port 443"
        "    Hostname ssh.gitee.com"
        "    IdentitiesOnly yes"
        "    TCPKeepAlive yes"
        "    ProxyCommand corkscrew ${host} ${port} %h %p"
        "Host ssh.gitee.com"
        "    User git"
        "    Port 443"
        "    Hostname ssh.gitee.com"
        "    IdentitiesOnly yes"
        "    TCPKeepAlive yes"
        "    ProxyCommand corkscrew ${host} ${port} %h %p"
    )
    
    Sudo safe_insert "Gitee.com proxy for SSH access" "$filename" "$title_line" "${content[@]}"
    
    log_info "SSH proxy for Git hosts configured" "$MODULE_NAME"
    return 0
}

# Function to configure dconf proxy settings (for GNOME desktop)
setup_proxy_dconf() {
    log_debug "Setting up dconf proxy settings" "$MODULE_NAME"
    
    local host="${PROXY_CONFIG[host]}"
    local port="${PROXY_CONFIG[port]}"
    
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
    
    # Configure proxy settings in dconf
    filename="/etc/dconf/db/local.d/00-proxy"
    title_line="[system/proxy]"
    content=(
        "mode='manual'"
        "[system/proxy/http]"
        "host='${host}'"
        "port=${port}"
        "[system/proxy/https]"
        "host='${host}'"
        "port=${port}"
        "[system/proxy/ftp]"
        "host='${host}'"
        "port=${port}"
    )
    
    Sudo safe_insert "System proxy settings in dconf" "$filename" "$title_line" "${content[@]}"
    
    # Update dconf database
    Sudo dconf update
    
    log_info "Dconf proxy settings configured" "$MODULE_NAME"
    return 0
}

# Main function to set up all proxy settings
setup_proxy() {
    log_info "Setting up system-wide proxy configuration" "$MODULE_NAME"
    
    # Check if proxy is enabled
    if [ "${PROXY_CONFIG[enabled]}" != "true" ]; then
        log_warning "Proxy configuration is disabled, skipping setup" "$MODULE_NAME"
        return 0
    fi
    
    # Set up proxy in various places
    setup_proxy_env
    setup_proxy_apt
    setup_proxy_git
    setup_proxy_ssh
    setup_proxy_dconf
    
    # Source the proxy settings to apply them immediately
    if [ -f "/etc/profile.d/proxy.sh" ]; then
        source /etc/profile.d/proxy.sh
        log_info "Proxy settings applied to current session" "$MODULE_NAME"
    fi
    
    log_info "Proxy setup completed successfully" "$MODULE_NAME"
    return 0
}

# Export the main function
export -f setup_proxy
export -f setup_proxy_env
export -f setup_proxy_apt
export -f setup_proxy_git
export -f setup_proxy_ssh
export -f setup_proxy_dconf

# Module metadata
MODULE_COMMANDS=(
    "setup_proxy:Setup all proxy settings"
    "setup_proxy_env:Setup proxy environment variables"
    "setup_proxy_apt:Setup proxy for APT package manager"
    "setup_proxy_git:Setup proxy for Git"
    "setup_proxy_ssh:Setup SSH proxy for GitHub/GitLab access"
    "setup_proxy_dconf:Setup proxy in dconf (GNOME desktop)"
)
export MODULE_COMMANDS

log_debug "Proxy module loaded" "$MODULE_NAME"