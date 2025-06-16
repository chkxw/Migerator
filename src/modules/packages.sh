#!/bin/bash

# Level 2 abstraction: Package management module
# This module handles installation and removal of packages with pre/post processing

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
log_debug "Loading packages module" "packages"

# Function to check if package is installed
# Usage: is_package_installed package_name
# Returns: 0 if installed, 1 if not
is_package_installed() {
    local package="$1"
    log_debug "Checking if package '$package' is installed" "$MODULE_NAME"
    
    if command -v dpkg &>/dev/null; then
        # Use dpkg to check if package is installed
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            log_debug "Package '$package' is installed" "$MODULE_NAME"
            return 0
        fi
    else
        # Fallback to apt-cache
        local package_status=$(apt-cache policy "$package" 2>/dev/null | grep -E '^\s+Installed:' | awk '{print $2}')
        if [ -n "$package_status" ] && [ "$package_status" != "(none)" ]; then
            log_debug "Package '$package' is installed" "$MODULE_NAME"
            return 0
        fi
    fi
    
    log_debug "Package '$package' is not installed" "$MODULE_NAME"
    return 1
}

# Function to handle Chrome special pre/post processing
# Usage: handle_chrome_processing operation [install|remove]
# Returns: 0 on success, 1 on failure
handle_chrome_processing() {
    local operation="$1"
    log_debug "Handling Chrome $operation pre/post processing" "$MODULE_NAME"
    
    case "$operation" in
        install)
            # Add Chrome as default browser if requested
            if [ "${SCRIPT_CONFIG[chrome_set_default]}" = "true" ]; then
                log_info "Setting Chrome as default browser" "$MODULE_NAME"
                # This will update user's mimeapps.list
                if [ -n "$SUDO_USER" ]; then
                    local user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
                    if [ -n "$user_home" ] && [ -d "$user_home" ]; then
                        # Set Chrome as default browser for the user
                        sudo -u "$SUDO_USER" xdg-settings set default-web-browser google-chrome.desktop
                        if [ $? -ne 0 ]; then
                            log_warning "Failed to set Chrome as default browser" "$MODULE_NAME"
                        else
                            log_info "Chrome set as default browser" "$MODULE_NAME"
                        fi
                    fi
                else
                    # Set Chrome as default browser for current user
                    xdg-settings set default-web-browser google-chrome.desktop
                    if [ $? -ne 0 ]; then
                        log_warning "Failed to set Chrome as default browser" "$MODULE_NAME"
                    else
                        log_info "Chrome set as default browser" "$MODULE_NAME"
                    fi
                fi
            fi
            return 0
            ;;
        remove)
            # No special removal handling needed for Chrome
            return 0
            ;;
        *)
            log_error "Unknown operation: $operation" "$MODULE_NAME"
            return 1
            ;;
    esac
}

# Function to handle VS Code special pre/post processing
# Usage: handle_vscode_processing operation [install|remove]
# Returns: 0 on success, 1 on failure
handle_vscode_processing() {
    local operation="$1"
    log_debug "Handling VS Code $operation pre/post processing" "$MODULE_NAME"
    
    case "$operation" in
        install)
            # Install useful VS Code extensions if requested
            if [ "${SCRIPT_CONFIG[vscode_install_extensions]}" = "true" ]; then
                log_info "Installing recommended VS Code extensions" "$MODULE_NAME"
                local extensions=(
                    "ms-python.python"
                    "ms-vscode.cpptools"
                    "ms-toolsai.jupyter"
                    "github.copilot"
                    "github.vscode-pull-request-github"
                    "ritwickdey.liveserver"
                    "esbenp.prettier-vscode"
                    "dbaeumer.vscode-eslint"
                )
                
                if command -v code &>/dev/null; then
                    for ext in "${extensions[@]}"; do
                        log_debug "Installing VS Code extension: $ext" "$MODULE_NAME"
                        if [ -n "$SUDO_USER" ]; then
                            sudo -u "$SUDO_USER" code --install-extension "$ext" --force
                        else
                            code --install-extension "$ext" --force
                        fi
                    done
                    log_info "VS Code extensions installed" "$MODULE_NAME"
                else
                    log_warning "VS Code command not found, skipping extension installation" "$MODULE_NAME"
                fi
            fi
            return 0
            ;;
        remove)
            # No special removal handling needed for VS Code
            return 0
            ;;
        *)
            log_error "Unknown operation: $operation" "$MODULE_NAME"
            return 1
            ;;
    esac
}

