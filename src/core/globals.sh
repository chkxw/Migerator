#!/bin/bash

# Global variables for the setup script
# This file contains all the global variables and configurations used across the script

# Source the logger to use logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"

log_debug "Loading global variables" "globals"

# Proxy configuration
declare -A PROXY_CONFIG
PROXY_CONFIG[host]="squid.cs.wisc.edu"
PROXY_CONFIG[port]="3128"
PROXY_CONFIG[enabled]="false"

# User configuration
declare -A USER_CONFIG
USER_CONFIG[default_password]="badgerrl"
USER_CONFIG[admin]="badgerrl"
USER_CONFIG[shared_group]="rllab"
USER_CONFIG[shared_dir]="/home/Shared"
USER_CONFIG[usr_scripts_path]="/usr/local/usr_scripts"
USER_CONFIG[net_shared_dir]="NetShared"

# Conda configuration
declare -A CONDA_CONFIG
CONDA_CONFIG[path]="/usr/local/miniconda3"
CONDA_CONFIG[env_path]="/home/Shared/conda_envs"
CONDA_CONFIG[type]="miniconda" # or "miniforge"

# Script behavior configuration
declare -A SCRIPT_CONFIG
SCRIPT_CONFIG[confirm_all]="false"
SCRIPT_CONFIG[log_level]="2" # INFO level

# User information
# Structure: fullname join_year is_superuser
declare -A USER_FULLNAME
declare -A USER_JOIN_YEAR
declare -A USER_IS_SUPERUSER

# Regular lab members
USER_FULLNAME["joseph_zhong"]="Joseph Zhong"
USER_JOIN_YEAR["joseph_zhong"]="2024"
USER_IS_SUPERUSER["joseph_zhong"]="false"

USER_FULLNAME["chen_li"]="Chen Li"
USER_JOIN_YEAR["chen_li"]="2024"
USER_IS_SUPERUSER["chen_li"]="false"

USER_FULLNAME["erika_sy"]="Erika Sy"
USER_JOIN_YEAR["erika_sy"]="2024"
USER_IS_SUPERUSER["erika_sy"]="false"

USER_FULLNAME["allen_chien"]="Allen Chien"
USER_JOIN_YEAR["allen_chien"]="2024"
USER_IS_SUPERUSER["allen_chien"]="false"

USER_FULLNAME["nicholas_corrado"]="Nicholas Corrado"
USER_JOIN_YEAR["nicholas_corrado"]="2024"
USER_IS_SUPERUSER["nicholas_corrado"]="false"

USER_FULLNAME["andrew_wang"]="Andrew Wang"
USER_JOIN_YEAR["andrew_wang"]="2024"
USER_IS_SUPERUSER["andrew_wang"]="false"

USER_FULLNAME["subhojyoti_mukerjee"]="Subhojyoti Mukerjee"
USER_JOIN_YEAR["subhojyoti_mukerjee"]="2024"
USER_IS_SUPERUSER["subhojyoti_mukerjee"]="false"

USER_FULLNAME["brahma_pavse"]="Brahma Pavse"
USER_JOIN_YEAR["brahma_pavse"]="2024"
USER_IS_SUPERUSER["brahma_pavse"]="false"

USER_FULLNAME["will_cong"]="Will Cong"
USER_JOIN_YEAR["will_cong"]="2024"
USER_IS_SUPERUSER["will_cong"]="false"

USER_FULLNAME["alan_zhong"]="Alan Zhong"
USER_JOIN_YEAR["alan_zhong"]="2024"
USER_IS_SUPERUSER["alan_zhong"]="false"

USER_FULLNAME["brennen_hill"]="Brennen Hill"
USER_JOIN_YEAR["brennen_hill"]="2024"
USER_IS_SUPERUSER["brennen_hill"]="false"

USER_FULLNAME["jeffrey_zou"]="Jeffrey Zou"
USER_JOIN_YEAR["jeffrey_zou"]="2024"
USER_IS_SUPERUSER["jeffrey_zou"]="false"

USER_FULLNAME["zisen_shao"]="Zisen Shao"
USER_JOIN_YEAR["zisen_shao"]="2024"
USER_IS_SUPERUSER["zisen_shao"]="false"

# Super users (with sudo access)
USER_FULLNAME["benjamin_hong"]="Benjamin Hong"
USER_JOIN_YEAR["benjamin_hong"]="2024"
USER_IS_SUPERUSER["benjamin_hong"]="true"

