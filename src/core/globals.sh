#!/bin/bash

# Global variables for the setup script
# This file contains all the global variables and configurations used across the script

# Source the logger to use logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"

log_debug "Loading global variables" "globals"

# Proxy configuration
declare -A PROXY_CONFIG
PROXY_CONFIG[host]="squid.cs.wisc.edu"
PROXY_CONFIG[port]="3128"
PROXY_CONFIG[enabled]="false"

# User configuration
declare -A USER_CONFIG
USER_CONFIG[default_password]="badgerrl"
USER_CONFIG[admin]="badgerrl"
USER_CONFIG[shared_group]="rllab"
USER_CONFIG[shared_dir]="/home/Shared"
USER_CONFIG[net_shared_dir]="NetShared"

# Conda configuration
declare -A CONDA_CONFIG
CONDA_CONFIG[path]="/usr/local/miniconda3"
CONDA_CONFIG[env_path]="/home/Shared/conda_envs"
CONDA_CONFIG[type]="miniconda" # or "miniforge"

# Script behavior configuration
declare -A SCRIPT_CONFIG
SCRIPT_CONFIG[confirm_all]="false"
SCRIPT_CONFIG[log_level]="2" # INFO level

# Array of regular users (regular lab members)
declare -a LAB_USERS=(
    "Joseph Zhong"
    "Chen Li"
    "Erika Sy"
    "Allen Chien"
    "Nicholas Corrado"
    "Andrew Wang"
    "Subhojyoti Mukerjee"
    "Brahma Pavse"
    "Will Cong"
    "Alan Zhong"
    "Brennen Hill"
    "Jeffrey Zou"
    "Zisen Shao"
)

# Array of super users (will be given sudo access)
declare -a LAB_SUPER_USERS=(
    "Benjamin Hong"
    "Abhinav Harish"
    "Adam Labiosa"
    "Yunfu Deng"
    "Yuhao Li"
)

# Package repository information
# Structure: nickname pkg_formal_name gpg_key_url pkg_arch pkg_version_codename pkg_branch pkg_deb_src repo_base_url
declare -A PKG_FORMAL_NAME
declare -A PKG_GPG_KEY_URL
declare -A PKG_ARCH
declare -A PKG_VERSION_CODENAME
declare -A PKG_BRANCH
declare -A PKG_DEB_SRC
declare -A PKG_REPO_BASE_URL

# Chrome
PKG_FORMAL_NAME[chrome]="google-chrome-stable"
PKG_GPG_KEY_URL[chrome]="https://dl.google.com/linux/linux_signing_key.pub"
PKG_ARCH[chrome]="amd64"
PKG_VERSION_CODENAME[chrome]="stable"
PKG_BRANCH[chrome]="main"
PKG_DEB_SRC[chrome]="false"
PKG_REPO_BASE_URL[chrome]="http://dl.google.com/linux/chrome/deb/"

# VS Code
PKG_FORMAL_NAME[vscode]="code"
PKG_GPG_KEY_URL[vscode]="https://packages.microsoft.com/keys/microsoft.asc"
PKG_ARCH[vscode]="amd64"
PKG_VERSION_CODENAME[vscode]="stable"
PKG_BRANCH[vscode]="main"
PKG_DEB_SRC[vscode]="false"
PKG_REPO_BASE_URL[vscode]="https://packages.microsoft.com/repos/code"

# Docker
PKG_FORMAL_NAME[docker]="docker-ce"
PKG_GPG_KEY_URL[docker]="https://download.docker.com/linux/ubuntu/gpg"
PKG_ARCH[docker]="amd64"
PKG_VERSION_CODENAME[docker]="$OS_CODENAME"
PKG_BRANCH[docker]="stable"
PKG_DEB_SRC[docker]="false"
PKG_REPO_BASE_URL[docker]="https://download.docker.com/linux/ubuntu"

# NodeJS
PKG_FORMAL_NAME[nodejs]="nodejs"
PKG_GPG_KEY_URL[nodejs]="https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
PKG_ARCH[nodejs]="amd64"
PKG_VERSION_CODENAME[nodejs]="nodistro"
PKG_BRANCH[nodejs]="main"
PKG_DEB_SRC[nodejs]="false"
PKG_REPO_BASE_URL[nodejs]="https://deb.nodesource.com/node_21.x"

