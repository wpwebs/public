#!/bin/sh

set -e  # Exit on any error

# Update package list and install dependencies
sudo apt update && sudo apt install -y zsh git curl

# Install Oh My Zsh (unattended) for the root user first
if [ ! -d "/root/.oh-my-zsh" ]; then
    sudo sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended"
fi

# Define global Zsh configuration directory
ZSH_GLOBAL="/etc/zsh"
ZSH_CUSTOM="$ZSH_GLOBAL/custom"

# Create global Zsh configuration directory if it doesn't exist
sudo mkdir -p "$ZSH_CUSTOM"

# Clone essential plugins and themes globally
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
fi

# Set up a global default Zsh configuration in /etc/zsh/zshrc
cat << 'EOF' | sudo tee /etc/zsh/zshrc > /dev/null
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load global plugins and theme
source /etc/zsh/custom/zsh-autosuggestions/zsh-autosuggestions.zsh
source /etc/zsh/custom/zsh-completions/zsh-completions.plugin.zsh
source /etc/zsh/custom/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /etc/zsh/custom/powerlevel10k/powerlevel10k.zsh-theme

# Load global Powerlevel10k configuration
[[ ! -f /etc/zsh/.p10k.zsh ]] || source /etc/zsh/.p10k.zsh

# Start SSH agent
eval "$(ssh-agent -s)" 2>/dev/null
[ -f "$HOME/.ssh/sshkey" ] && chmod 600 "$HOME/.ssh/sshkey" && ssh-add "$HOME/.ssh/sshkey" 2>/dev/null

# Set default alias
alias ll="ls -lah"
EOF

# Ensure new users get the same Zsh configuration
sudo mkdir -p /etc/skel/.config
sudo cp /etc/zsh/zshrc /etc/skel/.zshrc

# Add Zsh to the list of valid shells if not already present
if ! grep -qxF "$(command -v zsh)" /etc/shells; then
    command -v zsh | sudo tee -a /etc/shells > /dev/null
fi

# Set Zsh as the default shell for all existing users (except system users)
for user in $(getent passwd | awk -F: '$3 >= 1000 {print $1}'); do
    sudo chsh -s "$(which zsh)" "$user"
done

# Set Zsh as the default shell for new users
sudo usermod --shell "$(which zsh)" root

# Restart shell to apply changes
exec zsh
