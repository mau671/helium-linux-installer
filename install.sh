#!/usr/bin/env bash

set -e

# URL of the main Helium script
HELIUM_SCRIPT_URL="https://raw.githubusercontent.com/mau671/helium-linux-installer/main/helium.sh"

# User's local binary directory
LOCAL_BIN="$HOME/.local/bin"

# Create ~/.local/bin if it doesn't exist
mkdir -p "$LOCAL_BIN"

echo "Downloading Helium launcher script..."
curl -fsSL "$HELIUM_SCRIPT_URL" -o "$LOCAL_BIN/helium"

# Make the script executable
chmod +x "$LOCAL_BIN/helium"

echo "Script 'helium' installed at $LOCAL_BIN/helium"

# Warn if ~/.local/bin is not in PATH
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo "Warning: $LOCAL_BIN is not in your PATH."
    echo "To add it temporarily:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo
    echo "To add it permanently (bash):"
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo "  source ~/.bashrc"
fi

# Execute helium --update to download and install Helium
echo "Downloading and installing Helium..."
"$LOCAL_BIN/helium" --update "$@"

echo
echo "Installation complete. You can run 'helium' to start the browser."
