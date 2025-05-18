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

# Log with hard-coded module name for initial loading
log_debug "Loading proxy module" "proxy"

# Function to generate proxy environment variables content
# Args: $1 - host, $2 - port
# Returns: configuration content as a string
proxy_generate_env_content() {
    local host="$1"
    local port="$2"
    
    local http_proxy="http://${host}:${port}/"
    local https_proxy="http://${host}:${port}/"
    local ftp_proxy="ftp://${host}:${port}/"
    
    local content="# System Proxy
export http_proxy=\"${http_proxy}\"
export https_proxy=\"${https_proxy}\"
export ftp_proxy=\"${ftp_proxy}\"
export no_proxy=\"localhost,127.0.0.1,::1\"
#For curl
export HTTP_PROXY=\"${http_proxy}\"
export HTTPS_PROXY=\"${https_proxy}\"
export FTP_PROXY=\"${ftp_proxy}\"
export NO_PROXY=\"localhost,127.0.0.1,::1\""

    echo "$content"
}

# Function to generate apt proxy configuration content
# Args: $1 - host, $2 - port
# Returns: configuration content as a string
proxy_generate_apt_content() {
    local host="$1"
    local port="$2"
    
    local http_proxy="http://${host}:${port}"
    local https_proxy="http://${host}:${port}"
    local ftp_proxy="ftp://${host}:${port}"
    
    local content="# System Proxy
Acquire::http::Proxy \"${http_proxy}\";
Acquire::https::Proxy \"${https_proxy}\";
Acquire::ftp::Proxy \"${ftp_proxy}\";"

    echo "$content"
}

# Function to generate git proxy configuration content
# Args: $1 - host, $2 - port
# Returns: configuration content as a string
proxy_generate_git_content() {
    local host="$1"
    local port="$2"
    
    local content="[https]
    proxy = http://${host}:${port}
[http]
    proxy = http://${host}:${port}"

    echo "$content"
}

# Function to generate SSH proxy configuration for GitHub/GitLab
# Args: $1 - host, $2 - port
# Returns: configuration content as a string
proxy_generate_ssh_github_content() {
    local host="$1"
    local port="$2"
    
    local content="# Proxy settings to use SSH over HTTPS to access GitHub
Host github.com
    User git
    Port 443
    Hostname ssh.github.com
    IdentitiesOnly yes
    TCPKeepAlive yes
    ProxyCommand corkscrew ${host} ${port} %h %p
Host ssh.github.com
    User git
    Port 443
    Hostname ssh.github.com
    IdentitiesOnly yes
    TCPKeepAlive yes
    ProxyCommand corkscrew ${host} ${port} %h %p"

    echo "$content"
}

# Function to generate SSH proxy configuration for Gitee
# Args: $1 - host, $2 - port
# Returns: configuration content as a string
proxy_generate_ssh_gitee_content() {
    local host="$1"
    local port="$2"
    
    local content="# Proxy settings to use SSH over HTTPS to access Gitee
Host gitee.com
    User git
    Port 443
    Hostname ssh.gitee.com
    IdentitiesOnly yes
    TCPKeepAlive yes
    ProxyCommand corkscrew ${host} ${port} %h %p
Host ssh.gitee.com
    User git
    Port 443
    Hostname ssh.gitee.com
    IdentitiesOnly yes
    TCPKeepAlive yes
    ProxyCommand corkscrew ${host} ${port} %h %p"

    echo "$content"
}

# Function to generate dconf proxy configuration content
# Args: $1 - host, $2 - port
# Returns: configuration content as a string
proxy_generate_dconf_content() {
    local host="$1"
    local port="$2"
    
    local content="[system/proxy]
mode='manual'
[system/proxy/http]
host='${host}'
port=${port}
[system/proxy/https]
host='${host}'
port=${port}
[system/proxy/ftp]
host='${host}'
port=${port}"

    echo "$content"
}

