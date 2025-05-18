#!/bin/bash

# Ubuntu Setup Script
# A systematic and modular setup script for Ubuntu systems

# Store the script directory
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$SCRIPT_DIR"

# Source the required dependencies
source "$PROJECT_ROOT/src/core/logger.sh"
source "$PROJECT_ROOT/src/core/utils.sh"
source "$PROJECT_ROOT/src/core/globals.sh"
source "$PROJECT_ROOT/src/cli/parser.sh"

# Set the script name for logging
SCRIPT_NAME="setup"

# Check for debug mode
if [[ "$*" == *"--debug"* ]]; then
    set_log_level "DEBUG"
    log_debug "Debug mode enabled" "$SCRIPT_NAME"
fi

# Print banner
echo "================================================================================"
echo "Ubuntu Setup Script"
echo "A systematic and modular setup script for Ubuntu systems"
echo "================================================================================"
echo ""

# Run the CLI with all arguments
run_cli "$@"
exit $?