USER_FULLNAME["abhinav_harish"]="Abhinav Harish"
USER_JOIN_YEAR["abhinav_harish"]="2024"
USER_IS_SUPERUSER["abhinav_harish"]="true"

USER_FULLNAME["adam_labiosa"]="Adam Labiosa"
USER_JOIN_YEAR["adam_labiosa"]="2024"
USER_IS_SUPERUSER["adam_labiosa"]="true"

USER_FULLNAME["yunfu_deng"]="Yunfu Deng"
USER_JOIN_YEAR["yunfu_deng"]="2024"
USER_IS_SUPERUSER["yunfu_deng"]="true"

USER_FULLNAME["yuhao_li"]="Yuhao Li"
USER_JOIN_YEAR["yuhao_li"]="2024"
USER_IS_SUPERUSER["yuhao_li"]="true"

# Package repository information
# Structure: nickname pkg_formal_name gpg_key_url pkg_arch pkg_version_codename pkg_branch pkg_deb_src repo_base_url
declare -A PKG_FORMAL_NAME
declare -A PKG_GPG_KEY_URL
declare -A PKG_ARCH
declare -A PKG_VERSION_CODENAME
declare -A PKG_BRANCH
declare -A PKG_DEB_SRC
declare -A PKG_REPO_BASE_URL

# Chrome
PKG_FORMAL_NAME[google-chrome]="google-chrome-stable"
PKG_GPG_KEY_URL[google-chrome]="https://dl.google.com/linux/linux_signing_key.pub"
PKG_ARCH[google-chrome]="amd64"
PKG_VERSION_CODENAME[google-chrome]="stable"
PKG_BRANCH[google-chrome]="main"
PKG_DEB_SRC[google-chrome]="false"
PKG_REPO_BASE_URL[google-chrome]="http://dl.google.com/linux/chrome/deb/"

# VS Code
PKG_FORMAL_NAME[vscode]="code"
PKG_GPG_KEY_URL[vscode]="https://packages.microsoft.com/keys/microsoft.asc"
PKG_ARCH[vscode]="amd64"
PKG_VERSION_CODENAME[vscode]="stable"
PKG_BRANCH[vscode]="main"
PKG_DEB_SRC[vscode]="false"
PKG_REPO_BASE_URL[vscode]="https://packages.microsoft.com/repos/code"

# Docker
PKG_FORMAL_NAME[docker]="docker-ce"
PKG_GPG_KEY_URL[docker]="https://download.docker.com/linux/ubuntu/gpg"
PKG_ARCH[docker]="amd64"
PKG_VERSION_CODENAME[docker]="$OS_CODENAME"
PKG_BRANCH[docker]="stable"
PKG_DEB_SRC[docker]="false"
PKG_REPO_BASE_URL[docker]="https://download.docker.com/linux/ubuntu"

# NodeJS
PKG_FORMAL_NAME[nodejs]="nodejs"
PKG_GPG_KEY_URL[nodejs]="https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
PKG_ARCH[nodejs]="amd64"
PKG_VERSION_CODENAME[nodejs]="nodistro"
PKG_BRANCH[nodejs]="main"
PKG_DEB_SRC[nodejs]="false"
PKG_REPO_BASE_URL[nodejs]="https://deb.nodesource.com/node_22.x"

PKG_FORMAL_NAME[nodejs21]="nodejs"
PKG_GPG_KEY_URL[nodejs21]="https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
PKG_ARCH[nodejs21]="amd64"
PKG_VERSION_CODENAME[nodejs21]="nodistro"
PKG_BRANCH[nodejs21]="main"
PKG_DEB_SRC[nodejs21]="false"
PKG_REPO_BASE_URL[nodejs21]="https://deb.nodesource.com/node_21.x"

# VirtualGL
PKG_FORMAL_NAME[virtualgl]="virtualgl"
PKG_GPG_KEY_URL[virtualgl]="https://packagecloud.io/dcommander/virtualgl/gpgkey"
PKG_ARCH[virtualgl]="amd64"
PKG_VERSION_CODENAME[virtualgl]="any"
PKG_BRANCH[virtualgl]="main"
PKG_DEB_SRC[virtualgl]="false"
PKG_REPO_BASE_URL[virtualgl]="https://packagecloud.io/dcommander/virtualgl/any/"

