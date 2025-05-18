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
   - Key functions: `confirm`, `ensure_directory`
   - Features: User interaction, directory manipulation

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

0. Migerate more package options from the old setup script (Now only a few of them exist in globals.sh's # Package repository information)
1. Check+Test the implementation of adding new lab users / remove lab users
   Ok, I find a serious problem here, Now, we just have a list of user, but actually, there should be some other fields about the user, like their year that they join this Lab, Let's first assume everyone join 2024. And maybe we need to have more fields in the future, so I think the data strcture should be more like the one we have for # Package repository information, that we refer by one's full name 
2. Complete+Test remaining Level 2 modules (extend existing modules for proxy, conda, power)
3. Develop the CLI interface for command dispatching and parameter handling
5. Integrate all components into a cohesive single-file deliverable