# Function to handle Docker special pre/post processing
# Usage: handle_docker_processing operation [install|remove]
# Returns: 0 on success, 1 on failure
handle_docker_processing() {
    local operation="$1"
    log_debug "Handling Docker $operation pre/post processing" "$MODULE_NAME"
    
    case "$operation" in
        install)
            # Add current user to docker group to avoid sudo
            if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
                log_info "Adding user $SUDO_USER to docker group" "$MODULE_NAME"
                Sudo usermod -aG docker "$SUDO_USER"
                if [ $? -ne 0 ]; then
                    log_warning "Failed to add user to docker group" "$MODULE_NAME"
                else
                    log_info "User added to docker group" "$MODULE_NAME"
                fi
            fi
            
            # Enable and start Docker service
            log_debug "Enabling and starting Docker service" "$MODULE_NAME"
            Sudo systemctl enable docker
            Sudo systemctl start docker
            
            # Verify Docker installation
            log_debug "Verifying Docker installation" "$MODULE_NAME"
            Sudo docker --version
            
            return 0
            ;;
        remove)
            # Stop and disable Docker service before removal
            log_debug "Stopping and disabling Docker service" "$MODULE_NAME"
            Sudo systemctl stop docker
            Sudo systemctl disable docker
            
            # Remove docker group if it exists
            if getent group docker &>/dev/null; then
                log_info "Removing docker group" "$MODULE_NAME"
                Sudo groupdel docker
            fi
            
            return 0
            ;;
        *)
            log_error "Unknown operation: $operation" "$MODULE_NAME"
            return 1
            ;;
    esac
}

# Function to handle NodeJS special pre/post processing
# Usage: handle_nodejs_processing operation [install|remove]
# Returns: 0 on success, 1 on failure
handle_nodejs_processing() {
    local operation="$1"
    log_debug "Handling NodeJS $operation pre/post processing" "$MODULE_NAME"
    
    case "$operation" in
        install)
            # Check if we should install global npm packages
            if [ "${SCRIPT_CONFIG[nodejs_install_globals]}" = "true" ]; then
                log_info "Installing global npm packages" "$MODULE_NAME"
                local npm_globals=(
                    "yarn"
                    "typescript"
                    "ts-node"
                    "http-server"
                    "nodemon"
                )
                
                if command -v npm &>/dev/null; then
                    for pkg in "${npm_globals[@]}"; do
                        log_debug "Installing global npm package: $pkg" "$MODULE_NAME"
                        if [ -n "$SUDO_USER" ]; then
                            sudo -u "$SUDO_USER" npm install -g "$pkg"
                        else
                            npm install -g "$pkg"
                        fi
                    done
                    log_info "Global npm packages installed" "$MODULE_NAME"
                else
                    log_warning "npm command not found, skipping global package installation" "$MODULE_NAME"
                fi
            fi
            return 0
            ;;
        remove)
            # No special removal handling needed
            return 0
            ;;
        *)
            log_error "Unknown operation: $operation" "$MODULE_NAME"
            return 1
            ;;
    esac
}

