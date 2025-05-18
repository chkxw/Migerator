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

# Function to get username from user_id
# Usage: get_username "user_id"
# Returns: the username in format firstYYYY (lowercase first name + join year)
get_username() {
    local user_id="$1"
    log_debug "Generating username for user_id: $user_id" "$MODULE_NAME"
    
    # Get the full name and join year from the data structures
    local full_name="${USER_FULLNAME[$user_id]}"
    local join_year="${USER_JOIN_YEAR[$user_id]}"
    
    if [ -z "$full_name" ] || [ -z "$join_year" ]; then
        log_error "User details not found for user_id: $user_id" "$MODULE_NAME"
        return 1
    fi
    
    # Extract first name and convert to lowercase
    local username=$(echo "$full_name" | cut -d' ' -f1)
    username=$(echo "$username" | tr '[:upper:]' '[:lower:]')
    
    # Add join year
    username+="$join_year"
    
    log_debug "Generated username: $username" "$MODULE_NAME"
    echo "$username"
}

# Function to check if shared resources exist
# Usage: check_shared_resources
# Returns: 0 if all resources exist, 1 if any resource is missing
check_shared_resources() {
    log_debug "Checking shared resources" "$MODULE_NAME"
    
    local shared_group="${USER_CONFIG[shared_group]}"
    local shared_dir="${USER_CONFIG[shared_dir]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    local missing_resources=()
    
    # Check if shared group exists
    if ! getent group "${shared_group}" >/dev/null; then
        missing_resources+=("Group '${shared_group}'")
    fi
    
    # Check if shared directories exist
    if [ ! -d "${shared_dir}" ]; then
        missing_resources+=("Directory '${shared_dir}'")
    fi
    
    if [ ! -d "${conda_env_path}" ]; then
        missing_resources+=("Directory '${conda_env_path}'")
    fi
    
    # Report results
    if [ ${#missing_resources[@]} -eq 0 ]; then
        log_info "All shared resources exist" "$MODULE_NAME"
        return 0
    else
        log_warning "Missing shared resources: ${missing_resources[*]}" "$MODULE_NAME"
        return 1
    fi
}

# Function to remove shared resources
# Usage: remove_shared_resources [force]
# Returns: 0 on success, 1 on failure
remove_shared_resources() {
    local force="$1"
    
    log_debug "Removing shared resources" "$MODULE_NAME"
    
    local shared_group="${USER_CONFIG[shared_group]}"
    local shared_dir="${USER_CONFIG[shared_dir]}"
    local conda_env_path="${CONDA_CONFIG[env_path]}"
    
    # Check if we should force deletion or ask for confirmation
    if [ "$force" != "force" ] && [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "This will remove all shared resources. Are you sure?"; then
            log_warning "Shared resource removal cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Remove shared directories if they exist
    if [ -d "${shared_dir}" ]; then
        log_info "Removing shared directory: ${shared_dir}" "$MODULE_NAME"
        Sudo rm -rf "${shared_dir}"
    fi
    
    if [ -d "${conda_env_path}" ]; then
        log_info "Removing conda environment directory: ${conda_env_path}" "$MODULE_NAME"
        Sudo rm -rf "${conda_env_path}"
    fi
    
    # Don't remove the shared group if users are still in it
    local group_members=$(getent group "${shared_group}" | cut -d: -f4)
    if [ -n "$group_members" ]; then
        log_warning "Group '${shared_group}' still has members: $group_members" "$MODULE_NAME"
        log_warning "Not removing group '${shared_group}'" "$MODULE_NAME"
    else
        if getent group "${shared_group}" >/dev/null; then
            log_info "Removing group '${shared_group}'" "$MODULE_NAME"
            Sudo groupdel "${shared_group}"
        fi
    fi
    
    log_info "Shared resources removed successfully" "$MODULE_NAME"
    return 0
}

# Function to create shared resources (group, directories)
# Usage: create_shared_resources
# Returns: 0 on success, 1 on failure
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
        if [ $? -ne 0 ]; then
            log_error "Failed to create group '${shared_group}'" "$MODULE_NAME"
            return 1
        fi
        log_info "Group '${shared_group}' created successfully" "$MODULE_NAME"
    fi
    
    # Create shared directories
    log_info "Creating shared directory: ${shared_dir}" "$MODULE_NAME"
    Sudo ensure_directory "${shared_dir}" "775"
    
    log_info "Creating conda environment directory: ${conda_env_path}" "$MODULE_NAME"
    Sudo ensure_directory "${conda_env_path}" "775"
    
    # Set proper group ownership
    log_info "Setting group ownership for shared directories" "$MODULE_NAME"
    Sudo chgrp -R "${shared_group}" "${shared_dir}"
    Sudo chgrp -R "${shared_group}" "${conda_env_path}"
    
    # Add admin user to the shared group
    if [ -n "$admin" ]; then
        if id "$admin" &>/dev/null; then
            if id -nG "$admin" | grep -qw "$shared_group"; then
                log_debug "User '$admin' is already in group '$shared_group'" "$MODULE_NAME"
            else
                log_info "Adding user '$admin' to group '$shared_group'" "$MODULE_NAME"
                Sudo usermod -aG "$shared_group" "${admin}"
            fi
        else
            log_warning "Admin user '$admin' does not exist, skipping group membership" "$MODULE_NAME"
        fi
    fi
    
    log_info "Shared resources created successfully" "$MODULE_NAME"
    return 0
}

# Function to generate VNC configuration content for a user
# Usage: generate_vnc_config username
# Returns: Complete VNC configuration content
generate_vnc_config() {
    local username="$1"
    log_debug "Generating VNC configuration for user: $username" "$MODULE_NAME"
    
    local content="#!/bin/sh
# For some reason, VNC does not start without these lines.
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# Load Xresources (Configuration file for X clients)
if [ -r \$HOME/.Xresources ]; then
    xrdb \$HOME/.Xresources
fi

xsetroot -solid grey
# Fix to make GNOME work
export XKL_XMODMAP_DISABLE=1

gnome-session &
# More light weight desktop environment
# startxfce4 &

wait"

    echo "$content"
}

# Function to generate Samba share configuration for a user
# Usage: generate_samba_share_config username
# Returns: Complete Samba share configuration content
generate_samba_share_config() {
    local username="$1"
    log_debug "Generating Samba share configuration for: $username" "$MODULE_NAME"
    
    local net_shared_dir="${USER_CONFIG[net_shared_dir]}"
    local home_dir=$(getent passwd "$username" | cut -d: -f6)
    
    if [ -z "$home_dir" ]; then
        log_error "Could not determine home directory for user: $username" "$MODULE_NAME"
        return 1
    fi
    
    local content="[${username}-${net_shared_dir}]
   path = ${home_dir}/${net_shared_dir}
   available = yes
   valid users = ${username}
   read only = no
   browsable = yes
   public = yes
   writable = yes"

    echo "$content"
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
    log_info "Creating symlink from $shared_dir to ${home_dir}/Shared" "$MODULE_NAME"
    Sudo create_symlink "$shared_dir" "${home_dir}/Shared" "force"
    if [ $? -eq 0 ]; then
        # Set ownership of the symlink
        Sudo chown -h "${username}:${username}" "${home_dir}/Shared"
    else
        log_error "Failed to create symlink to shared directory" "$MODULE_NAME"
    fi
    
    # Create Net Shared Folder
    Sudo ensure_directory "${home_dir}/${net_shared_dir}" "755"
    Sudo chown -R "${username}:${username}" "${home_dir}/${net_shared_dir}"
    
    # Set up Samba configuration for the user (regardless of whether Samba is installed)
    local samba_config=$(generate_samba_share_config "$username")
    
    if [ -z "$samba_config" ]; then
        log_error "Failed to generate Samba configuration for user: $username" "$MODULE_NAME"
    else
        # Configure Samba share for the user
        local filename="/etc/samba/smb.conf"
        
        # Create Samba config directory if it doesn't exist
        Sudo ensure_directory "/etc/samba" "755"
        
        # Create empty smb.conf if it doesn't exist
        if [ ! -f "$filename" ]; then
            Sudo touch "$filename"
            Sudo chmod 644 "$filename"
        fi
        
        # Use the generated config for insertion
        Sudo safe_insert "Create Net Shared Folder for ${username}" "$filename" "$samba_config"
    fi
    
    # Set up Samba password for the user if Samba is installed
    if command -v smbpasswd &>/dev/null; then
        log_debug "Setting up Samba password for user: $username" "$MODULE_NAME"
        (
            echo "${default_password}"
            echo "${default_password}"
        ) | Sudo smbpasswd -s -a "${username}"
    else
        log_info "Samba is not installed, password will be set when Samba is installed" "$MODULE_NAME"
    fi
    
    # Set up VNC for the user
    local vnc_dir="${home_dir}/.vnc"
    Sudo ensure_directory "$vnc_dir" "700"
    
    local filename="${vnc_dir}/xstartup"
    local vnc_config=$(generate_vnc_config "$username")
    
    Sudo safe_insert "Config VNC Server X session for ${username}" "$filename" "$vnc_config"
    Sudo chmod +x "$filename"
    Sudo chown -R "${username}:${username}" "${vnc_dir}"
    
    log_info "Resources set up successfully for user: $username" "$MODULE_NAME"
    return 0
}

# Function to add a new system user based on the user entry in globals.sh
# Usage: add_system_user user_id
# Returns: 0 on success, 1 on failure
add_system_user() {
    local user_id="$1"
    
    # Check if user exists in user data structure
    if [[ -z "${USER_FULLNAME[$user_id]}" ]]; then
        log_error "User '$user_id' not found in global user data structure" "$MODULE_NAME"
        return 1
    fi
    
    # Ensure shared resources exist before creating the user
    if ! check_shared_resources; then
        log_info "Creating shared resources before adding user" "$MODULE_NAME"
        if ! create_shared_resources; then
            log_error "Failed to create shared resources, cannot add user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    local full_name="${USER_FULLNAME[$user_id]}"
    local is_super="${USER_IS_SUPERUSER[$user_id]}"
    local username=$(get_username "$user_id")
    
    log_debug "Adding system user: $username (user_id: $user_id, super: $is_super, full name: $full_name)" "$MODULE_NAME"
    
    # Call create_user to handle the actual system user creation
    create_user "$username" "$is_super" "$full_name"
    return $?
}

# Function to remove a system user based on the user entry in globals.sh
# Usage: remove_system_user user_id
# Returns: 0 on success, 1 on failure
remove_system_user() {
    local user_id="$1"
    
    # Check if user exists in user data structure
    if [[ -z "${USER_FULLNAME[$user_id]}" ]]; then
        log_error "User '$user_id' not found in global user data structure" "$MODULE_NAME"
        return 1
    fi
    
    local username=$(get_username "$user_id")
    
    log_debug "Removing system user: $username (user_id: $user_id)" "$MODULE_NAME"
    
    # Check if the user exists on the system
    if ! id "$username" &>/dev/null; then
        log_warning "System user $username does not exist" "$MODULE_NAME"
        return 1
    fi
    
    # Ask for confirmation before deleting the user
    if [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "Remove system user $username?"; then
            log_warning "User removal cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Delete the user's home directory and mail spool
    log_info "Removing system user: $username" "$MODULE_NAME"
    Sudo userdel -r "$username"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to remove system user: $username" "$MODULE_NAME"
        return 1
    fi
    
    log_info "System user $username removed successfully" "$MODULE_NAME"
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

# Function to create users from the global data structures
create_users_from_list() {
    log_debug "Creating users from global data structures" "$MODULE_NAME"
    
    # Create shared resources first
    create_shared_resources
    
    # Get all users and create them based on their user information
    for user_id in "${!USER_FULLNAME[@]}"; do
        # Add the system user
        add_system_user "$user_id"
    done
    
    # Add admin user as a super user if not already in the list
    local admin="${USER_CONFIG[admin]}"
    if [ -n "$admin" ]; then
        local admin_in_super_users=false
        
        # Check if admin is already in the super users list
        for user_id in "${!USER_FULLNAME[@]}"; do
            if [ "${USER_IS_SUPERUSER[$user_id]}" = "true" ]; then
                local super_username=$(get_username "$user_id")
                if [ "$super_username" = "$admin" ]; then
                    admin_in_super_users=true
                    break
                fi
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


# Main function to set up users and shared resources
setup_users() {
    log_info "Setting up users and shared resources" "$MODULE_NAME"
    
    # Create shared resources
    create_shared_resources
    
    # Create users from lists
    create_users_from_list
    
    log_info "User setup completed" "$MODULE_NAME"
    return 0
}

# Function to tear down all users and shared resources
# Usage: teardown_users [force]
# Returns: 0 on success, 1 on failure
teardown_users() {
    local force="$1"
    log_info "Tearing down all users and shared resources" "$MODULE_NAME"
    
    # Track success/failure
    local failure=0
    
    # Check if we should force deletion or ask for confirmation
    if [ "$force" != "force" ] && [ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]; then
        if ! confirm "This will remove all lab users and shared resources. Are you sure?"; then
            log_warning "Teardown cancelled by user" "$MODULE_NAME"
            return 1
        fi
    fi
    
    # Remove all users from the system
    log_info "Removing all users from the system" "$MODULE_NAME"
    
    # Get a list of all users from globals.sh
    local all_users=$(global_vars "all_users")
    
    # First pass: Attempt to remove each user
    for user_id in $all_users; do
        local username=$(get_username "$user_id")
        
        # Check if user exists in the system
        if id "$username" &>/dev/null; then
            log_info "Removing user: $username" "$MODULE_NAME"
            userdel -r "$username" >/dev/null 2>&1
            
            if [ $? -ne 0 ]; then
                log_warning "Failed to remove user: $username" "$MODULE_NAME"
                failure=1
            else
                log_info "Successfully removed user: $username" "$MODULE_NAME"
            fi
        else
            log_debug "User does not exist in system: $username" "$MODULE_NAME"
        fi
    done
    
    # Also check for the admin user if it's not already in the list
    local admin="${USER_CONFIG[admin]}"
    if [ -n "$admin" ]; then
        if id "$admin" &>/dev/null; then
            log_info "Admin user exists: $admin" "$MODULE_NAME"
            
            # Check if admin user should be removed (if it was created by the system)
            local admin_in_super_users=false
            for user_id in $all_users; do
                local username=$(get_username "$user_id")
                if [ "$username" = "$admin" ]; then
                    admin_in_super_users=true
                    break
                fi
            done
            
            # Only remove if it was added by the system and not already processed
            if [ "$admin_in_super_users" = "false" ]; then
                log_info "Removing admin user: $admin" "$MODULE_NAME"
                userdel -r "$admin" >/dev/null 2>&1
                
                if [ $? -ne 0 ]; then
                    log_warning "Failed to remove admin user: $admin" "$MODULE_NAME"
                    failure=1
                else
                    log_info "Successfully removed admin user: $admin" "$MODULE_NAME"
                fi
            fi
        fi
    fi
    
    # Remove Samba configurations for users
    if [ -f "/etc/samba/smb.conf" ]; then
        log_info "Cleaning up Samba configurations" "$MODULE_NAME"
        
        # For each user, use safe_remove to remove their Samba configuration
        local removal_count=0
        
        for user_id in $all_users; do
            local username=$(get_username "$user_id")
            
            # Check if the user exists in the system (needed for home directory)
            if id "$username" &>/dev/null; then
                # Generate the same Samba configuration we would have used for insertion
                local samba_config=$(generate_samba_share_config "$username")
                
                if [ -n "$samba_config" ]; then
                    # Check if the entry exists before attempting removal
                    local title_line="[${username}-${USER_CONFIG[net_shared_dir]}]"
                    if Sudo grep -q "$title_line" "/etc/samba/smb.conf"; then
                        log_debug "Removing Samba configuration for $username" "$MODULE_NAME"
                        
                        # Use safe_remove to remove the section with exactly the same configuration
                        Sudo safe_remove "Remove Samba configuration for $username" "/etc/samba/smb.conf" "$samba_config"
                        
                        if [ $? -eq 0 ]; then
                            ((removal_count++))
                        fi
                    fi
                fi
            else
                # User doesn't exist in system, so we need a different approach
                # Try to find and remove any sections matching this username pattern
                local net_shared_dir="${USER_CONFIG[net_shared_dir]}"
                local pattern="[$username-$net_shared_dir]"
                
                if Sudo grep -q "$pattern" "/etc/samba/smb.conf"; then
                    log_debug "Removing Samba configuration for deleted user: $username" "$MODULE_NAME"
                    
                    # For deleted users, generate the same Samba configuration we would have used for insertion
                    # We can use generate_samba_share_config to create consistent configuration
                    
                    # Create a temporary home directory path since the user is deleted
                    local net_shared_dir="${USER_CONFIG[net_shared_dir]}"
                    local temp_home_dir="/home/$username"  # Assume standard home directory format
                    
                    # Override the getent passwd function call inside generate_samba_share_config
                    # by setting a temporary function that returns our fake home directory
                    function getent() {
                        if [[ "$1" == "passwd" && "$2" == "$username" ]]; then
                            echo "$username:x:1000:1000::/home/$username:/bin/bash"
                        else
                            command getent "$@"
                        fi
                    }
                    
                    # Generate the same Samba configuration we would have used for insertion
                    local samba_config=$(generate_samba_share_config "$username")
                    
                    # Unset the temporary function
                    unset -f getent
                    
                    if [ -n "$samba_config" ]; then
                        log_debug "Generated Samba configuration for removal for user: $username" "$MODULE_NAME"
                        Sudo safe_remove "Remove Samba configuration for deleted user $username" "/etc/samba/smb.conf" "$samba_config"
                    fi
                    
                    if [ $? -eq 0 ]; then
                        ((removal_count++))
                    fi
                fi
            fi
        done
        
        log_info "Removed $removal_count Samba configurations" "$MODULE_NAME"
        
        # Restart Samba if it's installed and we made changes
        if [ $removal_count -gt 0 ] && command -v systemctl &>/dev/null && systemctl list-unit-files | grep -q "smbd.service"; then
            log_debug "Restarting Samba services" "$MODULE_NAME"
            Sudo systemctl restart smbd
            Sudo systemctl restart nmbd
        fi
    fi
    
    # Remove shared resources
    log_info "Removing shared resources" "$MODULE_NAME"
    if ! remove_shared_resources "force"; then
        log_warning "Failed to remove some shared resources" "$MODULE_NAME"
        failure=1
    fi
    
    if [ $failure -eq 0 ]; then
        log_info "Successfully removed all users and shared resources" "$MODULE_NAME"
        return 0
    else
        log_warning "Completed teardown with some failures" "$MODULE_NAME"
        return 1
    fi
}

# Function to handle user management commands
# Usage: lab_users_main [args...]
# Returns: 0 on success, 1 on failure
lab_users_main() {
    log_debug "User management module main function called with args: $@" "$MODULE_NAME"
    
    # Parse arguments
    local setup=false
    local teardown=false
    local force=false
    local add_user=""
    local remove_user=""
    local check=false
    local show_help=false
    
    # Process arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            setup)
                setup=true
                shift
                ;;
            teardown)
                teardown=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            add)
                if [[ -n "$2" ]]; then
                    add_user="$2"
                    shift 2
                else
                    log_error "Error: Missing user ID for add command" "$MODULE_NAME"
                    return 1
                fi
                ;;
            remove)
                if [[ -n "$2" ]]; then
                    remove_user="$2"
                    shift 2
                else
                    log_error "Error: Missing user ID for remove command" "$MODULE_NAME"
                    return 1
                fi
                ;;
            check)
                check=true
                shift
                ;;
            --help|-h)
                show_help=true
                shift
                ;;
            *)
                log_error "Unknown argument: $1" "$MODULE_NAME"
                show_help=true
                shift
                ;;
        esac
    done
    
    # Show help
    if [ "$show_help" = "true" ]; then
        echo "Usage: lab_users_main [command] [options]"
        echo ""
        echo "Commands:"
        echo "  setup                  Setup all users and shared resources"
        echo "  teardown [--force]     Remove all users and shared resources"
        echo "  add <user_id>          Add a system user based on user_id in globals.sh"
        echo "  remove <user_id>       Remove a system user based on user_id in globals.sh"
        echo "  check                  Check if all shared resources exist"
        echo ""
        echo "Options:"
        echo "  --force                Force operation without confirmation"
        echo "  --help, -h             Show this help message"
        return 0
    fi
    
    # Execute the appropriate command
    if [ "$setup" = "true" ]; then
        setup_users
        return $?
    elif [ "$teardown" = "true" ]; then
        if [ "$force" = "true" ]; then
            teardown_users "force"
        else
            teardown_users
        fi
        return $?
    elif [ -n "$add_user" ]; then
        add_system_user "$add_user"
        return $?
    elif [ -n "$remove_user" ]; then
        remove_system_user "$remove_user"
        return $?
    elif [ "$check" = "true" ]; then
        check_shared_resources
        return $?
    else
        log_error "No command specified" "$MODULE_NAME"
        return 1
    fi
}

# Export only the main function
export -f lab_users_main

# Module metadata
MODULE_COMMANDS=(
    "lab_users_main setup:Setup all users and shared resources"
    "lab_users_main teardown:Remove all users and shared resources (args: [--force])"
    "lab_users_main check:Check if all shared resources exist"
    "lab_users_main add:Add a system user based on user_id in globals.sh (args: user_id)"
    "lab_users_main remove:Remove a system user based on user_id in globals.sh (args: user_id)"
)
export MODULE_COMMANDS

log_debug "User management module loaded" "$MODULE_NAME"