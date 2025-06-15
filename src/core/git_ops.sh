#!/bin/bash

# Git operations module for managing git repositories
# Provides functions to clone, update, and remove git repositories with optional SSH key support

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/globals.sh"
source "$SCRIPT_DIR/sudo.sh"

log_debug "Loading git operations module" "git_ops"

# Function to clone a git repository (with submodules by default)
# Usage: git_clone repo_url target_dir [options]
# Options:
#   --ssh-key PATH    Path to SSH private key to use for authentication
#   --branch NAME     Branch to checkout (default: repository default)
#   --depth NUMBER    Create a shallow clone with history truncated to specified number
#   --force          Remove existing directory before cloning
# Note: --recursive is enabled by default to clone submodules
# Returns: 0 on success, 1 on failure
git_clone() {
    local repo_url="$1"
    local target_dir="$2"
    shift 2
    
    # Parse optional arguments
    local ssh_key=""
    local branch=""
    local depth=""
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssh-key)
                # Expand tilde in SSH key path
                ssh_key="${2/#\~/$HOME}"
                shift 2
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            --depth)
                depth="$2"
                shift 2
                ;;
            --force)
                force=true
                shift
                ;;
            *)
                log_error "Unknown option: $1" "git_ops"
                return 1
                ;;
        esac
    done
    
    log_info "Cloning git repository: $repo_url -> $target_dir" "git_ops"
    
    # Validate inputs
    if [ -z "$repo_url" ] || [ -z "$target_dir" ]; then
        log_error "Repository URL and target directory are required" "git_ops"
        return 1
    fi
    
    # Check if target directory already exists
    if [ -d "$target_dir" ]; then
        if [ "$force" = true ]; then
            log_warning "Target directory exists, removing: $target_dir" "git_ops"
            rm -rf "$target_dir"
        else
            log_error "Target directory already exists: $target_dir (use --force to overwrite)" "git_ops"
            return 1
        fi
    fi
    
    # Create parent directory if it doesn't exist
    local parent_dir=$(dirname "$target_dir")
    if [ ! -d "$parent_dir" ]; then
        log_debug "Creating parent directory: $parent_dir" "git_ops"
        mkdir -p "$parent_dir"
    fi
    
    # Build git command with recursive as default
    local git_cmd="git clone --recursive"
    
    # Add branch option if specified
    if [ -n "$branch" ]; then
        git_cmd="$git_cmd --branch $branch"
    fi
    
    # Add depth option if specified
    if [ -n "$depth" ]; then
        git_cmd="$git_cmd --depth $depth"
    fi
    
    # Add repository URL and target directory
    git_cmd="$git_cmd \"$repo_url\" \"$target_dir\""
    
    # Execute git clone with optional SSH key
    if [ -n "$ssh_key" ]; then
        # Validate SSH key file
        if [ ! -f "$ssh_key" ]; then
            log_error "SSH key file not found: $ssh_key" "git_ops"
            return 1
        fi
        
        # Check SSH key permissions
        local key_perms=$(stat -c %a "$ssh_key" 2>/dev/null || stat -f %A "$ssh_key" 2>/dev/null)
        log_debug "SSH key permissions: $key_perms" "git_ops"
        
        # Use GIT_SSH_COMMAND to specify the SSH key
        log_debug "Using SSH key: $ssh_key" "git_ops"
        log_debug "Executing: GIT_SSH_COMMAND=\"ssh -i $ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new\" $git_cmd" "git_ops"
        
        # Add verbose SSH logging in debug mode
        if [ "$DEBUG_MODE" = "true" ]; then
            GIT_SSH_COMMAND="ssh -v -i $ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30" eval $git_cmd
        else
            GIT_SSH_COMMAND="ssh -i $ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30" eval $git_cmd
        fi
    else
        log_debug "Executing: $git_cmd" "git_ops"
        eval $git_cmd
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Successfully cloned repository to: $target_dir" "git_ops"
        return 0
    else
        log_error "Failed to clone repository: $repo_url" "git_ops"
        return 1
    fi
}

