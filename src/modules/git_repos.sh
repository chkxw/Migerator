#!/bin/bash

# Level 2 abstraction: Git Repositories module
# This module handles cloning and managing personal git repositories

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/core/sudo.sh"
source "$PROJECT_ROOT/src/core/file_ops.sh"
source "$PROJECT_ROOT/src/core/git_ops.sh"

# Log with hard-coded module name for initial loading
log_debug "Loading git_repos module" "git_repos"

# Function to generate example configuration for globals.sh
# Returns: example configuration as a string
git_repos_generate_example_config() {
    local content="
# Git Repository Configuration
# Add these lines to your globals.sh file:

# Example public repository
GIT_REPO_URL[myproject]=\"https://github.com/username/myproject.git\"
GIT_REPO_DIR[myproject]=\"\$HOME/projects/myproject\"
GIT_REPO_BRANCH[myproject]=\"main\"
GIT_REPO_SSH_KEY[myproject]=\"\"

# Example private repository with SSH
GIT_REPO_URL[private_repo]=\"git@github.com:username/private-repo.git\"
GIT_REPO_DIR[private_repo]=\"\$HOME/work/private-repo\"
GIT_REPO_BRANCH[private_repo]=\"develop\"
GIT_REPO_SSH_KEY[private_repo]=\"\$HOME/.ssh/id_rsa\"
"
    
    echo "$content"
}

# Function to clone a single repository
# Args: $1 - repo URL, $2 - target dir, $3 - branch, $4 - ssh key (optional), $5 - force (optional)
# Returns: 0 on success, 1 on failure, 2 if skipped
git_repos_clone_single() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="$3"
    local ssh_key="$4"
    local force="${5:-false}"
    
    log_info "Processing repository: $repo_url -> $target_dir (branch: $branch)" "$MODULE_NAME"
    
    # Check if directory already exists
    if [[ -d "$target_dir" ]] && [[ "$force" != "true" ]]; then
        log_warning "Directory already exists, skipping: $target_dir" "$MODULE_NAME"
        log_info "Use --force to overwrite existing directories" "$MODULE_NAME"
        return 2
    fi
    
    # Build git_clone command arguments
    local clone_args="\"$repo_url\" \"$target_dir\" --branch \"$branch\""
    
    if [[ "$force" == "true" ]]; then
        clone_args="$clone_args --force"
    fi
    
    if [[ -n "$ssh_key" ]]; then
        clone_args="$clone_args --ssh-key \"$ssh_key\""
    fi
    
    # Clone the repository
    if eval git_clone $clone_args; then
        log_info "Successfully cloned: $repo_url" "$MODULE_NAME"
        return 0
    else
        log_error "Failed to clone: $repo_url" "$MODULE_NAME"
        return 1
    fi
}

# Function to update a single repository
# Args: $1 - target dir, $2 - branch, $3 - ssh key (optional)
# Returns: 0 on success, 1 on failure
git_repos_update_single() {
    local target_dir="$1"
    local branch="$2"
    local ssh_key="$3"
    
    log_info "Updating repository: $target_dir (branch: $branch)" "$MODULE_NAME"
    
    # Build git_update command arguments
    local update_args="\"$target_dir\" --branch \"$branch\""
    
    if [[ -n "$ssh_key" ]]; then
        update_args="$update_args --ssh-key \"$ssh_key\""
    fi
    
    # Update the repository
    if eval git_update $update_args; then
        log_info "Successfully updated: $target_dir" "$MODULE_NAME"
        return 0
    else
        log_error "Failed to update: $target_dir" "$MODULE_NAME"
        return 1
    fi
}

