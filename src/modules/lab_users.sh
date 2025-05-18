#!/bin/bash

# Level 2 abstraction: User management module
# This module handles creating and setting up users

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"

# Module info
MODULE_NAME="users"
MODULE_DESCRIPTION="Manage system users and shared resources"
MODULE_VERSION="1.0.0"

log_debug "Loading user management module" "$MODULE_NAME"

# Function to convert full name to username
# Usage: fullname_to_username "First Last"
# Returns: firstYYYY (lowercase first name + current year)
fullname_to_username() {
    local user_full_name="$1"
    log_debug "Converting full name to username: $user_full_name" "$MODULE_NAME"
    
    # Extract first name and convert to lowercase
    local username=$(echo "$user_full_name" | cut -d' ' -f1)
    username=$(echo "$username" | tr '[:upper:]' '[:lower:]')
    
    # Add current year
    username+="$(date +%Y)"
    
    log_debug "Generated username: $username" "$MODULE_NAME"
    echo "$username"
}

# Function to create shared resources (group, directories)
create_shared_resources() {
    log_debug "Creating shared resources" "$MODULE_NAME"
    
    local shared_group="${USER_CONFIG[shared_group]}"
    local shared_dir="${USER_CONFIG[shared_dir]}"
    local admin="${USER_CONFIG[admin]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    
    # Create shared group if it doesn't exist
    if getent group "${shared_group}" >/dev/null; then
        log_info "Group '${shared_group}' already exists" "$MODULE_NAME"
    else
        log_info "Creating group '${shared_group}'" "$MODULE_NAME"
        Sudo groupadd "${shared_group}"
        if [ $? -eq 0 ]; then
            log_info "Group '${shared_group}' created successfully" "$MODULE_NAME"
        else
            log_error "Failed to create group '${shared_group}'" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Create shared directories
    Sudo ensure_directory "${shared_dir}" "775"
    Sudo ensure_directory "${conda_env_path}" "775"
    
    # Set proper group ownership
    Sudo chgrp -R "${shared_group}" "${shared_dir}"
    Sudo chgrp -R "${shared_group}" "${conda_env_path}"
    
    # Add admin user to the shared group
    if [ -n "$admin" ]; then
        if id -nG "$admin" | grep -qw "$shared_group"; then
            log_debug "User '$admin' is already in group '$shared_group'" "$MODULE_NAME"
        else
            log_info "Adding user '$admin' to group '$shared_group'" "$MODULE_NAME"
            Sudo usermod -aG "$shared_group" "${admin}"
        fi
    fi
    
    log_info "Shared resources created successfully" "$MODULE_NAME"
    return 0
}

