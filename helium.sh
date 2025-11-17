#!/usr/bin/env bash

set -e

# ================
# Configuration
# ================

HELIUM_REPO="imputnet/helium-linux"

# AppImage installation directory (override with HELIUM_INSTALL_DIR)
INSTALL_DIR="${HELIUM_INSTALL_DIR:-$HOME/.local/share/helium}"
HELIUM_APP="$INSTALL_DIR/helium.AppImage"
VERSION_FILE="$INSTALL_DIR/.helium_version"

# Where the 'helium' command is installed
LOCAL_BIN="$HOME/.local/bin"

# Official icon and .desktop file
ICON_URL="https://raw.githubusercontent.com/imputnet/helium/main/resources/branding/app_icon/raw.png"
DESKTOP_URL="https://raw.githubusercontent.com/imputnet/helium-linux/main/package/helium.desktop"

# Desktop integration paths
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLICATIONS_DIR="$DATA_HOME/applications"
ICON_ROOT_DIR="$DATA_HOME/icons"
ICON_SIZE="512"
ICON_THEME_DIR="$ICON_ROOT_DIR/hicolor/${ICON_SIZE}x${ICON_SIZE}/apps"
ICON_NAME="helium"
ICON_FILE="$ICON_THEME_DIR/${ICON_NAME}.png"
DESKTOP_FILE="$APPLICATIONS_DIR/helium.desktop"

# ================
# Utilities
# ================

ensure_deps() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: 'curl' is required to use this script." >&2
    exit 1
  fi
}

configure_apparmor() {
  # Configure AppArmor to allow userns for Helium
  # This is necessary on distributions that disable unprivileged userns (Ubuntu 23.10+, etc.)
  
  if ! command -v apparmor_parser >/dev/null 2>&1; then
    # AppArmor is not available, no need to configure
    return 0
  fi
  
  local profile_file="/etc/apparmor.d/helium"
  local profile_content="abi <abi/4.0>,
include <tunables/global>

profile helium $HELIUM_APP flags=(unconfined) {
  userns,
  include if exists <local/helium>
}"
  
  # Check if the profile already exists and is identical
  if [[ -f "$profile_file" ]]; then
    local existing_content
    existing_content="$(cat "$profile_file")"
    if [[ "$existing_content" == "$profile_content" ]]; then
      # Profile already exists and is equal, do nothing
      return 0
    fi
  fi
  
  # Create/update the AppArmor profile
  echo "Configuring AppArmor profile for Helium..."
  echo "$profile_content" | sudo tee "$profile_file" >/dev/null
  
  # Load/reload the profile
  sudo apparmor_parser -r "$profile_file" 2>/dev/null || true
  
  echo "AppArmor profile configured successfully."
}

ensure_install_dir() {
  mkdir -p "$INSTALL_DIR"
}

get_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      echo "Unsupported architecture: $arch (only x86_64 and arm64 are supported)." >&2
      exit 1
      ;;
  esac
}

normalize_track() {
  # stable (default, official releases only) or latest (includes pre-releases)
  case "$1" in
    ""|stable|release) echo "stable" ;;
    latest|prerelease|edge) echo "latest" ;;
    *)
      # Default to stable if the track is not recognized
      echo "stable"
      ;;
  esac
}

supports_sort_v() {
  sort -V </dev/null >/dev/null 2>&1
}

# Returns 0 if remote > local, 1 if there's nothing new
is_remote_newer() {
  local local_ver="$1"
  local remote_ver="$2"

  # If there's no local version, remote is "new"
  if [[ -z "$local_ver" ]]; then
    return 0
  fi

  if [[ "$local_ver" == "$remote_ver" ]]; then
    return 1
  fi

  local winner
  if supports_sort_v; then
    winner=$(printf "%s\n%s\n" "$local_ver" "$remote_ver" | sort -V | tail -n1)
  else
    winner=$(printf "%s\n%s\n" "$local_ver" "$remote_ver" | sort | tail -n1)
  fi

  [[ "$winner" == "$remote_ver" ]]
}