# Function to clone repositories from globals
# Args: $1 - force (optional), $2 - space-separated list of repo keys to clone (optional), $3 - SSH key override (optional)
# Returns: 0 on success, 1 on failure
git_repos_clone_from_globals() {
    local force="${1:-false}"
    local selected_repos="$2"
    local ssh_key_override="$3"
    local repo_list=$(global_vars git_repos)
    
    if [[ -z "$repo_list" ]]; then
        log_warning "No git repositories configured in globals.sh" "$MODULE_NAME"
        log_info "Add repository configurations to globals.sh. Example:" "$MODULE_NAME"
        git_repos_generate_example_config
        return 1
    fi
    
    local failed=0
    local success=0
    local skipped=0
    
    # Filter repo list if specific repos are selected
    if [[ -n "$selected_repos" ]]; then
        local filtered_list=""
        for repo_name in $repo_list; do
            for selected in $selected_repos; do
                if [[ "$repo_name" == "$selected" ]]; then
                    filtered_list="$filtered_list $repo_name"
                    break
                fi
            done
        done
        repo_list="$filtered_list"
        
        if [[ -z "$repo_list" ]]; then
            log_warning "No matching repositories found for: $selected_repos" "$MODULE_NAME"
            log_info "Available repositories: $(global_vars git_repos)" "$MODULE_NAME"
            return 1
        fi
        
        log_info "Cloning selected repositories: $repo_list" "$MODULE_NAME"
    fi
    
    for repo_name in $repo_list; do
        local url="${GIT_REPO_URL[$repo_name]}"
        local dir="${GIT_REPO_DIR[$repo_name]}"
        local branch="${GIT_REPO_BRANCH[$repo_name]:-main}"
        local ssh_key="${GIT_REPO_SSH_KEY[$repo_name]}"
        
        # Use SSH key override if provided
        if [[ -n "$ssh_key_override" ]]; then
            ssh_key="$ssh_key_override"
        fi
        
        # Expand variables in directory path
        dir=$(eval echo "$dir")
        ssh_key=$(eval echo "$ssh_key")
        
        if [[ -n "$url" ]] && [[ -n "$dir" ]]; then
            log_info "Processing repository: $repo_name" "$MODULE_NAME"
            local result
            git_repos_clone_single "$url" "$dir" "$branch" "$ssh_key" "$force"
            result=$?
            
            case $result in
                0) ((success++)) ;;
                1) ((failed++)) ;;
                2) ((skipped++)) ;;
            esac
        else
            log_warning "Incomplete configuration for repository: $repo_name" "$MODULE_NAME"
            ((failed++))
        fi
    done
    
    log_info "Clone summary: $success succeeded, $failed failed, $skipped skipped" "$MODULE_NAME"
    
    [[ $failed -eq 0 ]] && return 0 || return 1
}

# Function to update repositories from globals
# Returns: 0 on success, 1 on failure
git_repos_update_from_globals() {
    local repo_list=$(global_vars git_repos)
    
    if [[ -z "$repo_list" ]]; then
        log_warning "No git repositories configured in globals.sh" "$MODULE_NAME"
        return 1
    fi
    
    local failed=0
    local success=0
    
    for repo_name in $repo_list; do
        local dir="${GIT_REPO_DIR[$repo_name]}"
        local branch="${GIT_REPO_BRANCH[$repo_name]:-main}"
        local ssh_key="${GIT_REPO_SSH_KEY[$repo_name]}"
        
        # Expand variables in directory path
        dir=$(eval echo "$dir")
        ssh_key=$(eval echo "$ssh_key")
        
        if [[ -d "$dir" ]]; then
            log_info "Processing repository: $repo_name" "$MODULE_NAME"
            if git_repos_update_single "$dir" "$branch" "$ssh_key"; then
                ((success++))
            else
                ((failed++))
            fi
        else
            log_warning "Repository directory not found, skipping: $repo_name ($dir)" "$MODULE_NAME"
        fi
    done
    
    log_info "Update summary: $success succeeded, $failed failed" "$MODULE_NAME"
    
    [[ $failed -eq 0 ]] && return 0 || return 1
}

