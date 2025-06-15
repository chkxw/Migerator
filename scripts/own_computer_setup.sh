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

"$PROJECT_ROOT/setup.sh" -y \
packages_main install slack \
# packages_main install nodejs \
# packages_main install virtualgl \
# packages_main install turbovnc \
# ssh_server_main \
# conda_main

