#!/bin/sh

set -e  # Exit script on any error

# Update package list and install dependencies
sudo apt update && sudo apt install -y zsh git curl 

# Install Oh My Zsh (unattended)
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended

# Define the Oh My Zsh custom plugin/theme directory
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"

# Clone essential plugins and themes
git clone --quiet https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
git clone --quiet https://github.com/zsh-users/zsh-completions "${ZSH_CUSTOM}/plugins/zsh-completions"
git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
git clone --quiet https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM}/themes/powerlevel10k"

# Download and move Powerlevel10k configuration
curl -fsSL https://raw.githubusercontent.com/wpwebs/public/refs/heads/main/.p10k.zsh -o "${HOME}/.p10k.zsh"

# Ensure ~/.zshrc exists before modifying
touch "${HOME}/.zshrc"

# Append configurations to .zshrc
cat << 'EOF' | tee -a "${HOME}/.zshrc" > /dev/null

# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load plugins and theme
source $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.oh-my-zsh/custom/plugins/zsh-completions/zsh-completions.plugin.zsh
source $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $HOME/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme

# Load Powerlevel10k configuration
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh

# Start SSH agent and add key
eval "$(ssh-agent -s)"
chmod 600 $HOME/.ssh/sshkey
ssh-add $HOME/.ssh/sshkey

# Set Zsh as default shell
if ! grep -qxF "$(command -v zsh)" /etc/shells; then
    command -v zsh | sudo tee -a /etc/shells > /dev/null
fi
sudo chsh -s "$(which zsh)" "$USER"

clear
EOF

# Remove setup script (optional, only if running from a script)
rm -- "$0"

# Switch to Zsh
exec zsh
