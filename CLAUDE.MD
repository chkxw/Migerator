# Ubuntu Setup Script Project

This document serves as the comprehensive reference for the modular Ubuntu setup script project. It contains all requirements, implementation guidelines, project structure, and progress tracking.

## Project Goals

We are developing a systematic and modular setup script for Ubuntu systems with these key requirements:

1. **Single executable file** as the final deliverable
2. **Modular development process** for easy maintenance and extension
3. **Multi-level abstraction** for clean code organization
4. **Safe configuration management** to prevent duplicate modifications
5. **Comprehensive logging** for debugging and error tracking
6. **Testing coverage** for all core functionalities

## Project Structure

The current project structure is as follows:

```
/home/oem/Documents/SetupScriptTest/
├── src/                      # Source code directory
│   ├── core/                 # Core functionality (Level 0 and Level 1)
│   │   ├── logger.sh         # Logging functionality
│   │   ├── utils.sh          # Utility functions
│   │   ├── globals.sh        # Global variables and configuration
│   │   ├── file_ops.sh       # File operations functionality
│   │   ├── package_manager.sh# Package management functionality
│   │   └── sudo.sh           # Sudo execution functionality
│   ├── modules/              # High-level modules (Level 2)
│   │   ├── atuin.sh          # Atuin shell history manager
│   │   ├── conda.sh          # Conda installation and configuration
│   │   ├── lab_proxy.sh      # Proxy configuration for lab environment
│   │   ├── lab_users.sh      # User management for lab environment
│   │   └── power.sh          # Power management configuration
│   └── cli/                  # Command-line interface components (pending)
├── tests/                    # Test directory
│   ├── run_tests.sh          # Test runner script
│   ├── test_safe_insert.sh   # Tests for safe_insert functionality
│   ├── test_safe_remove.sh   # Tests for safe_remove functionality
│   ├── test_package_manager.sh # Tests for package management
│   └── test_sudo.sh          # Tests for sudo functionality
├── setup.sh                  # Main executable (pending)
├── setup-old.sh              # Previous version of the script
├── intermediates/            # Working directory for draft materials
├── outputs/                  # Directory for final outputs
└── CLAUDE.MD                 # This documentation file
```

## Architectural Design

The script follows a tiered architecture with three levels of abstraction:

### Level 0: Core Helper Functions

Basic utilities and low-level operations:
- **Logging system** with configurable verbosity levels
- **User interaction** utilities (confirmation prompts, status displays)
- **Error handling** and validation functions
- **Path and string manipulation** utilities

### Level 1: Low-Level Abstractions

Core building blocks used throughout the system:
- **File operations** (safe_insert, safe_remove)
- **Package management** (repository handling, GPG key management)
- **Sudo execution** with environment preservation
- **User management** functions

### Level 2: High-Level Functionality

Domain-specific operations that use Level 1 abstractions:
- **Proxy configuration** module
- **Package installation** workflows
- **System configuration** functions
- **Specialized software installation** (VirtualGL, TurboVNC, etc.)

## Command-Line Interface

The script supports both interactive and CLI modes:

### CLI Mode Syntax

```
./setup.sh <-global options>... [level2 command] <-option>... [Next level2 command]
```

Examples:
- `./setup.sh conda --use-miniforge`

### Interactive Mode

If a Level 2 command doesn't receive enough parameters, it falls back to interactive mode to gather the necessary information from the user.

## Implementation Guidelines

### Global Variables and Configuration

- **Namespace prefixing**: All global variables must use prefixes (e.g., PKG_ for package-related variables)
- **Centralized configuration**: Store all configurable parameters in globals.sh
- **Associative arrays**: Use SCRIPT_CONFIG associative array for runtime configuration

### Logging Protocol

- **Multiple log levels**: ERROR, WARNING, INFO, DEBUG
- **Module identification**: All log messages must include module identifier
- **Configurable verbosity**: Control log level via environment variable
- **Format**: `[LEVEL][module] YYYY-MM-DD HH:MM:SS - Message`

### Error Handling

- **Graceful degradation**: Handle errors without crashing when possible
- **Clear messaging**: Provide informative error messages
- **Exit codes**: Use standardized exit codes for different error types

### Testing Requirements

- **Comprehensive tests**: Every Level 1 function must have thorough tests
- **Edge case coverage**: Test normal operations, edge cases, and error conditions
- **Verification functions**: Include output verification in each test
- **Cleanup procedures**: Tests should clean up after themselves

## Implemented Functionality

### Core Level 0 Components

1. **Logging System** (logger.sh)
   - Implementation style: Bash functions with configurable log levels
   - Key functions: `log_error`, `log_warning`, `log_info`, `log_debug`
   - Features: Module tagging, timestamp formatting, color coding