# TurboVNC
PKG_FORMAL_NAME[turbovnc]="turbovnc"
PKG_GPG_KEY_URL[turbovnc]="https://packagecloud.io/dcommander/turbovnc/gpgkey"
PKG_ARCH[turbovnc]="amd64"
PKG_VERSION_CODENAME[turbovnc]="any"
PKG_BRANCH[turbovnc]="main"
PKG_DEB_SRC[turbovnc]="false"
PKG_REPO_BASE_URL[turbovnc]="https://packagecloud.io/dcommander/turbovnc/any/"

# Slack
PKG_FORMAL_NAME[slack]="slack-desktop"
PKG_GPG_KEY_URL[slack]="https://packagecloud.io/slacktechnologies/slack/gpgkey"
PKG_ARCH[slack]="amd64"
PKG_VERSION_CODENAME[slack]="jessie"
PKG_BRANCH[slack]="main"
PKG_DEB_SRC[slack]="true"
PKG_REPO_BASE_URL[slack]="https://packagecloud.io/slacktechnologies/slack/debian/"

# Wine
PKG_FORMAL_NAME[wine]="winehq-stable"
PKG_GPG_KEY_URL[wine]="https://dl.winehq.org/wine-builds/winehq.key"
PKG_ARCH[wine]="amd64,i386"
PKG_VERSION_CODENAME[wine]="$OS_CODENAME"
PKG_BRANCH[wine]="main"
PKG_DEB_SRC[wine]="false"
PKG_REPO_BASE_URL[wine]="https://dl.winehq.org/wine-builds/ubuntu"

# FFmpeg
PKG_FORMAL_NAME[ffmpeg]="ffmpeg"
PKG_GPG_KEY_URL[ffmpeg]="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf4e48910a020e77056748b745738ae8480447ddf"
PKG_ARCH[ffmpeg]="amd64"
PKG_VERSION_CODENAME[ffmpeg]="jammy"
PKG_BRANCH[ffmpeg]="main"
PKG_DEB_SRC[ffmpeg]="true"
PKG_REPO_BASE_URL[ffmpeg]="https://ppa.launchpadcontent.net/ubuntuhandbook1/ffmpeg6/ubuntu"

# Cubic
PKG_FORMAL_NAME[cubic]="cubic"
PKG_GPG_KEY_URL[cubic]="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xB7579F80E494ED3406A59DF9081525E2B4F1283B"
PKG_ARCH[cubic]="amd64"
PKG_VERSION_CODENAME[cubic]="$OS_CODENAME"
PKG_BRANCH[cubic]="main"
PKG_DEB_SRC[cubic]="true"
PKG_REPO_BASE_URL[cubic]="https://ppa.launchpadcontent.net/cubic-wizard/release/ubuntu"

# Remmina
PKG_FORMAL_NAME[remmina]="remmina"
PKG_GPG_KEY_URL[remmina]="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x04E38CE134B239B9F38F82EE8A993C2521C5F0BA"
PKG_ARCH[remmina]="amd64"
PKG_VERSION_CODENAME[remmina]="$OS_CODENAME"
PKG_BRANCH[remmina]="main"
PKG_DEB_SRC[remmina]="true"
PKG_REPO_BASE_URL[remmina]="https://ppa.launchpadcontent.net/remmina-ppa-team/remmina-next/ubuntu"

# VLC
PKG_FORMAL_NAME[vlc]="vlc"
PKG_GPG_KEY_URL[vlc]="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF4E48910A020E77056748B745738AE8480447DDF"
PKG_ARCH[vlc]="amd64"
PKG_VERSION_CODENAME[vlc]="$OS_CODENAME"
PKG_BRANCH[vlc]="main"
PKG_DEB_SRC[vlc]="true"
PKG_REPO_BASE_URL[vlc]="https://ppa.launchpadcontent.net/ubuntuhandbook1/vlc/ubuntu"

# Linux Wifi Hotspot
PKG_FORMAL_NAME[wifi-hotspot]="linux-wifi-hotspot"
PKG_GPG_KEY_URL[wifi-hotspot]="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x0E49A504B40CA53C5D8C72B487B8838C5E2893D3"
PKG_ARCH[wifi-hotspot]="amd64"
PKG_VERSION_CODENAME[wifi-hotspot]="$OS_CODENAME"
PKG_BRANCH[wifi-hotspot]="main"
PKG_DEB_SRC[wifi-hotspot]="true"
PKG_REPO_BASE_URL[wifi-hotspot]="https://ppa.launchpadcontent.net/lakinduakash/lwh/ubuntu"

