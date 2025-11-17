#!/usr/bin/env bash

set -e

echo "Desinstalando Helium..."

INSTALL_DIR="${HELIUM_INSTALL_DIR:-$HOME/Applications/helium}"
HELIUM_APP="$INSTALL_DIR/helium"

LOCAL_BIN="$HOME/.local/bin"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLICATIONS_DIR="$DATA_HOME/applications"
ICON_ROOT_DIR="$DATA_HOME/icons"

# Eliminar AppImage renombrada
if [[ -f "$HELIUM_APP" ]]; then
  echo "Eliminando AppImage de Helium: $HELIUM_APP"
  rm -f "$HELIUM_APP"
else
  echo "No se encontró AppImage en $HELIUM_APP"
fi

# Eliminar archivos auxiliares de versión
if [[ -f "$INSTALL_DIR/.helium_version" ]]; then
  echo "Eliminando archivo de versión: $INSTALL_DIR/.helium_version"
  rm -f "$INSTALL_DIR/.helium_version"
fi

# Intentar eliminar el directorio si queda vacío
if [[ -d "$INSTALL_DIR" ]]; then
  rmdir "$INSTALL_DIR" 2>/dev/null || true
fi

# Eliminar script 'helium' de ~/.local/bin
if [[ -f "$LOCAL_BIN/helium" ]]; then
  echo "Eliminando script 'helium' de $LOCAL_BIN..."
  rm -f "$LOCAL_BIN/helium"
else
  echo "Script 'helium' no encontrado en $LOCAL_BIN."
fi

# Eliminar iconos de Helium
echo "Eliminando iconos de Helium..."
find "$ICON_ROOT_DIR" -type f -name "helium.png" -delete 2>/dev/null || true

# Eliminar archivo .desktop
DESKTOP_FILE="$APPLICATIONS_DIR/helium.desktop"
if [[ -f "$DESKTOP_FILE" ]]; then
  echo "Eliminando archivo desktop: $DESKTOP_FILE"
  rm -f "$DESKTOP_FILE"
fi

echo "Helium ha sido desinstalado (binario, iconos y .desktop)."

# Preguntar por configuración
read -r -p "¿Quieres eliminar también archivos de configuración (~/.config/helium* )? (y/N) " remove_config
if [[ "$remove_config" =~ ^[Yy]$ ]]; then
  echo "Eliminando posibles configuraciones de Helium en ~/.config/helium* ..."
  rm -rf "$HOME/.config/helium" \
         "$HOME/.config/helium-browser" \
         "$HOME/.config/Helium" 2>/dev/null || true
  echo "Archivos de configuración eliminados (si existían)."
else
  echo "Archivos de configuración conservados."
fi

echo "Desinstalación completa."