# Function to generate dconf profile content
# Returns: configuration content as a string
proxy_generate_dconf_profile_content() {
    local content="user-db:user
system-db:local"

    echo "$content"
}

# Function to setup proxy for a single system service
# Args: $1 - service name (env, apt, git, ssh, dconf), $2 - host, $3 - port
# Returns: 0 on success, 1 on failure
proxy_setup_service() {
    local service="$1"
    local host="$2"
    local port="$3"
    
    log_debug "Setting up proxy for $service" "$MODULE_NAME"
    
    case "$service" in
        env)
            local content=$(proxy_generate_env_content "$host" "$port")
            local filename="/etc/profile.d/proxy.sh"
            
            # Configure proxy for login shells
            if ! Sudo safe_insert "Login shells proxy" "$filename" "$content"; then
                log_error "Failed to configure proxy for login shells" "$MODULE_NAME"
                return 1
            fi
            
            # Configure proxy for non-login shells
            local bashrc_content="# System Proxy
source /etc/profile.d/proxy.sh"
            
            if ! Sudo safe_insert "Non-login shells proxy" "/etc/bash.bashrc" "$bashrc_content"; then
                log_error "Failed to configure proxy for non-login shells" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        apt)
            local content=$(proxy_generate_apt_content "$host" "$port")
            local filename="/etc/apt/apt.conf.d/proxy.conf"
            
            if ! Sudo safe_insert "Apt proxy" "$filename" "$content"; then
                log_error "Failed to configure proxy for APT" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        git)
            local content=$(proxy_generate_git_content "$host" "$port")
            local filename="/etc/gitconfig"
            
            if ! Sudo safe_insert "Configure Git settings" "$filename" "$content"; then
                log_error "Failed to configure proxy for Git" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        ssh)
            # Check if corkscrew is installed
            if ! command -v corkscrew &>/dev/null; then
                log_warning "corkscrew package is not installed, installing now" "$MODULE_NAME"
                Sudo apt update >/dev/null
                Sudo apt install -y corkscrew
                if [ $? -ne 0 ]; then
                    log_error "Failed to install corkscrew package" "$MODULE_NAME"
                    return 1
                fi
            fi
            
            local filename="/etc/ssh/ssh_config"
            
            # Configure GitHub.com proxy
            local github_content=$(proxy_generate_ssh_github_content "$host" "$port")
            if ! Sudo safe_insert "GitHub.com proxy for SSH access" "$filename" "$github_content"; then
                log_error "Failed to configure GitHub proxy for SSH" "$MODULE_NAME"
                return 1
            fi
            
            # Configure Gitee.com proxy
            local gitee_content=$(proxy_generate_ssh_gitee_content "$host" "$port")
            if ! Sudo safe_insert "Gitee.com proxy for SSH access" "$filename" "$gitee_content"; then
                log_error "Failed to configure Gitee proxy for SSH" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        dconf)
            # Ensure dconf directories exist
            Sudo ensure_directory "/etc/dconf/profile" "0755"
            Sudo ensure_directory "/etc/dconf/db/local.d" "0755"
            
            # Create dconf profile
            local profile_content=$(proxy_generate_dconf_profile_content)
            if ! Sudo safe_insert "Create dconf profile for system-wide settings" "/etc/dconf/profile/user" "$profile_content"; then
                log_error "Failed to configure dconf profile" "$MODULE_NAME"
                return 1
            fi
            
            # Configure proxy settings in dconf
            local content=$(proxy_generate_dconf_content "$host" "$port")
            if ! Sudo safe_insert "System proxy settings in dconf" "/etc/dconf/db/local.d/00-proxy" "$content"; then
                log_error "Failed to configure proxy in dconf" "$MODULE_NAME"
                return 1
            fi
            
            # Update dconf database
            Sudo dconf update
            ;;
            
        *)
            log_error "Unknown service: $service" "$MODULE_NAME"
            return 1
            ;;
    esac
    
    log_info "Proxy configured for $service" "$MODULE_NAME"
    return 0
}

