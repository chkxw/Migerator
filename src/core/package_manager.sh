#!/bin/bash

# Package management functions for the setup script
# This addresses the issues mentioned in Review 2 from CLAUDE.MD

# Source the required dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/globals.sh"
source "$SCRIPT_DIR/sudo.sh"

log_debug "Loading package management implementation" "package_manager"

# Function to parse a package repository entry
# Usage: parse_package_repo nickname
# Returns: An array of values (package_name, gpg_key_url, arch, version_codename, branch, deb_src, repo_url, repo_base_url)
parse_package_repo() {
    local nickname="$1"
    
    log_debug "Parsing package repo for nickname: $nickname" "package_manager"
    
    # Check if the package exists in our repositories
    if [[ ! " ${!PKG_FORMAL_NAME[@]} " =~ " $nickname " ]]; then
        log_error "No repository information found for nickname: $nickname" "package_manager"
        return 1
    fi
    
    local package_name="${PKG_FORMAL_NAME[$nickname]}"
    local gpg_key_url="${PKG_GPG_KEY_URL[$nickname]}"
    local arch="${PKG_ARCH[$nickname]}"
    local version_codename="${PKG_VERSION_CODENAME[$nickname]}"
    local branch="${PKG_BRANCH[$nickname]}"
    local deb_src="${PKG_DEB_SRC[$nickname]}"
    local repo_base_url="${PKG_REPO_BASE_URL[$nickname]}"
    
    # Auto-detect architecture if not specified
    if [ -z "$arch" ] || [ "$arch" = "auto" ]; then
        arch=$(dpkg --print-architecture)
        log_debug "Auto-detected architecture: $arch" "package_manager"
    fi
    
    # Auto-detect OS version codename if not specified or contains placeholder
    if [ -z "$version_codename" ] || [[ "$version_codename" == *"$"* ]]; then
        detect_os_info
        # Only replace if the version_codename contains a placeholder
        if [[ "$version_codename" == *"$"* ]]; then
            # Replace with actual OS codename
            version_codename="$OS_CODENAME"
            log_debug "Replaced placeholder in version_codename with: $version_codename" "package_manager"
        else
            # Use auto-detected value
            version_codename="$OS_CODENAME"
            log_debug "Auto-detected OS codename: $version_codename" "package_manager"
        fi
    fi
    
    # Handle OS_CODENAME placeholder in branch field (now executes independently)
    if [[ "$branch" == *'$OS_CODENAME'* ]]; then
        detect_os_info
        branch="${branch//\$OS_CODENAME/$OS_CODENAME}"
        log_debug "Replaced \$OS_CODENAME in branch with: $branch" "package_manager"
    fi
    
    # Generate multiple possible repository URLs for availability check
    local repo_url=""
    local check_urls=()
    
    # Remove trailing slash from base URL for consistent processing
    if [[ "$repo_base_url" == */ ]]; then
        repo_base_url="${repo_base_url%/}"
    fi
    
    # 1. Try base URL with InRelease appended
    check_urls+=("$(normalize_url "$repo_base_url/InRelease")")
    
    # 2. Try base URL with dists/codename/InRelease appended
    if [[ ! "$repo_base_url" == */dists* ]]; then
        check_urls+=("$(normalize_url "$repo_base_url/dists/$version_codename/InRelease")")
    fi
    
    # Special handling for repositories with "./" as distribution (like discord-apt)
    if [[ "$version_codename" == "./" ]]; then
        check_urls+=("$(normalize_url "$repo_base_url/./Release")")
        check_urls+=("$(normalize_url "$repo_base_url/./InRelease")")
        check_urls+=("$(normalize_url "$repo_base_url/./Packages")")
        check_urls+=("$(normalize_url "$repo_base_url/./Packages.gz")")
    fi
    
    # 3. Try APT-style repo URLs (for packagecloud, etc.)
    if [[ "$repo_base_url" == *packagecloud* ]]; then
        # Add standard packagecloud patterns
        check_urls+=("$(normalize_url "$repo_base_url/Packages.gz")")
        check_urls+=("$(normalize_url "$repo_base_url/Release")")
        check_urls+=("$(normalize_url "$repo_base_url/InRelease")")
        
        # Add specific patterns for "any" version repositories (like VirtualGL and TurboVNC)
        if [[ "$version_codename" == "any" ]]; then
            check_urls+=("$(normalize_url "${repo_base_url%/}/repos/any/any/x86_64/Packages.gz")")
            check_urls+=("$(normalize_url "${repo_base_url%/}/repos/any/any/x86_64/")")
        fi
    fi
    
    # 4. Try launchpad-specific URLs
    if [[ "$repo_base_url" == *launchpad* ]]; then
        check_urls+=("$(normalize_url "$repo_base_url/$version_codename/InRelease")")
    fi
    
    # Find first URL that's accessible
    for url in "${check_urls[@]}"; do
        if curl --output /dev/null --silent --head --fail "$url"; then
            repo_url="$url"
            log_debug "Found accessible repository URL: $repo_url" "package_manager"
            break
        fi
    done
    
    # If no URL is accessible, use the first one for further checks
    if [ -z "$repo_url" ]; then
        repo_url="${check_urls[0]}"
        log_debug "No accessible URL found, using: $repo_url" "package_manager"
    fi
    
    # Return values as an array using a delimiter that won't appear in the data
    # Use unit separator (ASCII 31) which is specifically designed for this purpose
    local delimiter=$'\x1F'
    printf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n" \
        "$package_name" "$delimiter" \
        "$gpg_key_url" "$delimiter" \
        "$arch" "$delimiter" \
        "$version_codename" "$delimiter" \
        "$branch" "$delimiter" \
        "$deb_src" "$delimiter" \
        "$repo_url" "$delimiter" \
        "$repo_base_url"
}

