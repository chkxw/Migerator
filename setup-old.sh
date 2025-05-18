#!/bin/bash

# The setup script for rllab computer
# OS: Ubuntu 24.01 LTS
# Last update: 2025-01-08 11:43 By Yuhao Li (yli2565@wisc.edu)

global_vars() {
    local key="$1"
    local AllPort="3128"
    local AllHost="squid.cs.wisc.edu"
    local Default_User_Password="badgerrl"
    local admin="badgerrl"
    local shared_group_name="rllab"
    local shared_dir="/home/Shared"
    local net_shared_dir_name="NetShared"
    local users=("Joseph Zhong" "Chen Li" "Erika Sy" "Allen Chien" "Nicholas Corrado" "Andrew Wang" "Subhojyoti Mukerjee" "Brahma Pavse" "Will Cong" "Yunfu Deng" "Alan Zhong" "Brennen Hill" "Jeffrey Zou" "Zisen Shao")
    local super_users=("Benjamin Hong" "Abhinav Harish" "Adam Labiosa" "Yuhao Li")
    local conda_path="/usr/local/miniconda3"
    local conda_env_path="/home/Shared/conda_envs"
    # Convert array into string
    local users_string=$(printf "%s," "${users[@]}")
    local super_users_string=$(printf "%s," "${super_users[@]}")
    case "$key" in

    "AllPort") echo "${AllPort}" ;;
    "AllHost") echo "${AllHost}" ;;
    "Default_User_Password") echo "${Default_User_Password}" ;;
    "admin") echo "${admin}" ;;
    "shared_group_name") echo "${shared_group_name}" ;;
    "shared_dir") echo "${shared_dir}" ;;
    "net_shared_dir_name") echo "${net_shared_dir_name}" ;;
    "users") echo "${users_string%,}" ;;
    "super_users") echo "${super_users_string%,}" ;;
    "conda_path") echo "${conda_path}" ;;
    "conda_env_path") echo "${conda_env_path}" ;;
    *)
        echo "Error: Invalid key '$key'"
        return 1
        ;;
    esac
}

