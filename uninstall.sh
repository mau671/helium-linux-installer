#!/usr/bin/env bash

set -e

echo "Uninstalling Helium..."

# New installation paths (compatible with new installer)
INSTALL_DIR="${HELIUM_INSTALL_DIR:-$HOME/.local/share/helium}"
HELIUM_APP="$INSTALL_DIR/helium.AppImage"

LOCAL_BIN="$HOME/.local/bin"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLICATIONS_DIR="$DATA_HOME/applications"
ICON_ROOT_DIR="$DATA_HOME/icons"

echo "Using installation directory: $INSTALL_DIR"

# Remove AppImage
if [[ -f "$HELIUM_APP" ]]; then
  echo "Removing Helium AppImage: $HELIUM_APP"
  rm -f "$HELIUM_APP"
else
  echo "AppImage not found at $HELIUM_APP"
fi

# Remove version file
if [[ -f "$INSTALL_DIR/.helium_version" ]]; then
  echo "Removing version file: $INSTALL_DIR/.helium_version"
  rm -f "$INSTALL_DIR/.helium_version"
fi

# Try to remove the directory if it's empty
if [[ -d "$INSTALL_DIR" ]]; then
  rmdir "$INSTALL_DIR" 2>/dev/null || true
fi

# Remove 'helium' script from ~/.local/bin
if [[ -f "$LOCAL_BIN/helium" ]]; then
  echo "Removing 'helium' script from $LOCAL_BIN..."
  rm -f "$LOCAL_BIN/helium"
else
  echo "'helium' script not found in $LOCAL_BIN."
fi

# Remove Helium icons
echo "Removing Helium icons..."
find "$ICON_ROOT_DIR" -type f -name "helium.png" -delete 2>/dev/null || true

# Remove .desktop file
DESKTOP_FILE="$APPLICATIONS_DIR/helium.desktop"
if [[ -f "$DESKTOP_FILE" ]]; then
  echo "Removing desktop file: $DESKTOP_FILE"
  rm -f "$DESKTOP_FILE"
fi

# Remove AppArmor profile if it exists
APPARMOR_PROFILE="/etc/apparmor.d/helium"
if [[ -f "$APPARMOR_PROFILE" ]]; then
  echo "Removing AppArmor profile: $APPARMOR_PROFILE"
  sudo rm -f "$APPARMOR_PROFILE"
  
  # Reload AppArmor if available
  if command -v apparmor_parser >/dev/null 2>&1; then
    echo "Reloading AppArmor..."
    sudo apparmor_parser -R "$APPARMOR_PROFILE" 2>/dev/null || true
  fi
fi

echo "Helium has been uninstalled (binary, icons, .desktop, and AppArmor)."

# Ask about configuration
read -r -p "Do you also want to remove configuration files (~/.config/helium*)? (y/N) " remove_config
if [[ "$remove_config" =~ ^[Yy]$ ]]; then
  echo "Removing possible Helium configurations in ~/.config..."
  rm -rf "$HOME/.config/helium" \
         "$HOME/.config/helium-browser" \
         "$HOME/.config/Helium" 2>/dev/null || true
  echo "Configuration files removed (if they existed)."
else
  echo "Configuration files preserved."
fi

echo "Uninstallation complete."
