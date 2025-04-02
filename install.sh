#!/bin/zsh

if [[ "$ZSH_EVAL_CONTEXT" != *:file ]]; then
  echo "This script must be sourced, not executed."
  return 1 2>/dev/null || exit 1
fi

echo "Installing driver..."

cargo install --path "$(dirname "$0")/helix-driver"

echo "Driver installed"

if [ -n "$ZSH_CUSTOM" ]; then
    echo "Installing zsh plugin..."
    mkdir -p "$ZSH_CUSTOM/plugins/helix-zsh"

    cp helix_zsh.zsh "$ZSH_CUSTOM/plugins/helix-zsh/helix-zsh.plugin.zsh"

    omz plugin enable helix-zsh
    echo "Installed as zsh plugin 'helix-zsh'"
else
    echo "The '\$ZSH_CUSTOM' variable could not be found"
    echo "Manually place the 'helix_zsh.zsh' file where you would like it, and 'source <PATH>' it within your '.zshrc' file"
fi

echo "Installation complete!"