2. **Utility Functions** (utils.sh)
   - Implementation style: Pure Bash functions without external dependencies
   - Key functions: 
     - `confirm`: Interactive yes/no confirmation with auto-confirm support
     - `ensure_directory`: Creates directories with specified permissions
     - `prompt_input`: Prompts user for input with optional default values
     - `prompt_password`: Secure password input with hidden characters
     - `prompt_multiline`: Collects multiline input with custom end marker
   - Features: User interaction, directory manipulation, secure input handling

3. **Global Configuration** (globals.sh)
   - Implementation style: Associative arrays and exported variables
   - Key components: `SCRIPT_CONFIG` array, prefixed global variables
   - Features: Centralized configuration, namespace management

### Level 1 Abstractions

1. **File Operations** (file_ops.sh)
   - Implementation style: Modular functions with strict input validation
   - Key functions:
     - `safe_insert`: Safely adds content to files with section headers
     - `check_and_add_lines`: Helper for adding content under section headers
     - `safe_remove`: Safely removes content from files with section headers
     - `check_and_remove_lines`: Helper for removing content and orphaned headers
   - Features:
     - File backups before modification
     - Colored diff preview
     - User confirmation with auto-confirm option
     - Intelligent section management
     - Newline preservation

2. **Package Management** (package_manager.sh)
   - Implementation style: Modular functions with error checking
   - Key functions:
     - `add_package_repository`: Registers package repositories
     - `normalize_url`: Prevents URL formation issues
   - Features:
     - Architecture detection
     - GPG key handling
     - Repository availability checking
     - Version codename detection

## Testing Implementation

Each Level 1 abstraction has a dedicated test script covering all functionality:

1. **File Operations Tests**
   - `test_safe_insert.sh`: Tests for file content addition
   - `test_safe_remove.sh`: Tests for file content removal
   - Key test cases:
     - Basic content addition/removal
     - Title line handling
     - Orphaned section cleanup
     - Empty file handling
     - Nonexistent file handling
     - End-to-end verification (safe_remove undoes safe_insert)

2. **Package Management Tests**
   - `test_package_manager.sh`: Tests repository management
   - Key test cases:
     - Repository registration
     - GPG key handling
     - URL normalization
     - Architecture detection

3. **Power Management Tests**
   - `test_power.sh`: Tests power settings configuration
   - Key test cases:
     - Content generation functions
     - Command line argument parsing
     - DConf settings application
     - DConf settings removal
     - Complete setup and teardown

4. **Proxy Management Tests**
   - `test_proxy.sh`: Tests proxy settings configuration
   - Key test cases:
     - Multiple content generation functions for different services
     - Command line argument parsing
     - Configuration for individual services (env, apt, git, dconf)
     - Configuration for multiple services simultaneously
     - Complete configuration removal

## Implemented and Pending Functionality

### Implemented Level 1 Abstractions

1. **Sudo Functionality** ✓
   - Implemented in `sudo.sh`
   - Features:
     - Preserves all environment variables using `sudo -E`
     - Supports function execution with elevated privileges
     - Maintains global configuration state
     - Handles function definitions and variable passing
     - Comprehensive test suite in `test_sudo.sh`

### Pending Implementation

1. **User Management Functions**
   - Requirements:
     - Add/remove system users
     - Configure user permissions
     - Set up shared user environments
   - Note: Partial implementation exists in `lab_users.sh` but needs expansion

2. **CLI Interface**
   - Requirements:
     - Command dispatching
     - Parameter parsing
     - Interactive mode
     - Help documentation

## Development Process

1. Follow test-driven development - create test cases before implementation
2. Develop each module separately for easier testing and debugging
3. Document all functions with clear descriptions and examples
4. Use consistent logging throughout the codebase
5. Keep global variables namespaced to avoid conflicts
6. Ensure backward compatibility when refactoring

## Coding Style Guidelines

1. **Bash Style**
   - Use double brackets `[[ ]]` for condition testing
   - Quote all variables unless explicitly needed unquoted
   - Use descriptive function and variable names
   - Include comments for complex logic

2. **Error Handling**
   - Check return values of external commands
   - Provide meaningful error messages
   - Exit with appropriate status codes

3. **Modularity**
   - Create focused functions that do one thing well
   - Design for reusability
   - Minimize dependencies between modules

## Recent Accomplishments

1. **File Operations Refinement**
   - Completed `safe_remove` as counterpart to `safe_insert`
   - Fixed newline handling in file operations
   - Implemented intelligent section header removal
   - Created comprehensive tests for end-to-end verification
   - Added robust empty file handling

2. **Package Management**
   - Implemented URL normalization to prevent formatting issues
   - Added namespaced global variables with PKG_ prefix
   - Created architecture detection functionality
   - Implemented repository availability checking

3. **Sudo Functionality**
   - Implemented robust sudo execution with environment preservation
   - Added support for function execution with elevated privileges
   - Created comprehensive test suite for Sudo functionality
   - Fixed issues mentioned in Review 3 from original requirements