confirm() {
    local hint_message="$1"
    while true; do
        echo -e -n "$hint_message"
        read -p " (Y/N): " user_response
        case "$user_response" in
        [Yy]*)
            echo -e "\033[34;1mChanges confirmed.\033[0m\n"
            return 0
            ;;
        [Nn]*)
            # If user denies, do not apply changes
            echo -e "\033[31;1mChanges not applied.\033[0m\n"
            return 1
            ;;
        *)
            echo -e "\033[31;1mInvalid input. Changes not applied.\033[0m\n"
            return 1
            ;;
        '')
            trap - INT
            echo -e "\033[31;1mUser interrupted.\033[0m\n"
            return 1
            ;;
        esac
    done
}
create_symlink() {
    local source="$1"
    local target="$2"

    if [ ! -e "$source" ]; then
        echo "Error: Source '$source' does not exist."
        return 1
    fi

    if [ -e "$target" ]; then
        if [ -L "$target" ]; then
            existing_target=$(readlink "$target")
            if [ "$existing_target" != "$source" ]; then
                echo "Warning: $target already exists and points to a different location: $existing_target"
            else
                echo "Symbolic link already exists: $target -> $source"
                return 0
            fi
        else
            echo "Warning: $target already exists and is not a symbolic link."
            return 1
        fi
    fi

    ln -s "$source" "$target"
    if [ "$?" -eq 0 ]; then
        echo "Symbolic link created: $target -> $source"
    else
        echo "Error creating symbolic link: $target -> $source"
        return 1
    fi
}
check_package_installed() {
    local PKG_FORMAL_NAME="$1"
    local package_status=$(apt-cache policy "$PKG_FORMAL_NAME" 2>/dev/null | grep -E '^\s+Installed:' | awk '{print $2}')
    if [ "$?" -eq 1 ]; then
        return 1
    elif ! apt-cache show "${PKG_FORMAL_NAME}" &>/dev/null; then
        return 2
    elif [ "$package_status" == "(none)" ]; then
        return 3
    else
        return 0
    fi
}
check_internet_connection() {
    ping -c 4 google.com >/dev/null 2>&1
    if [ ! "$?" -eq 0 ]; then
        return false
    fi
    return true
}
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This function must be run as root" 1>&2
        exit 1
    fi
}
Sudo() {
    local firstArg="$1"

    if [[ $(type "$firstArg") == *function* ]]; then
        shift               # Remove the first argument
        local params=("$@") # Capture all remaining arguments in an array
        # Create a temporary file to store function definitions
        local tmpfile=$(mktemp)
        # Save all function definitions to the file
        declare -F | cut -d' ' -f3 | while read -r func; do declare -f "$func"; done >>"$tmpfile"

        shift
        local cmd="$firstArg"
        for arg in "${params[@]}"; do
            cmd+=" \"${arg//\"/\\\"}\""
        done

        command sudo bash -c -i "source $tmpfile; $cmd"
        rm "$tmpfile"
    elif [[ $(type "$firstArg") = *alias* ]]; then
        alias sudo='\sudo '
        eval "sudo $@"
    else
        command sudo "$@"
    fi
}
# Function to add lines to a file if they are missing
check_and_add_lines() {
    local filename="$1"
    local title="$2"
    shift 2
    local content=("$@")

    # Check if the file exists and is not a directory
    if [[ ! -f "$filename" && ! -d "$filename" ]]; then
        touch "$filename"
    elif [[ -d "$filename" ]]; then
        echo "Error: $filename is a directory" >&2
        return 1
    fi

    # Check if the title line is present, append if not
    if ! grep -Fxq "$title" "$filename"; then
        echo -e "\n$title" >>"$filename"
    fi

    # Read the file into an array
    mapfile -t lines <"$filename"

    # Find the index of the title line
    local title_index=-1
    for i in "${!lines[@]}"; do
        if [[ "${lines[$i]}" == "$title" ]]; then
            title_index="$i"
            break
        fi
    done

    # Insert content lines after the title line if they are missing
    local line_found line_insert_index=$((title_index + 1))
    for content_line in "${content[@]}"; do
        line_found=false
        for existing_line in "${lines[@]:$line_insert_index}"; do
            if [[ "$existing_line" == "$content_line" ]]; then
                line_found=true
                break
            fi
        done

        if [[ "$line_found" == false ]]; then
            # Insert the line after the last inserted line to maintain order
            lines=("${lines[@]:0:$line_insert_index}" "$content_line" "${lines[@]:$line_insert_index}")
        fi
        ((line_insert_index++))
    done

    # Write the updated array back to the file
    printf "%s\n" "${lines[@]}" >"$filename"
}
# Function to safely modify a file with user confirmation
safe_modify_file() {
    local useage="$1" # Describe what the modification is for
    local filename="$2"
    local title_line="$3"
    shift 3
    local content=("$@")

    # Use /tmp directory for temporary file operations, which is universally writable on Unix-like systems
    local base_filename=$(basename "$filename")
    local temp_file="/tmp/${base_filename}.tmp"
    local empty_file="/tmp/${base_filename}.empty"

    # Copy the original file to a temporary file
    if [[ -f "$filename" ]]; then
        cp "$filename" "$temp_file"
    else
        touch "$temp_file" # Create a temp file if the source file does not exist
    fi
    # echo "Content(Before) of temp file $temp_file"
    # cat $temp_file
    # Perform the add lines operation on the temporary file
    # echo "Processing changes..."
    check_and_add_lines "$temp_file" "$title_line" "${content[@]}"

    # Compare the original file with the modified temporary file
    # echo "Comparing changes..."
    # Run the diff command and store the output in a variable
    local diff_output=""
    if [[ -f "$filename" ]]; then
        diff_output=$(diff -U2 "$filename" "$temp_file")
    else
        touch "$empty_file" # Create an empty file to compare with
        diff_output=$(diff -U2 "$empty_file" "$temp_file")
    fi

    local start_content=false
    local content_added=false

    # Iterate through the lines of the diff output
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
        echo -e "$useage: No change proposed\n"
        rm "$temp_file"
        return 0
    else
        if confirm "The above changes are made for \033[34;1m${useage}\033[0m. Apply changes?"; then
            mkdir -p $(dirname "$filename")
            mv "$temp_file" "$filename"
        fi
        rm "$temp_file" 2>/dev/null || true
        rm "$empty_file" 2>/dev/null || true
        return 0
    fi
}
setup_proxy() {
    local AllPort=$(global_vars "AllPort")
    local AllHost=$(global_vars "AllHost")
    local HTTP_PROXY="http://${AllHost}"
    local HTTPS_PROXY="http://${AllHost}"
    local FTP_PROXY="ftp://${AllHost}"

    local filename=""
    local title_line=""
    local content_lines=""

    echo "HTTP_PROXY=${HTTP_PROXY}:${AllPort}"
    echo "HTTPS_PROXY=${HTTPS_PROXY}:${AllPort}"
    echo "FTP_PROXY=${FTP_PROXY}:${AllPort}"
    echo -e "Please \033[1mDOUBLE CHECK\033[0m the proxy above\n"
    if ! confirm "Is the proxy above correct?"; then
        return 1
    fi
    # Configure Proxy for login shells
    filename="/etc/profile.d/proxy.sh"
    title_line="# Proxy settings for WISC CS Building"
    content_lines=(
        "export http_proxy=\"${HTTP_PROXY}:${AllPort}/\""
        "export https_proxy=\"${HTTPS_PROXY}:${AllPort}/\""
        "export ftp_proxy=\"${FTP_PROXY}:${AllPort}/\""
        "export no_proxy=\"localhost.127.0.0.1,::1\""
        "#For curl"
        "export HTTP_PROXY=\"${HTTP_PROXY}:${AllPort}/\""
        "export HTTPS_PROXY=\"${HTTPS_PROXY}:${AllPort}/\""
        "export FTP_PROXY=\"${FTP_PROXY}:${AllPort}/\""
        "export NO_PROXY=\"localhost.127.0.0.1,::1\""
    )
    Sudo safe_modify_file "Login shells proxy" "$filename" "$title_line" "${content_lines[@]}"

    # Configure Proxy for non-login shells
    filename="/etc/bash.bashrc"
    title_line="# Proxy settings for WISC CS Building"
    content_lines=(
        "source /etc/profile.d/proxy.sh"
    )
    Sudo safe_modify_file "Non-login shells proxy" "$filename" "$title_line" "${content_lines[@]}"

    # GSettings proxy are now configured in dconf

    # Configure APT proxy
    filename="/etc/apt/apt.conf.d/proxy.conf"
    title_line="# Proxy settings for WISC CS Building"
    content_lines=(
        "Acquire::http::Proxy \"${HTTP_PROXY}:${AllPort}\";"
        "Acquire::https::Proxy \"${HTTPS_PROXY}:${AllPort}\";"
        "Acquire::ftp::Proxy \"${FTP_PROXY}:${AllPort}\";"
    )
    Sudo safe_modify_file "Apt proxy" "$filename" "$title_line" "${content_lines[@]}"

    # Configure GIT proxy
    filename="/etc/git_config"
    title_line="[https]"
    content_lines=(
        "    proxy = http://squid.cs.wisc.edu:3128"
        "[http]"
        "    proxy = http://squid.cs.wisc.edu:3128"
    )
    Sudo safe_modify_file "Configure Git settings?" "$filename" "$title_line" "${content_lines[@]}"

    # If you need access to gitlab and etc., please also add it here
    # Configure github.com proxy for ssh access
    filename="/etc/ssh/ssh_config"
    title_line="# Proxy settings to use ssh over https to access Github"
    content_lines=(
        "Host github.com"
        "    User git"
        "    Port 443"
        "    Hostname ssh.github.com"
        "    IdentitiesOnly yes"
        "    TCPKeepAlive yes"
        "    ProxyCommand corkscrew squid.cs.wisc.edu 3128 %h %p"
        "Host ssh.github.com"
        "    User git"
        "    Port 443"
        "    Hostname ssh.github.com"
        "    IdentitiesOnly yes"
        "    TCPKeepAlive yes"
        "    ProxyCommand corkscrew squid.cs.wisc.edu 3128 %h %p"
    )

    Sudo safe_modify_file "Github.com proxy for ssh access" "$filename" "$title_line" "${content_lines[@]}"

    filename="/etc/ssh/ssh_config"
    title_line="# Proxy settings to use ssh over https to access Gitee"
    content_lines=(
        "Host gitee.com"
        "    User git"
        "    Port 443"
        "    Hostname ssh.gitee.com"
        "    IdentitiesOnly yes"
        "    TCPKeepAlive yes"
        "    ProxyCommand corkscrew squid.cs.wisc.edu 3128 %h %p"
        "Host ssh.gitee.com"
        "    User git"
        "    Port 443"
        "    Hostname ssh.gitee.com"
        "    IdentitiesOnly yes"
        "    TCPKeepAlive yes"
        "    ProxyCommand corkscrew squid.cs.wisc.edu 3128 %h %p"
    )
    Sudo safe_modify_file "Gitee.com proxy for ssh access" "$filename" "$title_line" "${content_lines[@]}"

}
set_power_settings() {
    if [ ! "$(powerprofilesctl get mode)" == "performance" ]; then
        echo -e "Settings->Power->Power Mode: \033[1mPerformance\033[0m"
        if confirm "Set power mode to performance"; then
            powerprofilesctl set performance
        fi
    fi
    # Set "Settings->Power->Screen Blank: Never"
    filename="/etc/dconf/db/local.d/00-screen_blank"
    title_line="[org/gnome/desktop/session]"
    content_lines=(
        "idle-delay=uint32 0"
    )
    Sudo safe_modify_file "Settings->Power->Screen Blank: \033[1mNever\033[0m" "$filename" "$title_line" "${content_lines[@]}"
    # Set "Settings->Power->Automatic Suspend: Off"
    filename="/etc/dconf/db/local.d/00-automatic_suspend"
    title_line="[org/gnome/settings-daemon/plugins/power]"
    content_lines=(
        "sleep-inactive-ac-type='nothing'"
    )
    Sudo safe_modify_file "Settings->Power->Automatic Suspend: \033[1mOff\033[0m" "$filename" "$title_line" "${content_lines[@]}"
}
set_dconf_proxy() {
    local AllPort=$(global_vars "AllPort")
    local AllHost=$(global_vars "AllHost")
    local HTTP_PROXY="http://${AllHost}"
    local HTTPS_PROXY="http://${AllHost}"
    local FTP_PROXY="ftp://${AllHost}"

    # Set "Settings->Network->Network Proxy"
    filename="/etc/dconf/db/local.d/00-proxy"
    title_line="[system/proxy]"
    content_lines=(
        "mode='manual'"
        "[system/proxy/http]"
        "host='${HTTP_PROXY}'"
        "port=${AllPort}"
        "[system/proxy/https]"
        "host='${HTTPS_PROXY}'"
        "port=${AllPort}"
        "[system/proxy/ftp]"
        "host='${FTP_PROXY}'"
        "port=${AllPort}"
    )
    Sudo safe_modify_file "Settings->Network->Network Proxy: \033[1m${AllHost}:${AllPort}\033[0m" "$filename" "$title_line" "${content_lines[@]}"
}
set_dconf() {
    Sudo mkdir -p /etc/dconf/profile
    Sudo mkdir -p /etc/dconf/db/local.d
    # Create a dconf profile for system-wide settings
    local filename="/etc/dconf/profile/user"
    local title_line="user-db:user"
    local content_lines=("system-db:local")
    Sudo safe_modify_file "Create a dconf profile for system-wide settings" "$filename" "$title_line" "${content_lines[@]}"
    set_power_settings
    set_dconf_proxy
    Sudo dconf update
}
install_chrome() {
    ensure_root

    if check_package_installed google-chrome; then
        echo -e "\033[34;1mChrome is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fSsL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/google-chrome.gpg >/dev/null
    echo deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
    sudo apt update >/dev/null
    sudo apt install google-chrome-stable -y
    echo -e "\033[34;1mChrome installed.\033[0m\n"
}
install_wine() {
    ensure_root

    if check_package_installed winehq-stable; then
        echo -e "\033[34;1mWine is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fSsL https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/winehq.gpg >/dev/null
    echo deb [arch=amd64,i386 signed-by=/etc/apt/keyrings/winehq.gpg] https://dl.winehq.org/wine-builds/ubuntu noble main | sudo tee /etc/apt/sources.list.d/winehq.list >/dev/null

    # Special for wine: need 32 bit support
    sudo dpkg --add-architecture i386

    sudo apt update >/dev/null
    sudo apt install --install-recommends wine-stable -y
    echo -e "\033[34;1mWine installed.\033[0m\n"
}
install_ffmpeg() {
    ensure_root

    if check_package_installed ffmpeg; then
        echo -e "\033[34;1mffmpeg is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup\?op\=get\&search\=0xf4e48910a020e77056748b745738ae8480447ddf | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/ffmpeg6.gpg >/dev/null
    echo -e "deb [signed-by=/etc/apt/keyrings/ffmpeg6.gpg] https://ppa.launchpadcontent.net/ubuntuhandbook1/ffmpeg6/ubuntu/ noble main\ndeb-src [signed-by=/etc/apt/keyrings/ffmpeg6.gpg] https://ppa.launchpadcontent.net/ubuntuhandbook1/ffmpeg6/ubuntu/ noble main" | sudo tee /etc/apt/sources.list.d/ffmpeg6.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install ffmpeg -y
    echo -e "\033[34;1mffmpeg installed.\033[0m\n"
}
install_cubic() {
    ensure_root

    if check_package_installed cubic; then
        echo -e "\033[34;1mcubic is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup\?op\=get\&search\=0xB7579F80E494ED3406A59DF9081525E2B4F1283B | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/cubic-wizard.gpg >/dev/null
    echo -e "deb [signed-by=/etc/apt/keyrings/cubic-wizard.gpg] https://ppa.launchpadcontent.net/cubic-wizard/release/ubuntu/ noble main\ndeb-src [signed-by=/etc/apt/keyrings/cubic-wizard.gpg] https://ppa.launchpadcontent.net/cubic-wizard/release/ubuntu/ noble main" | sudo tee /etc/apt/sources.list.d/cubic-wizard.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install cubic -y
    echo -e "\033[34;1mcubic installed.\033[0m\n"
}
install_remmina() {
    ensure_root

    if check_package_installed remmina; then
        echo -e "\033[34;1mRemmina is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup\?op\=get\&search\=0x04E38CE134B239B9F38F82EE8A993C2521C5F0BA | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/remmina-next.gpg >/dev/null
    echo -e "deb [signed-by=/etc/apt/keyrings/remmina-next.gpg] https://ppa.launchpadcontent.net/remmina-ppa-team/remmina-next/ubuntu/ noble main\ndeb-src [signed-by=/etc/apt/keyrings/remmina-next.gpg] https://ppa.launchpadcontent.net/remmina-ppa-team/remmina-next/ubuntu/ noble main" | sudo tee /etc/apt/sources.list.d/remmina-next.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install remmina -y
    echo -e "\033[34;1mRemmina installed.\033[0m\n"
}
install_vlc() {
    ensure_root

    if check_package_installed vlc; then
        echo -e "\033[34;1mVLC Media Player is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup\?op\=get\&search\=0xF4E48910A020E77056748B745738AE8480447DDF | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/vlc.gpg >/dev/null
    echo -e "deb [signed-by=/etc/apt/keyrings/vlc.gpg] https://ppa.launchpadcontent.net/ubuntuhandbook1/vlc/ubuntu/ noble main\ndeb-src [signed-by=/etc/apt/keyrings/vlc.gpg] https://ppa.launchpadcontent.net/ubuntuhandbook1/vlc/ubuntu/ noble main" | sudo tee /etc/apt/sources.list.d/vlc.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install vlc -y
    echo -e "\033[34;1mVLC Media Player installed.\033[0m\n"
}
install_linux_hotspot() {
    ensure_root

    if check_package_installed linux-wifi-hotspot; then
        echo -e "\033[34;1mlinux-wifi-hotspot is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup\?op\=get\&search\=0x0E49A504B40CA53C5D8C72B487B8838C5E2893D3 | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/linux-wifi-hotspot.gpg >/dev/null
    echo -e "deb [signed-by=/etc/apt/keyrings/linux-wifi-hotspot.gpg] https://ppa.launchpadcontent.net/lakinduakash/lwh/ubuntu/ noble main\ndeb-src [signed-by=/etc/apt/keyrings/linux-wifi-hotspot.gpg] https://ppa.launchpadcontent.net/lakinduakash/lwh/ubuntu/ noble main" | sudo tee /etc/apt/sources.list.d/linux-wifi-hotspot.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install linux-wifi-hotspot -y
    echo -e "\033[34;1mlinux-wifi-hotspot installed.\033[0m\n"
}
install_docker() {
    ensure_root

    if check_package_installed docker-ce-cli; then
        echo -e "\033[34;1mDocker is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fSsL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/docker.gpg >/dev/null
    echo deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
    echo -e "\033[34;1mDocker installed.\033[0m\n"
}
install_andriod_studio() {
    ensure_root

    if check_package_installed android-studio; then
        echo -e "\033[34;1mAndroid Studio is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fsSL https://keyserver.ubuntu.com/pks/lookup\?op\=get\&search\=0xB0B65046D9826D045FAFBA324EE97B1881326419 | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/android-studio.gpg >/dev/null
    echo -e "deb [signed-by=/etc/apt/keyrings/android-studio.gpg] https://ppa.launchpadcontent.net/maarten-fonville/android-studio/ubuntu/ noble main\ndeb-src [signed-by=/etc/apt/keyrings/android-studio.gpg] https://ppa.launchpadcontent.net/maarten-fonville/android-studio/ubuntu/ noble main" | sudo tee /etc/apt/sources.list.d/android-studio.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install android-studio -y
    echo -e "\033[34;1mAndroid Studio installed.\033[0m\n"
}
install_vscode() {
    ensure_root

    if check_package_installed code; then
        echo -e "\033[34;1mVSCode is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fSsL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
    echo deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt update >/dev/null
    sudo apt install code -y
    echo -e "\033[34;1mVSCode installed.\033[0m\n"
}
install_slack() {
    ensure_root

    if check_package_installed slack-desktop; then
        echo -e "\033[34;1mSlack is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fSsL https://packagecloud.io/slacktechnologies/slack/gpgkey | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/slacktechnologies_slack-archive-keyring.gpg >/dev/null
    echo -e "deb [signed-by=/etc/apt/keyrings/slacktechnologies_slack-archive-keyring.gpg] https://packagecloud.io/slacktechnologies/slack/debian/ noble main\ndeb-src [signed-by=/etc/apt/keyrings/slacktechnologies_slack-archive-keyring.gpg] https://packagecloud.io/slacktechnologies/slack/debian/ noble main" | sudo tee /etc/apt/sources.list.d/slack.list >/dev/null
    sudo apt update >/dev/null
    sudo apt install slack-desktop -y
    echo -e "\033[34;1mSlack installed.\033[0m\n"
}
install_nodejs() {
    ensure_root

    if check_package_installed nodejs; then
        echo -e "\033[34;1mNodejs is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fSsL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/nodesource.gpg >/dev/null
    echo deb [arch=amd64 signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_21.x nodistro main | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install nodejs -y
    echo -e "\033[34;1mNodejs installed.\033[0m\n"
}
install_virtualgl() {
    ensure_root

    if check_package_installed virtualgl; then
        echo -e "\033[34;1mVirtualGL is already installed.\033[0m\n"
        return
    fi

    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fSsL https://packagecloud.io/dcommander/virtualgl/gpgkey | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/VirtualGL.gpg >/dev/null
    echo deb [arch=amd64 signed-by=/etc/apt/keyrings/VirtualGL.gpg] https://packagecloud.io/dcommander/virtualgl/any/ any main | sudo tee /etc/apt/sources.list.d/VirtualGL.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install virtualgl -y

    # Additional configurations to enable VirtualGL golbally
    # TODO: Maybe make this optional?
    local vglserver_config_bin=$(which vglserver_config)
    sudo ${vglserver_config_bin} +glx -s -f -t

    echo -e "\033[34;1mVirtualGL installed and configured globally.\033[0m\n"
}
install_turbovnc() {
    ensure_root

    if check_package_installed turbovnc; then
        echo -e "\033[34;1mTurbovnc is already installed.\033[0m\n"
        return
    fi
    sudo mkdir -m 0755 -p /etc/apt/keyrings/
    curl -fSsL https://packagecloud.io/dcommander/turbovnc/gpgkey | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/TurboVNC.gpg >/dev/null
    echo deb [arch=amd64 signed-by=/etc/apt/keyrings/TurboVNC.gpg] https://packagecloud.io/dcommander/turbovnc/any/ any main | sudo tee /etc/apt/sources.list.d/TurboVNC.list >/dev/null

    sudo apt update >/dev/null
    sudo apt install turbovnc -y

    if [ ! -e "/usr/bin/vncserver" ]; then
        # It seems turbovnc won't automatically create link under /usr/bin, so we need to create it
        turbovnc_binary_folder=$(whereis vncserver | grep -o '/[^ ]*[Tt]urbo[Vv][Nn][Cc][^ ]*/bin')
        local filename="/usr/bin/vncserver"
        local title_line="#!/bin/bash"
        local content=(
            'cpwd="\$PWD"'
            "cd ${turbovnc_binary_folder}"
            './vncserver "\$@" '
            'cd "\$cpwd"'
            'exit 0'
        )
        Sudo safe_modify_file "Create /usr/bin/vncserver link" "$filename" "$title_line" "${content[@]}"
        if [ -e "/usr/bin/vncserver" ]; then
            Sudo chmod +x /usr/bin/vncserver
        fi
    fi

    echo -e "\033[34;1mTurboVNC installed.\033[0m\n"
}
# install_thunderbird() {
#     ensure_root

#     if check_package_installed nodejs; then
#         echo -e "\033[34;1mNodejs is already installed.\033[0m\n"
#         return
#     fi
#     sudo mkdir -m 0755 -p /etc/apt/keyrings/
#     curl -fSsL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --yes --dearmor --batch --no-tty -o /etc/apt/keyrings/nodesource.gpg >/dev/null
#     echo deb [arch=amd64 signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_21.x nodistro main | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null

#     sudo apt update >/dev/null
#     sudo apt install nodejs -y
#     echo -e "\033[34;1mNodejs installed.\033[0m\n"
# }
install_miniconda() {
    local conda_path=$(global_vars "conda_path")
    local conda_env_path=$(global_vars "conda_env_path")
    if [ -d "${conda_path}" ] && [ -x "${conda_path}/bin/conda" ]; then
        echo -e "\033[34;1mconda is already installed in ${conda_path}\033[0m\n"
    else
        if [ -x "$(command -v conda)" ]; then
            echo -e "\033[31;1mconda has been installed in a different location, please remove it first before using this script to install it again.\033[0m\n"
        else
            wget "https://repo.anaconda.com/miniconda/Miniconda3-latest-$(uname)-$(uname -m).sh" -O /tmp/miniconda.sh
            Sudo bash /tmp/miniconda.sh -b -p "${conda_path}"
        fi
    fi

    if confirm "Init conda for all users?"; then
        # Init conda for login shell
        Sudo create_symlink "${conda_path}/etc/profile.d/conda.sh" /etc/profile.d/conda.sh
        # Init conda for non-login shell
        local filename="/etc/bash.bashrc"
        local title_line="# >>> conda initialize >>>"
        local content=(
            '# !! Contents within this block are managed by '\''conda init'\'' !!'
            '__conda_setup="\$'"('${conda_path}/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\""
            'if [ \$? -eq 0 ]; then'
            '    eval "\$__conda_setup"'
            'else'
            "    if [ -f \"${conda_path}/etc/profile.d/conda.sh\" ]; then"
            "        . \"${conda_path}/etc/profile.d/conda.sh\""
            '    else'
            "        export PATH=\"${conda_path}/bin:"'\$PATH"'
            '    fi'
            'fi'
            'unset __conda_setup'
            '# <<< conda initialize <<<'
        )
        Sudo safe_modify_file "Global conda init" "$filename" "$title_line" "${content[@]}"
        filename="/etc/conda/.condarc"
        title_line="# Shared conda environment folder"
        content=(
            'envs_dirs:'
            "  - ${conda_env_path}"
        )
        Sudo safe_modify_file "Global conda configurations" "$filename" "$title_line" "${content[@]}"
    fi
}
install_miniforge() {
    local conda_path=$(global_vars "conda_path")
    local conda_env_path=$(global_vars "conda_env_path")
    if [ -d "${conda_path}" ] && [ -x "${conda_path}/bin/conda" ]; then
        echo -e "\033[34;1mconda is already installed in ${conda_path}\033[0m\n"
    else
        if [ -x "$(command -v conda)" ]; then
            echo -e "\033[31;1mconda has been installed in a different location, please remove it first before using this script to install it again.\033[0m\n"
        else
            wget "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" -O /tmp/miniforge.sh
            Sudo bash /tmp/miniforge.sh -b -p "${conda_path}"
        fi
    fi

    if confirm "Init conda for all users?"; then
        # Init conda for login shell
        Sudo create_symlink "${conda_path}/etc/profile.d/conda.sh" /etc/profile.d/conda.sh
        Sudo create_symlink "${conda_path}/etc/profile.d/mamba.sh" /etc/profile.d/mamba.sh
        # Init conda for non-login shell
        local filename="/etc/bash.bashrc"
        local title_line="# >>> conda initialize >>>"
        local content=(
            '# !! Contents within this block are managed by '\''conda init'\'' !!'
            '__conda_setup="\$'"('${conda_path}/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\""
            'if [ \$? -eq 0 ]; then'
            '    eval "\$__conda_setup"'
            'else'
            "    if [ -f \"${conda_path}/etc/profile.d/conda.sh\" ]; then"
            "        . \"${conda_path}/etc/profile.d/conda.sh\""
            '    else'
            "        export PATH=\"${conda_path}/bin:"'\$PATH"'
            '    fi'
            'fi'
            'unset __conda_setup'
            "if [ -f \"${conda_path}/etc/profile.d/mamba.sh\" ]; then"
            "    . \"${conda_path}/etc/profile.d/mamba.sh\""
            'fi'
            '# <<< conda initialize <<<'
        )
        Sudo safe_modify_file "Global conda init" "$filename" "$title_line" "${content[@]}"
        filename="/etc/conda/.condarc"
        title_line="# Shared conda environment folder"
        content=(
            'envs_dirs:'
            "  - ${conda_env_path}"
            "# Always use conda-forge channel"
            'channels:'
            '- conda-forge'
            '- nodefaults'
        )
        Sudo safe_modify_file "Global conda configurations" "$filename" "$title_line" "${content[@]}"
    fi
}
install_utilities() {
    Sudo apt update
    local BadgerRL_requests=(ccache clang cmake git graphviz libasound2-dev libbox2d-dev libgl-dev libqt6opengl6-dev libqt6svg6-dev libstdc++-12-dev llvm mold net-tools ninja-build pigz qt6-base-dev rsync xxd)
    local common_dependencies=("software-properties-common" "apt-transport-https" "wget" "curl" "corkscrew" "ca-certificates" "samba")
    local utilities=("openssh-server" "git" "bashtop" "gnome-tweaks" "expect" "dconf-editor" "net-tools")

    if confirm "Install BadgerRL dependencies?"; then
        Sudo apt install "${BadgerRL_requests[@]}" -y
    fi
    if confirm "Install common dependencies?"; then
        Sudo apt install "${common_dependencies[@]}" -y
    fi
    if confirm "Install utilities?"; then
        Sudo apt install "${utilities[@]}" -y
        Sudo install_virtualgl
        Sudo install_turbovnc
    fi
    if confirm "Install Miniconda?"; then
        Sudo install_miniconda
    fi
    if confirm "Install Nodejs?"; then
        Sudo install_nodejs
    fi
    if confirm "Install Chrome?"; then
        Sudo install_chrome
    fi
    if confirm "Install VSCode?"; then
        Sudo install_vscode
    fi
    if confirm "Install Slack?"; then
        Sudo install_slack
    fi
}
create_shared_resources() {
    local shared_group_name=$(global_vars "shared_group_name")
    local shared_dir=$(global_vars "shared_dir")
    local admin=$(global_vars "admin")
    local conda_env_path=$(global_vars "conda_env_path")

    if getent group "${shared_group_name}" >/dev/null; then
        echo "Group '${shared_group_name}' already exists."
    else
        Sudo groupadd "${shared_group_name}"
        if [ "$?" -eq 0 ]; then
            echo "Group '${shared_group_name}' create successfully."
        else
            echo "Failed to create group '${shared_group_name}'."
        fi
    fi
    Sudo mkdir -p -m 775 "${shared_dir}"
    Sudo mkdir -p -m 775 "${conda_env_path}"
    # TODO: download start_vnc_server.sh from github use its content to create/update the vnc script
    Sudo chgrp -R "${shared_group_name}" "${shared_dir}"

    Sudo usermod -aG "$shared_group_name" "${admin}"
}
fullname_to_username() {
    local user_full_name="$1"
    local username=$(echo "$user_full_name" | cut -d' ' -f1)
    username=$(echo "$username" | tr '[:upper:]' '[:lower:]')
    username+="$(date +%Y)"
    echo "$username"
}
setup_for_each_user() {
    local shared_group_name=$(global_vars "shared_group_name")
    local admin=$(global_vars "admin")
    local Default_User_Password=$(global_vars "Default_User_Password")
    local net_shared_dir_name=$(global_vars "net_shared_dir_name")

    local username="$1"
    local home_dir=$(getent passwd "$username" | cut -d: -f6)

    #link shared folder
    Sudo create_symlink "/home/Shared" "${home_dir}/Shared"
    Sudo chown -R "${admin}:${shared_group_name}" "${home_dir}/Shared"

    #Create Net Shared Folder
    Sudo mkdir -p "${home_dir}/${net_shared_dir_name}"
    Sudo chown -R "${username}:${username}" "${home_dir}/${net_shared_dir_name}"
    (
        echo "${Default_User_Password}"
        echo "${Default_User_Password}"
    ) | sudo smbpasswd -s -a "${username}"

    local filename="/etc/samba/smb.conf"
    local title_line="[${username}-${net_shared_dir_name}]"
    local content_lines=(
        "   path = ${home_dir}/${net_shared_dir_name}"
        "   available = yes"
        "   valid users = ${username}"
        "   read only = no"
        "   browsable = yes"
        "   public = yes"
        "   writable = yes"
    )
    Sudo safe_modify_file "Create Net Shared Folder for ${username}" "$filename" "$title_line" "${content_lines[@]}"

    # Config VNC Server X session
    filename="${home_dir}/.vnc/xstartup"
    title_line="#!/bin/sh"
    content_lines=(
        '# For some reason, VNC does not start without these lines.'
        'unset SESSION_MANAGER'
        'unset DBUS_SESSION_BUS_ADDRESS'
        '# Load Xresources (Configuration file for X clients)'
        'if [ -r $HOME/.Xresources ]; then'
        '    xrdb $HOME/.Xresources'
        'fi'
        ''
        'xsetroot -solid grey'
        '# Fix to make GNOME work'
        'export XKL_XMODMAP_DISABLE=1'
        ''
        'gnome-session &'
        '# More light weight desktop environment'
        '# startxfce4 &'
        ''
        'wait'
    )
    Sudo safe_modify_file "Config VNC Server X session for ${username}" "$filename" "$title_line" "${content_lines[@]}"
    Sudo chmod +x "$filename"
    Sudo chown -R "${username}:${username}" "${home_dir}/.vnc"
}
create_user() {
    ensure_root

    local shared_group_name=$(global_vars "shared_group_name")
    local Default_User_Password=$(global_vars "Default_User_Password")

    local username="$1"
    local password="${Default_User_Password}"
    local groups=("${shared_group_name}")

    # Check if the username is valid
    if [[ ! "$username" =~ ^[a-z0-9]+$ ]]; then
        echo -e "\033[31;1mError: Username must contain only lowercase alphanumeric characters.\033[0m\n"
        return 1
    fi

    if [[ -n "$2" ]]; then
        groups+=("$2")
    fi

    # Check if the user already exists
    if id "$username" &>/dev/null; then
        echo -e "\033[34;1mUser $username already exists\033[0m"
        return 0
    fi
    if confirm "Create user \033[34;1m$username\033[0m?"; then
        # Create a new user and give it a home directory
        sudo useradd -m -s /bin/bash "$username"
        # Add the user to the sudo group so it can run sudo commands
        local groups_list=$(
            IFS=','
            echo "${groups[*]}"
        )
        sudo usermod -aG "$groups_list" "${username}"
        sudo echo "$username:$password" | sudo chpasswd

        setup_for_each_user "${username}"

        echo -e "\033[34;1mUser $username created.\033[0m\n"
    fi
}
create_users_from_list() {
    local IFS=','
    local users=()
    read -ra users <<<$(global_vars "users")
    local super_users=()
    read -ra super_users <<<$(global_vars "super_users")
    local admin=$(global_vars "admin")
    super_users+=("${admin}")
    for user in "${users[@]}"; do
        local username=$(fullname_to_username "$user")
        Sudo create_user "$username"
        Sudo
    done
    for super_user in "${super_users[@]}"; do
        local super_username=$(fullname_to_username "$super_user")
        Sudo create_user "$super_username" "sudo"
    done
    # Load the Net shared folders
    Sudo systemctl restart smbd
    Sudo systemctl restart nmbd
}
setup_users_from_list() {
    local IFS=','
    local users=()
    read -ra users <<<$(global_vars "users")
    local super_users=()
    read -ra super_users <<<$(global_vars "super_users")
    local admin=$(global_vars "admin")
    super_users+=("${admin}")
    for user in "${users[@]}"; do
        local username=$(fullname_to_username "$user")
        Sudo setup_for_each_user "$username"
    done
    for super_user in "${super_users[@]}"; do
        local super_username=$(fullname_to_username "$super_user")
        Sudo setup_for_each_user "$super_username"
    done
    # Load the Net shared folders
    Sudo systemctl restart smbd
    Sudo systemctl restart nmbd
}
add_new_user() {
    # Type the user with full name, we
    local is_super=false
    local name=""

    if [[ $# -eq 0 ]]; then
        echo -e "usage: $0 [-s|--super] [-h|--help] [[full name] ...]\nNames after [-s|--super] are super users with sudo access."
        exit
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -s | --super)
            is_super=true
            shift
            ;;
        -h | --help)
            echo -e "usage: $0 [-s|--super] [-h|--help] [[full name] ...]\nNames after [-s|--super] are super users with sudo access."
            exit
            ;;
        *)
            if [[ -z "$name" ]]; then
                local username=$(fullname_to_username "$1")
                if $is_super; then
                    Sudo create_user "$username" "sudo"
                else
                    Sudo create_user "$username"
                fi
                Sudo usermod -c "${1},,," "$username" >/dev/null 2>&1
            fi
            shift
            ;;
        esac
    done
}
setup_ssh() {
    if confirm "Set up ssh server?"; then
        Sudo systemctl enable ssh
        Sudo systemctl start ssh
        Sudo ufw allow ssh
    fi
}

