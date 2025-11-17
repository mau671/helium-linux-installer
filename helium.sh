#!/usr/bin/env bash

set -e

# ================
# Configuración
# ================

HELIUM_REPO="imputnet/helium-linux"

# Carpeta de instalación de la AppImage (puedes sobreescribir con HELIUM_INSTALL_DIR)
INSTALL_DIR="${HELIUM_INSTALL_DIR:-$HOME/Applications/helium}"
HELIUM_APP="$INSTALL_DIR/helium"
VERSION_FILE="$INSTALL_DIR/.helium_version"

# Dónde se instala el comando 'helium'
LOCAL_BIN="$HOME/.local/bin"

# Icono oficial e .desktop oficial
ICON_URL="https://raw.githubusercontent.com/imputnet/helium/main/resources/branding/app_icon/raw.png"
DESKTOP_URL="https://raw.githubusercontent.com/imputnet/helium-linux/main/package/helium.desktop"

# Rutas para integración de escritorio
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLICATIONS_DIR="$DATA_HOME/applications"
ICON_ROOT_DIR="$DATA_HOME/icons"
ICON_SIZE="512"
ICON_THEME_DIR="$ICON_ROOT_DIR/hicolor/${ICON_SIZE}x${ICON_SIZE}/apps"
ICON_NAME="helium"
ICON_FILE="$ICON_THEME_DIR/${ICON_NAME}.png"
DESKTOP_FILE="$APPLICATIONS_DIR/helium.desktop"

# ================
# Utilidades
# ================

ensure_deps() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: se requiere 'curl' para usar este script." >&2
    exit 1
  fi
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
      echo "Arquitectura no soportada: $arch (solo x86_64 y arm64)." >&2
      exit 1
      ;;
  esac
}

normalize_track() {
  # stable (por defecto) o latest (incluye pre-releases)
  case "$1" in
    ""|stable|release) echo "stable" ;;
    latest|prerelease|edge) echo "latest" ;;
    *)
      echo "stable"
      ;;
  esac
}

supports_sort_v() {
  sort -V </dev/null >/dev/null 2>&1
}

# 0 si remote > local, 1 si no hay nada nuevo
is_remote_newer() {
  local local_ver="$1"
  local remote_ver="$2"

  # Si no hay versión local, remote es "nuevo"
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

# Obtiene URL y versión desde la API de GitHub
get_download_info() {
  local track
  track="$(normalize_track "$1")"

  ensure_deps

  local api_url tmp file_arch download_url version

  if [[ "$track" == "latest" ]]; then
    # Lista de releases (incluso pre-releases)
    api_url="https://api.github.com/repos/${HELIUM_REPO}/releases?per_page=5"
  else
    # Solo último release estable
    api_url="https://api.github.com/repos/${HELIUM_REPO}/releases/latest"
  fi

  tmp="$(mktemp)"

  if ! curl -fsSL "$api_url" -o "$tmp"; then
    echo "ERROR=No se pudo obtener la información de releases desde GitHub." >&2
    rm -f "$tmp"
    return 1
  fi

  case "$(get_arch)" in
    x86_64) file_arch="x86_64" ;;
    arm64) file_arch="arm64" ;;
  esac

  # Buscar la primera URL de AppImage para nuestra arquitectura
  download_url=$(grep -o "https://[^\"]*${file_arch}.AppImage" "$tmp" | head -n1 || true)

  if [[ -z "$download_url" ]]; then
    echo "ERROR=No se encontró un AppImage para la arquitectura ${file_arch} en los releases." >&2
    rm -f "$tmp"
    return 1
  fi

  # Intentar obtener versión desde tag_name
  version=$(grep -m1 '"tag_name"' "$tmp" | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)

  # Fallback: parsear desde el nombre del archivo
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
# Icono y .desktop
# ================