## New requirements
All functionality should be able to be redo!!!


## Next Steps

1. Finalize integration testing:
   - Test all modules together in a complete workflow
   - Verify that each module correctly implements the undo/remove functionality
   - Test edge cases with various command line options

2. Create the single-file deliverable:
   - Write a script to combine all modules into a single file
   - Ensure proper load order of functions and dependencies
   - Verify the bundled script works correctly with all modules

3. Add comprehensive documentation:
   - Create a user manual with usage examples
   - Document all available commands and options
   - Add maintenance guidelines for future development

4. Further enhancements (if time permits):
   - Add more package repository options
   - Expand lab user management capabilities
   - Add version checking and update mechanism

## Current progress
All core functionality has been implemented and tested successfully! This includes:

1. All Level 0 and Level 1 abstractions:
   - Logging system with configurable verbosity
   - File operations with safe_insert and safe_remove
   - Package management system with repository and GPG key handling
   - User management utilities
   - Sudo execution with environment preservation

2. Level 2 modules for common tasks:
   - Proxy configuration for various services
   - SSH server setup
   - Power management settings
   - Lab user management
   - Conda installation and configuration

3. Command-line interface:
   - Module discovery and registration
   - Command dispatching with argument parsing
   - Help message generation
   - Support for subcommands

The CLI parser and main setup.sh script are now working correctly, with the ability to handle subcommands from modules (e.g., "lab_users_main check"). Global options are correctly passed to modules, and help messages are generated for both the main script and individual modules.

The main challenge of ensuring all operations are reversible has been solved by implementing content generation functions that produce the exact same content for both insertion and removal operations.

Current remaining work is primarily integration testing and bundling the components into a single file deliverable.

## Important
I change the API of safe_insert and safe_remove to accept only content instead of title + content, and will split it into title line and other content lines in the function itself, but haven't change all the place that uses this API. This change is intend to make the API easier so that we can directly return a bunch of lines for the content generating function.

Each module should: 
Use new API, for content need to pass into safe_insert, generate with a content generating function
have a standard arg parser inside its entry function. This entry function should have names <module_name>_main. The only work this top level function should do is parse arg and call other functions
Each module should not expose all its functios, just expose the main function + other top level function (function that main function calls), don't export util functions

## Module Implementation Guidelines

After rewriting several modules to comply with the new API requirements, here is a comprehensive guide for implementing modules in our project:

### 1. Content Generation Functions

Each module must include content generation functions that:

- Generate complete content blocks as strings, not arrays
- Include both the title line and content lines in a single return
- Follow consistent naming: `module_generate_*` (e.g., `ssh_server_generate_config`)
- Accept parameters needed to customize the content (e.g., port numbers, usernames)
- Handle edge cases with proper validation and error logging
- Use heredoc syntax for multi-line string generation

Example:
```bash
# Function to generate configuration content
generate_samba_share_config() {
    local username="$1"
    log_debug "Generating configuration for: $username" "$MODULE_NAME"
    
    # Validate inputs
    if [ -z "$username" ]; then
        log_error "Missing required username parameter" "$MODULE_NAME"
        return 1
    fi
    
    # Generate complete content block (title + content)
    local content="[${username}-share]
   path = /home/${username}/shared
   available = yes
   valid users = ${username}
   read only = no
   browsable = yes"

    echo "$content"
}
```

### 2. Main Function Structure

Each module must have a single main function that:

- Follows naming convention: `module_name_main` (e.g., `lab_users_main`)
- Is the only function exported from the module
- Implements a standardized argument parser
- Calls appropriate internal functions based on arguments
- Provides clear help/usage information
- Returns standardized exit codes

Example:
```bash
module_main() {
    log_debug "Module main function called with args: $@" "$MODULE_NAME"
    
    # Default values
    local setup=false
    local remove=false
    local force=false
    local show_help=false
    
    # Process arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            setup)
                setup=true
                shift
                ;;
            remove)
                remove=true
                shift
                ;;
            --force)
                force=true
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
        echo "Usage: module_main [command] [options]"
        echo ""
        echo "Commands:"
        echo "  setup                  Setup the module functionality"
        echo "  remove [--force]       Remove the module functionality"
        echo ""
        echo "Options:"
        echo "  --force                Force operation without confirmation"
        echo "  --help, -h             Show this help message"
        return 0
    fi
    
    # Execute commands
    if [ "$setup" = "true" ]; then
        setup_function
        return $?
    elif [ "$remove" = "true" ]; then
        if [ "$force" = "true" ]; then
            remove_function "force"
        else
            remove_function
        fi
        return $?
    else
        log_error "No command specified" "$MODULE_NAME"
        return 1
    fi
}

# Export only the main function
export -f module_main
```

### 3. File Operations with safe_insert and safe_remove

When using the file operations functions:

