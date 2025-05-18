#!/bin/bash

# Logger implementation with configurable log levels
# Usage: log [ERROR|WARNING|INFO|DEBUG] "message"

# Log levels: 0 = ERROR, 1 = WARNING, 2 = INFO, 3 = DEBUG
# Default log level is 2 (INFO)
export LOG_LEVEL=${LOG_LEVEL:-2}

# Define colors for log levels
RESET="\033[0m"
ERROR_COLOR="\033[31;1m"   # Bold Red
WARNING_COLOR="\033[33;1m" # Bold Yellow
INFO_COLOR="\033[34;1m"    # Bold Blue
DEBUG_COLOR="\033[36;1m"   # Bold Cyan

log() {
    local level_str="$1"
    local message="$2"
    local source="$3"
    local level=2
    local color="$INFO_COLOR"
    
    # Determine numeric level and color based on level string
    case "$level_str" in
        ERROR)
            level=0
            color="$ERROR_COLOR"
            ;;
        WARNING)
            level=1
            color="$WARNING_COLOR"
            ;;
        INFO)
            level=2
            color="$INFO_COLOR"
            ;;
        DEBUG)
            level=3
            color="$DEBUG_COLOR"
            ;;
        *)
            # Default to INFO if invalid level
            level=2
            color="$INFO_COLOR"
            level_str="INFO"
            ;;
    esac
    
    # Only log if the message level is <= the configured log level
    if [ "$level" -le "$LOG_LEVEL" ]; then
        # Format: [LEVEL][SOURCE] Message
        local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        if [ -n "$source" ]; then
            echo -e "${color}[${level_str}][${source}]${RESET} ${timestamp} - ${message}" >&2
        else
            echo -e "${color}[${level_str}]${RESET} ${timestamp} - ${message}" >&2
        fi
    fi
}

# Helper functions for each log level
log_error() {
    log "ERROR" "$1" "$2"
}

log_warning() {
    log "WARNING" "$1" "$2"
}

log_info() {
    log "INFO" "$1" "$2"
}

log_debug() {
    log "DEBUG" "$1" "$2"
}

# Function to set the log level
set_log_level() {
    case "$1" in
        ERROR|error|0)
            export LOG_LEVEL=0
            ;;
        WARNING|warning|1)
            export LOG_LEVEL=1
            ;;
        INFO|info|2)
            export LOG_LEVEL=2
            ;;
        DEBUG|debug|3)
            export LOG_LEVEL=3
            ;;
        *)
            # Invalid level provided, keep current
            log_warning "Invalid log level '$1'. Must be ERROR, WARNING, INFO, or DEBUG" "logger"
            return 1
            ;;
    esac
    log_debug "Log level set to $LOG_LEVEL" "logger"
    return 0
}

# Export functions for use in other scripts
export -f log
export -f log_error
export -f log_warning
export -f log_info
export -f log_debug
export -f set_log_level