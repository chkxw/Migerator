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

# Function to download and install Miniconda
install_miniconda() {
    log_debug "Installing Miniconda" "$MODULE_NAME"
    
    local conda_path="${CONDA_CONFIG[path]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    
    # Check if conda is already installed
    if [ -d "${conda_path}" ] && [ -x "${conda_path}/bin/conda" ]; then
        log_info "Conda is already installed in ${conda_path}" "$MODULE_NAME"
        return 0
    fi
    
    # Check if conda is installed elsewhere
    if command -v conda &>/dev/null; then
        local existing_conda=$(which conda)
        log_warning "Conda is already installed in a different location: ${existing_conda}" "$MODULE_NAME"
        
        if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
            if ! confirm "Proceed with installing Conda in ${conda_path}?"; then
                log_warning "Conda installation cancelled by user" "$MODULE_NAME"
                return 1
            fi
        fi
    fi
    
    # Download the installer
    log_info "Downloading Miniconda installer" "$MODULE_NAME"
    local installer_path="/tmp/miniconda.sh"
    wget -q "https://repo.anaconda.com/miniconda/Miniconda3-latest-$(uname)-$(uname -m).sh" -O "$installer_path"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download Miniconda installer" "$MODULE_NAME"
        return 1
    fi
    
    # Install Miniconda
    log_info "Installing Miniconda to ${conda_path}" "$MODULE_NAME"
    Sudo bash "$installer_path" -b -p "${conda_path}"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to install Miniconda" "$MODULE_NAME"
        return 1
    fi
    
    # Clean up
    rm -f "$installer_path"
    
    log_info "Miniconda installed successfully" "$MODULE_NAME"
    return 0
}

# Function to download and install Miniforge
install_miniforge() {
    log_debug "Installing Miniforge" "$MODULE_NAME"
    
    local conda_path="${CONDA_CONFIG[path]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    
    # Check if conda is already installed
    if [ -d "${conda_path}" ] && [ -x "${conda_path}/bin/conda" ]; then
        log_info "Conda is already installed in ${conda_path}" "$MODULE_NAME"
        return 0
    fi
    
    # Check if conda is installed elsewhere
    if command -v conda &>/dev/null; then
        local existing_conda=$(which conda)
        log_warning "Conda is already installed in a different location: ${existing_conda}" "$MODULE_NAME"
        
        if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
            if ! confirm "Proceed with installing Conda in ${conda_path}?"; then
                log_warning "Conda installation cancelled by user" "$MODULE_NAME"
                return 1
            fi
        fi
    fi
    
    # Download the installer
    log_info "Downloading Miniforge installer" "$MODULE_NAME"
    local installer_path="/tmp/miniforge.sh"
    wget -q "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" -O "$installer_path"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download Miniforge installer" "$MODULE_NAME"
        return 1
    fi
    
    # Install Miniforge
    log_info "Installing Miniforge to ${conda_path}" "$MODULE_NAME"
    Sudo bash "$installer_path" -b -p "${conda_path}"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to install Miniforge" "$MODULE_NAME"
        return 1
    fi
    
    # Clean up
    rm -f "$installer_path"
    
    log_info "Miniforge installed successfully" "$MODULE_NAME"
    return 0
}