# Function to handle VirtualGL special pre/post processing
# Usage: handle_virtualgl_processing operation [install|remove]
# Returns: 0 on success, 1 on failure
handle_virtualgl_processing() {
    local operation="$1"
    log_debug "Handling VirtualGL $operation pre/post processing" "$MODULE_NAME"
    
    case "$operation" in
        install)
            # Check if VirtualGL needs configuration
            if [ "${SCRIPT_CONFIG[virtualgl_configure]}" = "true" ]; then
                log_info "Configuring VirtualGL" "$MODULE_NAME"
                
                # Install prerequisite packages if not already installed
                if ! is_package_installed "mesa-utils"; then
                    log_debug "Installing mesa-utils prerequisite package" "$MODULE_NAME"
                    Sudo apt update
                    Sudo apt install -y mesa-utils
                fi
                
                # Run VirtualGL configuration
                log_debug "Running VirtualGL configuration" "$MODULE_NAME"
                Sudo /opt/VirtualGL/bin/vglserver_config -config +s +f -t
                
                if [ $? -ne 0 ]; then
                    log_warning "VirtualGL configuration may not have completed successfully" "$MODULE_NAME"
                else
                    log_info "VirtualGL configured successfully" "$MODULE_NAME"
                fi
            fi
            return 0
            ;;
        remove)
            # Unconfigure VirtualGL
            if command -v /opt/VirtualGL/bin/vglserver_config &>/dev/null; then
                log_info "Removing VirtualGL configuration" "$MODULE_NAME"
                Sudo /opt/VirtualGL/bin/vglserver_config -config -s -f -t
            fi
            return 0
            ;;
        *)
            log_error "Unknown operation: $operation" "$MODULE_NAME"
            return 1
            ;;
    esac
}

# Function to handle TurboVNC special pre/post processing
# Usage: handle_turbovnc_processing operation [install|remove]
# Returns: 0 on success, 1 on failure
handle_turbovnc_processing() {
    local operation="$1"
    log_debug "Handling TurboVNC $operation pre/post processing" "$MODULE_NAME"
    
    case "$operation" in
        install)
            # Setup TurboVNC configuration
            if [ "${SCRIPT_CONFIG[turbovnc_configure]}" = "true" ]; then
                log_info "Configuring TurboVNC" "$MODULE_NAME"
                
                # Create TurboVNC configuration directory if it doesn't exist
                local config_dir="/etc/turbovncserver.conf"
                local config_content=$(cat << EOF
# TurboVNC Server Configuration
# Generated by setup script

# Security settings
SecurityTypes=TLSVnc,VncAuth
DeferUpdate=1
AlwaysShared=1
NeverShared=0
DisconnectClients=1

# Performance settings
FrameRate=60
CompressLevel=1
QualityLevel=95
EOF
)
                
                # Write configuration file
                log_debug "Writing TurboVNC configuration to $config_dir" "$MODULE_NAME"
                Sudo bash -c "echo '$config_content' > $config_dir"
                
                # Create symbolic links for easier access
                if [ -f /opt/TurboVNC/bin/vncserver ] && [ ! -f /usr/local/bin/vncserver ]; then
                    log_debug "Creating symbolic link for vncserver" "$MODULE_NAME"
                    Sudo ln -sf /opt/TurboVNC/bin/vncserver /usr/local/bin/vncserver
                    Sudo ln -sf /opt/TurboVNC/bin/vncviewer /usr/local/bin/vncviewer
                fi
            fi
            return 0
            ;;
        remove)
            # Remove TurboVNC configuration
            if [ -f /etc/turbovncserver.conf ]; then
                log_info "Removing TurboVNC configuration" "$MODULE_NAME"
                Sudo rm -f /etc/turbovncserver.conf
            fi
            
            # Remove symbolic links
            if [ -L /usr/local/bin/vncserver ]; then
                log_debug "Removing vncserver symbolic links" "$MODULE_NAME"
                Sudo rm -f /usr/local/bin/vncserver
                Sudo rm -f /usr/local/bin/vncviewer
            fi
            return 0
            ;;
        *)
            log_error "Unknown operation: $operation" "$MODULE_NAME"
            return 1
            ;;
    esac
}