# Function to remove proxy configuration for a single service
# Args: $1 - service name (env, apt, git, ssh, dconf), $2 - host, $3 - port
# Returns: 0 on success, 1 on failure
proxy_remove_service() {
    local service="$1"
    local host="$2"
    local port="$3"
    
    log_debug "Removing proxy for $service" "$MODULE_NAME"
    
    case "$service" in
        env)
            local content=$(proxy_generate_env_content "$host" "$port")
            local filename="/etc/profile.d/proxy.sh"
            
            # Remove proxy for login shells
            if ! Sudo safe_remove "Login shells proxy" "$filename" "$content"; then
                log_error "Failed to remove proxy for login shells" "$MODULE_NAME"
                return 1
            fi
            
            # Remove proxy from non-login shells
            local bashrc_content="# System Proxy
source /etc/profile.d/proxy.sh"
            
            if ! Sudo safe_remove "Non-login shells proxy" "/etc/bash.bashrc" "$bashrc_content"; then
                log_error "Failed to remove proxy for non-login shells" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        apt)
            local content=$(proxy_generate_apt_content "$host" "$port")
            local filename="/etc/apt/apt.conf.d/proxy.conf"
            
            if ! Sudo safe_remove "Apt proxy" "$filename" "$content"; then
                log_error "Failed to remove proxy for APT" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        git)
            local content=$(proxy_generate_git_content "$host" "$port")
            local filename="/etc/gitconfig"
            
            if ! Sudo safe_remove "Configure Git settings" "$filename" "$content"; then
                log_error "Failed to remove proxy for Git" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        ssh)
            local filename="/etc/ssh/ssh_config"
            
            # Remove GitHub.com proxy
            local github_content=$(proxy_generate_ssh_github_content "$host" "$port")
            if ! Sudo safe_remove "GitHub.com proxy for SSH access" "$filename" "$github_content"; then
                log_error "Failed to remove GitHub proxy for SSH" "$MODULE_NAME"
                return 1
            fi
            
            # Remove Gitee.com proxy
            local gitee_content=$(proxy_generate_ssh_gitee_content "$host" "$port")
            if ! Sudo safe_remove "Gitee.com proxy for SSH access" "$filename" "$gitee_content"; then
                log_error "Failed to remove Gitee proxy for SSH" "$MODULE_NAME"
                return 1
            fi
            ;;
            
        dconf)
            # Remove dconf proxy settings
            local content=$(proxy_generate_dconf_content "$host" "$port")
            if ! Sudo safe_remove "System proxy settings in dconf" "/etc/dconf/db/local.d/00-proxy" "$content"; then
                log_error "Failed to remove proxy from dconf" "$MODULE_NAME"
                return 1
            fi
            
            # Update dconf database
            Sudo dconf update
            ;;
            
        *)
            log_error "Unknown service: $service" "$MODULE_NAME"
            return 1
            ;;
    esac
    
    log_info "Proxy removed for $service" "$MODULE_NAME"
    return 0
}

# Main function for the proxy module
# Usage: proxy_main [options]
# Options:
#   --host HOST       Set proxy host
#   --port PORT       Set proxy port
#   --services SRVS   Comma-separated list of services to configure (default: all)
#   --remove          Remove proxy configuration instead of adding it
#   --help            Display this help message
# Returns: 0 on success, 1 on failure
proxy_main() {
    # Save previous module context
    local PREV_MODULE_NAME="$MODULE_NAME"
    local PREV_MODULE_DESCRIPTION="$MODULE_DESCRIPTION"
    local PREV_MODULE_VERSION="$MODULE_VERSION"
    
    # Set this module's context
    MODULE_NAME="proxy"
    MODULE_DESCRIPTION="Configure system-wide proxy settings"
    MODULE_VERSION="1.0.0"
    
    log_debug "Proxy module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local host="${PROXY_CONFIG[host]}"
    local port="${PROXY_CONFIG[port]}"
    local services="env,apt,git,ssh,dconf"
    local remove=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host)
                host="$2"
                shift 2
                ;;
            --port)
                port="$2"
                shift 2
                ;;
            --services)
                services="$2"
                shift 2
                ;;
            --remove)
                remove=true
                shift
                ;;
            --help)
                # Display help message
                cat <<-EOF