install_AbstractSim_torchcpu_conda_environment() {
    local conda_path=$(global_vars "conda_path")
    local conda_env_path=$(global_vars "conda_env_path")
    local conda_runnable="${conda_path}/bin/conda"
    local ENV_NAME="AbstractSim_torchcpu"
    local ENV_FOLDER="${conda_env_path}"
    # Check if the environment already exists
    if "${conda_runnable}" env list | grep -q "$ENV_NAME"; then
        echo "The $ENV_NAME environment already exists. Skipping creation."
        echo -e "If you want to create a new one, run \033[34;1mconda env remove -n $ENV_NAME\033[0m"
    elif confirm "Create conda environment ${ENV_NAME} in ${ENV_FOLDER}"; then
        rm -f "/tmp/$ENV_NAME.yml"
        cat <<EOT >"/tmp/$ENV_NAME.yml"
name: $ENV_NAME
channels:
  - nvidia
  - pytorch
  - defaults
dependencies:
  - python=3.9
  - pip
  - cudatoolkit=11.8
  - cudnn=8.9.2.26=cuda11_0
  - pytorch==2.0.1
  - torchvision==0.15.2
  - torchaudio==2.0.2
  - pytorch-cuda=11.8
  - pip:
    - absl-py==2.0.0
    - appdirs==1.4.4
    - cachetools==5.3.2
    - certifi==2023.7.22
    - charset-normalizer==3.2.0
    - click==8.1.7
    - cloudpickle==2.2.1
    - coloredlogs==15.0.1
    - contourpy==1.1.1
    - cycler==0.11.0
    - docker-pycreds==0.4.0
    - Farama-Notifications==0.0.4
    - filelock==3.12.4
    - flatbuffers==23.5.26
    - fonttools==4.42.1
    - gitdb==4.0.10
    - GitPython==3.1.36
    - google-auth==2.23.4
    - google-auth-oauthlib==1.1.0
    - grpcio==1.59.3
    - gymnasium==0.29.1
    - humanfriendly==10.0
    - idna==3.4
    - importlib-metadata==6.8.0
    - importlib-resources==6.1.0
    - Jinja2==3.1.2
    - kiwisolver==1.4.5
    - llvmlite==0.41.1
    - Markdown==3.5.1
    - MarkupSafe==2.1.3
    - matplotlib==3.8.0
    - mpmath==1.3.0
    - networkx==3.1
    - numba==0.58.1
    - numpy==1.26.0
    - oauthlib==3.2.2
    - onnx==1.15.0
    - onnxruntime==1.17.0
    - overrides==7.7.0
    - packaging==23.1
    - pandas==2.1.1
    - pathtools==0.1.2
    - pettingzoo==1.24.1
    - Pillow==10.0.1
    - protobuf==4.23.4
    - psutil==5.9.5
    - pyasn1==0.5.1
    - pyasn1-modules==0.3.0
    - pygame==2.5.2
    - pyparsing==3.1.1
    - python-dateutil==2.8.2
    - pytz==2023.3.post1
    - PyYAML==6.0.1
    - requests==2.31.0
    - requests-oauthlib==1.3.1
    - rsa==4.9
    - sb3-contrib==2.1.0
    - scipy==1.12.0
    - sentry-sdk==1.31.0
    - setproctitle==1.3.2
    - six==1.16.0
    - smmap==5.0.1
    - stable-baselines3==2.1.0
    - SuperSuit==3.9.0
    - sympy==1.12
    - tensorboard==2.15.1
    - tensorboard-data-server==0.7.2
    - tinyscaler==1.2.7
    - typing_extensions==4.8.0
    - tzdata==2023.3
    - urllib3==2.0.5
    - wandb==0.16.0
    - Werkzeug==3.0.1
    - zipp==3.17.0
    - chardet==5.2.0
EOT
        # Create the Conda environment
        "${conda_runnable}" env create -f "/tmp/$ENV_NAME.yml" --prefix "${ENV_FOLDER}/${ENV_NAME}"
        rm -f "/tmp/$ENV_NAME.yml"
        echo -e "\033[32;1mThe $ENV_NAME environment has been created.\033[0m"
    fi
}

