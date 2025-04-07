# helix-zsh

Helix bindings for zsh.

ZSH contains in-built vim/emacs style bindings, and this repo is built to provide the same experience with Helix bindings. Unlike other implementations,it respects your Helix config, custom keybindings, and automatically incorporates new Helix features.

![Example usage](./assets/example.gif)

Requirements:

* Rust toolchain
  - Needed to build and install the driver
* Zsh
  - ...
* [Optional] [oh-my-zsh](https://ohmyz.sh)
  - Install script will automatically configure it as a plugin


It has two components:

* [`helix_zsh.zsh`](helix_zsh.zsh)
  - This script creates the keymaps and handles input/output via the driver
* [helix-driver](helix-driver)
  - This is a rust program which spins up a hidden instance of Helix
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
  - These are purely visual problems and don't affect functionality
* Autocomplete menu for some tools fails

All the shell scripts bits should be namespaced enough to prevent any problems.
Please open an issue if you find any other bugs.

Note on terminal usability:

`hx-zsh` _should_ automagically terminate itself and revert back to defaults when any glitches occur (driver vanishes, driver can't be executed, etc). I've been using it for a few months and never hit an issue that prevents all input to the terminal. If it does not, and this leaves the terminal in a weird state, this is a bug and opening an issue for it would be greatly appreciated. In the unlikely scenario it happens to you, there are a few ways to try and reset things:

* If you can input any characters, deleting the helix-driver executable and reloading the shell should cause it to auto-disable
* If you cannot, then using another editor/tool to disable where you `source` the plugin is the best bet

# Installing & using

How to use:

> [!NOTE]
> The installer will add the plugin if oh-my-zsh is used for plugin management
> If not, you must manually place [`helix_zsh.zsh`](helix_zsh.zsh) somewhere and `source <LOCATION>` in your `.zshrc`

> [!NOTE]
> Install can be a touch slow as it has to build helix itself

1. Clone
2. Run `source install.sh`

This should be enough for everything to work, but if it doesn't, reload your shell.
You can do a quick check by typing `foo`, then your 'enter-normal-mode' key, then `b`, and you should see `foo` be highlighted as it would if you made this movement in Helix.

The `hx-zsh` function can be used to check info about the plugin. Run `hx-zsh --help` for more details.

4. Optionally, if you use powerlevel10k, add this code to your powerlevel10k (`p10k.zsh`) file to get different characters for different modes:

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

* Run `source uninstall.sh`, which
  - `cargo uninstall`'s the driver
  - Removes the zsh plugin if it can
