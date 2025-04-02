# helix-zsh

Helix bindings for zsh.

ZSH contains in-built vim/emacs style bindings, and this repo is built to provide the same experience with Helix bindings. 

Requirements:

* Rust toolchain
  - Needed to build and install the driver
* Zsh
  - ...
* [Optional] (oh-my-zsh)(https://ohmyz.sh)
  - Install script will automatically configure it as a plugin


It has two components:

* [`helix_zsh.zsh`](helix_zsh.zsh)
  - This script creates the keymaps and handles input/output via the driver
* [helix-driver](helix-driver)
  - This is a rust program which spins up a hidden instance of Helix to
  - This is a different approach to other shell bindings (e.g `zsh-vi-mode`), but it means:
    - Your helix config file is respected
    - Updates to helix just require a driver rebuild rather than adding new mappings

### Known problems

* Movement to end-of-line does not work as we strip trailing newline
* Clipboard behaviour can occasionally be inconsistent (but generally works)
* Deleting single characters can cause zsh re-render - doesn't break anything but visually jarring
* Use of `coproc` causes process-id to flash on screen when driver starts
  - I haven't found a way to suppress this or a better alternative. Would love to find one
  - In certain scenarios, `terminated  _hx_driver` will show for the same reason (it is then automatically restarted)

All the shell scripts bits should be namespaced enough to prevent any problems.
Please open an issue if you find any other bugs.

# Installing & using

How to use:

> [!NOTE]
> The installer will add the plugin if oh-my-zsh is used for plugin management
> If not, you must manually place [`helix_zsh.zsh`](helix_zsh.zsh) somewhere and `source <LOCATION>` in your `.zshrc`

1. Clone
2. Run `install.sh`
3. Ensure 
4. Optionally, add this code to your powerlevel10k (`p10k.zsh`) file to get different characters for different modes:

```sh
  function prompt_hx_mode() {
    # will display '❯' for insert mode, else '❮'
    if (( _p9k__status )); then
      p10k segment -c '${${hx_mode:-main}:#hxcmd}' -f 196 -t "❯"
      p10k segment -c '${(M)hx_mode:#hxcmd}' -f 196 -t "❮"
    else
      p10k segment -c '${${hx_mode:-main}:#hxcmd}' -f 76 -t "❯"
      p10k segment -c '${(M)hx_mode:#hxcmd}' -f 76 -t "❮"
    fi
  }

  function instant_prompt_hx_mode() {
    p10k segment -f 76 -t "❯"
  }
```

And add it to your prompt elements:

```diff
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    # =========================[ Line #1 ]=========================
    # os_icon               # os identifier
    dir                     # current directory
    vcs                     # git status
    # =========================[ Line #2 ]=========================
    newline                 # \n
-    prompt_char # often also `vi_mode`
+    hx_mode
  )
```

### Uninstalling / disablings

To disable:

* If it is enabled as a oh-my-zsh plugin, simply `omz plugin disable helix-zsh`
* Else, simply comment out wherever you `source` it

To uninstall:

* [`uninstall.sh`](uninstall.sh) can be used, which simply
  - `cargo uninstall`'s the driver
  - Removes the zsh plugin if it can
