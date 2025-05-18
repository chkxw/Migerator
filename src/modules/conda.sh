#!/bin/bash

# Level 2 abstraction: Conda module
# This module handles installing and configuring Miniconda/Miniforge

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"

# Module info
MODULE_NAME="conda"
MODULE_DESCRIPTION="Install and configure Conda (Miniconda/Miniforge)"
MODULE_VERSION="1.0.0"

log_debug "Loading conda module" "$MODULE_NAME"

# Function to generate conda initialization content for bash
# Args: $1 - conda installation path
# Returns: configuration content as a string
conda_generate_init_content() {
    local conda_path="$1"
    
    local content="# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup=\"\$('${conda_path}/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\"
if [ \$? -eq 0 ]; then
    eval \"\$__conda_setup\"
else
    if [ -f \"${conda_path}/etc/profile.d/conda.sh\" ]; then
        . \"${conda_path}/etc/profile.d/conda.sh\"
    else
        export PATH=\"${conda_path}/bin:\$PATH\"
    fi
fi
unset __conda_setup"

    # Add mamba initialization if available
    if [ -f "${conda_path}/etc/profile.d/mamba.sh" ]; then
        content+="
if [ -f \"${conda_path}/etc/profile.d/mamba.sh\" ]; then
    . \"${conda_path}/etc/profile.d/mamba.sh\"
fi"
    fi

    content+="
# <<< conda initialize <<<"

    echo "$content"
}

# Function to generate conda config content
# Args: $1 - conda environment path, $2 - use miniforge (true/false)
# Returns: configuration content as a string
conda_generate_config_content() {
    local conda_env_path="$1"
    local use_miniforge="$2"
    
    local content="# Shared conda environment folder
envs_dirs:
  - ${conda_env_path}"

    # Add conda-forge channel configuration for Miniforge
    if [ "$use_miniforge" = "true" ]; then
        content+="
# Always use conda-forge channel
channels:
- conda-forge
- nodefaults"
    fi

    echo "$content"
}

# Function to download and install conda (miniconda or miniforge)
# Args: $1 - conda type (miniconda or miniforge)
# Returns: 0 on success, 1 on failure
conda_install() {
    local conda_type="$1"
    local conda_path="${CONDA_CONFIG[path]}"
    
    log_debug "Installing $conda_type" "$MODULE_NAME"
    
    # Check if conda is already installed
    if [ -d "${conda_path}" ] && [ -x "${conda_path}/bin/conda" ]; then
        log_info "Conda is already installed in ${conda_path}" "$MODULE_NAME"
        return 0
    fi
    
    # Check if conda is installed elsewhere
    if command -v conda &>/dev/null; then
        local existing_conda=$(which conda)
        log_warning "Conda is already installed in a different location: ${existing_conda}" "$MODULE_NAME"
    fi
    
    # Set download URL based on conda type
    local download_url=""
    local installer_path="/tmp/${conda_type}.sh"
    
    if [ "$conda_type" = "miniconda" ]; then
        download_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-$(uname)-$(uname -m).sh"
    else
        download_url="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
    fi
    
    # Download the installer
    log_info "Downloading $conda_type installer" "$MODULE_NAME"
    wget -q "$download_url" -O "$installer_path"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download $conda_type installer" "$MODULE_NAME"
        return 1
    fi
    
    # Install conda
    log_info "Installing $conda_type to ${conda_path}" "$MODULE_NAME"
    Sudo bash "$installer_path" -b -p "${conda_path}"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to install $conda_type" "$MODULE_NAME"
        rm -f "$installer_path"
        return 1
    fi
    
    # Clean up
    rm -f "$installer_path"
    
    log_info "$conda_type installed successfully" "$MODULE_NAME"
    return 0
}

# Function to initialize conda for all users
# Args: $1 - conda type (miniconda or miniforge)
# Returns: 0 on success, 1 on failure
conda_init() {
    local conda_type="$1"
    local conda_path="${CONDA_CONFIG[path]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    local use_miniforge=false
    
    [ "$conda_type" = "miniforge" ] && use_miniforge=true
    
    log_debug "Initializing conda for all users" "$MODULE_NAME"
    
    # Check if conda is installed
    if [ ! -d "${conda_path}" ] || [ ! -x "${conda_path}/bin/conda" ]; then
        log_error "Conda is not installed in ${conda_path}" "$MODULE_NAME"
        return 1
    fi
    
    # Create conda environment directory
    Sudo ensure_directory "$conda_env_path" "0755"
    
    # Init conda for login shell
    Sudo create_symlink "${conda_path}/etc/profile.d/conda.sh" "/etc/profile.d/conda.sh"
    
    # Check if mamba is available (Miniforge)
    if [ -f "${conda_path}/etc/profile.d/mamba.sh" ]; then
        Sudo create_symlink "${conda_path}/etc/profile.d/mamba.sh" "/etc/profile.d/mamba.sh"
    fi
    
    # Init conda for non-login shell
    local bash_init_content=$(conda_generate_init_content "$conda_path")
    if ! Sudo safe_insert "Global conda init" "/etc/bash.bashrc" "$bash_init_content"; then
        log_error "Failed to initialize conda in bash.bashrc" "$MODULE_NAME"
        return 1
    fi
    
    # Configure shared environment path
    Sudo ensure_directory "/etc/conda" "0755"
    local config_content=$(conda_generate_config_content "$conda_env_path" "$use_miniforge")
    if ! Sudo safe_insert "Global conda configurations" "/etc/conda/.condarc" "$config_content"; then
        log_error "Failed to create conda configuration" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Conda initialized for all users" "$MODULE_NAME"
    return 0
}

# Function to remove conda installation and configuration
# Args: $1 - conda path
# Returns: 0 on success, 1 on failure
conda_remove() {
    local conda_path="$1"
    log_debug "Removing conda installation and configuration" "$MODULE_NAME"
    
    # Remove conda directory
    if [ -d "$conda_path" ]; then
        log_info "Removing conda installation directory: $conda_path" "$MODULE_NAME"
        Sudo rm -rf "$conda_path"
    fi
    
    # Remove conda init from bash.bashrc
    local bash_init_content=$(conda_generate_init_content "$conda_path")
    Sudo safe_remove "Global conda init" "/etc/bash.bashrc" "$bash_init_content" || true
    
    # Remove conda profile scripts
    Sudo rm -f "/etc/profile.d/conda.sh" || true
    Sudo rm -f "/etc/profile.d/mamba.sh" || true
    
    # Remove conda configuration
    Sudo rm -rf "/etc/conda" || true
    
    log_info "Conda installation and configuration removed" "$MODULE_NAME"
    return 0
}

# Function to install a conda environment
# Args: $1 - environment name, $2 - environment file (optional)
# Returns: 0 on success, 1 on failure
conda_create_env() {
    local env_name="$1"
    local env_file="$2"
    
    if [ -z "$env_name" ]; then
        log_error "Environment name is required" "$MODULE_NAME"
        return 1
    fi
    
    local conda_path="${CONDA_CONFIG[path]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    
    log_debug "Creating conda environment: $env_name" "$MODULE_NAME"
    
    # Check if conda is installed
    if [ ! -d "${conda_path}" ] || [ ! -x "${conda_path}/bin/conda" ]; then
        log_error "Conda is not installed in ${conda_path}" "$MODULE_NAME"
        return 1
    fi
    
    # Check if the environment already exists
    if "${conda_path}/bin/conda" env list | grep -q "${env_name}"; then
        log_info "Conda environment '${env_name}' already exists" "$MODULE_NAME"
        return 0
    fi
    
    # Create the environment
    if [ -n "$env_file" ] && [ -f "$env_file" ]; then
        # Use the provided environment file
        log_info "Creating conda environment '${env_name}' from file '${env_file}'" "$MODULE_NAME"
        "${conda_path}/bin/conda" env create -f "${env_file}" -n "${env_name}" -p "${conda_env_path}/${env_name}"
    else
        # Create a basic environment with Python
        log_info "Creating basic conda environment '${env_name}'" "$MODULE_NAME"
        "${conda_path}/bin/conda" create -n "${env_name}" -p "${conda_env_path}/${env_name}" python -y
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create conda environment '${env_name}'" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Conda environment '${env_name}' created successfully" "$MODULE_NAME"
    return 0
}

# Main function for the conda module
# Usage: conda_main [options]
# Options:
#   --type TYPE       Set conda type (miniconda or miniforge)
#   --path PATH       Set conda installation path
#   --env-path PATH   Set conda environments path
#   --env-name NAME   Create environment with specified name
#   --env-file FILE   Use environment file for env creation
#   --init-only       Only initialize existing conda installation
#   --remove          Remove conda installation
#   --help            Display this help message
# Returns: 0 on success, 1 on failure
conda_main() {
    log_debug "Conda module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local conda_type="${CONDA_CONFIG[type]}"
    local conda_path="${CONDA_CONFIG[path]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    local env_name=""
    local env_file=""
    local init_only=false
    local remove=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                conda_type="$2"
                shift 2
                ;;
            --path)
                conda_path="$2"
                shift 2
                ;;
            --env-path)
                conda_env_path="$2"
                shift 2
                ;;
            --env-name)
                env_name="$2"
                shift 2
                ;;
            --env-file)
                env_file="$2"
                shift 2
                ;;
            --init-only)
                init_only=true
                shift
                ;;
            --remove)
                remove=true
                shift
                ;;
            --help)
                # Display help message
                cat <<-EOF