# Function to set up resources for a user
setup_for_each_user() {
    local username="$1"
    log_debug "Setting up resources for user: $username" "$MODULE_NAME"
    
    # Check if the user exists
    if ! id "$username" &>/dev/null; then
        log_error "User '$username' does not exist" "$MODULE_NAME"
        return 1
    fi
    
    local shared_group="${USER_CONFIG[shared_group]}"
    local shared_dir="${USER_CONFIG[shared_dir]}"
    local net_shared_dir="${USER_CONFIG[net_shared_dir]}"
    local default_password="${USER_CONFIG[default_password]}"
    local home_dir=$(getent passwd "$username" | cut -d: -f6)
    
    # Create symlink to shared folder
    Sudo create_symlink "$shared_dir" "${home_dir}/Shared"
    Sudo chown -h "${username}:${username}" "${home_dir}/Shared"
    
    # Create Net Shared Folder
    Sudo ensure_directory "${home_dir}/${net_shared_dir}" "755"
    Sudo chown -R "${username}:${username}" "${home_dir}/${net_shared_dir}"
    
    # Set up Samba password for the user
    if command -v smbpasswd &>/dev/null; then
        log_debug "Setting up Samba password for user: $username" "$MODULE_NAME"
        (
            echo "${default_password}"
            echo "${default_password}"
        ) | Sudo smbpasswd -s -a "${username}"
        
        # Configure Samba share for the user
        local filename="/etc/samba/smb.conf"
        local title_line="[${username}-${net_shared_dir}]"
        local content=(
            "   path = ${home_dir}/${net_shared_dir}"
            "   available = yes"
            "   valid users = ${username}"
            "   read only = no"
            "   browsable = yes"
            "   public = yes"
            "   writable = yes"
        )
        
        Sudo safe_insert "Create Net Shared Folder for ${username}" "$filename" "$title_line" "${content[@]}"
    else
        log_warning "Samba is not installed, skipping Samba configuration for user: $username" "$MODULE_NAME"
    fi
    
    # Set up VNC for the user
    local vnc_dir="${home_dir}/.vnc"
    Sudo ensure_directory "$vnc_dir" "700"
    
    local filename="${vnc_dir}/xstartup"
    local title_line="#!/bin/sh"
    local content=(
        "# For some reason, VNC does not start without these lines."
        "unset SESSION_MANAGER"
        "unset DBUS_SESSION_BUS_ADDRESS"
        "# Load Xresources (Configuration file for X clients)"
        "if [ -r \$HOME/.Xresources ]; then"
        "    xrdb \$HOME/.Xresources"
        "fi"
        ""
        "xsetroot -solid grey"
        "# Fix to make GNOME work"
        "export XKL_XMODMAP_DISABLE=1"
        ""
        "gnome-session &"
        "# More light weight desktop environment"
        "# startxfce4 &"
        ""
        "wait"
    )
    
    Sudo safe_insert "Config VNC Server X session for ${username}" "$filename" "$title_line" "${content[@]}"
    Sudo chmod +x "$filename"
    Sudo chown -R "${username}:${username}" "${vnc_dir}"
    
    log_info "Resources set up successfully for user: $username" "$MODULE_NAME"
    return 0
}

