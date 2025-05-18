#!/bin/bash

# Core utility functions for the setup script
# These are the base Level 0 helper functions that will be used throughout the script

# Source the logger to use logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"

# Function to confirm an action with the user
# Usage: confirm "Message" [default_yes]
# Returns: 0 for yes, 1 for no
confirm() {
    local hint_message="$1"
    local default_response="$2"
    local prompt_suffix="(Y/N)"
    
    # Check if CONFIRM_ALL environment variable is set to skip confirmation
    if [ "${CONFIRM_ALL:-false}" = "true" ]; then
        log_debug "Auto-confirming due to CONFIRM_ALL=true" "confirm"
        return 0
    fi
    
    # Set default response if provided
    if [ "$default_response" = "Y" ] || [ "$default_response" = "y" ]; then
        prompt_suffix="(Y/n)"
    elif [ "$default_response" = "N" ] || [ "$default_response" = "n" ]; then
        prompt_suffix="(y/N)"
    fi
    
    while true; do
        echo -e -n "$hint_message $prompt_suffix: "
        read -r user_response
        
        # Handle default responses
        if [ -z "$user_response" ]; then
            if [ "$default_response" = "Y" ] || [ "$default_response" = "y" ]; then
                user_response="y"
            elif [ "$default_response" = "N" ] || [ "$default_response" = "n" ]; then
                user_response="n"
            fi
        fi
        
        case "$user_response" in
            [Yy]*)
                log_debug "User confirmed: $hint_message" "confirm"
                echo -e "\033[34;1mChanges confirmed.\033[0m"
                return 0
                ;;
            [Nn]*)
                log_debug "User declined: $hint_message" "confirm"
                echo -e "\033[31;1mChanges not applied.\033[0m"
                return 1
                ;;
            *)
                echo -e "\033[31;1mInvalid input. Please enter Y or N.\033[0m"
                ;;
        esac
    done
}

# Function to create a symbolic link if it doesn't exist
# Usage: create_symlink source target
# Returns: 0 on success, 1 on failure
create_symlink() {
    local source="$1"
    local target="$2"

    log_debug "Attempting to create symlink: $target -> $source" "create_symlink"

    if [ ! -e "$source" ]; then
        log_error "Source '$source' does not exist." "create_symlink"
        return 1
    fi

    if [ -e "$target" ]; then
        if [ -L "$target" ]; then
            local existing_target=$(readlink "$target")
            if [ "$existing_target" != "$source" ]; then
                log_warning "$target already exists and points to a different location: $existing_target" "create_symlink"
                return 1
            else
                log_info "Symbolic link already exists: $target -> $source" "create_symlink"
                return 0
            fi
        else
            log_warning "$target already exists and is not a symbolic link." "create_symlink"
            return 1
        fi
    fi

    ln -s "$source" "$target"
    if [ "$?" -eq 0 ]; then
        log_info "Symbolic link created: $target -> $source" "create_symlink"
        return 0
    else
        log_error "Error creating symbolic link: $target -> $source" "create_symlink"
        return 1
    fi
}

# Function to check if a package is installed
# Usage: check_package_installed PKG_FORMAL_NAME
# Returns: 0 if installed, 1 if not found, 2 if package not in repos, 3 if not installed
check_package_installed() {
    local PKG_FORMAL_NAME="$1"
    log_debug "Checking if package '$PKG_FORMAL_NAME' is installed" "check_package"
    
    local package_status=$(apt-cache policy "$PKG_FORMAL_NAME" 2>/dev/null | grep -E '^\s+Installed:' | awk '{print $2}')
    if [ "$?" -eq 1 ]; then
        log_error "Error checking package status for $PKG_FORMAL_NAME" "check_package"
        return 1
    elif ! apt-cache show "${PKG_FORMAL_NAME}" &>/dev/null; then
        log_warning "Package $PKG_FORMAL_NAME not found in repositories" "check_package"
        return 2
    elif [ "$package_status" == "(none)" ]; then
        log_debug "Package $PKG_FORMAL_NAME is not installed" "check_package"
        return 3
    else
        log_debug "Package $PKG_FORMAL_NAME is installed (version: $package_status)" "check_package"
        return 0
    fi
}