- Always use content generation functions to create content blocks
- Pass the generated content directly to `safe_insert` or `safe_remove`
- Use the same content generation for both insertion and removal
- Provide descriptive usage messages for the operations
- Handle the return values properly with error checking

Example:
```bash
# Setup function using content generation
setup_function() {
    # Generate content using the content generation function
    local config_content=$(generate_config_content "param1" "param2")
    
    if [ -z "$config_content" ]; then
        log_error "Failed to generate configuration content" "$MODULE_NAME"
        return 1
    fi
    
    # Use safe_insert with the generated content
    Sudo safe_insert "Setting up module configuration" "/etc/config/file.conf" "$config_content"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to insert configuration" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Configuration successfully applied" "$MODULE_NAME"
    return 0
}

# Remove function using the same content generation
remove_function() {
    local force="$1"
    
    # Generate the same content for removal
    local config_content=$(generate_config_content "param1" "param2")
    
    if [ -z "$config_content" ]; then
        log_error "Failed to generate configuration content for removal" "$MODULE_NAME"
        return 1
    fi
    
    # Use safe_remove with the same generated content
    Sudo safe_remove "Removing module configuration" "/etc/config/file.conf" "$config_content"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to remove configuration" "$MODULE_NAME"
        return 1
    fi
    
    log_info "Configuration successfully removed" "$MODULE_NAME"
    return 0
}
```

### 4. Module Metadata and Documentation

Each module should include:

- Clear module info variables (name, description, version)
- Comprehensive function documentation with usage examples
- A MODULE_COMMANDS array for the CLI dispatcher
- Consistent log messages with appropriate module identifier

Example:
```bash
# Module info
MODULE_NAME="module_name"
MODULE_DESCRIPTION="Description of what this module does"
MODULE_VERSION="1.0.0"

# Module metadata for CLI dispatcher
MODULE_COMMANDS=(
    "module_main setup:Setup the module functionality"
    "module_main remove:Remove the module functionality (args: [--force])"
)
export MODULE_COMMANDS
```

### 5. Function Visibility (Export Control)

Modules should:

- Export ONLY the main function
- Keep all helper functions, content generation functions internal
- Export the MODULE_COMMANDS array for the CLI system
- Not pollute the global namespace with utility functions

Example:
```bash
# Export only the main function and metadata
export -f module_main
export MODULE_COMMANDS

# Do NOT export internal functions
# export -f internal_function  # WRONG
```

### 6. Testing

Each module should have a corresponding test script that:

- Tests both the main function and internal functions
- Verifies content generation produces expected output
- Tests both setup and removal operations
- Tests argument parsing in the main function
- Uses the MODULE_NAME constant for test reporting
- Cleans up any changes made during testing

Example test pattern:
```bash
# Test content generation
content=$(generate_config_content "param1" "param2")
if [[ "$content" == *"expected_line"* ]]; then
    report_result 0 "Content generation produces expected output"
else
    report_result 1 "Content generation failed to produce expected output"
fi

# Test main function
module_main setup
if [ $? -eq 0 ] && [ -f "/path/to/expected/file" ]; then
    report_result 0 "Setup operation completed successfully"
else
    report_result 1 "Setup operation failed"
fi

module_main remove --force
if [ $? -eq 0 ] && [ ! -f "/path/to/expected/file" ]; then
    report_result 0 "Remove operation completed successfully"
else
    report_result 1 "Remove operation failed"
fi
```

Following these guidelines will ensure consistency across all modules, facilitate maintenance, and enable the comprehensive reversibility of all configuration changes made by the setup script.

## Git Operations Core Module (git_ops.sh)

The git operations core module provides low-level git repository management functions with SSH key support and comprehensive submodule handling.

### Functions

#### git_clone
Clones a git repository with automatic submodule initialization.

```bash
git_clone repo_url target_dir [options]
```

Options:
- `--ssh-key PATH`: Path to SSH private key for authentication
- `--branch NAME`: Branch to checkout (default: repository default)
- `--depth NUMBER`: Create a shallow clone with specified depth
- `--force`: Remove existing directory before cloning

Features:
- **Recursive by default**: Automatically clones all submodules
- **SSH key support**: Works with private repositories requiring authentication
- **Validation**: Checks for existing directories and validates inputs
- **Parent directory creation**: Automatically creates parent directories if needed

Example:
```bash
# Clone with SSH key
git_clone "git@github.com:user/repo.git" "/home/user/repo" --ssh-key ~/.ssh/id_rsa

# Clone specific branch with shallow history
git_clone "https://github.com/user/repo.git" "/tmp/repo" --branch develop --depth 1

# Force clone (removes existing directory)
git_clone "https://github.com/user/repo.git" "/opt/app" --force
```

#### git_update
Updates an existing git repository including all submodules.

```bash
git_update target_dir [options]
```

Options:
- `--ssh-key PATH`: Path to SSH private key for authentication
- `--branch NAME`: Branch to checkout and pull
- `--reset`: Reset to origin state (discards local changes)

