# Helium Linux Installer

Helium is a modern web browser (https://helium.computer), but it doesn't treat Linux as a first-class citizen. Unlike macOS and Windows, which have distribution-specific installers, Linux users are left with an AppImage that doesn't integrate well with the system. This means no `helium` command in your terminal, making it less convenient to use.

This repository aims to solve that problem by providing a set of shell scripts that will:

1. Download and install Helium for you
2. Provide a `helium` command that you can run from your shell
3. Allow you to easily update Helium when new versions are released

> **Note:** This project was inspired by [cursor-linux-installer](https://github.com/watzon/cursor-linux-installer) by watzon, which provides similar functionality for the Cursor code editor.

## Installation

You can install the Helium Linux Installer using either curl or wget. Choose the method you prefer:

### Using curl

```bash
# Install stable version (default)
curl -fsSL https://raw.githubusercontent.com/mau671/helium-linux-installer/main/install.sh | bash

# Install latest version (includes pre-releases)
curl -fsSL https://raw.githubusercontent.com/mau671/helium-linux-installer/main/install.sh | bash -s -- latest
```

### Using wget

```bash
# Install stable version (default)
wget -qO- https://raw.githubusercontent.com/mau671/helium-linux-installer/main/install.sh | bash

# Install latest version (includes pre-releases)
wget -qO- https://raw.githubusercontent.com/mau671/helium-linux-installer/main/install.sh | bash -s -- latest
```

The installation script will:

1. Download the `helium.sh` script and save it as `helium` in `~/.local/bin/`
2. Make the script executable
3. Download and install the latest version of Helium

## Uninstalling

To uninstall the Helium Linux Installer, you can run the uninstall script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mau671/helium-linux-installer/main/uninstall.sh)"
```

or

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/mau671/helium-linux-installer/main/uninstall.sh)"
```

The uninstall script will:

1. Remove the `helium` script from `~/.local/bin/`
2. Remove the Helium AppImage
3. Ask if you want to remove the Helium configuration files

## Usage

After installation, you can use the `helium` command to launch Helium or update it:

- To launch Helium: `helium`
- To update Helium: `helium --update [channel]`
  - Update to stable version (official releases only): `helium --update` or `helium --update stable`
  - Update to latest version (includes pre-releases): `helium --update latest`
- To check for updates: `helium --check [channel]`
  - Check for stable updates: `helium --check` or `helium --check stable`
  - Check for latest updates: `helium --check latest`
- To check Helium version: `helium --version` or `helium -v`
  - Shows the installed version of Helium if available
  - Returns an error if Helium is not installed or version cannot be determined
- To install/update desktop integration: `helium --install-desktop`
  - Installs or updates the desktop file and icon for Helium

## Note

If you encounter a warning that `~/.local/bin` is not in your PATH, you can add it by running:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

or add it to your shell profile (e.g., `.bashrc`, `.zshrc`, etc.):

```bash
echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
source ~/.bashrc
```

## License

This software is released under the MIT License.

## Contributing

If you find a bug or have a feature request, please open an issue on GitHub.

If you want to contribute to the project, please fork the repository and submit a pull request.