# Function to remove cloned repositories from globals
# Returns: 0 on success, 1 on failure
git_repos_remove_from_globals() {
    local repo_list=$(global_vars git_repos)
    
    if [[ -z "$repo_list" ]]; then
        log_warning "No git repositories configured in globals.sh" "$MODULE_NAME"
        return 1
    fi
    
    local failed=0
    local success=0
    
    for repo_name in $repo_list; do
        local dir="${GIT_REPO_DIR[$repo_name]}"
        
        # Expand variables in directory path
        dir=$(eval echo "$dir")
        
        if [[ -d "$dir" ]]; then
            log_info "Removing repository: $repo_name ($dir)" "$MODULE_NAME"
            if rm -rf "$dir"; then
                ((success++))
                log_info "Successfully removed: $repo_name" "$MODULE_NAME"
            else
                ((failed++))
                log_error "Failed to remove: $repo_name" "$MODULE_NAME"
            fi
        else
            log_debug "Repository directory not found, skipping: $repo_name ($dir)" "$MODULE_NAME"
        fi
    done
    
    log_info "Remove summary: $success succeeded, $failed failed" "$MODULE_NAME"
    
    [[ $failed -eq 0 ]] && return 0 || return 1
}

# Main function for the git_repos module
# Usage: git_repos_main [command] [options]
# Commands:
#   clone         Clone repositories defined in globals
#   update        Update existing repositories
#   remove        Remove cloned repositories
# Options:
#   --url URL     Clone single repository (requires --dir and optionally --branch, --ssh-key)
#   --dir DIR     Target directory for single clone
#   --branch BR   Branch to clone (default: main)
#   --ssh-key KEY SSH key for authentication
#   --force       Force overwrite existing directories when cloning
#   --help        Display this help message
# Returns: 0 on success, 1 on failure
git_repos_main() {
    # Save previous module context
    local PREV_MODULE_NAME="$MODULE_NAME"
    local PREV_MODULE_DESCRIPTION="$MODULE_DESCRIPTION"
    local PREV_MODULE_VERSION="$MODULE_VERSION"
    
    # Set this module's context
    MODULE_NAME="git_repos"
    MODULE_DESCRIPTION="Clone and manage personal git repositories"
    MODULE_VERSION="1.0.0"
    
    log_debug "Git repos module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local command=""
    local single_url=""
    local single_dir=""
    local single_branch="main"
    local single_ssh_key=""
    local force=false
    local show_help=false
    local selected_repos=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            clone|update|remove|list)
                command="$1"
                shift
                ;;
            --url)
                single_url="$2"
                shift 2
                ;;
            --dir)
                single_dir="$2"
                shift 2
                ;;
            --branch)
                single_branch="$2"
                shift 2
                ;;
            --ssh-key)
                single_ssh_key="$2"
                shift 2
                ;;
            --force)
                force=true
                shift
                ;;
            --only)
                # Collect all repository names until next option or end
                shift
                while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                    selected_repos="$selected_repos $1"
                    shift
                done
                ;;
            --help)
                show_help=true
                shift
                ;;
            *)
                log_error "Unknown option: $1" "$MODULE_NAME"
                show_help=true
                shift
                ;;
        esac
    done
    
    # Show help if requested or no command specified
    if [[ "$show_help" = "true" ]] || [[ -z "$command" ]]; then
        help_text=$(cat << EOF
Usage: git_repos_main [command] [options]

Commands:
  clone         Clone repositories defined in globals.sh
  update        Update existing repositories
  remove        Remove cloned repositories
  list          List available repositories

Options:
  --url URL     Clone single repository (requires --dir)
  --dir DIR     Target directory for single clone
  --branch BR   Branch to clone (default: main)
  --ssh-key KEY SSH key for authentication
  --force       Force overwrite existing directories when cloning
  --only        Clone only specific repositories (space-separated list)
  --help        Display this help message

Repository Configuration:
  Repositories are configured in globals.sh using these arrays:
  - GIT_REPO_URL[name]     Repository URL
  - GIT_REPO_DIR[name]     Target directory
  - GIT_REPO_BRANCH[name]  Branch to clone (optional, default: main)
  - GIT_REPO_SSH_KEY[name] SSH key path (optional)

Examples:
  # Clone all repositories from globals (skip existing)
  git_repos_main clone

  # Clone all repositories from globals (force overwrite)
  git_repos_main clone --force

  # Clone only specific repositories
  git_repos_main clone --only usr_scripts
  git_repos_main clone --only usr_scripts important

  # Clone single repository
  git_repos_main clone --url https://github.com/user/repo.git --dir ~/projects/repo

  # Update all repositories
  git_repos_main update

  # Remove all cloned repositories
  git_repos_main remove

Available repositories:
EOF
)
        # Add repositories to the help text
        local repo_list=$(global_vars git_repos 2>/dev/null)
        if [[ -n "$repo_list" ]]; then
            for repo_name in $repo_list; do
                local url="${GIT_REPO_URL[$repo_name]}"
                local dir="${GIT_REPO_DIR[$repo_name]}"
                local branch="${GIT_REPO_BRANCH[$repo_name]:-main}"
                help_text="$help_text
  $repo_name - $url -> $dir (branch: $branch)"
            done
        else
            help_text="$help_text
  No repositories configured in globals.sh"
        fi
        
        # Output the help text
        echo "$help_text"
        # Restore previous module context
        MODULE_NAME="$PREV_MODULE_NAME"
        MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
        MODULE_VERSION="$PREV_MODULE_VERSION"
        return 0
    fi
    
    # Execute command
    local result=0
    
    case "$command" in
        clone)
            if [[ -n "$single_url" ]] && [[ -n "$single_dir" ]]; then
                # Clone single repository
                local clone_result
                git_repos_clone_single "$single_url" "$single_dir" "$single_branch" "$single_ssh_key" "$force"
                clone_result=$?
                if [[ $clone_result -eq 1 ]]; then
                    result=1
                fi
            else
                # Clone from globals
                if ! git_repos_clone_from_globals "$force" "$selected_repos" "$single_ssh_key"; then
                    result=1
                fi
            fi
            ;;
            
        update)
            if [[ -n "$single_dir" ]]; then
                # Update single repository
                if ! git_repos_update_single "$single_dir" "$single_branch" "$single_ssh_key"; then
                    result=1
                fi
            else
                # Update from globals
                if ! git_repos_update_from_globals; then
                    result=1
                fi
            fi
            ;;
            
        remove)
            if [[ "${SCRIPT_CONFIG[confirm_all]}" != "true" ]]; then
                if ! confirm "Remove all cloned repositories defined in globals?"; then
                    log_warning "Repository removal cancelled by user" "$MODULE_NAME"
                    result=1
                else
                    if ! git_repos_remove_from_globals; then
                        result=1
                    fi
                fi
            else
                if ! git_repos_remove_from_globals; then
                    result=1
                fi
            fi
            ;;
            
        list)
            list_text="Available repositories:"
            local repo_list=$(global_vars git_repos)
            if [[ -n "$repo_list" ]]; then
                for repo_name in $repo_list; do
                    local url="${GIT_REPO_URL[$repo_name]}"
                    local dir="${GIT_REPO_DIR[$repo_name]}"
                    local branch="${GIT_REPO_BRANCH[$repo_name]:-main}"
                    list_text="$list_text
  $repo_name - $url -> $dir (branch: $branch)"
                done
            else
                list_text="$list_text
  No repositories configured in globals.sh"
            fi
            echo "$list_text"
            
            # Restore previous module context
            MODULE_NAME="$PREV_MODULE_NAME"
            MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
            MODULE_VERSION="$PREV_MODULE_VERSION"
            
            return 0
            ;;
    esac
    
    if [[ $result -eq 0 ]]; then
        log_info "Git repos $command completed successfully" "$MODULE_NAME"
    else
        log_error "Git repos $command completed with errors" "$MODULE_NAME"
    fi
    
    # Restore previous module context
    MODULE_NAME="$PREV_MODULE_NAME"
    MODULE_DESCRIPTION="$PREV_MODULE_DESCRIPTION"
    MODULE_VERSION="$PREV_MODULE_VERSION"
    
    return $result
}

# Export only the main function
export -f git_repos_main

# Module metadata
MODULE_COMMANDS=(
    "git_repos_main:Clone and manage personal git repositories"
    "git_repos_main list:List available repositories"
)
export MODULE_COMMANDS

log_debug "Git repos module loaded" "git_repos"