Features:
- **Submodule updates**: Automatically updates all submodules
- **Reset capability**: Can discard local changes and clean untracked files
- **Branch switching**: Can change branches during update

Example:
```bash
# Update repository
git_update "/home/user/repo"

# Update and reset to origin state
git_update "/home/user/repo" --reset

# Update with SSH key and switch branch
git_update "/home/user/repo" --ssh-key ~/.ssh/id_rsa --branch main
```

#### git_remove
Removes a cloned git repository with optional backup.

```bash
git_remove target_dir [options]
```

Options:
- `--backup PATH`: Create backup before removing

Example:
```bash
# Remove repository
git_remove "/home/user/repo"

# Remove with backup
git_remove "/home/user/repo" --backup "/home/user/repo.backup"
```

#### Helper Functions

##### is_git_repo
Checks if a directory is a git repository.

```bash
if is_git_repo "/path/to/dir"; then
    echo "It's a git repository"
fi
```

##### git_current_branch
Gets the current branch of a git repository.

```bash
branch=$(git_current_branch "/path/to/repo")
echo "Current branch: $branch"
```

##### git_remote_url
Gets the remote URL of a git repository.

```bash
url=$(git_remote_url "/path/to/repo")
echo "Remote URL: $url"
```

### Implementation Details

1. **SSH Key Handling**: Uses `GIT_SSH_COMMAND` to specify SSH keys without modifying global git config
2. **Error Handling**: Comprehensive validation and error messages
3. **Logging**: Detailed debug logging following project standards
4. **Submodules**: All operations handle submodules automatically
5. **Security**: Validates SSH key files before use
6. **Compatibility**: Works with various git hosting services (GitHub, GitLab, Bitbucket, etc.)

### Usage as a Utility

The git_ops.sh module can be used by other modules that need git functionality. For example:

```bash
# In another module
source "$SCRIPT_DIR/../core/git_ops.sh"

# Clone a repository as part of setup
git_clone "https://github.com/user/config.git" "/opt/myapp/config" --branch stable

# Update repository
git_update "/opt/myapp/config" --reset

# Check if directory is a git repo
if is_git_repo "/opt/myapp"; then
    echo "App directory is version controlled"
fi
```

### Testing

Test files:
- `tests/test_git_ops.sh`: Tests core git operations
- Covers: clone, update, remove, SSH key handling, submodules, error cases

The module provides low-level git operations that can be used by other modules while maintaining the project's standards for logging, error handling, and reversibility.

## Atuin Shell History Manager Module (atuin.sh)

The Atuin module provides comprehensive management for the Atuin shell history synchronization tool, including installation, configuration, authentication, and sync operations.

### Features

1. **Installation Management**:
   - Downloads and installs Atuin from official installer
   - Detects existing installations
   - Configures shell integration for bash, zsh, and profile
   - Fully reversible installation

2. **Authentication Support**:
   - Login with existing accounts
   - Register new accounts
   - Interactive credential input for security
   - Encryption key management

3. **Configuration**:
   - Automatic shell integration setup
   - Sync settings management
   - Multiple shell support (bash, zsh, profile)
   - Configuration file generation

4. **History Management**:
   - Import existing shell history
   - Sync history with cloud servers
   - Automatic sync after setup

### Functions

#### Main Function
```bash
atuin_main [options]
```

Options:
- `--shell SHELL`: Configure for specific shell (bash, zsh, profile, all)
- `--no-sync`: Disable sync in configuration
- `--login`: Login to existing account
- `--register`: Register new account
- `--username USER`: Username for login/registration
- `--email EMAIL`: Email for registration
- `--password PASS`: Password for login/registration
- `--key KEY`: Encryption key for login
- `--import`: Import existing shell history
- `--sync`: Sync history with server after setup
- `--remove`: Remove Atuin installation
- `--help`: Display help message

### Interactive Mode

When credentials are not provided via command line, the module enters interactive mode:
- Prompts for missing username, email, or password
- Uses secure password input (hidden characters)
- Confirms password during registration
- Optional encryption key entry

### Usage Examples

```bash
# Full installation with interactive login
./setup.sh atuin_main --shell all --login

# Non-interactive installation with credentials
./setup.sh atuin_main --shell bash --login --username user --password pass --key "encryption key"

# Register new account interactively
./setup.sh atuin_main --register

# Import history and sync
./setup.sh atuin_main --import --sync

# Remove Atuin completely
./setup.sh atuin_main --remove
```

### Implementation Details

1. **Content Generation Functions**:
   - `atuin_generate_bash_init_content()`: Generates bash integration
   - `atuin_generate_zsh_init_content()`: Generates zsh integration
   - `atuin_generate_profile_init_content()`: Generates profile integration
   - `atuin_generate_config_content()`: Generates Atuin configuration