# Function to check if a package repository is available
# Usage: check_package_repo_available nickname
# Returns: 0 if available, 1 if not
check_package_repo_available() {
    local nickname="$1"
    IFS=$'\x1F' read -r package_name gpg_key_url arch version_codename branch deb_src repo_url repo_base_url <<< "$(parse_package_repo "$nickname")"
    
    log_debug "Checking if package repo is available: $nickname" "check_package_repo_available"
    
    # Handle nonexistent repositories
    if [ -z "$repo_url" ]; then
        log_error "Unknown package repository: $nickname" "check_package_repo_available"
        return 1
    fi
    
    # Use apt-get update --print-uris to validate repository availability
    # This method works uniformly for all repository types (standard, PPA, packagecloud, etc.)
    local temp_sources="/tmp/migerator-sources-test-$$"
    local temp_lists_dir="/tmp/migerator-lists-test-$$"
    
    # Generate the repository entry for testing (without GPG key requirement)
    local test_repo_entry="$(generate_repo_entry_template "$nickname" "dummy.gpg" | sed 's/\[.*signed-by=[^]]*\]/[trusted=yes]/')"
    
    if [ -z "$test_repo_entry" ]; then
        log_error "Failed to generate test repository entry for $nickname" "check_package_repo_available"
        return 1
    fi
    
    # Write temporary sources.list file
    echo "$test_repo_entry" > "$temp_sources"
    
    log_debug "Testing repository with apt-get update --print-uris" "check_package_repo_available"
    log_debug "Test repository entry: $test_repo_entry" "check_package_repo_available"
    
    # Create temp directory for lists
    mkdir -p "$temp_lists_dir"
    
    # Test if apt can fetch metadata from the repository
    # --print-uris shows what apt would download without actually downloading
    local apt_output
    apt_output=$(LC_ALL=C apt-get update \
        -o Dir::Etc::sourcelist="$temp_sources" \
        -o Dir::Etc::sourceparts=/dev/null \
        -o Dir::State::lists="$temp_lists_dir" \
        -o APT::Get::List-Cleanup=0 \
        -o Acquire::Check-Valid-Until=false \
        -o Debug::NoLocking=1 \
        --print-uris 2>&1)
    
    local result=$?
    
    # Clean up temporary files
    rm -f "$temp_sources"
    rm -rf "$temp_lists_dir"
    
    if [ $result -eq 0 ]; then
        # Check if apt actually found valid URIs to download
        # The output format is: 'URL' local_filename size
        if echo "$apt_output" | grep -qE "^'(https?|ftp)://.*/(InRelease|Release|Packages(\.(gz|xz|bz2))?)'|^'(https?|ftp)://.*/\.\/(InRelease|Release|Packages(\.(gz|xz|bz2))?)'" ; then
            log_debug "Repository is available: $nickname" "check_package_repo_available"
            return 0
        else
            log_warning "Repository returned no valid URIs: $nickname" "check_package_repo_available"
            return 1
        fi
    else
        # Extract meaningful error message if available
        local error_msg=$(echo "$apt_output" | grep -E "(Failed|404|Cannot|Unable)" | head -1)
        if [ -n "$error_msg" ]; then
            log_warning "Repository check failed for $nickname: $error_msg" "check_package_repo_available"
        else
            log_warning "Package repository is not available: $nickname" "check_package_repo_available"
        fi
        return 1
    fi
}

