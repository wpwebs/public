#!/bin/bash
# repo_init: Initializes a new repository by downloading a base .gitignore,
# creating a GitHub repository, initializing a local repo, and adding a collaborator.
#
# Usage:
#   repo_init [repository_name] [github_user]
#
# Default values:
#   repository_name = basename of the current directory
#   github_user     = "wpwebs"
#
# Make sure you’re logged in to 1Password (op CLI) before running this script.
# For macOS users: if your find command does not support -printf, see the alternative below.
#
# To install this script as a command:
#   sudo ln -s /path/to/repo_init.sh /usr/local/bin/repo_init
#

set -euo pipefail

# -----------------------------------------------------------------------------
# Step 1. Download the base .gitignore and append hidden files/folders
# -----------------------------------------------------------------------------
echo "Downloading base .gitignore and appending hidden files/folders..."
curl -sSf -o .gitignore https://raw.githubusercontent.com/wpwebs/public/refs/heads/main/.gitignore && \
find . -mindepth 1 -maxdepth 1 -name ".*" \
  ! -name '.' ! -name '..' ! -name '.git' ! -name '.gitignore' \
  -exec basename {} \; | sort -u >> .gitignore

# -----------------------------------------------------------------------------
# Step 2. Set default parameters
# -----------------------------------------------------------------------------
repository_name=${1:-$(basename "$(pwd)")}
github_user=${2:-"wpwebs"}

# -----------------------------------------------------------------------------
# Step 3. Retrieve credentials and keys from 1Password
# -----------------------------------------------------------------------------
echo "Retrieving GitHub credentials from 1Password..."
github_username=$(op read "op://dev/github_${github_user}/username") || { echo "Failed to retrieve GitHub username from 1Password"; exit 1; }
github_email=$(op read "op://dev/github_${github_user}/email") || { echo "Failed to retrieve GitHub email from 1Password"; exit 1; }
app_token=$(op read "op://dev/github_${github_user}/admin_token") || { echo "Failed to retrieve App Token from 1Password"; exit 1; }

# -----------------------------------------------------------------------------
# Step 4. Select SSH key and remote URL based on username
# -----------------------------------------------------------------------------
ssh_key_path="op://dev/${github_username}/private key"
remote_url="git@${github_username}:${github_username}/${repository_name}.git"

echo "Retrieving SSH key from 1Password..."
op read "$ssh_key_path" > /tmp/my_ssh_key || { echo "Failed to retrieve SSH key from 1Password"; exit 1; }

# -----------------------------------------------------------------------------
# Step 5. Start the ssh-agent and add the key
# -----------------------------------------------------------------------------
echo "Starting ssh-agent and adding the SSH key..."
eval "$(ssh-agent -s)"
chmod 600 /tmp/my_ssh_key
ssh-add /tmp/my_ssh_key || { echo "Failed to add SSH key to the ssh-agent"; rm /tmp/my_ssh_key; exit 1; }
rm /tmp/my_ssh_key

# -----------------------------------------------------------------------------
# Step 6. Create a new repository on GitHub
# -----------------------------------------------------------------------------
echo "Creating repository '$repository_name' on GitHub..."
# Capture both response body and HTTP status code
create_response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: token $app_token" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$repository_name\"}" \
    https://api.github.com/user/repos)

# Separate HTTP code and response body
http_code=$(echo "$create_response" | tail -n1)
response_body=$(echo "$create_response" | sed '$d')

if [ "$http_code" -ne 201 ]; then
    echo "Failed to create repository on GitHub: HTTP status code $http_code"
    echo "Response: $response_body"
    exit 1
else
    echo "Repository '$repository_name' created successfully on GitHub."
fi

# -----------------------------------------------------------------------------
# Step 7. Initialize a new local git repository and configure user details
# -----------------------------------------------------------------------------
echo "Initializing local git repository..."
rm -rf .git
git init

current_name=$(git config user.name || true)
current_email=$(git config user.email || true)
if [ -z "$current_name" ]; then
    git config user.name "$github_username"
    echo "Configured git user.name as $github_username"
fi
if [ -z "$current_email" ]; then
    git config user.email "$github_email"
    echo "Configured git user.email as $github_email"
fi

# -----------------------------------------------------------------------------
# Step 8. Add all files, commit, and push to GitHub
# -----------------------------------------------------------------------------
echo "Adding files and committing initial changes..."
git add .
git commit -m "Initial repository setup"

git remote add origin "$remote_url"
echo "Pushing changes to GitHub..."
current_branch=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch is: $current_branch"
git push -u origin "$current_branch"

echo "Repository $remote_url was created and pushed successfully."

# -----------------------------------------------------------------------------
# Step 9. Optionally add a collaborator if the GitHub user is not 'henrysimonfamily'
# -----------------------------------------------------------------------------
if [ "$github_username" != "henrysimonfamily" ]; then
    collaborator_username="henrysimonfamily"
    permission="push"
    echo "Adding collaborator '$collaborator_username' to the repository..."
    collab_response=$(curl -s -w "\n%{http_code}" -X PUT \
         -H "Authorization: token $app_token" \
         -H "Content-Type: application/json" \
         -d "{\"permission\": \"$permission\"}" \
         https://api.github.com/repos/${github_username}/${repository_name}/collaborators/${collaborator_username})
    
    collab_http_code=$(echo "$collab_response" | tail -n1)
    collab_response_body=$(echo "$collab_response" | sed '$d')
    
    # Accept both 201 (invitation created) and 204 (user already a collaborator) as success
    if [ "$collab_http_code" -ne 201 ] && [ "$collab_http_code" -ne 204 ]; then
        echo "Failed to add collaborator: HTTP status code $collab_http_code"
        echo "Response: $collab_response_body"
        exit 1
    else
        echo "Collaborator '$collaborator_username' added successfully."
    fi
fi