2. **Core Operations**:
   - `atuin_install()`: Handles Atuin installation
   - `atuin_configure_shell()`: Sets up shell integrations
   - `atuin_login()`: Manages authentication with proper argument syntax
   - `atuin_register()`: Handles new account registration
   - `atuin_sync_history()`: Performs history synchronization
   - `atuin_remove()`: Complete removal of Atuin and configurations

3. **Security Features**:
   - Interactive password input using `prompt_password()` from utils
   - No credentials stored in shell history
   - Encryption key support for cross-machine sync

### Testing

Test file: `tests/test_atuin.sh`
- Installation and removal
- Shell configuration for all supported shells
- Login and registration flows
- History import and sync operations
- Interactive mode testing

## Git Repository Management Module (git_repos.sh)

The git_repos module provides high-level management of personal git repositories with batch operations and configuration management through the globals.sh system.

### Features

1. **Batch Repository Management**:
   - Clone multiple repositories from centralized configuration
   - Update all configured repositories at once
   - Remove all cloned repositories with confirmation
   - Skip existing directories by default (safe behavior)

2. **Single Repository Operations**:
   - Clone individual repositories with custom parameters
   - Support for specific branches and SSH keys
   - Force overwrite with explicit `--force` flag
   - Update individual repositories

3. **Configuration Management**:
   - Repository definitions stored in `globals.sh`
   - Support for URL, directory, branch, and SSH key per repository
   - Variable expansion in paths (e.g., `$HOME/projects`)
   - Example configuration generation

4. **Safety Features**:
   - Skip existing directories by default (no accidental overwrites)
   - Force flag required for overwriting existing content
   - Confirmation prompts for removal operations
   - Comprehensive error handling and logging

### Functions

#### Main Function
```bash
git_repos_main [command] [options]
```

Commands:
- `clone`: Clone repositories defined in globals.sh
- `update`: Update existing repositories
- `remove`: Remove cloned repositories

Options:
- `--url URL`: Clone single repository (requires --dir)
- `--dir DIR`: Target directory for single clone
- `--branch BR`: Branch to clone (default: main)
- `--ssh-key KEY`: SSH key for authentication
- `--force`: Force overwrite existing directories when cloning
- `--help`: Display help message

### Repository Configuration

Repositories are configured in `globals.sh` using associative arrays:

```bash
# Example repository configurations
GIT_REPO_URL[dotfiles]="git@github.com:user/dotfiles.git"
GIT_REPO_DIR[dotfiles]="$HOME/.config/dotfiles"
GIT_REPO_BRANCH[dotfiles]="main"
GIT_REPO_SSH_KEY[dotfiles]="$HOME/.ssh/id_rsa"

GIT_REPO_URL[project]="https://github.com/user/project.git"
GIT_REPO_DIR[project]="$HOME/projects/project"
GIT_REPO_BRANCH[project]="develop"
GIT_REPO_SSH_KEY[project]=""  # No SSH key needed for public repos
```

### Usage Examples

```bash
# Clone all repositories from globals (skip existing)
./setup.sh git_repos_main clone

# Clone all repositories from globals (force overwrite)
./setup.sh git_repos_main clone --force

# Clone single repository
./setup.sh git_repos_main clone --url https://github.com/user/repo.git --dir ~/projects/repo

# Clone with SSH key and specific branch
./setup.sh git_repos_main clone --url git@github.com:user/repo.git --dir ~/work/repo --branch develop --ssh-key ~/.ssh/work_key

# Update all repositories
./setup.sh git_repos_main update

# Remove all cloned repositories (with confirmation)
./setup.sh git_repos_main remove
```

### Implementation Details

1. **Content Generation Functions**:
   - `git_repos_generate_example_config()`: Generates example configuration for globals.sh

2. **Core Operations**:
   - `git_repos_clone_single()`: Clones a single repository with skip/force logic
   - `git_repos_update_single()`: Updates a single repository
   - `git_repos_clone_from_globals()`: Batch clone from configuration
   - `git_repos_update_from_globals()`: Batch update from configuration
   - `git_repos_remove_from_globals()`: Batch removal from configuration

3. **Safety and Behavior**:
   - **Skip by Default**: Returns status code 2 when directory exists without force
   - **Force Override**: Uses `--force` flag to explicitly allow overwrites
   - **Status Tracking**: Provides summary of operations (succeeded, failed, skipped)
   - **Recursive Clone**: All repositories are cloned with `--recursive` for submodule support

4. **Integration with git_ops.sh**:
   - Uses core git operations for actual clone/update operations
   - Inherits SSH key support and submodule handling
   - Maintains consistent logging and error handling

### Skip vs Force Behavior

The module implements safe-by-default behavior:

**Skip Mode (Default)**:
```bash
# If /home/user/repo already exists:
git_repos_main clone --url https://github.com/user/repo.git --dir /home/user/repo
# Result: Warns and skips, preserves existing content
```