# Get URL and version from GitHub API
get_download_info() {
  local track
  track="$(normalize_track "$1")"

  ensure_deps

  local api_url tmp file_arch download_url version

  if [[ "$track" == "latest" ]]; then
    # List of releases (including pre-releases)
    api_url="https://api.github.com/repos/${HELIUM_REPO}/releases?per_page=5"
  else
    # Latest stable release only
    api_url="https://api.github.com/repos/${HELIUM_REPO}/releases/latest"
  fi

  tmp="$(mktemp)"

  if ! curl -fsSL "$api_url" -o "$tmp"; then
    echo "ERROR=Failed to get release information from GitHub." >&2
    rm -f "$tmp"
    return 1
  fi

  case "$(get_arch)" in
    x86_64) file_arch="x86_64" ;;
    arm64) file_arch="arm64" ;;
  esac

  # Search for the first AppImage URL for our architecture
  download_url=$(grep -o "https://[^\"]*${file_arch}.AppImage" "$tmp" | head -n1 || true)

  if [[ -z "$download_url" ]]; then
    echo "ERROR=No AppImage found for architecture ${file_arch} in releases." >&2
    rm -f "$tmp"
    return 1
  fi

  # Try to get version from tag_name
  version=$(grep -m1 '"tag_name"' "$tmp" | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)

  # Fallback: parse from filename
  if [[ -z "$version" ]]; then
    version=$(basename "$download_url" | sed -E 's/helium-([0-9.]+)-.*\.AppImage/\1/' || true)
  fi

  rm -f "$tmp"

  if [[ -z "$version" ]]; then
    version="unknown"
  fi

  echo "URL=$download_url"
  echo "VERSION=$version"
  echo "TRACK=$track"
  return 0
}

# ================
# Icon and .desktop
# ================

