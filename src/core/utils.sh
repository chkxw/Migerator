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
    
    # Check if SCRIPT_CONFIG[confirm_all] is set to skip confirmation
    if [ "${SCRIPT_CONFIG[confirm_all]:-false}" = "true" ]; then
        log_debug "Auto-confirming due to SCRIPT_CONFIG[confirm_all]=true" "confirm"
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

# Function to create a symbolic link, replacing any existing file or symlink
# Usage: create_symlink source target [force]
# Returns: 0 on success, 1 on failure
create_symlink() {
    local source="$1"
    local target="$2"
    local force="${3:-false}"

    log_debug "Attempting to create symlink: $target -> $source" "create_symlink"

    # Check if the source exists
    if [ ! -e "$source" ]; then
        log_error "Source '$source' does not exist." "create_symlink"
        return 1
    fi

    # Check if the target already exists
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ "$force" = "true" ] || [ "$force" = "force" ]; then
            # Force mode: remove existing target
            log_info "Removing existing target: $target" "create_symlink"
            rm -rf "$target"
            if [ $? -ne 0 ]; then
                log_error "Failed to remove existing target: $target" "create_symlink"
                return 1
            fi
        elif [ -L "$target" ]; then
            # If it's a symlink, check if it already points to our source
            local existing_target=$(readlink "$target")
            if [ "$existing_target" = "$source" ]; then
                log_info "Symbolic link already points to correct location: $target -> $source" "create_symlink"
                return 0
            else
                log_warning "Target $target exists and points to a different location: $existing_target" "create_symlink"
                return 1
            fi
        else
            # Target exists but is not a symlink and force is not set
            log_warning "Target $target already exists and is not a symbolic link" "create_symlink"
            return 1
        fi
    fi

    # Create parent directory if it doesn't exist
    local parent_dir=$(dirname "$target")
    if [ ! -d "$parent_dir" ]; then
        log_debug "Creating parent directory: $parent_dir" "create_symlink"
        mkdir -p "$parent_dir"
        if [ $? -ne 0 ]; then
            log_error "Failed to create parent directory: $parent_dir" "create_symlink"
            return 1
        fi
    fi

    # Create the symlink
    ln -s "$source" "$target"
    if [ $? -eq 0 ]; then
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
    
    # Force English locale to ensure consistent output parsing
    local package_status=$(LC_ALL=C apt-cache policy "$PKG_FORMAL_NAME" 2>/dev/null | grep -E '^\s+Installed:' | awk '{print $2}')
    if [ "$?" -eq 1 ]; then
        log_error "Error checking package status for $PKG_FORMAL_NAME" "check_package"
        return 1
    elif ! LC_ALL=C apt-cache show "${PKG_FORMAL_NAME}" &>/dev/null; then
        log_warning "Package $PKG_FORMAL_NAME not found in repositories" "check_package"
        return 2
    elif [ "$package_status" == "(none)" ] || [ -z "$package_status" ]; then
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
    # Check if already detected (caching)
    if [[ -n "$OS_NAME" ]] && [[ -n "$OS_VERSION" ]] && [[ -n "$OS_CODENAME" ]]; then
        log_debug "Using cached OS information: $OS_NAME $OS_VERSION ($OS_CODENAME)" "detect_os"
        return 0
    fi
    
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

# Function to prompt user for input
# Usage: prompt_input "prompt message" [default_value]
# Returns: User input via echo
prompt_input() {
    local prompt_message="$1"
    local default_value="$2"
    local user_input
    
    if [ -n "$default_value" ]; then
        echo -n "$prompt_message [$default_value]: " >&2
    else
        echo -n "$prompt_message: " >&2
    fi
    
    read -r user_input
    
    # Use default if no input provided
    if [ -z "$user_input" ] && [ -n "$default_value" ]; then
        user_input="$default_value"
    fi
    
    echo "$user_input"
}

# Function to prompt user for password (hidden input)
# Usage: prompt_password "prompt message"
# Returns: Password via echo
prompt_password() {
    local prompt_message="$1"
    local password
    
    # Check if we can disable echo for secure input
    if command -v stty >/dev/null 2>&1; then
        # Use stty method for better compatibility
        echo -n "$prompt_message: " >&2
        stty -echo
        read -r password
        stty echo
        echo >&2  # New line after password input (to stderr)
    else
        # Fallback to read -s
        echo -n "$prompt_message: " >&2
        read -s -r password
        echo >&2  # New line after password input (to stderr)
    fi
    
    # Trim any leading/trailing whitespace and carriage returns
    password="${password#"${password%%[![:space:]]*}"}"  # Remove leading whitespace
    password="${password%"${password##*[![:space:]]}"}"  # Remove trailing whitespace
    password="${password//$'\r'/}"  # Remove carriage returns
    
    echo "$password"
}

# Function to prompt user for multiline input
# Usage: prompt_multiline "prompt message" "end_marker"
# Returns: Multiline input via echo
prompt_multiline() {
    local prompt_message="$1"
    local end_marker="${2:-END}"
    local input=""
    local line
    
    echo "$prompt_message"
    echo "(Enter '$end_marker' on a new line to finish)"
    
    while IFS= read -r line; do
        if [ "$line" = "$end_marker" ]; then
            break
        fi
        if [ -n "$input" ]; then
            input="$input"$'\n'"$line"
        else
            input="$line"
        fi
    done
    
    echo "$input"
}

# Export all functions
export -f confirm
export -f prompt_input
export -f prompt_password
export -f prompt_multiline
export -f create_symlink
export -f check_package_installed
export -f check_internet_connection
export -f ensure_root
export -f get_value
export -f detect_os_info
export -f ensure_directory