# Function to initialize conda for all users
init_conda_global() {
    log_debug "Initializing conda for all users" "$MODULE_NAME"
    
    local conda_path="${CONDA_CONFIG[path]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    
    # Check if conda is installed
    if [ ! -d "${conda_path}" ] || [ ! -x "${conda_path}/bin/conda" ]; then
        log_error "Conda is not installed in ${conda_path}" "$MODULE_NAME"
        return 1
    fi
    
    # Ask for confirmation
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Initialize conda for all users?"; then
            log_warning "Conda initialization cancelled by user" "$MODULE_NAME"
            return 1
        fi
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
    local filename="/etc/bash.bashrc"
    local title_line="# >>> conda initialize >>>"
    local content=(
        "# !! Contents within this block are managed by 'conda init' !!"
        "__conda_setup=\"\$('${conda_path}/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\""
        "if [ \$? -eq 0 ]; then"
        "    eval \"\$__conda_setup\""
        "else"
        "    if [ -f \"${conda_path}/etc/profile.d/conda.sh\" ]; then"
        "        . \"${conda_path}/etc/profile.d/conda.sh\""
        "    else"
        "        export PATH=\"${conda_path}/bin:\$PATH\""
        "    fi"
        "fi"
        "unset __conda_setup"
    )
    
    # Add mamba initialization if available
    if [ -f "${conda_path}/etc/profile.d/mamba.sh" ]; then
        content+=(
            "if [ -f \"${conda_path}/etc/profile.d/mamba.sh\" ]; then"
            "    . \"${conda_path}/etc/profile.d/mamba.sh\""
            "fi"
        )
    fi
    
    content+=(
        "# <<< conda initialize <<<"
    )
    
    Sudo safe_insert "Global conda init" "$filename" "$title_line" "${content[@]}"
    
    # Configure shared environment path
    Sudo ensure_directory "/etc/conda" "0755"
    filename="/etc/conda/.condarc"
    title_line="# Shared conda environment folder"
    content=(
        "envs_dirs:"
        "  - ${conda_env_path}"
    )
    
    # Add conda-forge channel configuration for Miniforge
    if [ "${CONDA_CONFIG[type]}" = "miniforge" ]; then
        content+=(
            "# Always use conda-forge channel"
            "channels:"
            "- conda-forge"
            "- nodefaults"
        )
    fi
    
    Sudo safe_insert "Global conda configurations" "$filename" "$title_line" "${content[@]}"
    
    log_info "Conda initialized for all users" "$MODULE_NAME"
    return 0
}

# Function to install a conda environment
install_conda_env() {
    log_debug "Installing conda environment" "$MODULE_NAME"
    
    local env_name="$1"
    local env_file="$2"
    
    if [ -z "$env_name" ]; then
        log_error "Environment name is required" "$MODULE_NAME"
        return 1
    fi
    
    local conda_path="${CONDA_CONFIG[path]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    
    # Check if conda is installed
    if [ ! -d "${conda_path}" ] || [ ! -x "${conda_path}/bin/conda" ]; then
        log_error "Conda is not installed in ${conda_path}" "$MODULE_NAME"
        return 1
    fi
    
    # Check if the environment already exists
    if "${conda_path}/bin/conda" env list | grep -q "${env_name}"; then
        log_info "Conda environment '${env_name}' already exists" "$MODULE_NAME"
        
        if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
            if ! confirm "Re-create the environment?"; then
                log_warning "Environment creation cancelled by user" "$MODULE_NAME"
                return 0
            fi
            
            # Remove the existing environment
            log_info "Removing existing environment '${env_name}'" "$MODULE_NAME"
            "${conda_path}/bin/conda" env remove -n "${env_name}" -y
        fi
    fi
    
    # Create the environment
    if [ -n "$env_file" ]; then
        # Use the provided environment file
        if [ ! -f "$env_file" ]; then
            log_error "Environment file '${env_file}' not found" "$MODULE_NAME"
            return 1
        fi
        
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

# Main function to install and configure conda
setup_conda() {
    log_info "Setting up Conda" "$MODULE_NAME"
    
    local conda_type="${CONDA_CONFIG[type]}"
    
    # Install Conda based on the specified type
    if [ "$conda_type" = "miniforge" ]; then
        install_miniforge
    else
        install_miniconda
    fi
    
    # Initialize conda for all users
    init_conda_global
    
    log_info "Conda setup completed" "$MODULE_NAME"
    return 0
}

# Export the main function
export -f setup_conda
export -f install_miniconda
export -f install_miniforge
export -f init_conda_global
export -f install_conda_env

# Module metadata
MODULE_COMMANDS=(
    "setup_conda:Setup Conda (Miniconda or Miniforge)"
    "install_miniconda:Install Miniconda"
    "install_miniforge:Install Miniforge"
    "init_conda_global:Initialize conda for all users"
    "install_conda_env:Install a conda environment (args: name [file])"
)
export MODULE_COMMANDS

log_debug "Conda module loaded" "$MODULE_NAME"