# ros (Noetic)
PKG_FORMAL_NAME[ros]="ros-noetic-desktop-full"
PKG_GPG_KEY_URL[ros]="https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc"
PKG_ARCH[ros]="amd64"
PKG_VERSION_CODENAME[ros]="$OS_CODENAME"
PKG_BRANCH[ros]="main"
PKG_DEB_SRC[ros]="false"
PKG_REPO_BASE_URL[ros]="http://packages.ros.org/ros/ubuntu"

# Thunderbird
PKG_FORMAL_NAME[thunderbird]="thunderbird"
PKG_GPG_KEY_URL[thunderbird]="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x0AB215679C571D1C8325275B9BDB3D89CE49EC21"
PKG_ARCH[thunderbird]="amd64"
PKG_VERSION_CODENAME[thunderbird]="$OS_CODENAME"
PKG_BRANCH[thunderbird]="main"
PKG_DEB_SRC[thunderbird]="true"
PKG_REPO_BASE_URL[thunderbird]="https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu"

# Discord
PKG_FORMAL_NAME[discord]="discord"
PKG_GPG_KEY_URL[discord]="https://raw.githubusercontent.com/palfrey/discord-apt/refs/heads/main/discord-repo/discord-apt.gpg.asc"
PKG_ARCH[discord]="amd64"
PKG_VERSION_CODENAME[discord]="./"
PKG_BRANCH[discord]=""
PKG_DEB_SRC[discord]="false"
PKG_REPO_BASE_URL[discord]="https://palfrey.github.io/discord-apt/debian/"

# NeteaseCloudMusicGtk4
PKG_FORMAL_NAME[ncm4]="netease-cloud-music-gtk"
PKG_GPG_KEY_URL[ncm4]="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x61D88826EC7C7943D0D5DC6039B3993AD9F29276"
PKG_ARCH[ncm4]="amd64"
PKG_VERSION_CODENAME[ncm4]="$OS_CODENAME"
PKG_BRANCH[ncm4]="main"
PKG_DEB_SRC[ncm4]="true"
PKG_REPO_BASE_URL[ncm4]="https://ppa.launchpadcontent.net/gmg137/ncm/ubuntu"

PKG_FORMAL_NAME[zotero]="zotero"
PKG_GPG_KEY_URL[zotero]="https://raw.githubusercontent.com/retorquere/zotero-deb/master/zotero-archive-keyring.asc"
PKG_ARCH[zotero]="amd64"
PKG_VERSION_CODENAME[zotero]="./"
PKG_BRANCH[zotero]=""
PKG_DEB_SRC[zotero]="false"
PKG_REPO_BASE_URL[zotero]="https://zotero.retorque.re/file/apt-package-archive"
# Package Groups Definition
# These are groups of packages for batch installation

# BadgerRL dependencies array
# Packages needed specifically for BadgerRL development
declare -a BA_PKG_BADGER_RL_DEPS=(
    "ccache"
    "clang"
    "cmake"
    "git"
    "graphviz"
    "libasound2-dev"
    "libbox2d-dev"
    "libgl-dev"
    "libqt6opengl6-dev"
    "libqt6svg6-dev"
    "libstdc++-12-dev"
    "llvm"
    "mold"
    "net-tools"
    "ninja-build"
    "pigz"
    "qt6-base-dev"
    "rsync"
    "xxd"
)
export BA_PKG_BADGER_RL_DEPS
export BA_PKG_BADGER_RL_DEPS_DESCRIPTION="BadgerRL Development Dependencies"

# Common dependencies array
# Basic packages needed for most system operations and other installations
declare -a BA_PKG_COMMON_DEPS=(
    "software-properties-common"
    "apt-transport-https"
    "wget"
    "curl"
    "corkscrew"
    "ca-certificates"
)
export BA_PKG_COMMON_DEPS
export BA_PKG_COMMON_DEPS_DESCRIPTION="Common System Dependencies"

# Utilities array
# Useful system tools and utilities
declare -a BA_PKG_UTILITIES=(
    "openssh-server"
    "gnome-tweaks"
    "expect"
    "dconf-editor"
    "net-tools"
)
export BA_PKG_UTILITIES
export BA_PKG_UTILITIES_DESCRIPTION="System Utilities"

