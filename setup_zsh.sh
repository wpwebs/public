#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Logging functions
# -----------------------------------------------------------------------------
log_info()  { echo -e "\033[1;32m[INFO]\033[0m $1"; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# -----------------------------------------------------------------------------
# Determine if sudo is needed
# -----------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

# -----------------------------------------------------------------------------
# Update package list and install dependencies
# -----------------------------------------------------------------------------
log_info "Updating package list and installing dependencies..."
$SUDO apt update
$SUDO apt install -y zsh git curl

# -----------------------------------------------------------------------------
# Install Oh My Zsh for root (unattended) if not already installed
# -----------------------------------------------------------------------------
if [ ! -d "/root/.oh-my-zsh" ]; then
    log_info "Installing Oh My Zsh for root..."
    $SUDO bash -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
else
    log_info "Oh My Zsh is already installed for root."
fi

# -----------------------------------------------------------------------------
# Set up global Zsh configuration directories
# -----------------------------------------------------------------------------
ZSH_GLOBAL="/etc/zsh"
ZSH_CUSTOM="${ZSH_GLOBAL}/custom"

log_info "Creating global Zsh directories at ${ZSH_CUSTOM}..."
$SUDO mkdir -p "$ZSH_CUSTOM"
$SUDO chmod -R 755 "$ZSH_GLOBAL"

# -----------------------------------------------------------------------------
# Clone essential plugins and themes (if not already cloned)
# -----------------------------------------------------------------------------
plugins=(
    "https://github.com/zsh-users/zsh-autosuggestions"
    "https://github.com/zsh-users/zsh-completions"
    "https://github.com/zsh-users/zsh-syntax-highlighting"
    "https://github.com/romkatv/powerlevel10k"
)

log_info "Cloning essential plugins and themes..."
for repo in "${plugins[@]}"; do
    repo_name=$(basename "$repo")
    target_dir="${ZSH_CUSTOM}/${repo_name}"
    if [ ! -d "$target_dir" ]; then
        log_info "Cloning ${repo} into ${target_dir}..."
        $SUDO git clone --quiet "$repo" "$target_dir"
    else
        log_info "${repo_name} already exists. Skipping clone."
    fi
done

# -----------------------------------------------------------------------------
# Download global Powerlevel10k configuration if needed
# -----------------------------------------------------------------------------
P10K_GLOBAL="${ZSH_GLOBAL}/.p10k.zsh"
if [ ! -f "$P10K_GLOBAL" ]; then
    log_info "Downloading global Powerlevel10k configuration..."
    $SUDO curl -fsSL https://raw.githubusercontent.com/wpwebs/public/main/.p10k.zsh -o "$P10K_GLOBAL"
fi
$SUDO chmod 644 "$P10K_GLOBAL"

# Copy .p10k.zsh to /etc/skel so that new users get it
log_info "Copying global .p10k.zsh to /etc/skel..."
$SUDO cp "$P10K_GLOBAL" /etc/skel/.p10k.zsh

# -----------------------------------------------------------------------------
# Create default .zshrc for new users in /etc/skel
# -----------------------------------------------------------------------------
log_info "Creating default .zshrc in /etc/skel..."
$SUDO tee /etc/skel/.zshrc > /dev/null << 'EOF'
# Load Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load global plugins and theme
source /etc/zsh/custom/zsh-autosuggestions/zsh-autosuggestions.zsh
source /etc/zsh/custom/zsh-completions/zsh-completions.plugin.zsh
source /etc/zsh/custom/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /etc/zsh/custom/powerlevel10k/powerlevel10k.zsh-theme

# Ensure Powerlevel10k config is loaded
if [[ -f "$HOME/.p10k.zsh" ]]; then
    source "$HOME/.p10k.zsh"
elif [[ -f /etc/zsh/.p10k.zsh ]]; then
    cp /etc/zsh/.p10k.zsh "$HOME/.p10k.zsh"
    chmod 644 "$HOME/.p10k.zsh"
    source "$HOME/.p10k.zsh"
fi

# Disable Powerlevel10k setup wizard
echo 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' >> ~/.zshrc

# Set default alias
alias ll="ls -lah"
EOF

# Ensure /etc/skel/.config exists
$SUDO mkdir -p /etc/skel/.config

# -----------------------------------------------------------------------------
# Update existing users (UID ≥ 1000) to use Zsh and set up their config files
# -----------------------------------------------------------------------------
log_info "Configuring existing users..."

# Read /etc/passwd line by line
while IFS=: read -r username _ uid _ homedir _; do
    # Only update users with UID ≥ 1000 and a valid home directory
    if [ "$uid" -ge 1000 ] && [ -d "$homedir" ]; then
        log_info "Configuring user: $username"
        $SUDO chsh -s "$(command -v zsh)" "$username"

        # Copy .p10k.zsh if missing
        if [ ! -f "${homedir}/.p10k.zsh" ]; then
            $SUDO cp "$P10K_GLOBAL" "${homedir}/.p10k.zsh"
            $SUDO chmod 644 "${homedir}/.p10k.zsh"
            $SUDO chown "$username":"$username" "${homedir}/.p10k.zsh"
        fi

        # Copy .zshrc if missing
        if [ ! -f "${homedir}/.zshrc" ]; then
            $SUDO cp "/etc/skel/.zshrc" "${homedir}/.zshrc"
            $SUDO chown "$username":"$username" "${homedir}/.zshrc"
        fi
    fi
done < <(getent passwd)

# -----------------------------------------------------------------------------
# Set Zsh as the default shell for all existing users
# -----------------------------------------------------------------------------
log_info "Setting Zsh as the default shell for all existing users..."
for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    $SUDO chsh -s $(command -v zsh) $user
done


# -----------------------------------------------------------------------------
# Restart shell to apply changes
# -----------------------------------------------------------------------------
log_info "Switching to Zsh..."
exec zsh