main() {
    create_shared_resources # should be called first

    set_dconf

    setup_proxy

    source /etc/profile.d/proxy.sh

    if $(check_internet_connection); then
        echo "Cannot connect to internet, please reboot and continue"
        exit 1
    fi

    install_utilities

    create_users_from_list

    setup_ssh

}

install_something() {
    Sudo install_miniforge
}

install_new_personal_comp() {
    Sudo apt install ccache clang cmake git graphviz libasound2-dev libbox2d-dev libgl-dev libqt6opengl6-dev libqt6svg6-dev libstdc++-12-dev llvm mold net-tools ninja-build pigz qt6-base-dev rsync xxd
    Sudo apt install "software-properties-common" "apt-transport-https" "wget" "curl" "corkscrew" "ca-certificates"
    Sudo apt install "git" "bashtop" "gnome-tweaks" "expect" "dconf-editor" "net-tools"

    Sudo mkdir -p /etc/dconf/profile
    Sudo mkdir -p /etc/dconf/db/local.d
    # Create a dconf profile for system-wide settings
    local filename="/etc/dconf/profile/user"
    local title_line="user-db:user"
    local content_lines=("system-db:local")
    Sudo safe_modify_file "Create a dconf profile for system-wide settings" "$filename" "$title_line" "${content_lines[@]}"
    Sudo set_power_settings

    Sudo dconf update

    Sudo install_miniconda
    Sudo install_chrome
    # Sudo  install_wine
    Sudo install_ffmpeg
    Sudo install_vlc
    Sudo install_vscode
    Sudo install_slack
    Sudo install_nodejs
    Sudo install_virtualgl
    Sudo install_turbovnc
}

do_something() {
    turbovnc_binary_folder=$(whereis vncserver | grep -o '/[^ ]*[Tt]urbo[Vv][Nn][Cc][^ ]*/bin')
    local filename="/usr/bin/vncserver"
    local title_line="#!/bin/bash"
    local content=(
        'cpwd="\$PWD"'
        "cd ${turbovnc_binary_folder}"
        './vncserver "\$@" '
        'cd "\$cpwd"'
        'exit 0'
    )
    Sudo safe_modify_file "Create /usr/bin/vncserver link" "$filename" "$title_line" "${content[@]}"
    if [ -e "/usr/bin/vncserver" ]; then
        Sudo chmod +x /usr/bin/vncserver
    fi
}

# Setup the whole computer from scratch
# main

# install optional software
# install_something

#add_new_user "<FirstName> <LastName>", currently only support two word name
#Names before -s|--super would be normal users, names after that would be super users with sudo access
#add_new_user "$@"
#install_new_personal_comp

install_something