# Function to handle Wine special pre/post processing
# Usage: handle_wine_processing operation [install|remove]
# Returns: 0 on success, 1 on failure
handle_wine_processing() {
    local operation="$1"
    log_debug "Handling Wine $operation pre/post processing" "$MODULE_NAME"
    
    case "$operation" in
        install)
            # Wine might need additional dependencies
            log_info "Checking Wine dependencies" "$MODULE_NAME"
            
            # Install dependencies
            Sudo apt update
            Sudo apt install -y --install-recommends winehq-stable
            
            # Initialize Wine for current user if requested
            if [ "${SCRIPT_CONFIG[wine_init]}" = "true" ]; then
                log_info "Initializing Wine for current user" "$MODULE_NAME"
                if [ -n "$SUDO_USER" ]; then
                    sudo -u "$SUDO_USER" sh -c "WINEARCH=win64 WINEPREFIX=~/.wine wine wineboot --init"
                else
                    WINEARCH=win64 WINEPREFIX=~/.wine wine wineboot --init
                fi
            fi
            return 0
            ;;
        remove)
            # No special handling needed for Wine removal
            return 0
            ;;
        *)
            log_error "Unknown operation: $operation" "$MODULE_NAME"
            return 1
            ;;
    esac
}

# Function to handle Thunderbird special pre/post processing
# Usage: handle_thunderbird_processing operation [install|remove]
# Returns: 0 on success, 1 on failure
handle_thunderbird_processing() {
    local operation="$1"
    log_debug "Handling Thunderbird $operation pre/post processing" "$MODULE_NAME"
    
    case "$operation" in
        install)
            # Create APT preferences to prioritize PPA version over snap
            log_info "Configuring APT preferences for Thunderbird" "$MODULE_NAME"
            local preferences_file="/etc/apt/preferences.d/thunderbird"
            
            # Since safe_insert uses check_and_add_lines which appends lines,
            # and we need to write a complete file, we'll create it directly
            # First remove any existing file to ensure clean content
            if [[ -f "$preferences_file" ]]; then
                log_debug "Removing existing Thunderbird preferences file" "$MODULE_NAME"
                Sudo rm -f "$preferences_file"
            fi
            
            # Content for the preferences file
            local preferences_content="Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: thunderbird
Pin: version 2:1snap*
Pin-Priority: -1"
            
            # Use safe_insert to create the file with proper permissions
            if Sudo safe_insert "Thunderbird APT preferences" "$preferences_file" "$preferences_content"; then
                log_info "Thunderbird APT preferences configured successfully" "$MODULE_NAME"
                # Ensure proper permissions
                Sudo chmod 644 "$preferences_file"
                Sudo chown root:root "$preferences_file"
            else
                log_warning "Failed to configure Thunderbird APT preferences" "$MODULE_NAME"
                return 1
            fi
            
            return 0
            ;;
        remove)
            # Remove APT preferences file
            local preferences_file="/etc/apt/preferences.d/thunderbird"
            if [[ -f "$preferences_file" ]]; then
                log_info "Removing Thunderbird APT preferences" "$MODULE_NAME"
                # safe_remove expects content to remove, but we want to remove the entire file
                # So we'll use direct removal
                if Sudo rm -f "$preferences_file"; then
                    log_info "Thunderbird APT preferences removed" "$MODULE_NAME"
                else
                    log_warning "Failed to remove Thunderbird APT preferences" "$MODULE_NAME"
                fi
            fi
            return 0
            ;;
        *)
            log_error "Unknown operation: $operation" "$MODULE_NAME"
            return 1
            ;;
    esac
}

# Function to handle package-specific pre/post processing
# Usage: handle_package_processing nickname operation
# Returns: 0 on success, 1 on failure
handle_package_processing() {
    local nickname="$1"
    local operation="$2"
    
    log_debug "Handling package-specific processing for: $nickname ($operation)" "$MODULE_NAME"
    
    case "$nickname" in
        google-chrome)
            handle_chrome_processing "$operation"
            return $?
            ;;
        vscode)
            handle_vscode_processing "$operation"
            return $?
            ;;
        docker)
            handle_docker_processing "$operation"
            return $?
            ;;
        nodejs)
            handle_nodejs_processing "$operation"
            return $?
            ;;
        virtualgl)
            handle_virtualgl_processing "$operation"
            return $?
            ;;
        turbovnc)
            handle_turbovnc_processing "$operation"
            return $?
            ;;
        wine)
            handle_wine_processing "$operation"
            return $?
            ;;
        thunderbird)
            handle_thunderbird_processing "$operation"
            return $?
            ;;
        *)
            # No special handling required for other packages
            log_debug "No special handling required for $nickname" "$MODULE_NAME"
            return 0
            ;;
    esac
}

