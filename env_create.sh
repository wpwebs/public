#!/bin/bash

# Exit immediately if a command fails and treat unset variables as an error
set -euo pipefail

# Get the current folder name and define the virtual environment directory
current_folder=$(basename "$(pwd)")
venv_dir=".${current_folder}"

# Function to display messages
log() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

# Function to display errors
error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

# Check if Python is installed
if ! command -v python &>/dev/null; then
    error "Python is not installed or not in the system PATH."
    exit 1
fi

# Create the virtual environment if it does not exist
if [ ! -d "$venv_dir" ]; then
    log "Creating a virtual environment in $venv_dir..."
    python -m venv "$venv_dir"
else
    log "Virtual environment already exists in $venv_dir. Skipping creation."
fi

# Activate the virtual environment
log "Activating the virtual environment..."
# Use different activation scripts based on OS
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    source "$venv_dir/bin/activate"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    source "$venv_dir/Scripts/activate"
else
    error "Unsupported OS type: $OSTYPE"
    exit 1
fi

# Upgrade pip, setuptools, and wheel
log "Upgrading pip, setuptools, and wheel..."
python -m pip install --upgrade pip setuptools wheel

# Install dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    log "Installing dependencies from requirements.txt..."
    pip install -r requirements.txt
else
    log "No requirements.txt found. Skipping dependency installation."
fi

log "Virtual environment setup is complete in $venv_dir."
log "To activate, run: source $venv_dir/bin/activate"

source $venv_dir/bin/activate
$SHELL

exit 0