install_icon_and_desktop() {
  ensure_deps

  mkdir -p "$ICON_THEME_DIR" "$APPLICATIONS_DIR"

  # Official icon
  if [[ ! -f "$ICON_FILE" ]]; then
    echo "Downloading official Helium icon..."
    if ! curl -fsSL "$ICON_URL" -o "$ICON_FILE"; then
      echo "Warning: failed to download icon from $ICON_URL" >&2
    fi
  fi

  # Official .desktop file
  echo "Installing Helium desktop file..."
  # Use absolute path to ensure it works from the desktop
  local bin_path="${LOCAL_BIN}/helium"
  # Ensure the path is absolute
  if [[ "$bin_path" != /* ]]; then
    bin_path="$HOME/.local/bin/helium"
  fi
  
  # Use absolute path for the icon
  local icon_path="$ICON_FILE"
  
  if ! curl -fsSL "$DESKTOP_URL" -o "$DESKTOP_FILE"; then
    echo "Warning: failed to download helium.desktop from $DESKTOP_URL, creating minimal one..." >&2
    cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=Helium
GenericName=Web Browser
Comment=Access the Internet
Exec=${bin_path} %U
StartupNotify=true
StartupWMClass=helium
Terminal=false
Icon=${icon_path}
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=${bin_path}

[Desktop Action new-private-window]
Name=New Incognito Window
Exec=${bin_path} --incognito
EOF
  else
    # Replace ALL Exec lines that contain chromium
    # Use sed to replace all occurrences in a simple and robust way
    sed -i "s|^Exec=chromium|Exec=${bin_path}|g" "$DESKTOP_FILE" 2>/dev/null || true
    
    # Ensure the main Exec line has %U if it has no arguments
    if grep -q "^Exec=${bin_path}$" "$DESKTOP_FILE" 2>/dev/null; then
      sed -i "s|^Exec=${bin_path}$|Exec=${bin_path} %U|" "$DESKTOP_FILE" 2>/dev/null || true
    fi
    
    # Replace the icon with the absolute path
    if ! grep -q "^Icon=" "$DESKTOP_FILE" 2>/dev/null; then
      # Find the Name line and add Icon after it
      sed -i "/^Name=Helium/a Icon=${icon_path}" "$DESKTOP_FILE" 2>/dev/null || true
    else
      # Replace any existing icon with the absolute path
      sed -i "s|^Icon=.*|Icon=${icon_path}|" "$DESKTOP_FILE" 2>/dev/null || true
    fi
  fi

  # Update .desktop and icon database (if the tools exist)
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache "$ICON_ROOT_DIR/hicolor" >/dev/null 2>&1 || true
  fi

  echo "Desktop integration ready: $DESKTOP_FILE"
}

# ================
# Installation / Update
# ================

update_helium() {
  ensure_install_dir
  ensure_deps

  local track info url version current

  track="$(normalize_track "$1")"

  if [[ -f "$VERSION_FILE" ]]; then
    current="$(cat "$VERSION_FILE")"
  else
    current=""
  fi

  info="$(get_download_info "$track" || true)"

  if echo "$info" | grep -q '^ERROR='; then
    echo "$info" | sed 's/^ERROR=//'
    return 1
  fi

  url="$(echo "$info" | sed -n 's/^URL=//p')"
  version="$(echo "$info" | sed -n 's/^VERSION=//p')"

  if [[ -n "$current" ]] && ! is_remote_newer "$current" "$version"; then
    echo "Helium is already up to date (version ${current}, channel ${track})."
    return 0
  fi

  echo "Downloading Helium ${version} (channel ${track})..."
  local tmp
  tmp="$(mktemp)"

  if ! curl -fL "$url" -o "$tmp"; then
    echo "Error downloading Helium from $url" >&2
    rm -f "$tmp"
    return 1
  fi

  chmod +x "$tmp"
  mv "$tmp" "$HELIUM_APP"
  chmod +x "$HELIUM_APP"
  echo "$version" >"$VERSION_FILE"

  echo "Helium ${version} installed at $HELIUM_APP"

  # Configure AppArmor if necessary (for systems with unprivileged userns disabled)
  configure_apparmor

  # Ensure desktop integration
  install_icon_and_desktop
}

check_updates_only() {
  ensure_deps

  local track info version current
  track="$(normalize_track "$1")"

  if [[ -f "$VERSION_FILE" ]]; then
    current="$(cat "$VERSION_FILE")"
  else
    current=""
  fi

  info="$(get_download_info "$track" || true)"

  if echo "$info" | grep -q '^ERROR='; then
    echo "$info" | sed 's/^ERROR=//'
    return 1
  fi

  version="$(echo "$info" | sed -n 's/^VERSION=//p')"

  if [[ -z "$current" ]]; then
    echo "Helium is not installed. Latest available version (${track}): ${version}"
    return 1
  fi

  if is_remote_newer "$current" "$version"; then
    echo "An update is available (${track}): ${current} → ${version}"
    return 0
  else
    echo "You are on the latest version (${current}, channel ${track})."
    return 1
  fi
}

launch_helium() {
  ensure_install_dir

  if [[ ! -x "$HELIUM_APP" ]]; then
    echo "Helium is not installed yet. Installing stable version..."
    update_helium "stable"
  fi

  # Check if AppArmor needs to be configured on first run
  # (if the AppImage fails due to sandbox, try to configure AppArmor)
  # Note: This is a security check for Ubuntu 23.10+ systems
  if [[ -f "$HELIUM_APP" ]]; then
    # Try to detect if AppArmor is blocking the AppImage
    local apparmor_profile="/etc/apparmor.d/helium"
    if [[ ! -f "$apparmor_profile" ]] && command -v apparmor_parser >/dev/null 2>&1; then
      # AppArmor is available but profile is not configured, try to configure
      configure_apparmor
    fi
  fi

  # Execute the AppImage directly as a simple wrapper
  # According to the GitHub issue solution, executing the AppImage directly from a simple wrapper
  # helps resolve sandbox issues. We use exec to completely replace the current process.
  # The AppImage must be named helium.AppImage and execute directly without bash script interference.
  exec "$HELIUM_APP" "$@"
}

show_version() {
  if [[ -f "$VERSION_FILE" ]]; then
    local v
    v="$(cat "$VERSION_FILE")"
    if [[ -n "$v" ]]; then
      echo "Helium installed (version: ${v})"
      return 0
    fi
  fi
  echo "Helium is not installed or version information could not be found."
  return 1
}

print_usage() {
  cat <<EOF
Usage:
  helium                       Launch Helium (install if necessary).
  helium --update [channel]    Download/update Helium.
                               channel: stable (default, official releases only) or latest (includes pre-releases).
                               --update and --update stable are equivalent.
  helium --check [channel]     Check for available updates.
  helium --version, -v         Show the installed version (if available).
  helium --install-desktop     Force creation/update of .desktop file and icon.
  helium --setup-apparmor      Configure the AppArmor profile for Helium (if necessary).
  helium --help, -h            Show this help.

Paths used:
  AppImage:      $HELIUM_APP
  Version:       $VERSION_FILE
  Desktop file:  $DESKTOP_FILE
  Icon:          $ICON_FILE
  AppArmor:      /etc/apparmor.d/helium
EOF
}

# ================
# CLI
# ================

cmd="${1:-}"

case "$cmd" in
  --version|-v)
    show_version
    ;;
  --update)
    shift
    # --update without arguments is equivalent to --update stable
    track="${1:-stable}"
    update_helium "$track"
    ;;
  --check)
    shift
    check_updates_only "${1:-stable}"
    ;;
  --install-desktop)
    install_icon_and_desktop
    ;;
  --setup-apparmor)
    configure_apparmor
    ;;
  --help|-h)
    print_usage
    ;;
  *)
    # Anything else (including no arguments) is passed to the Helium binary
    launch_helium "$@"
    ;;
esac

exit $?
