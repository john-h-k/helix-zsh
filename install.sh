#!/bin/zsh

source ~/.zshrc

set -e

echo "Installing driver..."

cd helix-driver
cargo install --path .
cd ..

echo "Driver installed"

if [ -n "$ZSH_CUSTOM" ]; then
    echo "Installing zsh plugin..."
    mkdir -p "$ZSH_CUSTOM/plugins/helix-zsh"

    cp helix_zsh.zsh "$ZSH_CUSTOM/plugins/helix-zsh/helix-zsh.plugin.zsh"

    echo "Installed as zsh plugin 'helix-zsh'. Run 'omz plugin enable helix-zsh' to enable"
fi

echo "Installation complete!"

