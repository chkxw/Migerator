SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

check_internet_connection() {
    ping -c 4 google.com >/dev/null 2>&1
    if [ ! "$?" -eq 0 ]; then
        return 1  # Return 1 for false
    fi
    return 0  # Return 0 for true
}

# "$PROJECT_ROOT/setup.sh" -y proxy_main
"$PROJECT_ROOT/setup.sh" -y proxy_main --remove

source /etc/profile.d/proxy.sh

if ! check_internet_connection; then
    echo "Cannot connect to internet, please reboot and continue"
    exit 1
fi

"$PROJECT_ROOT/setup.sh" -y \
power_main \
batch_packages_main install common_deps \
batch_packages_main install utilities \
batch_packages_main install dev_tools \
batch_packages_main install ml_tools \
packages_main install chrome \
packages_main install vscode \
packages_main install slack \
packages_main install nodejs \
packages_main install virtualgl \
packages_main install turbovnc \
lab_users_main setup \
ssh_server_main \
conda_main