# Function to update an existing git repository
# Usage: git_update target_dir [options]
# Options:
#   --ssh-key PATH    Path to SSH private key to use for authentication
#   --branch NAME     Branch to checkout and pull
#   --reset          Reset to origin state (discards local changes)
# Returns: 0 on success, 1 on failure
git_update() {
    local target_dir="$1"
    shift
    
    # Parse optional arguments
    local ssh_key=""
    local branch=""
    local reset=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssh-key)
                # Expand tilde in SSH key path
                ssh_key="${2/#\~/$HOME}"
                shift 2
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            --reset)
                reset=true
                shift
                ;;
            *)
                log_error "Unknown option: $1" "git_ops"
                return 1
                ;;
        esac
    done
    
    log_info "Updating git repository: $target_dir" "git_ops"
    
    # Check if directory exists and is a git repository
    if [ ! -d "$target_dir" ]; then
        log_error "Target directory does not exist: $target_dir" "git_ops"
        return 1
    fi
    
    if [ ! -d "$target_dir/.git" ]; then
        log_error "Target directory is not a git repository: $target_dir" "git_ops"
        return 1
    fi
    
    # Change to repository directory
    pushd "$target_dir" > /dev/null
    
    # Checkout branch if specified
    if [ -n "$branch" ]; then
        log_debug "Checking out branch: $branch" "git_ops"
        git checkout "$branch"
    fi
    
    # Pull latest changes (including submodules)
    if [ -n "$ssh_key" ]; then
        # Validate SSH key file
        if [ ! -f "$ssh_key" ]; then
            log_error "SSH key file not found: $ssh_key" "git_ops"
            popd > /dev/null
            return 1
        fi
        
        log_debug "Pulling with SSH key: $ssh_key" "git_ops"
        GIT_SSH_COMMAND="ssh -i $ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" git pull --recurse-submodules
    else
        git pull --recurse-submodules
    fi
    
    # Update submodules to ensure they're properly initialized
    log_debug "Updating submodules" "git_ops"
    if [ -n "$ssh_key" ]; then
        GIT_SSH_COMMAND="ssh -i $ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" git submodule update --init --recursive
    else
        git submodule update --init --recursive
    fi
    
    # Reset if requested (after pull to get latest origin state)
    if [ "$reset" = true ]; then
        log_debug "Resetting repository to origin state" "git_ops"
        git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)
        # Clean untracked files
        git clean -fd
    fi
    
    local result=$?
    popd > /dev/null
    
    if [ $result -eq 0 ]; then
        log_info "Successfully updated repository: $target_dir" "git_ops"
        return 0
    else
        log_error "Failed to update repository: $target_dir" "git_ops"
        return 1
    fi
}

# Function to remove a cloned git repository
# Usage: git_remove target_dir [options]
# Options:
#   --backup PATH    Backup directory before removing
# Returns: 0 on success, 1 on failure
git_remove() {
    local target_dir="$1"
    shift
    
    # Parse optional arguments
    local backup_path=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backup)
                backup_path="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1" "git_ops"
                return 1
                ;;
        esac
    done
    
    log_info "Removing git repository: $target_dir" "git_ops"
    
    # Check if directory exists
    if [ ! -d "$target_dir" ]; then
        log_warning "Target directory does not exist: $target_dir" "git_ops"
        return 0
    fi
    
    # Create backup if requested
    if [ -n "$backup_path" ]; then
        log_debug "Creating backup: $target_dir -> $backup_path" "git_ops"
        cp -r "$target_dir" "$backup_path"
        if [ $? -ne 0 ]; then
            log_error "Failed to create backup" "git_ops"
            return 1
        fi
    fi
    
    # Remove the repository
    rm -rf "$target_dir"
    
    if [ $? -eq 0 ]; then
        log_info "Successfully removed repository: $target_dir" "git_ops"
        return 0
    else
        log_error "Failed to remove repository: $target_dir" "git_ops"
        return 1
    fi
}

# Function to check if a directory is a git repository
# Usage: is_git_repo directory
# Returns: 0 if it's a git repo, 1 otherwise
is_git_repo() {
    local dir="$1"
    
    if [ -d "$dir/.git" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get the current branch of a git repository
# Usage: git_current_branch directory
# Returns: Branch name on stdout, empty on error
git_current_branch() {
    local dir="$1"
    
    if ! is_git_repo "$dir"; then
        return 1
    fi
    
    pushd "$dir" > /dev/null
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    popd > /dev/null
    
    echo "$branch"
}

# Function to get the remote URL of a git repository
# Usage: git_remote_url directory [remote_name]
# Returns: Remote URL on stdout, empty on error
git_remote_url() {
    local dir="$1"
    local remote="${2:-origin}"
    
    if ! is_git_repo "$dir"; then
        return 1
    fi
    
    pushd "$dir" > /dev/null
    local url=$(git config --get remote.${remote}.url 2>/dev/null)
    popd > /dev/null
    
    echo "$url"
}

log_debug "Git operations module loaded successfully" "git_ops"