Usage: proxy_main [options]
Options:
  --host HOST       Set proxy host (default: ${PROXY_CONFIG[host]})
  --port PORT       Set proxy port (default: ${PROXY_CONFIG[port]})
  --services SRVS   Comma-separated list of services to configure
                     Available services: env,apt,git,ssh,dconf
                     Default: all
  --remove          Remove proxy configuration instead of adding it
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
    
    # Check if proxy settings are valid
    if [ -z "$host" ] || [ -z "$port" ]; then
        log_error "Invalid proxy settings: host=$host, port=$port" "$MODULE_NAME"
        # Restore previous module context
        MODULE_NAME="$PREV_MODULE_NAME"
        MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
        MODULE_VERSION="$PREV_MODULE_VERSION"
        return 1
    fi
    
    # Log proxy settings
    log_info "Using proxy settings:" "$MODULE_NAME"
    log_info "  Host: $host" "$MODULE_NAME"
    log_info "  Port: $port" "$MODULE_NAME"
    log_info "  Services: $services" "$MODULE_NAME"
    
    # Confirm proxy settings if not in auto-confirm mode
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if $remove; then
            if ! confirm "Remove proxy configuration with these settings?"; then
                log_warning "Proxy removal cancelled by user" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        else
            if ! confirm "Configure proxy with these settings?"; then
                log_warning "Proxy setup cancelled by user" "$MODULE_NAME"
                # Restore previous module context
                MODULE_NAME="$PREV_MODULE_NAME"
                MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
                MODULE_VERSION="$PREV_MODULE_VERSION"
                return 1
            fi
        fi
    fi
    
    # Convert services string to array
    IFS=',' read -ra service_array <<< "$services"
    
    # Process each service
    local result=0
    for service in "${service_array[@]}"; do
        if $remove; then
            if ! proxy_remove_service "$service" "$host" "$port"; then
                log_error "Failed to remove proxy for $service" "$MODULE_NAME"
                result=1
            fi
        else
            if ! proxy_setup_service "$service" "$host" "$port"; then
                log_error "Failed to configure proxy for $service" "$MODULE_NAME"
                result=1
            fi
        fi
    done
    
    # Apply environment variables immediately if env service was modified
    if [[ "$services" == *"env"* ]] && [ -f "/etc/profile.d/proxy.sh" ] && [ "$remove" = false ]; then
        source /etc/profile.d/proxy.sh
        log_info "Proxy settings applied to current session" "$MODULE_NAME"
    fi
    
    if [ $result -eq 0 ]; then
        if $remove; then
            log_info "Proxy configuration removed successfully" "$MODULE_NAME"
        else
            log_info "Proxy configuration completed successfully" "$MODULE_NAME"
        fi
    else
        if $remove; then
            log_error "Proxy configuration removal completed with errors" "$MODULE_NAME"
        else
            log_error "Proxy configuration completed with errors" "$MODULE_NAME"
        fi
    fi
    
    # Restore previous module context
    MODULE_NAME="$PREV_MODULE_NAME"
    MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
    MODULE_VERSION="$PREV_MODULE_VERSION"
    
    return $result
}

# Export only the main function and necessary functions
export -f proxy_main
export -f proxy_setup_service
export -f proxy_remove_service

# Module metadata
MODULE_COMMANDS=(
    "proxy_main:Configure system-wide proxy settings"
)
export MODULE_COMMANDS

log_debug "Proxy module loaded" "proxy"