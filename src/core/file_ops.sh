#!/bin/bash

# File operations implementation for the setup script
# This includes the safe_insert functionality

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/globals.sh"

log_debug "Loading file operations implementation" "file_ops"

# Function to add lines to a file if they are missing
# Usage: check_and_add_lines filename content_line1 content_line2 ...
# Returns: 0 on success, 1 on failure
check_and_add_lines() {
    local filename="$1"
    shift 1
    local content=("$@")
    local title_line="${content[0]}"  # First line is used as the section locator
    
    log_debug "Checking and adding lines to file: $filename" "check_and_add_lines"

    # Check if the file exists and is not a directory
    if [[ ! -f "$filename" && ! -d "$filename" ]]; then
        log_debug "File doesn't exist, creating it: $filename" "check_and_add_lines"
        touch "$filename"
    elif [[ -d "$filename" ]]; then
        log_error "Error: $filename is a directory" "check_and_add_lines"
        return 1
    fi

    # Check if the title line is present, append if not
    if ! grep -Fxq "$title_line" "$filename"; then
        log_debug "Title line not found, adding it: $title_line" "check_and_add_lines"
        # Check if there's already a newline at the end of the file
        if [[ -s "$filename" && $(tail -c 1 "$filename" | wc -l) -eq 0 ]]; then
            # File is not empty and doesn't end with a newline
            echo -e "\n$title_line" >> "$filename"
        else
            # File is empty or already ends with a newline
            echo "$title_line" >> "$filename"
        fi
    else
        log_debug "Title line already exists: $title_line" "check_and_add_lines"
    fi

    # Read the file into an array
    mapfile -t lines < "$filename"

    # Find the index of the title line
    local title_index=-1
    for i in "${!lines[@]}"; do
        if [[ "${lines[$i]}" == "$title_line" ]]; then
            title_index="$i"
            break
        fi
    done

    # Insert content lines after the title line if they are missing
    # Skip the first element (title line) when adding content
    local line_found line_insert_index=$((title_index + 1))
    for ((i=1; i<${#content[@]}; i++)); do
        local content_line="${content[$i]}"
        line_found=false
        for existing_line in "${lines[@]:$line_insert_index}"; do
            if [[ "$existing_line" == "$content_line" ]]; then
                line_found=true
                break
            fi
        done

        if [[ "$line_found" == false ]]; then
            # Insert the line after the last inserted line to maintain order
            log_debug "Adding missing line: $content_line" "check_and_add_lines"
            lines=("${lines[@]:0:$line_insert_index}" "$content_line" "${lines[@]:$line_insert_index}")
        else
            log_debug "Line already exists: $content_line" "check_and_add_lines"
        fi
        ((line_insert_index++))
    done

    # Write the updated array back to the file
    printf "%s\n" "${lines[@]}" > "$filename"
    log_debug "File updated: $filename" "check_and_add_lines"
    
    return 0
}

# Function to remove lines from a file if they match the specified content
# Usage: check_and_remove_lines filename content_line1 content_line2 ...
# Returns: 0 on success, 1 on failure
check_and_remove_lines() {
    local filename="$1"
    shift 1
    local content=("$@")
    local title_line="${content[0]}"  # First line is used as the section locator
    
    log_debug "Checking and removing lines from file: $filename" "check_and_remove_lines"

    # Check if the file exists and is not a directory
    if [[ ! -f "$filename" ]]; then
        log_warning "File doesn't exist, nothing to remove: $filename" "check_and_remove_lines"
        return 0
    elif [[ -d "$filename" ]]; then
        log_error "Error: $filename is a directory" "check_and_remove_lines"
        return 1
    fi

    # Check if the title line is present, if not, nothing to remove
    if ! grep -Fxq "$title_line" "$filename"; then
        log_debug "Title line not found, nothing to remove: $title_line" "check_and_remove_lines"
        return 0
    else
        log_debug "Title line exists, checking content lines" "check_and_remove_lines"
    fi

    # Read the file into an array
    mapfile -t lines < "$filename"

    # Find the index of the title line
    local title_index=-1
    for i in "${!lines[@]}"; do
        if [[ "${lines[$i]}" == "$title_line" ]]; then
            title_index="$i"
            break
        fi
    done

    # If title line not found, return (shouldn't happen due to grep check above)
    if [ $title_index -eq -1 ]; then
        log_warning "Title line not found in array, skipping removal" "check_and_remove_lines"
        return 0
    fi

    # Create a new array with lines to keep
    local new_lines=()
    local removed_count=0
    local skip_lines=()

    # Create the skip_lines array containing all content lines to remove
    # Start from index 1 to skip the title line
    for ((i=1; i<${#content[@]}; i++)); do
        skip_lines+=("${content[$i]}")
    done

    # Loop through all lines, adding to new_lines unless it's a line to remove
    for i in "${!lines[@]}"; do
        local line="${lines[$i]}"
        local skip=false
        
        # Check if it's a line to remove
        if [ $i -gt $title_index ]; then  # Only check lines after the title line
            for skip_line in "${skip_lines[@]}"; do
                if [[ "$line" == "$skip_line" ]]; then
                    skip=true
                    ((removed_count++))
                    log_debug "Removing line: $line" "check_and_remove_lines"
                    break
                fi
            done
        fi
        
        # Add to new_lines if not to be skipped
        if ! $skip; then
            new_lines+=("$line")
        fi
    done

    # Check if we should also remove the title line
    # 1. If all content was removed and only title remains
    # 2. If explicitly requested by providing only the title
    # 3. If the title is followed by another title or empty
    if [ $removed_count -gt 0 ] || [ ${#content[@]} -eq 1 ]; then
        # If only the title line was provided, remove it directly
        if [ ${#content[@]} -eq 1 ]; then
            log_debug "Removing title line as requested: $title_line" "check_and_remove_lines"
            new_lines=("${new_lines[@]:0:$title_index}" "${new_lines[@]:$((title_index + 1))}")
            ((removed_count++))
        else
            # Check if the title is now followed by only whitespace or another title
            # or if it's the last line
            if [ ${#new_lines[@]} -gt $((title_index + 1)) ]; then
                # Check if next line is empty or a header/title (starts with # or [)
                local next_line="${new_lines[$((title_index + 1))]}"
                if [[ -z "$next_line" || "$next_line" =~ ^[#\[] ]]; then
                    # Remove the title line
                    log_debug "Removing isolated title line: $title_line" "check_and_remove_lines"
                    new_lines=("${new_lines[@]:0:$title_index}" "${new_lines[@]:$((title_index + 1))}")
                    ((removed_count++))
                fi
            else
                # Title line is the last line, remove it
                log_debug "Removing last title line: $title_line" "check_and_remove_lines"
                new_lines=("${new_lines[@]:0:$title_index}")
                ((removed_count++))
            fi
        fi
    fi

    # If no lines were removed, return success (nothing to do)
    if [ $removed_count -eq 0 ]; then
        log_debug "No lines to remove, file unchanged: $filename" "check_and_remove_lines"
        return 0
    fi

    # Write the updated array back to the file
    printf "%s\n" "${new_lines[@]}" > "$filename"
    log_debug "File updated, removed $removed_count lines: $filename" "check_and_remove_lines"
    
    return 0
}

# Function to safely modify a file with user confirmation (adding content)
# Usage: safe_insert usage filename content
# Returns: 0 on success, 1 on failure
safe_insert() {
    local usage="$1"      # Describe what the modification is for
    local filename="$2"   # Path to the file to modify
    local content_block="$3" # Content block to add
    
    log_debug "Safely inserting content into file: $filename for $usage" "safe_insert"

    # Split the content block into an array of lines
    mapfile -t content_lines <<< "$content_block"
    
    # Use /tmp directory for temporary file operations
    local base_filename=$(basename "$filename")
    local temp_file="/tmp/${base_filename}.tmp"
    local empty_file="/tmp/${base_filename}.empty"

    # Copy the original file to a temporary file or create an empty one
    if [[ -f "$filename" ]]; then
        cat "$filename" > "$temp_file"
        log_debug "Original file copied to temp file: $temp_file" "safe_insert"
    else
        touch "$temp_file" # Create a temp file if the source file does not exist
        log_debug "Source file doesn't exist, created empty temp file" "safe_insert"
    fi
    
    # Perform the add lines operation on the temporary file
    log_debug "Adding lines to temporary file" "safe_insert"
    check_and_add_lines "$temp_file" "${content_lines[@]}"

    # Compare the original file with the modified temporary file
    log_debug "Comparing changes" "safe_insert"
    local diff_output=""
    if [[ -f "$filename" ]]; then
        diff_output=$(diff -U2 "$filename" "$temp_file")
    else
        touch "$empty_file" # Create an empty file to compare with
        diff_output=$(diff -U2 "$empty_file" "$temp_file")
    fi

    local start_content=false
    local content_added=false

    # Iterate through the lines of the diff output to show proposed changes
    while IFS= read -r line; do
        if [[ "$line" =~ ^@@.*@@$ ]]; then
            start_content=true
            echo "Proposed changes in $filename:"
            echo -e "\033[1m$line\033[0m"
            continue
        fi
        if "$start_content"; then
            if [[ "$line" == +* ]]; then
                # Added line, print in green
                echo -e "\033[92m\033[1m$line\033[0m"
                content_added=true
            else
                echo "$line"
            fi
        fi
    done <<<"$diff_output"

    if ! "${content_added}"; then
        log_info "$usage: No change proposed" "safe_insert"
        rm "$temp_file" 2>/dev/null || true
        rm "$empty_file" 2>/dev/null || true
        return 0
    else
        # Skip confirmation if CONFIRM_ALL is set
        if [ "${SCRIPT_CONFIG[confirm_all]}" = "true" ]; then
            log_debug "Auto-applying changes due to CONFIRM_ALL=true" "safe_insert"
            mkdir -p $(dirname "$filename")
            cat "$temp_file" > "$filename"
            log_info "Changes applied automatically for $usage" "safe_insert"
        else
            if confirm "The above changes are made for \033[34;1m${usage}\033[0m. Apply changes?"; then
                mkdir -p $(dirname "$filename")
                cat "$temp_file" > "$filename"
                log_info "Changes applied for $usage" "safe_insert"
            else
                log_info "Changes declined for $usage" "safe_insert"
            fi
        fi
        
        # Clean up
        rm "$temp_file" 2>/dev/null || true
        rm "$empty_file" 2>/dev/null || true
        return 0
    fi
}

# Function to safely modify a file with user confirmation (removing content)
# Usage: safe_remove usage filename content
# Returns: 0 on success, 1 on failure
safe_remove() {
    local usage="$1"      # Describe what the modification is for
    local filename="$2"   # Path to the file to modify
    local content_block="$3" # Content block to remove
    
    log_debug "Safely removing content from file: $filename for $usage" "safe_remove"

    # Split the content block into an array of lines
    mapfile -t content_lines <<< "$content_block"

    # Check if file exists
    if [[ ! -f "$filename" ]]; then
        log_info "$usage: File doesn't exist, nothing to remove" "safe_remove"
        return 0
    fi

    # Use /tmp directory for temporary file operations
    local base_filename=$(basename "$filename")
    local temp_file="/tmp/${base_filename}.tmp"

    # Copy the original file to a temporary file
    cat "$filename" > "$temp_file"
    log_debug "Original file copied to temp file: $temp_file" "safe_remove"
    
    # Perform the remove lines operation on the temporary file
    log_debug "Removing lines from temporary file" "safe_remove"
    check_and_remove_lines "$temp_file" "${content_lines[@]}"

    # Compare the original file with the modified temporary file
    log_debug "Comparing changes" "safe_remove"
    local diff_output=$(diff -U2 "$filename" "$temp_file")

    local start_content=false
    local content_removed=false

    # Iterate through the lines of the diff output to show proposed changes
    while IFS= read -r line; do
        if [[ "$line" =~ ^@@.*@@$ ]]; then
            start_content=true
            echo "Proposed changes in $filename:"
            echo -e "\033[1m$line\033[0m"
            continue
        fi
        if "$start_content"; then
            if [[ "$line" == -* && "$line" != "--" ]]; then
                # Removed line, print in red
                echo -e "\033[91m\033[1m$line\033[0m"
                content_removed=true
            else
                echo "$line"
            fi
        fi
    done <<<"$diff_output"

    if ! "${content_removed}"; then
        log_info "$usage: No change proposed" "safe_remove"
        rm "$temp_file" 2>/dev/null || true
        return 0
    else
        # Skip confirmation if CONFIRM_ALL is set
        if [ "${SCRIPT_CONFIG[confirm_all]}" = "true" ]; then
            log_debug "Auto-applying changes due to CONFIRM_ALL=true" "safe_remove"
            cat "$temp_file" > "$filename"
            log_info "Changes applied automatically for $usage" "safe_remove"
        else
            if confirm "The above changes are made for \033[34;1m${usage}\033[0m. Apply changes?"; then
                cat "$temp_file" > "$filename"
                log_info "Changes applied for $usage" "safe_remove"
            else
                log_info "Changes declined for $usage" "safe_remove"
            fi
        fi
        
        # Clean up
        rm "$temp_file" 2>/dev/null || true
        return 0
    fi
}


# Export functions for use in other scripts
export -f check_and_add_lines
export -f check_and_remove_lines
export -f safe_insert
export -f safe_remove

log_debug "File operations implementation loaded" "file_ops"