# Function to install a specific package with pre/post processing
# Usage: install_package_with_processing nickname [additional_packages...]
# Returns: 0 on success, 1 on failure
install_package_with_processing() {
    local nickname="$1"
    shift
    local additional_packages=("$@")
    
    log_info "Installing package with processing: $nickname" "$MODULE_NAME"
    
    # Verify that the package exists in our repository information
    if ! parse_package_repo "$nickname" &>/dev/null; then
        log_error "Package $nickname not found in repository information" "$MODULE_NAME"
        return 1
    fi
    
    # Pre-processing
    log_debug "Running pre-processing for $nickname" "$MODULE_NAME"
    handle_package_processing "$nickname" "install" # Call with correct operation name
    
    # Install the package using core functionality
    log_debug "Installing package $nickname" "$MODULE_NAME"
    if ! install_package "$nickname" "${additional_packages[@]}"; then
        log_error "Failed to install package: $nickname" "$MODULE_NAME"
        return 1
    fi
    
    # Post-processing
    log_debug "Running post-processing for $nickname" "$MODULE_NAME"
    if ! handle_package_processing "$nickname" "install"; then
        log_warning "Post-processing for $nickname returned non-zero status" "$MODULE_NAME"
    fi
    
    log_info "Successfully installed package with processing: $nickname" "$MODULE_NAME"
    return 0
}

# Function to uninstall a package with proper cleanup
# Usage: uninstall_package nickname [purge]
# Returns: 0 on success, 1 on failure
uninstall_package() {
    local nickname="$1"
    local purge="${2:-false}"  # Default to false
    
    log_info "Uninstalling package: $nickname" "$MODULE_NAME"
    
    # Read package information
    read -r package_name gpg_key_url arch version_codename branch deb_src repo_url repo_base_url <<< "$(parse_package_repo "$nickname")"
    
    if [ -z "$package_name" ]; then
        log_error "Failed to get package name for $nickname" "$MODULE_NAME"
        return 1
    fi
    
    # Pre-removal processing
    log_debug "Running pre-removal processing for $nickname" "$MODULE_NAME"
    if ! handle_package_processing "$nickname" "remove"; then
        log_warning "Pre-removal processing for $nickname returned non-zero status" "$MODULE_NAME"
    fi
    
    # Check if package is installed
    if ! is_package_installed "$package_name"; then
        log_info "Package $nickname ($package_name) is not installed, skipping uninstallation" "$MODULE_NAME"
        
        # Still remove the repository information if requested
        if [ "$remove_repos_option" = "true" ]; then
            log_info "Removing repository information for $nickname" "$MODULE_NAME"
            # Remove repository file
            local repo_file="/etc/apt/sources.list.d/${nickname}.list"
            if [ -f "$repo_file" ]; then
                log_debug "Removing repository file: $repo_file" "$MODULE_NAME"
                Sudo rm -f "$repo_file"
            fi
            
            # Remove GPG key
            local gpg_key_file="/etc/apt/keyrings/${nickname}.gpg"
            if [ -f "$gpg_key_file" ]; then
                log_debug "Removing GPG key file: $gpg_key_file" "$MODULE_NAME"
                Sudo rm -f "$gpg_key_file"
            fi
            
            # Update package lists
            log_debug "Updating package lists after repository removal" "$MODULE_NAME"
            Sudo apt update >/dev/null
        fi
        
        return 0
    fi
    
    # Uninstall the package
    if [ "$purge" = "true" ]; then
        log_debug "Purging package: $package_name" "$MODULE_NAME"
        Sudo apt purge -y "$package_name"
    else
        log_debug "Removing package: $package_name" "$MODULE_NAME"
        Sudo apt remove -y "$package_name"
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Failed to uninstall package: $nickname ($package_name)" "$MODULE_NAME"
        return 1
    fi
    
    # Remove repository information if requested
    if [ "$remove_repos_option" = "true" ]; then
        log_info "Removing repository information for $nickname" "$MODULE_NAME"
        # Remove repository file
        local repo_file="/etc/apt/sources.list.d/${nickname}.list"
        if [ -f "$repo_file" ]; then
            log_debug "Removing repository file: $repo_file" "$MODULE_NAME"
            Sudo rm -f "$repo_file"
        fi
        
        # Remove GPG key
        local gpg_key_file="/etc/apt/keyrings/${nickname}.gpg"
        if [ -f "$gpg_key_file" ]; then
            log_debug "Removing GPG key file: $gpg_key_file" "$MODULE_NAME"
            Sudo rm -f "$gpg_key_file"
        fi
        
        # Update package lists
        log_debug "Updating package lists after repository removal" "$MODULE_NAME"
        Sudo apt update >/dev/null
    fi
    
    # Post-removal processing
    log_debug "Running post-removal processing for $nickname" "$MODULE_NAME"
    if ! handle_package_processing "$nickname" "post_remove"; then
        log_warning "Post-removal processing for $nickname returned non-zero status" "$MODULE_NAME"
    fi
    
    # Run autoremove to clean up dependencies if requested or by default
    if [ "$auto_remove_option" = "true" ]; then
        log_debug "Running autoremove to clean up dependencies" "$MODULE_NAME"
        Sudo apt autoremove -y
    fi
    
    log_info "Successfully uninstalled package: $nickname ($package_name)" "$MODULE_NAME"
    return 0
}