**Force Mode (Explicit)**:
```bash
# If /home/user/repo already exists:
git_repos_main clone --url https://github.com/user/repo.git --dir /home/user/repo --force
# Result: Removes existing directory and clones fresh
```

### Return Values

Functions return standardized exit codes:
- `0`: Success
- `1`: Error/failure
- `2`: Skipped (directory exists, no force)

### Testing

Test file: `tests/test_git_repos.sh`
- Example configuration generation
- Globals configuration retrieval
- Single repository operations
- Skip behavior verification
- Force behavior verification
- Main function argument parsing
- Module context preservation
- Batch operations from globals

The git_repos module provides a comprehensive solution for managing multiple personal repositories while maintaining safety through skip-by-default behavior and requiring explicit confirmation for potentially destructive operations.

## Recent Changes and Improvements

### Conda Module Enhancements (December 2024)

The conda module (`src/modules/conda.sh`) has been significantly enhanced to improve user experience and follow established project patterns:

#### Key Improvements Made:

1. **Automatic User Configuration for ALL System Users**
   - **New Function**: `conda_configure_all_users()`
   - **Purpose**: Automatically configures conda for every user on the system during installation
   - **Scope**: Processes all users with UID ≥ 1000 (regular users) and UID 0 (root)
   - **Integration**: Called automatically during `conda_init()` after global setup

2. **User-Specific Environment Management**
   - **Default Location**: `$HOME/.conda/envs` (primary location for user environments)
   - **Fallback Support**: Users still have access to shared environments at `/home/Shared/conda_envs`
   - **Package Cache**: User-specific cache at `$HOME/.conda/pkgs` with system fallback
   - **Ownership**: All user directories properly owned by respective users (`chown user:user`)

3. **Enhanced Configuration Generation**
   - **New Function**: `conda_generate_user_config_content()`
   - **Purpose**: Generates user-specific `.condarc` configuration following same pattern as global config
   - **Features**: Supports both Miniconda and Miniforge channel configurations
   - **Consistency**: Follows established content generation patterns in the project

4. **safe_insert API Integration for Installation**
   - **Implementation**: User `.condarc` files now use `safe_insert` API consistently
   - **Pattern**: `Sudo safe_insert "User conda configuration for $username" "$home/.condarc" "$content"`
   - **Benefits**: Users see exactly what will be configured and can approve/decline changes
   - **Consistency**: Matches global configuration approach and other modules (proxy, etc.)

5. **safe_remove API Integration for Removal**
   - **New Function**: `conda_remove_all_user_configs()`
   - **Implementation**: User `.condarc` removal now uses `safe_remove` API
   - **Pattern**: `Sudo safe_remove "User conda configuration for $username" "$home/.condarc" "$content"`
   - **Safety**: Shows users exactly what conda content will be removed
   - **Integration**: Called during `conda_remove()` before global cleanup

#### Technical Implementation Details:

**User Directory Structure Created:**
```
$HOME/.conda/
├── envs/           # User's personal environments (primary location)
├── pkgs/           # User's package cache
└── ...
$HOME/.condarc      # User-specific configuration file
```

**User Configuration Content:**
```yaml
# User-specific conda configuration
envs_dirs:
  - $HOME/.conda/envs                    # Primary location
  - /home/Shared/conda_envs              # Shared fallback

pkgs_dirs:
  - $HOME/.conda/pkgs                    # User cache
  - /usr/local/miniconda3/pkgs           # System fallback

# Miniforge-specific (if applicable)
channels:
  - conda-forge
  - nodefaults
```

**User Experience Improvements:**
- No permission issues when creating/managing environments
- Default `conda create -n myenv` creates in user's home directory
- Transparent configuration process with user approval
- Safe removal with clear preview of what will be deleted
- Consistent behavior across all user accounts

**Error Handling:**
- Tracks success/failure for each user during configuration
- Continues processing even if individual users fail
- Reports comprehensive summary of results
- Graceful degradation with detailed logging

#### Functions Added/Modified:

**New Functions:**
- `conda_generate_user_config_content()` - Generate user-specific config content
- `conda_configure_all_users()` - Configure conda for all system users
- `conda_remove_all_user_configs()` - Remove conda config for all users using safe_remove

**Modified Functions:**
- `conda_init()` - Now includes automatic user configuration
- `conda_remove()` - Now includes user configuration cleanup using safe_remove

**Exported Functions:**
- Added exports for `conda_configure_all_users` and `conda_remove_all_user_configs`

#### Benefits Achieved:

1. **Zero-Configuration User Experience**: Users can immediately use conda without manual setup
2. **Permission-Free Environment Management**: No sudo required for personal environments
3. **Safe Configuration Management**: All changes use safe_insert/safe_remove APIs
4. **Consistent Project Patterns**: Follows established conventions for content generation and safe operations
5. **Comprehensive User Coverage**: All valid system users automatically configured
6. **Transparent Operations**: Users see and approve all configuration changes

