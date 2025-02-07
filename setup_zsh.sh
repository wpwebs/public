#!/bin/sh

set -e  # Exit on any error

# Update package list and install dependencies
sudo apt update && sudo apt install -y zsh git curl

# Install Oh My Zsh (unattended) for root if not already installed
if [ ! -d "/root/.oh-my-zsh" ]; then
    sudo sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
fi

# Define global Zsh configuration directory
ZSH_GLOBAL="/etc/zsh"
ZSH_CUSTOM="$ZSH_GLOBAL/custom"

# Create global Zsh directories and set proper permissions
sudo mkdir -p "$ZSH_CUSTOM"
sudo chmod -R 755 "$ZSH_GLOBAL"

# Clone essential plugins and themes globally (only if they don't exist)
for repo in \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-completions" \
    "https://github.com/zsh-users/zsh-syntax-highlighting" \
    "https://github.com/romkatv/powerlevel10k"
do
    dir="${ZSH_CUSTOM}/$(basename $repo)"
    [ ! -d "$dir" ] && sudo git clone --quiet "$repo" "$dir"
done

# Ensure global Powerlevel10k config exists
if [ ! -f "$ZSH_GLOBAL/.p10k.zsh" ]; then
    sudo curl -fsSL https://raw.githubusercontent.com/wpwebs/public/refs/heads/main/.p10k.zsh -o "$ZSH_GLOBAL/.p10k.zsh"
    sudo chmod 644 "$ZSH_GLOBAL/.p10k.zsh"
fi

# Ensure .p10k.zsh is copied to /etc/skel/ for new users
sudo cp "$ZSH_GLOBAL/.p10k.zsh" /etc/skel/.p10k.zsh

# Set up a global default Zsh configuration in /etc/zsh/zshrc
sudo tee /etc/zsh/zshrc > /dev/null << 'EOF'
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load global plugins and theme
source /etc/zsh/custom/zsh-autosuggestions/zsh-autosuggestions.zsh
source /etc/zsh/custom/zsh-completions/zsh-completions.plugin.zsh
source /etc/zsh/custom/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /etc/zsh/custom/powerlevel10k/powerlevel10k.zsh-theme

# Load Powerlevel10k configuration
if [[ -f $HOME/.p10k.zsh ]]; then
    source $HOME/.p10k.zsh
elif [[ -f /etc/zsh/.p10k.zsh ]]; then
    source /etc/zsh/.p10k.zsh
fi

# Set default alias
alias ll="ls -lah"
EOF

# Ensure all users (including new ones) get the same Zsh configuration
sudo mkdir -p /etc/skel/.config
sudo cp /etc/zsh/zshrc /etc/skel/.zshrc

# Add Zsh to the list of valid shells if not already present
if ! grep -qxF "$(command -v zsh)" /etc/shells; then
    command -v zsh | sudo tee -a /etc/shells > /dev/null
fi

# Set Zsh as the default shell for all existing users (excluding system users)
for user in $(getent passwd | awk -F: '$3 >= 1000 {print $1}'); do
    HOME_DIR=$(eval echo "~$user")
    
    # Skip users with no home directory
    if [ "$HOME_DIR" = "/home/nobody" ] || [ ! -d "$HOME_DIR" ]; then
        echo "Skipping user: $user (No valid home directory)"
        continue
    fi

    sudo chsh -s "$(which zsh)" "$user"
    sudo cp "$ZSH_GLOBAL/.p10k.zsh" "$HOME_DIR/.p10k.zsh"
    sudo chown "$user":"$user" "$HOME_DIR/.p10k.zsh"
done

# Set Zsh as the default shell for new users and root
sudo usermod --shell "$(which zsh)" root

# Restart shell to apply changes
exec zsh