install_icon_and_desktop() {
  ensure_deps

  mkdir -p "$ICON_THEME_DIR" "$APPLICATIONS_DIR"

  # Icono oficial
  if [[ ! -f "$ICON_FILE" ]]; then
    echo "Descargando icono oficial de Helium..."
    if ! curl -fsSL "$ICON_URL" -o "$ICON_FILE"; then
      echo "Advertencia: no se pudo descargar el icono desde $ICON_URL" >&2
    fi
  fi

  # .desktop oficial
  echo "Instalando archivo desktop de Helium..."
  if ! curl -fsSL "$DESKTOP_URL" -o "$DESKTOP_FILE"; then
    echo "Advertencia: no se pudo descargar helium.desktop desde $DESKTOP_URL, creando uno mínimo..." >&2
    cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=Helium
GenericName=Web Browser
Comment=Access the Internet
Exec=${LOCAL_BIN}/helium %U
StartupNotify=true
StartupWMClass=helium
Terminal=false
Icon=helium
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=${LOCAL_BIN}/helium

[Desktop Action new-private-window]
Name=New Incognito Window
Exec=${LOCAL_BIN}/helium --incognito
EOF
  else
    # Ajustar Exec para usar nuestro script en lugar de "chromium"
    local bin_path="${LOCAL_BIN}/helium"
    sed -i "s|^Exec=chromium %U|Exec=${bin_path} %U|" "$DESKTOP_FILE" 2>/dev/null || true
    sed -i "s|^Exec=chromium --incognito|Exec=${bin_path} --incognito|" "$DESKTOP_FILE" 2>/dev/null || true
    sed -i "s|^Exec=chromium$|Exec=${bin_path}|" "$DESKTOP_FILE" 2>/dev/null || true
  fi

  # Actualizar base de datos de .desktop e iconos (si existen las herramientas)
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache "$ICON_ROOT_DIR/hicolor" >/dev/null 2>&1 || true
  fi

  echo "Integración de escritorio lista: $DESKTOP_FILE"
}

# ================
# Instalación / actualización
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
    echo "Helium ya está actualizado (versión ${current}, canal ${track})."
    return 0
  fi

  echo "Descargando Helium ${version} (canal ${track})..."
  local tmp
  tmp="$(mktemp)"

  if ! curl -fL "$url" -o "$tmp"; then
    echo "Error al descargar Helium desde $url" >&2
    rm -f "$tmp"
    return 1
  fi

  chmod +x "$tmp"
  mv "$tmp" "$HELIUM_APP"
  chmod +x "$HELIUM_APP"
  echo "$version" >"$VERSION_FILE"

  echo "Helium ${version} instalado en $HELIUM_APP"

  # Asegurar integración con el escritorio
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
    echo "Helium no está instalado. Última versión disponible (${track}): ${version}"
    return 1
  fi

  if is_remote_newer "$current" "$version"; then
    echo "Hay una actualización disponible (${track}): ${current} → ${version}"
    return 0
  else
    echo "Ya estás en la última versión (${current}, canal ${track})."
    return 1
  fi
}

launch_helium() {
  ensure_install_dir

  if [[ ! -x "$HELIUM_APP" ]]; then
    echo "Helium no está instalado todavía. Instalando versión estable..."
    update_helium "stable"
  fi

  # Ejecutar la AppImage renombrada como 'helium', pasando todos los argumentos
  exec "$HELIUM_APP" "$@"
}

show_version() {
  if [[ -f "$VERSION_FILE" ]]; then
    local v
    v="$(cat "$VERSION_FILE")"
    if [[ -n "$v" ]]; then
      echo "Helium instalado (versión: ${v})"
      return 0
    fi
  fi
  echo "Helium no está instalado o no se encontró la información de versión."
  return 1
}

print_usage() {
  cat <<EOF
Uso:
  helium                    Lanza Helium (instala si es necesario).
  helium --update [canal]   Descarga/actualiza Helium.
                            canal: stable (por defecto) o latest (incluye pre-releases).
  helium --check [canal]    Comprueba si hay actualizaciones disponibles.
  helium --version, -v      Muestra la versión instalada (si existe).
  helium --install-desktop  Fuerza la creación/actualización del .desktop e icono.
  helium --help, -h         Muestra esta ayuda.

Rutas usadas:
  AppImage:      $HELIUM_APP
  Versión:       $VERSION_FILE
  Desktop file:  $DESKTOP_FILE
  Icono:         $ICON_FILE
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
    update_helium "${1:-stable}"
    ;;
  --check)
    shift
    check_updates_only "${1:-stable}"
    ;;
  --install-desktop)
    install_icon_and_desktop
    ;;
  --help|-h)
    print_usage
    ;;
  *)
    # Cualquier otra cosa (incluido sin argumentos) se pasa al binario Helium
    launch_helium "$@"
    ;;
esac

exit $?
