#!/usr/bin/env bash

set -e

# URL del script principal de Helium
HELIUM_SCRIPT_URL="https://raw.githubusercontent.com/mau671/helium-linux-installer/main/helium.sh"

# Binario local del usuario
LOCAL_BIN="$HOME/.local/bin"

# Crear ~/.local/bin si no existe
mkdir -p "$LOCAL_BIN"

echo "Descargando script lanzador de Helium..."
curl -fsSL "$HELIUM_SCRIPT_URL" -o "$LOCAL_BIN/helium"

# Hacer el script ejecutable
chmod +x "$LOCAL_BIN/helium"

echo "Script 'helium' instalado en $LOCAL_BIN/helium"

# Avisar si ~/.local/bin no está en PATH
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo "Advertencia: $LOCAL_BIN no está en tu PATH."
    echo "Para agregarlo temporalmente:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo
    echo "Para agregarlo permanentemente (bash):"
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo "  source ~/.bashrc"
fi

# Ejecutar helium --update para descargar e instalar Helium
echo "Descargando e instalando Helium..."
"$LOCAL_BIN/helium" --update "$@"

echo
echo "Instalación completa. Puedes ejecutar 'helium' para iniciar el navegador."