# Function to check internet connectivity
# Usage: check_internet_connection
# Returns: 0 if connected, 1 if not connected
check_internet_connection() {
    log_debug "Checking internet connection" "check_internet"
    
    if ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log_debug "Internet connection is available" "check_internet"
        return 0
    else
        log_warning "No internet connection available" "check_internet"
        return 1
    fi
}

# Normalize URL to prevent double slashes
normalize_url() {
    local url="$1"
    # Replace double slashes (but not in http:// or https://)
    echo "$url" | sed -E 's#([^:])//+#\1/#g'
}

# Function to ensure the script is run as root
# Usage: ensure_root
# Returns: N/A (exits script if not root)
ensure_root() {
    log_debug "Checking if running as root" "ensure_root"
    
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This function must be run as root" "ensure_root"
        exit 1
    fi
    
    log_debug "Running as root, proceeding" "ensure_root"
}

# Function to get value from a key-value mapping
# Usage: get_value map_name key
# Returns: Value or empty if not found
get_value() {
    local map_name="$1"
    local key="$2"
    
    # Use associative array if supported
    if declare -p "$map_name" 2>/dev/null | grep -q "declare -A"; then
        local ref="$map_name[$key]"
        echo "${!ref}"
    else
        # Fallback to eval for older bash versions
        local line
        eval "for key_val in \"\${${map_name}[@]}\"; do
            if [[ \"\$key_val\" == \"$key=\"* ]]; then
                echo \"\${key_val#*=}\"
                break
            fi
        done"
    fi
}

# Function to detect OS information
# Usage: detect_os_info
# Sets globals: OS_NAME, OS_VERSION, OS_CODENAME
detect_os_info() {
    log_debug "Detecting OS information" "detect_os"
    
    # Get OS information from /etc/os-release
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        OS_CODENAME=$VERSION_CODENAME
    elif [ -f /etc/lsb-release ]; then
        source /etc/lsb-release
        OS_NAME=$DISTRIB_ID
        OS_VERSION=$DISTRIB_RELEASE
        OS_CODENAME=$DISTRIB_CODENAME
    else
        # Fallback detection
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
        OS_CODENAME="unknown"
    fi
    
    # Convert to lowercase
    OS_NAME=$(echo "$OS_NAME" | tr '[:upper:]' '[:lower:]')
    OS_CODENAME=$(echo "$OS_CODENAME" | tr '[:upper:]' '[:lower:]')
    
    # Export variables
    export OS_NAME
    export OS_VERSION
    export OS_CODENAME
    
    log_info "Detected OS: $OS_NAME $OS_VERSION ($OS_CODENAME)" "detect_os"
}

# Function to create directory if it doesn't exist
# Usage: ensure_directory directory [mode]
# Returns: 0 on success, 1 on failure
ensure_directory() {
    local directory="$1"
    local mode="${2:-755}"
    
    log_debug "Ensuring directory exists: $directory (mode: $mode)" "ensure_dir"
    
    if [ -d "$directory" ]; then
        log_debug "Directory already exists: $directory" "ensure_dir"
        return 0
    fi
    
    mkdir -p -m "$mode" "$directory"
    if [ $? -eq 0 ]; then
        log_info "Created directory: $directory (mode: $mode)" "ensure_dir"
        return 0
    else
        log_error "Failed to create directory: $directory" "ensure_dir"
        return 1
    fi
}

# Export all functions
export -f confirm
export -f create_symlink
export -f check_package_installed
export -f check_internet_connection
export -f ensure_root
export -f get_value
export -f detect_os_info
export -f ensure_directory