# Function to create a new user
create_user() {
    # Ensure root privileges
    ensure_root
    
    local username="$1"
    local is_super="$2"
    local full_name="$3"
    
    log_debug "Creating user: $username (super: $is_super, full name: $full_name)" "$MODULE_NAME"
    
    local shared_group="${USER_CONFIG[shared_group]}"
    local default_password="${USER_CONFIG[default_password]}"
    local groups=("$shared_group")
    
    # Validate username
    if [[ ! "$username" =~ ^[a-z0-9]+$ ]]; then
        log_error "Error: Username must contain only lowercase alphanumeric characters" "$MODULE_NAME"
        return 1
    fi
    
    # Add sudo group if this is a super user
    if [ "$is_super" = "true" ]; then
        groups+=("sudo")
    fi
    
    # Check if the user already exists
    if id "$username" &>/dev/null; then
        log_info "User $username already exists" "$MODULE_NAME"
        
        # Add user to groups if they exist but don't have the right groups
        local current_groups=$(id -Gn "$username" | tr ' ' '\n')
        local groups_to_add=()
        
        for group in "${groups[@]}"; do
            if ! echo "$current_groups" | grep -q "^$group$"; then
                groups_to_add+=("$group")
            fi
        done
        
        if [ ${#groups_to_add[@]} -gt 0 ]; then
            log_info "Adding user $username to groups: ${groups_to_add[*]}" "$MODULE_NAME"
            local groups_list=$(IFS=','; echo "${groups_to_add[*]}")
            Sudo usermod -aG "$groups_list" "$username"
        fi
        
        return 0
    fi
    
    # Ask for confirmation before creating the user
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Create user $username?"; then
            log_warning "User creation cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Create the user
    log_info "Creating user: $username" "$MODULE_NAME"
    Sudo useradd -m -s /bin/bash "$username"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create user: $username" "$MODULE_NAME"
        return 1
    fi
    
    # Add the user to groups
    local groups_list=$(IFS=','; echo "${groups[*]}")
    Sudo usermod -aG "$groups_list" "$username"
    
    # Set the user's password
    Sudo bash -c "echo '$username:$default_password' | chpasswd"
    
    # Set the full name if provided
    if [ -n "$full_name" ]; then
        Sudo usermod -c "${full_name},,," "$username"
    fi
    
    # Set up resources for the user
    setup_for_each_user "$username"
    
    log_info "User $username created successfully" "$MODULE_NAME"
    return 0
}

# Function to create users from the global lists
create_users_from_list() {
    log_debug "Creating users from global lists" "$MODULE_NAME"
    
    # Create shared resources first
    create_shared_resources
    
    # Create regular users
    for user in "${LAB_USERS[@]}"; do
        local username=$(fullname_to_username "$user")
        create_user "$username" "false" "$user"
    done
    
    # Create super users
    for super_user in "${LAB_SUPER_USERS[@]}"; do
        local super_username=$(fullname_to_username "$super_user")
        create_user "$super_username" "true" "$super_user"
    done
    
    # Add admin user as a super user if not already in the list
    local admin="${USER_CONFIG[admin]}"
    if [ -n "$admin" ]; then
        local admin_in_super_users=false
        for super_user in "${LAB_SUPER_USERS[@]}"; do
            if [ "$(fullname_to_username "$super_user")" = "$admin" ]; then
                admin_in_super_users=true
                break
            fi
        done
        
        if [ "$admin_in_super_users" = "false" ]; then
            create_user "$admin" "true" "$admin"
        fi
    fi
    
    # Restart Samba services if installed
    if command -v systemctl &>/dev/null && systemctl list-unit-files | grep -q "smbd.service"; then
        log_debug "Restarting Samba services" "$MODULE_NAME"
        Sudo systemctl restart smbd
        Sudo systemctl restart nmbd
    fi
    
    log_info "All users created successfully" "$MODULE_NAME"
    return 0
}

# Function to set up SSH server
setup_ssh() {
    log_debug "Setting up SSH server" "$MODULE_NAME"
    
    # Check if OpenSSH server is installed
    if ! command -v sshd &>/dev/null; then
        log_warning "OpenSSH server is not installed, installing now" "$MODULE_NAME"
        Sudo apt update >/dev/null
        Sudo apt install -y openssh-server
        
        if [ $? -ne 0 ]; then
            log_error "Failed to install OpenSSH server" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Ask for confirmation
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Set up SSH server?"; then
            log_warning "SSH server setup cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Enable and start SSH service
    log_info "Enabling and starting SSH service" "$MODULE_NAME"
    Sudo systemctl enable ssh
    Sudo systemctl start ssh
    
    # Configure firewall if ufw is installed
    if command -v ufw &>/dev/null; then
        log_info "Allowing SSH through firewall" "$MODULE_NAME"
        Sudo ufw allow ssh
    fi
    
    log_info "SSH server set up successfully" "$MODULE_NAME"
    return 0
}

# Main function to set up users and shared resources
setup_users() {
    log_info "Setting up users and shared resources" "$MODULE_NAME"
    
    # Create shared resources
    create_shared_resources
    
    # Create users from lists
    create_users_from_list
    
    # Set up SSH server
    setup_ssh
    
    log_info "User setup completed" "$MODULE_NAME"
    return 0
}

# Export the main functions
export -f setup_users
export -f create_shared_resources
export -f create_users_from_list
export -f create_user
export -f setup_for_each_user
export -f setup_ssh
export -f fullname_to_username

# Module metadata
MODULE_COMMANDS=(
    "setup_users:Setup all users and shared resources"
    "create_shared_resources:Create shared group and directories"
    "create_users_from_list:Create users from global lists"
    "create_user:Create a single user (args: username is_super [full_name])"
    "setup_for_each_user:Setup resources for a specific user (args: username)"
    "setup_ssh:Setup SSH server"
)
export MODULE_COMMANDS

log_debug "User management module loaded" "$MODULE_NAME"