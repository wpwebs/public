#!/bin/bash

# =============================================================================
#
# Oh My Zsh & Powerlevel10k Installer
#
# Description: This script installs and configures Oh My Zsh, Powerlevel10k,
#              and essential plugins for root and all regular users (UID >= 1000).
#
# Usage:       sudo ./setup_zsh.sh
#
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
# Add plugin repository URLs to this array.
# The script will automatically derive the plugin name from the URL.
readonly PLUGINS=(
    "https://github.com/zsh-users/zsh-autosuggestions"
    "https://github.com/zsh-users/zsh-completions"
    "https://github.com/zsh-users/zsh-syntax-highlighting"
)

# Powerlevel10k theme repository.
readonly P10K_REPO="https://github.com/romkatv/powerlevel10k.git"

# URL for the default .p10k.zsh configuration file.
readonly P10K_CONFIG_URL="https://raw.githubusercontent.com/wpwebs/public/main/.p10k.zsh"

# -----------------------------------------------------------------------------
# Logging and Utility Functions
# -----------------------------------------------------------------------------
log_info()  { echo -e "\033[1;32m[INFO]\033[0m $1"; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; exit 1; }

# Function to check if a command exists.
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Core Functions
# -----------------------------------------------------------------------------

# Install package dependencies required for the script.
install_dependencies() {
    log_info "Updating package list and installing dependencies..."
    apt-get update
    apt-get install -y zsh git curl
}

# Install Oh My Zsh for a specific user if it's not already installed.
# Arguments:
#   $1: Username
#   $2: User's home directory
install_oh_my_zsh() {
    local user="$1"
    local home_dir="$2"
    local zsh_dir="${home_dir}/.oh-my-zsh"

    if [[ -d "$zsh_dir" ]]; then
        log_info "Oh My Zsh is already installed for ${user}."
        return
    fi

    log_info "Installing Oh My Zsh for ${user}..."
    sudo -u "$user" git clone --quiet https://github.com/ohmyzsh/ohmyzsh.git "$zsh_dir"
    sudo -u "$user" cp "${zsh_dir}/templates/zshrc.zsh-template" "${home_dir}/.zshrc"
}

# Install Zsh plugins and the Powerlevel10k theme for a user.
# Arguments:
#   $1: Username
#   $2: User's home directory
install_plugins_and_theme() {
    local user="$1"
    local home_dir="$2"
    local custom_dir="${home_dir}/.oh-my-zsh/custom"

    # Install Powerlevel10k
    local p10k_dir="${custom_dir}/themes/powerlevel10k"
    if [[ ! -d "$p10k_dir" ]]; then
        log_info "Cloning Powerlevel10k for ${user}..."
        sudo -u "$user" git clone --quiet --depth=1 "$P10K_REPO" "$p10k_dir"
    fi

    # Install other plugins
    for plugin_repo in "${PLUGINS[@]}"; do
        local plugin_name=$(basename "$plugin_repo")
        local plugin_dir="${custom_dir}/plugins/${plugin_name}"
        if [[ ! -d "$plugin_dir" ]]; then
            log_info "Cloning plugin ${plugin_name} for ${user}..."
            sudo -u "$user" git clone --quiet "$plugin_repo" "$plugin_dir"
        fi
    done
}

# Configure .zshrc and .p10k.zsh for a user.
# Arguments:
#   $1: Username
#   $2: User's home directory
configure_user_files() {
    local user="$1"
    local home_dir="$2"
    local zshrc_file="${home_dir}/.zshrc"
    local p10k_file="${home_dir}/.p10k.zsh"

    # Configure .zshrc
    log_info "Configuring .zshrc for ${user}..."
    local plugin_names=("git") # Start with the 'git' plugin by default
    for plugin_repo in "${PLUGINS[@]}"; do
        plugin_names+=("$(basename "$plugin_repo")")
    done
    local plugins_string="${plugin_names[*]}" # Convert array to space-separated string

    # Set the theme and activate all plugins in .zshrc
    sudo -u "$user" sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc_file"
    sudo -u "$user" sed -i "s/^plugins=(.*/plugins=(${plugins_string})/" "$zshrc_file"

    # Add sourcing for .p10k.zsh to the end of .zshrc if not already present
    # Note: The p10k theme sources this automatically, but we add it for explicitness.
    local p10k_source_line='[[ -s "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"'
    if ! sudo -u "$user" grep -qF 'source "$HOME/.p10k.zsh"' "$zshrc_file"; then
        log_info "Adding Powerlevel10k source line to ${user}'s .zshrc"
        echo -e "\n# To customize prompt, run 'p10k configure' or edit ~/.p10k.zsh.\n${p10k_source_line}" | sudo -u "$user" tee -a "$zshrc_file" > /dev/null
    fi

    # Download .p10k.zsh if it doesn't exist
    if [[ ! -f "$p10k_file" ]]; then
        log_info "Downloading default .p10k.zsh for ${user}..."
        sudo -u "$user" curl -fsSL "$P10K_CONFIG_URL" -o "$p10k_file"
    fi
    
    # Set correct ownership for all config files
    sudo chown "${user}:${user}" "${home_dir}/.zshrc"
    if [[ -f "$p10k_file" ]]; then
        sudo chown "${user}:${user}" "$p10k_file"
    fi
}

# Main function to process a single user.
# Arguments:
#   $1: Username
configure_user() {
    local user="$1"
    local home_dir
    home_dir=$(eval echo "~${user}") # Safely get home directory

    if [[ ! -d "$home_dir" ]]; then
        log_warn "Home directory for user '${user}' not found. Skipping."
        return
    fi
    
    log_info "--- Configuring user: ${user} ---"

    # Set Zsh as default shell if not already set
    if [[ "$(getent passwd "$user" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
        log_info "Setting Zsh as default shell for ${user}."
        chsh -s "$(command -v zsh)" "$user"
    else
        log_info "Zsh is already the default shell for ${user}."
    fi

    install_oh_my_zsh "$user" "$home_dir"
    install_plugins_and_theme "$user" "$home_dir"
    configure_user_files "$user" "$home_dir"

    log_info "--- Finished configuring ${user} ---"
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
main() {
    # Ensure the script is run as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root. Please use sudo."
    fi

    # Check for required commands
    for cmd in git curl getent; do
        if ! command_exists "$cmd"; then
            log_error "Command '${cmd}' not found. Please install it."
        fi
    done

    install_dependencies

    # Find all users to configure (root + users with UID >= 1000)
    local users_to_configure=()
    users_to_configure+=("root")
    while IFS=: read -r username _ uid _ _ _; do
        if [[ "$uid" -ge 1000 ]]; then
            users_to_configure+=("$username")
        fi
    done < <(getent passwd)

    # Process each user
    for user in "${users_to_configure[@]}"; do
        if id "$user" &>/dev/null; then
            configure_user "$user"
        else
            log_warn "User '${user}' does not exist. Skipping."
        fi
    done

    log_info "✅ All users have been configured successfully."
}

# Run the main function
main
