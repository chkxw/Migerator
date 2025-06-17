SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

check_internet_connection() {
    ping -c 4 google.com >/dev/null 2>&1
    if [ ! "$?" -eq 0 ]; then
        return 1  # Return 1 for false
    fi
    return 0  # Return 0 for true
}


if ! check_internet_connection; then
    echo "Cannot connect to internet, please reboot and continue"
    exit 1
fi

"$PROJECT_ROOT/setup.sh" -y --debug \
power_main \
batch_packages_main install common_deps \
batch_packages_main install utilities \
batch_packages_main install dev_tools \
batch_packages_main install ml_tools \
packages_main install google-chrome vscode slack \
packages_main install nodejs \
packages_main install virtualgl turbovnc \
packages_main install thunderbird remmina wifi-hotspot \
packages_main install ffmpeg vlc \
ssh_server_main \
conda_main \
atuin_main --shell bash --login --key 'dove broom ten trade pet heart inside scissors summer matrix trick vapor minimum venue remain hospital opera squeeze panda target metal service alcohol demand' --username chkxwlyh --sync \
personal_setup_main setup \
git_repos_main clone --only usr_scripts important \
symlinks_main create --only profile bash_aliases gitconfig msgfilter study_daemon pip npmrc --force \
personal_setup_main install-claude \