# Function to generate repository entry template
# Usage: generate_repo_entry_template nickname gpg_key_file
# Returns: The repository entry template with variables substituted
generate_repo_entry_template() {
    local nickname="$1"
    local gpg_key_file="$2"
    IFS=$'\x1F' read -r package_name gpg_key_url arch version_codename branch deb_src repo_url repo_base_url <<< "$(parse_package_repo "$nickname")"
    
    log_debug "Generating repo entry template for $nickname" "package_manager"
    
    # Ensure repo_base_url has trailing slash if needed
    if [[ ! "$repo_base_url" == */ ]]; then
        repo_base_url="$repo_base_url/"
    fi
    
    # Create the basic template
    local template="deb [arch=$arch signed-by=$gpg_key_file] $repo_base_url $version_codename"
    
    # Only add branch if it's not empty
    if [ -n "$branch" ]; then
        template="$template $branch"
    fi
    
    echo "$template"
}

# Function to register a package repository
# Usage: register_package_repo nickname
# Returns: 0 on success, 1 on failure
register_package_repo() {
    local nickname="$1"
    IFS=$'\x1F' read -r package_name gpg_key_url arch version_codename branch deb_src repo_url repo_base_url <<< "$(parse_package_repo "$nickname")"
    
    log_debug "Registering package repository: $nickname" "package_manager"
    
    # Check if the package repository is available
    if ! check_package_repo_available "$nickname"; then
        log_warning "Skipping repository registration as it's not available: $nickname" "package_manager"
        return 1
    fi
    
    # Ensure the keyrings directory exists
    Sudo ensure_directory "/etc/apt/keyrings" "0755"
    
    # Download and register the GPG key
    local gpg_key_file="/etc/apt/keyrings/${nickname}.gpg"
    log_debug "Downloading GPG key from $gpg_key_url to $gpg_key_file" "package_manager"
    
    if [[ "$gpg_key_url" == *"keyserver.ubuntu.com"* ]]; then
        # Handle keys from Ubuntu keyserver - use a more robust approach
        local key_id=$(echo "$gpg_key_url" | grep -o '0x[A-Z0-9]*')
        log_debug "Extracted key ID: $key_id" "package_manager"
        # Create a temporary file to download and process the key
        local temp_key="/tmp/${nickname}-key.gpg"
        if curl -fsSL "$gpg_key_url" > "$temp_key.asc" 2>/dev/null; then
            if gpg --homedir /tmp --dearmor --batch --no-tty < "$temp_key.asc" > "$temp_key" 2>/dev/null; then
                Sudo cp "$temp_key" "$gpg_key_file"
                rm -f "$temp_key" "$temp_key.asc"
            else
                log_error "Failed to process GPG key for $nickname" "package_manager"
                rm -f "$temp_key" "$temp_key.asc"
                return 1
            fi
        else
            log_error "Failed to download GPG key for $nickname" "package_manager"
            return 1
        fi
    else
        # Regular key URLs
        Sudo bash -c "curl -fsSL $gpg_key_url | gpg --yes --dearmor --batch --no-tty -o $gpg_key_file"
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download and register GPG key for $nickname" "package_manager"
        return 1
    fi
    
    # Create the repository list file
    local list_file="/etc/apt/sources.list.d/${nickname}.list"
    
    # Generate the repository entry
    local repo_entry="$(generate_repo_entry_template "$nickname" "$gpg_key_file")"
    if [ -z "$repo_entry" ]; then
        log_error "Failed to generate repository entry for $nickname" "package_manager"
        return 1
    fi
    
    # Add deb-src entry if required
    if [ "$deb_src" = "true" ]; then
        # Extract just the URL and components from the deb line
        local deb_src_entry=$(echo "$repo_entry" | sed "s/^deb /deb-src /")
        repo_entry="${repo_entry}\n${deb_src_entry}"
    fi
    
    # Write the repository entry to the list file
    log_debug "Writing repository entry to $list_file: $repo_entry" "package_manager"
    Sudo bash -c "echo -e \"$repo_entry\" > $list_file"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to write repository entry to $list_file" "package_manager"
        return 1
    fi
    
    # Log the actual content that was written to verify
    log_debug "Repository file content written to $list_file:" "package_manager"
    log_debug "$(cat $list_file 2>/dev/null || echo 'Could not read file')" "package_manager"
    
    log_info "Successfully registered package repository: $nickname" "package_manager"
    return 0
}

