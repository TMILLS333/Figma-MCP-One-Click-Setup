#!/usr/bin/env bash
# Double-clickable launcher for macOS.
# Runs setup.sh from the same folder this file lives in.

# Get the directory of this script (handles spaces, symlinks, and being double-clicked from Finder)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$DIR" || exit 1

# Make sure setup.sh is executable
chmod +x "$DIR/setup.sh" 2>/dev/null || true

# Run it
bash "$DIR/setup.sh"

# Keep the Terminal window open so the user can read the output
echo
echo "Press Return to close this window."
read -r
