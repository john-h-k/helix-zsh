#!/bin/zsh

if [[ "$ZSH_EVAL_CONTEXT" != *:file ]]; then
  echo "This script must be sourced, not executed."
  return 1 2>/dev/null || exit 1
fi

_hx_zsh_install() {
    echo "Installing driver..."

    local flags=()
    if [[ -n "$HELIX_ZSH_HELIX_REPO_USER" ]]; then
        echo "Using helix repo 'https://github.com/$HELIX_ZSH_HELIX_REPO_USER/helix'"
        local deps=(
            helix-core
            helix-view
            helix-loader
            helix-term
            helix-event
        )

        for dep in "${deps[@]}"; do
            flags+=(
                --config
                "patch.'https://github.com/helix-editor/helix'.'$dep'.git = 'https://github.com/$HELIX_ZSH_HELIX_REPO_USER/helix.git'"
            )
        done
    else
        echo "Using default helix repo 'https://github.com/helix-editor/helix'"
    fi

    if ! cargo install "${flags[@]}" --path "$(dirname "$0")/helix-driver"; then
        echo "driver install failed!"
        return 1
    fi

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
}

_hx_zsh_install

unset -f _hx_zsh_install