# Development tools array
# Tools for software development
declare -a BA_PKG_DEV_TOOLS=(
    "build-essential"
    "git"
    "vim"
    "neovim"
    "tmux"
    "htop"
    "jq"
    "shellcheck"
    "curl"
    "wget"
    "unzip"
    "p7zip-full"
    "swig"
    "cmake"
)
export BA_PKG_DEV_TOOLS
export BA_PKG_DEV_TOOLS_DESCRIPTION="Development Tools"

# ML/AI tools array
# Tools for machine learning and AI development
declare -a BA_PKG_ML_TOOLS=(
    "python3"
    "python3-pip"
    "python3-dev"
    "python3-venv"
    "libopenblas-dev"
    "liblapack-dev"
    "gfortran"
)
export BA_PKG_ML_TOOLS
export BA_PKG_ML_TOOLS_DESCRIPTION="Machine Learning Tools"

PKG_BRANCH[wifi-hotspot]="main"
PKG_DEB_SRC[wifi-hotspot]="true"
PKG_REPO_BASE_URL[wifi-hotspot]="https://ppa.launchpadcontent.net/lakinduakash/lwh/ubuntu"

# Android Studio
PKG_FORMAL_NAME[android-studio]="android-studio"
PKG_GPG_KEY_URL[android-studio]="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xB0B65046D9826D045FAFBA324EE97B1881326419"
PKG_ARCH[android-studio]="amd64"
PKG_VERSION_CODENAME[android-studio]="$OS_CODENAME"
PKG_BRANCH[android-studio]="main"
PKG_DEB_SRC[android-studio]="true"
PKG_REPO_BASE_URL[android-studio]="https://ppa.launchpadcontent.net/maarten-fonville/android-studio/ubuntu"

# Git Repository Configuration
# Structure: repo_nickname -> url, directory, branch, ssh_key
declare -A GIT_REPO_URL
declare -A GIT_REPO_DIR
declare -A GIT_REPO_BRANCH
declare -A GIT_REPO_SSH_KEY

# Example repository configurations
# GIT_REPO_URL[myproject]="https://github.com/username/myproject.git"
# GIT_REPO_DIR[myproject]="$HOME/projects/myproject"
# GIT_REPO_BRANCH[myproject]="main"
# GIT_REPO_SSH_KEY[myproject]=""

GIT_REPO_URL[usr_scripts]="git@gitee.com:chkxwlyh/usr_scripts.git"
GIT_REPO_DIR[usr_scripts]="${USER_CONFIG[usr_scripts_path]}"
GIT_REPO_BRANCH[usr_scripts]="master"
GIT_REPO_SSH_KEY[usr_scripts]="$HOME/.ssh/id_ed25519"

GIT_REPO_URL[important]="git@gitee.com:chkxwlyh/important.git"
GIT_REPO_DIR[important]="$HOME/Documents/important"
GIT_REPO_BRANCH[important]="master"
GIT_REPO_SSH_KEY[important]="$HOME/.ssh/id_ed25519"

# Symlink Configuration
# Structure: symlink_nickname -> source, target
declare -A SYMLINK_SOURCE
declare -A SYMLINK_TARGET

# Bash aliases
SYMLINK_SOURCE[bash_aliases]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/bash_aliases.sh"
SYMLINK_TARGET[bash_aliases]="$HOME/.bash_aliases"

# Git configuration
SYMLINK_SOURCE[gitconfig]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/gitconfig"
SYMLINK_TARGET[gitconfig]="$HOME/.gitconfig"

# Profile
SYMLINK_SOURCE[profile]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/profile"
SYMLINK_TARGET[profile]="$HOME/.profile"

# Pip configuration/
SYMLINK_SOURCE[pip]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/pip.conf"
SYMLINK_TARGET[pip]="$HOME/.pip/pip.conf"

# Thunderbird message filter rules
SYMLINK_SOURCE[msgfilter]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/msgFilterRules.dat"
SYMLINK_TARGET[msgfilter]="$HOME/.thunderbird/*/ImapMail/*/msgFilterRules.dat"

# Study daemon service
SYMLINK_SOURCE[study_daemon]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/study_daemon.service"
SYMLINK_TARGET[study_daemon]="/etc/systemd/system/study_daemon.service"

# NPM config
SYMLINK_SOURCE[npmrc]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/npmrc"
SYMLINK_TARGET[npmrc]="$HOME/.npmrc"

