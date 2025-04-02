#!/bin/zsh

# in order to load "$ZSH_CUSTOM"
source ~/.zshrc

set -e

echo "Uninstalling driver..."

cargo uninstall helix-driver

echo "Driver uninstalled"

if [ -n "$ZSH_CUSTOM" ]; then
    echo "Uninstalling zsh plugin..."
    rm -rf "$ZSH_CUSTOM/plugins/helix-zsh"

    omz plugin disable helix-zsh
    echo "Uninstalled from '$ZSH_CUSTOM/plugins/helix-zsh'"
else
    echo "The driver is uninstalled and helix-zsh will not run"
    echo "However, you will need to manually remove the 'helix_zsh.zsh' file as it was not installed via the installer"
fi

echo "Installation complete!"