# Function to install multiple packages
# Usage: install_packages nickname1 [nickname2...]
# Returns: 0 on success, non-zero on any failure
install_packages() {
    local packages=("$@")
    local result=0
    
    if [ ${#packages[@]} -eq 0 ]; then
        log_error "No packages specified for installation" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Installing ${#packages[@]} packages: ${packages[*]}" "$MODULE_NAME"
    
    # Update package lists first
    log_debug "Updating package lists before installation" "$MODULE_NAME"
    Sudo apt update >/dev/null
    
    # Install each package
    for package in "${packages[@]}"; do
        log_debug "Installing package: $package" "$MODULE_NAME"
        if ! install_package_with_processing "$package"; then
            log_error "Failed to install package: $package" "$MODULE_NAME"
            result=1
        else
            log_info "Successfully installed package: $package" "$MODULE_NAME"
        fi
    done
    
    if [ $result -eq 0 ]; then
        log_info "All packages installed successfully" "$MODULE_NAME"
    else
        log_warning "Some packages failed to install" "$MODULE_NAME"
    fi
    
    return $result
}

# Function to uninstall multiple packages
# Usage: uninstall_packages nickname1 [nickname2...]
# Returns: 0 on success, non-zero on any failure
uninstall_packages() {
    local packages=("$@")
    local result=0
    
    if [ ${#packages[@]} -eq 0 ]; then
        log_error "No packages specified for uninstallation" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Uninstalling ${#packages[@]} packages: ${packages[*]}" "$MODULE_NAME"
    
    # Uninstall each package
    for package in "${packages[@]}"; do
        log_debug "Uninstalling package: $package" "$MODULE_NAME"
        if ! uninstall_package "$package" "$purge_option"; then
            log_error "Failed to uninstall package: $package" "$MODULE_NAME"
            result=1
        else
            log_info "Successfully uninstalled package: $package" "$MODULE_NAME"
        fi
    done
    
    if [ $result -eq 0 ]; then
        log_info "All packages uninstalled successfully" "$MODULE_NAME"
    else
        log_warning "Some packages failed to uninstall" "$MODULE_NAME"
    fi
    
    return $result
}

# Function to install a curated set of packages
# Usage: install_package_set set_name
# Returns: 0 on success, non-zero on any failure
install_package_set() {
    local set_name="$1"
    local packages=()
    
    log_info "Installing package set: $set_name" "$MODULE_NAME"
    
    case "$set_name" in
        essential)
            packages=(
                "google-chrome"
                "vscode"
                "ffmpeg"
                "vlc"
            )
            ;;
        development)
            packages=(
                "google-chrome"
                "vscode"
                "docker"
                "nodejs"
                "ffmpeg"
                "remmina"
            )
            ;;
        remote)
            packages=(
                "virtualgl"
                "turbovnc"
                "remmina"
            )
            ;;
        multimedia)
            packages=(
                "ffmpeg"
                "vlc"
            )
            ;;
        all)
            packages=(
                "google-chrome"
                "vscode"
                "docker"
                "nodejs"
                "virtualgl"
                "turbovnc"
                "slack"
                "wine"
                "ffmpeg"
                "cubic"
                "remmina"
                "vlc"
            )
            ;;
        *)
            log_error "Unknown package set: $set_name" "$MODULE_NAME"
            echo "Available package sets:"
            echo "  essential   - Basic essential packages (Chrome, VS Code, ffmpeg, VLC)"
            echo "  development - Development-focused packages (Chrome, VS Code, Docker, Node.js, etc.)"
            echo "  remote      - Remote access packages (VirtualGL, TurboVNC, Remmina)"
            echo "  multimedia  - Multimedia packages (ffmpeg, VLC)"
            echo "  all         - All available packages"
            return 1
            ;;
    esac
    
    # Install the packages
    install_packages "${packages[@]}"
    return $?
}