# VirtualGL
PKG_FORMAL_NAME[virtualgl]="virtualgl"
PKG_GPG_KEY_URL[virtualgl]="https://packagecloud.io/dcommander/virtualgl/gpgkey"
PKG_ARCH[virtualgl]="amd64"
PKG_VERSION_CODENAME[virtualgl]="any"
PKG_BRANCH[virtualgl]="main"
PKG_DEB_SRC[virtualgl]="false"
PKG_REPO_BASE_URL[virtualgl]="https://packagecloud.io/dcommander/virtualgl/any/"

# TurboVNC
PKG_FORMAL_NAME[turbovnc]="turbovnc"
PKG_GPG_KEY_URL[turbovnc]="https://packagecloud.io/dcommander/turbovnc/gpgkey"
PKG_ARCH[turbovnc]="amd64"
PKG_VERSION_CODENAME[turbovnc]="any"
PKG_BRANCH[turbovnc]="main"
PKG_DEB_SRC[turbovnc]="false"
PKG_REPO_BASE_URL[turbovnc]="https://packagecloud.io/dcommander/turbovnc/any/"

# Slack
PKG_FORMAL_NAME[slack]="slack-desktop"
PKG_GPG_KEY_URL[slack]="https://packagecloud.io/slacktechnologies/slack/gpgkey"
PKG_ARCH[slack]="amd64"
PKG_VERSION_CODENAME[slack]="jessie"
PKG_BRANCH[slack]="main"
PKG_DEB_SRC[slack]="true"
PKG_REPO_BASE_URL[slack]="https://packagecloud.io/slacktechnologies/slack/debian/"

# Wine
PKG_FORMAL_NAME[wine]="winehq-stable"
PKG_GPG_KEY_URL[wine]="https://dl.winehq.org/wine-builds/winehq.key"
PKG_ARCH[wine]="amd64,i386"
PKG_VERSION_CODENAME[wine]="$OS_CODENAME"
PKG_BRANCH[wine]="main"
PKG_DEB_SRC[wine]="false"
PKG_REPO_BASE_URL[wine]="https://dl.winehq.org/wine-builds/ubuntu"

# Function to get a global variable
# Usage: global_vars key
# Returns: The value of the key or empty if not found
global_vars() {
    local key="$1"
    local value=""
    
    log_debug "Retrieving global variable: $key" "globals"
    
    # Check in each config map
    for config_map in "PROXY_CONFIG" "USER_CONFIG" "CONDA_CONFIG" "SCRIPT_CONFIG"; do
        value=$(get_value "$config_map" "$key")
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    done
    
    # Handle arrays
    case "$key" in
        "users")
            echo "${LAB_USERS[@]}"
            ;;
        "super_users")
            echo "${LAB_SUPER_USERS[@]}"
            ;;
        "package_repos")
            echo "${!PKG_FORMAL_NAME[@]}"
            ;;
        *)
            log_warning "Global variable not found: $key" "globals"
            return 1
            ;;
    esac
}

# Function to set a global variable
# Usage: set_global_var key value
# Returns: 0 on success, 1 on failure
set_global_var() {
    local key="$1"
    local value="$2"
    
    log_debug "Setting global variable: $key = $value" "globals"
    
    # Determine which config map to update
    case "$key" in
        "host"|"port"|"enabled")
            PROXY_CONFIG[$key]="$value"
            ;;
        "default_password"|"admin"|"shared_group"|"shared_dir"|"net_shared_dir")
            USER_CONFIG[$key]="$value"
            ;;
        "path"|"env_path"|"type")
            CONDA_CONFIG[$key]="$value"
            ;;
        "confirm_all"|"log_level")
            SCRIPT_CONFIG[$key]="$value"
            if [ "$key" = "log_level" ]; then
                set_log_level "$value"
            fi
            ;;
        *)
            log_warning "Unknown global variable: $key" "globals"
            return 1
            ;;
    esac
    
    return 0
}

# Export functions for use in other scripts
export -f global_vars
export -f set_global_var

# Export arrays and maps
export LAB_USERS
export LAB_SUPER_USERS
export PKG_FORMAL_NAME
export PKG_GPG_KEY_URL
export PKG_ARCH
export PKG_VERSION_CODENAME
export PKG_BRANCH
export PKG_DEB_SRC
export PKG_REPO_BASE_URL
export PROXY_CONFIG
export USER_CONFIG
export CONDA_CONFIG
export SCRIPT_CONFIG

log_debug "Global variables loaded" "globals"