# Function to install a package
# Usage: install_package nickname [additional_packages...]
# Returns: 0 on success, 1 on failure
install_package() {
    local nickname="$1"
    shift
    local additional_packages=("$@")
    
    IFS=$'\x1F' read -r package_name gpg_key_url arch version_codename branch deb_src repo_url repo_base_url <<< "$(parse_package_repo "$nickname")"
    
    log_debug "Installing package: $nickname ($package_name)" "package_manager"
    
    # Check if the package is already installed
    if check_package_installed "$package_name"; then
        log_info "Package already installed: $nickname ($package_name)" "package_manager"
        return 0
    fi
    
    # Register the package repository if needed
    if ! grep -q "^deb.*$nickname" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
        log_debug "Repository not registered for $nickname, registering now" "package_manager"
        if ! register_package_repo "$nickname"; then
            log_error "Failed to register repository for $nickname" "package_manager"
            return 1
        fi
        
        # Update package lists after adding a new repository
        log_debug "Updating package lists" "package_manager"
        Sudo apt update >/dev/null
    fi
    
    # Check if multi-arch support is needed based on architecture string
    if [[ "$arch" == *","* ]] && [[ "$arch" == *"i386"* ]]; then
        log_debug "Adding i386 architecture support for multi-arch package" "package_manager"
        Sudo dpkg --add-architecture i386
    fi
    
    # Install the package and any additional packages
    log_debug "Installing package $package_name and ${additional_packages[*]}" "package_manager"
    if [ ${#additional_packages[@]} -gt 0 ]; then
        Sudo apt install -y "$package_name" "${additional_packages[@]}"
    else
        Sudo apt install -y "$package_name"
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Failed to install package: $nickname ($package_name)" "package_manager"
        return 1
    fi
    
    log_info "Successfully installed package: $nickname ($package_name)" "package_manager"
    return 0
}

# Export functions for use in other scripts
export -f parse_package_repo
export -f check_package_repo_available
export -f generate_repo_entry_template
export -f register_package_repo
export -f install_package
export -f normalize_url

log_debug "Package management implementation loaded" "package_manager"