This enhancement ensures that conda installation provides an optimal out-of-the-box experience for all users while maintaining the safety and transparency standards established throughout the project.

## Personal Computer Setup Module (personal_setup.sh)

The personal_setup module provides essential personal computer configurations including system permission modifications and development tool installations.

### Features

1. **System Permission Management**:
   - Modifies `/usr/local` permissions to 777 for unrestricted user access
   - Safely restores `/usr/local` permissions to 755 during removal
   - Enables permission-free development tool installations

2. **Claude CLI Integration**:
   - Installs Claude CLI globally via npm (`@anthropic-ai/claude-code`)
   - Validates npm availability before installation
   - Provides clean removal of Claude CLI
   - Graceful handling of missing dependencies

3. **Full Reversibility**:
   - All operations can be completely undone
   - `remove` command restores original system state
   - Safe handling of cases where components are already removed

### Functions

#### Main Function
```bash
personal_setup_main [command] [options]
```

**Commands:**
- `setup`: Setup personal computer configuration (sets /usr/local permissions to 777)
- `install-claude`: Install Claude CLI via npm
- `remove [--force]`: Remove personal computer configuration and Claude CLI

**Options:**
- `--force`: Force operation without confirmation
- `--help, -h`: Display help message

#### Core Operations

**Permission Management:**
- `personal_setup_configure_usr_local()`: Sets /usr/local permissions to 777
- `personal_setup_restore_usr_local()`: Restores /usr/local permissions to 755

**Claude CLI Management:**
- `personal_setup_install_claude()`: Installs Claude CLI globally via npm
- `personal_setup_remove_claude()`: Removes Claude CLI installation

### Usage Examples

```bash
# Setup /usr/local permissions for development
./setup.sh personal_setup_main setup

# Install Claude CLI (requires npm)
./setup.sh personal_setup_main install-claude

# Remove all personal configurations
./setup.sh personal_setup_main remove

# Display help
./setup.sh personal_setup_main --help
```

### Implementation Details

1. **Permission Strategy**:
   - Changes `/usr/local` to 777 permissions for unrestricted access
   - Enables development tools to install without sudo requirements
   - Automatically restores secure 755 permissions during removal

2. **Claude CLI Installation**:
   - Uses `npm install -g @anthropic-ai/claude-code`
   - Validates npm availability before proceeding
   - Provides clear error messages for missing dependencies
   - Uses `npm uninstall -g @anthropic-ai/claude-code` for removal

3. **Error Handling**:
   - Comprehensive validation of system prerequisites
   - Graceful handling of missing tools (npm, Claude CLI)
   - Clear logging of all operations and failures
   - Safe operation continuation when components are already removed

4. **Integration Patterns**:
   - Follows established project module patterns
   - Uses standard argument parsing and help generation
   - Implements MODULE_COMMANDS for CLI dispatcher integration
   - Maintains consistent logging with module identification

### Security Considerations

**Permission Changes:**
- `/usr/local` permission change to 777 provides broad access
- Intended for personal development systems only
- Should be used with caution on shared or production systems
- Automatically restored to secure 755 during removal

**Claude CLI Installation:**
- Requires npm to be available and properly configured
- Installs globally, making Claude CLI available system-wide
- No additional security implications beyond standard npm global packages

### Testing

Test file: `tests/test_personal_setup.sh`

**Test Coverage:**
- Module loading and exports
- Argument parsing and help generation
- Function existence verification
- Command recognition and processing
- MODULE_COMMANDS integration
- Error handling for invalid arguments

**Test Limitations:**
- Permission tests require sudo access (may fail in CI environments)
- Claude CLI installation tests are limited to command recognition
- Actual npm operations are not performed during testing

### Module Metadata

```bash
MODULE_COMMANDS=(
    "personal_setup_main setup:Setup personal computer configuration (/usr/local permissions)"
    "personal_setup_main install-claude:Install Claude CLI via npm"
    "personal_setup_main remove:Remove personal computer configuration (args: [--force])"
)
```

**Export Structure:**
- Exports only `personal_setup_main` function
- Exports `MODULE_COMMANDS` array for CLI integration
- Internal functions remain private to the module

### Use Cases

**Personal Development Setup:**
```bash
# Complete personal development environment setup
./setup.sh personal_setup_main setup
./setup.sh personal_setup_main install-claude
```

**Development Tool Installation:**
```bash
# Install Claude CLI only
./setup.sh personal_setup_main install-claude
```

**System Cleanup:**
```bash
# Remove all personal configurations
./setup.sh personal_setup_main remove
```

The personal_setup module provides essential personal computer configurations while maintaining the project's standards for safety, reversibility, and comprehensive logging. It's designed specifically for personal development systems where broader permissions and development tools are needed.