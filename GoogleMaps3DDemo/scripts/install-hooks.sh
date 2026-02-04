#!/bin/bash

# Install git hooks for the AgGuidance project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.githooks"
GIT_HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks..."

# Ensure .git/hooks directory exists
mkdir -p "$GIT_HOOKS_DIR"

# Install pre-push hook
if [ -f "$HOOKS_DIR/pre-push" ]; then
    cp "$HOOKS_DIR/pre-push" "$GIT_HOOKS_DIR/pre-push"
    chmod +x "$GIT_HOOKS_DIR/pre-push"
    echo "✓ Installed pre-push hook"
else
    echo "✗ pre-push hook not found in $HOOKS_DIR"
    exit 1
fi

# Optionally configure git to use the hooks directory directly
# This is an alternative approach that doesn't require copying
# git config core.hooksPath .githooks

echo ""
echo "Git hooks installed successfully!"
echo ""
echo "Hooks will run automatically on git push."
echo "To bypass hooks (not recommended): git push --no-verify"