# Main function for package module to handle CLI
# Usage: packages_main [command] [options]
# Commands:
#   install [package1 package2...] - Install specified packages
#   remove [package1 package2...]  - Remove specified packages
#   set [set_name]                - Install a predefined set of packages
#   list                           - List available packages
# Options:
#   --purge                       - Purge packages when removing
#   --remove-repos                - Remove repositories after package removal
#   --autoremove                  - Run autoremove after package removal
#   --help                        - Show help message
# Returns: 0 on success, 1 on failure
packages_main() {
    # Save previous module context
    local PREV_MODULE_NAME="$MODULE_NAME"
    local PREV_MODULE_DESCRIPTION="$MODULE_DESCRIPTION"
    local PREV_MODULE_VERSION="$MODULE_VERSION"
    
    # Set this module's context
    MODULE_NAME="packages"
    MODULE_DESCRIPTION="Install and manage system packages with pre/post processing"
    MODULE_VERSION="1.0.0"
    
    log_debug "Packages module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local command=""
    local packages=()
    local set_name=""
    local purge="false"
    local keep_repos="false"
    local autoremove="false"
    local show_help="false"
    
    # No arguments - show help
    if [ $# -eq 0 ]; then
        show_help="true"
    fi
    
    # Check if first argument is help
    if [ $# -gt 0 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
        show_help="true"
        shift
    # First argument is the command
    elif [ $# -gt 0 ]; then
        command="$1"
        shift
    fi
    
    # Process options
    while [ $# -gt 0 ]; do
        case "$1" in
            --purge)
                purge="true"
                shift
                ;;
            --keep-repos)
                keep_repos="true"
                shift
                ;;
            --autoremove)
                autoremove="true"
                shift
                ;;
            --help|-h)
                show_help="true"
                shift
                ;;
            -*)
                log_error "Unknown option: $1" "$MODULE_NAME"
                show_help="true"
                shift
                ;;
            *)
                # Not an option, must be a package name or set name
                if [ "$command" = "set" ]; then
                    set_name="$1"
                else
                    packages+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # Store values locally instead of in global configuration
    local purge_option="$purge"
    local auto_remove_option="${autoremove:-true}" # Default to true
    # Remove repos by default, unless --keep-repos is specified
    if [[ "$keep_repos" == "true" ]]; then
        remove_repos_option="false"
    else
        remove_repos_option="true"
    fi
    log_debug "Using purge: $purge_option, auto_remove: $auto_remove_option, remove_repos: $remove_repos_option" "$MODULE_NAME"
    
    # Show help message
    if [ "$show_help" = "true" ]; then
        help_text=$(cat << EOF
Usage: packages_main [command] [options]

Commands:
  install [package1 package2...] - Install specified packages
  remove [package1 package2...]  - Remove specified packages
  set [set_name]                - Install a predefined set of packages
  list                           - List available packages

Options:
  --purge                       - Purge packages when removing
  --keep-repos                  - Keep repositories after package removal (default: remove)
  --autoremove                  - Run autoremove after package removal
  --help, -h                    - Show this help message

Available package sets:
  essential   - Basic essential packages (Chrome, VS Code, ffmpeg, VLC)
  development - Development-focused packages (Chrome, VS Code, Docker, Node.js, etc.)
  remote      - Remote access packages (VirtualGL, TurboVNC, Remmina)
  multimedia  - Multimedia packages (ffmpeg, VLC)
  all         - All available packages

Available packages:
EOF
)
        # Add packages to the help text
        for nickname in "${!PKG_FORMAL_NAME[@]}"; do
            help_text="$help_text
  $nickname - ${PKG_FORMAL_NAME[$nickname]}"
        done
        
        # Output the help text
        echo "$help_text"
        
        # Restore previous module context
        MODULE_NAME="$PREV_MODULE_NAME"
        MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
        MODULE_VERSION="$PREV_MODULE_VERSION"
        
        return 0
    fi
    
    # Execute the appropriate command
    case "$command" in
        install)
            local result=0
            if [ ${#packages[@]} -eq 0 ]; then
                log_error "No packages specified for installation" "$MODULE_NAME"
                result=1
            else
                install_packages "${packages[@]}"
                result=$?
            fi
            
            # Restore previous module context
            MODULE_NAME="$PREV_MODULE_NAME"
            MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
            MODULE_VERSION="$PREV_MODULE_VERSION"
            
            return $result
            ;;
        remove)
            local result=0
            if [ ${#packages[@]} -eq 0 ]; then
                log_error "No packages specified for removal" "$MODULE_NAME"
                result=1
            else
                uninstall_packages "${packages[@]}"
                result=$?
            fi
            
            # Restore previous module context
            MODULE_NAME="$PREV_MODULE_NAME"
            MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
            MODULE_VERSION="$PREV_MODULE_VERSION"
            
            return $result
            ;;
        set)
            local result=0
            if [ -z "$set_name" ]; then
                log_error "No package set specified" "$MODULE_NAME"
                result=1
            else
                install_package_set "$set_name"
                result=$?
            fi
            
            # Restore previous module context
            MODULE_NAME="$PREV_MODULE_NAME"
            MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
            MODULE_VERSION="$PREV_MODULE_VERSION"
            
            return $result
            ;;
        list)
            list_text="Available packages:"
            for nickname in "${!PKG_FORMAL_NAME[@]}"; do
                list_text="$list_text
  $nickname - ${PKG_FORMAL_NAME[$nickname]}"
            done
            echo "$list_text"
            
            # Restore previous module context
            MODULE_NAME="$PREV_MODULE_NAME"
            MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
            MODULE_VERSION="$PREV_MODULE_VERSION"
            
            return 0
            ;;
        *)
            log_error "Unknown command: $command" "$MODULE_NAME"
            
            # Restore previous module context
            MODULE_NAME="$PREV_MODULE_NAME"
            MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
            MODULE_VERSION="$PREV_MODULE_VERSION"
            
            return 1
            ;;
    esac
}

# Define commands
MODULE_COMMANDS=(
    "packages_main install:Install specified packages"
    "packages_main remove:Remove specified packages"
    "packages_main set:Install a predefined set of packages"
    "packages_main list:List available packages"
)
export MODULE_COMMANDS

# Export functions for use in other scripts
export -f packages_main
export -f install_package_with_processing
export -f uninstall_package
export -f install_packages
export -f uninstall_packages
export -f install_package_set

log_debug "Packages module loaded" "packages"