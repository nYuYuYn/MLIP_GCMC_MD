#!/bin/bash
set -euo pipefail

REPO_DIR="/K/yy276937/MLIP_GCMC_MD_PBA"

cd "$REPO_DIR" || {
    echo "Repository directory not found."
    exit 1
}

# Check that we are working on the intended branch.
branch=$(git branch --show-current)

if [[ "$branch" != "main" ]]; then
    echo "Current branch is '$branch'. Switch to main before running."
    exit 1
fi

# Use HTTPS because SSH port 22 is unavailable.
git remote set-url origin \
    https://github.com/nYuYuYn/MLIP_GCMC_MD.git

echo "Current repository status:"
git status --short

# Stage modifications and deletions of tracked files.
# Untracked files and the nested repository are excluded.
git add -A -- . ':!MLIP_GCMC_MD'

if ! git diff --cached --quiet; then
    echo
    echo "Changes to be committed:"
    git diff --cached --stat

    read -r -p "Enter commit message: " commit_msg

    if [[ -z "${commit_msg//[[:space:]]/}" ]]; then
        echo "Commit message is empty. Aborting."
        exit 1
    fi

    git commit -m "$commit_msg"
else
    echo "No staged changes to commit."
fi

echo "Fetching GitHub changes..."
git -c credential.helper= fetch origin

echo "Merging GitHub changes..."
# Allows the initial merge if local and GitHub histories
# were initialized independently. Also works for normal merges.
if ! git merge --no-edit --allow-unrelated-histories origin/main; then
    echo "Merge failed. Inspect 'git status' and resolve any conflicts."
    echo "Nothing has been pushed."
    exit 1
fi

echo "Pushing to GitHub..."
git -c credential.helper= push --set-upstream origin main

echo "Update complete!"