# Atuin config
SYMLINK_SOURCE[atuin_config]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/atuin_config.toml"
SYMLINK_TARGET[atuin_config]="$HOME/.config/atuin/config.toml"

# Fcitx5 user dic
SYMLINK_SOURCE[fcitx5_user_dict]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/fcitx5_user.dict"
SYMLINK_TARGET[fcitx5_user_dict]="$HOME/.local/share/fcitx5/pinyin/user.dict"

# Fcitx5 user history
SYMLINK_SOURCE[fcitx5_user_history]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/fcitx5_user.history"
SYMLINK_TARGET[fcitx5_user_history]="$HOME/.local/share/fcitx5/pinyin/user.history"

# Fcitx5 themes
SYMLINK_SOURCE[fcitx5_themes]="${USER_CONFIG[usr_scripts_path]}/ubuntu_configs/fcitx5_themes"
SYMLINK_TARGET[fcitx5_themes]="$HOME/.local/share/fcitx5/themes"
# Function to get a global variable
# Usage: global_vars key
# Returns: The value of the key or empty if not found
global_vars() {
    local key="$1"
    local value=""
    
    log_debug "Retrieving global variable: $key" "globals"
    
    # Check in each config map
    for config_map in "PROXY_CONFIG" "USER_CONFIG" "CONDA_CONFIG" "SCRIPT_CONFIG"; do
        value=$(get_value "$config_map" "$key")
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    done
    
    # Handle arrays
    case "$key" in
        "users")
            # Get all users who are not superusers
            local regular_users=()
            for user in "${!USER_FULLNAME[@]}"; do
                if [ "${USER_IS_SUPERUSER[$user]}" = "false" ]; then
                    regular_users+=("$user")
                fi
            done
            echo "${regular_users[@]}"
            ;;
        "super_users")
            # Get all users who are superusers
            local super_users=()
            for user in "${!USER_FULLNAME[@]}"; do
                if [ "${USER_IS_SUPERUSER[$user]}" = "true" ]; then
                    super_users+=("$user")
                fi
            done
            echo "${super_users[@]}"
            ;;
        "all_users")
            # Get all users (both regular and super)
            echo "${!USER_FULLNAME[@]}"
            ;;
        "package_repos")
            echo "${!PKG_FORMAL_NAME[@]}"
            ;;
        "git_repos")
            echo "${!GIT_REPO_URL[@]}"
            ;;
        "symlinks")
            echo "${!SYMLINK_SOURCE[@]}"
            ;;
        *)
            log_warning "Global variable not found: $key" "globals"
            return 1
            ;;
    esac
}

# Function to set a global variable
# Usage: set_global_var key value
# Returns: 0 on success, 1 on failure
set_global_var() {
    local key="$1"
    local value="$2"
    
    log_debug "Setting global variable: $key = $value" "globals"
    
    # Determine which config map to update
    case "$key" in
        "host"|"port"|"enabled")
            PROXY_CONFIG[$key]="$value"
            ;;
        "default_password"|"admin"|"shared_group"|"shared_dir"|"net_shared_dir")
            USER_CONFIG[$key]="$value"
            ;;
        "path"|"env_path"|"type")
            CONDA_CONFIG[$key]="$value"
            ;;
        "confirm_all"|"log_level")
            SCRIPT_CONFIG[$key]="$value"
            if [ "$key" = "log_level" ]; then
                set_log_level "$value"
            fi
            ;;
        *)
            log_warning "Unknown global variable: $key" "globals"
            return 1
            ;;
    esac
    
    return 0
}


# Export functions for use in other scripts
export -f global_vars
export -f set_global_var

# Export arrays and maps
export USER_FULLNAME
export USER_JOIN_YEAR
export USER_IS_SUPERUSER
export PKG_FORMAL_NAME
export PKG_GPG_KEY_URL
export PKG_ARCH
export PKG_VERSION_CODENAME
export PKG_BRANCH
export PKG_DEB_SRC
export PKG_REPO_BASE_URL
export GIT_REPO_URL
export GIT_REPO_DIR
export GIT_REPO_BRANCH
export GIT_REPO_SSH_KEY
export SYMLINK_SOURCE
export SYMLINK_TARGET
export PROXY_CONFIG
export USER_CONFIG
export CONDA_CONFIG
export SCRIPT_CONFIG

log_debug "Global variables loaded" "globals"