Usage: conda_main [options]
Options:
  --type TYPE       Set conda type (miniconda or miniforge)
  --path PATH       Set conda installation path
  --env-path PATH   Set conda environments path
  --env-name NAME   Create environment with specified name
  --env-file FILE   Use environment file for env creation
  --init-only       Only initialize existing conda installation
  --remove          Remove conda installation
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
    
    # Validate conda type
    if [ "$conda_type" != "miniconda" ] && [ "$conda_type" != "miniforge" ]; then
        log_error "Invalid conda type: $conda_type. Must be 'miniconda' or 'miniforge'" "$MODULE_NAME"
        return 1
    fi
    
    # Ask for confirmation if not in auto-confirm mode
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if $remove; then
            if ! confirm "Remove conda installation from $conda_path?"; then
                log_warning "Conda removal cancelled by user" "$MODULE_NAME"
                return 1
            fi
        elif $init_only; then
            if ! confirm "Initialize conda from $conda_path?"; then
                log_warning "Conda initialization cancelled by user" "$MODULE_NAME"
                return 1
            fi
        else
            if ! confirm "Install $conda_type to $conda_path?"; then
                log_warning "Conda installation cancelled by user" "$MODULE_NAME"
                return 1
            fi
        fi
    fi
    
    # Execute requested operation
    local result=0
    
    if $remove; then
        if ! conda_remove "$conda_path"; then
            log_error "Failed to remove conda" "$MODULE_NAME"
            result=1
        fi
    elif $init_only; then
        if ! conda_init "$conda_type"; then
            log_error "Failed to initialize conda" "$MODULE_NAME"
            result=1
        fi
    else
        # Full installation
        if ! conda_install "$conda_type"; then
            log_error "Failed to install $conda_type" "$MODULE_NAME"
            result=1
        elif ! conda_init "$conda_type"; then
            log_error "Failed to initialize conda" "$MODULE_NAME"
            result=1
        fi
    fi
    
    # Create environment if requested
    if [ -n "$env_name" ] && [ $result -eq 0 ] && [ "$remove" = "false" ]; then
        if ! conda_create_env "$env_name" "$env_file"; then
            log_error "Failed to create conda environment: $env_name" "$MODULE_NAME"
            result=1
        fi
    fi
    
    if [ $result -eq 0 ]; then
        if $remove; then
            log_info "Conda removal completed successfully" "$MODULE_NAME"
        elif $init_only; then
            log_info "Conda initialization completed successfully" "$MODULE_NAME"
        else
            log_info "Conda setup completed successfully" "$MODULE_NAME"
        fi
    else
        log_error "Conda operation completed with errors" "$MODULE_NAME"
    fi
    
    return $result
}

# Export only the main function
export -f conda_main

# Module metadata
MODULE_COMMANDS=(
    "conda_main:Install and configure Conda (Miniconda/Miniforge)"
)
export MODULE_COMMANDS

log_debug "Conda module loaded" "$MODULE_NAME"