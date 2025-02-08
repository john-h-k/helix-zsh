# helix-zsh
Helix bindings for zsh

How to use:

1. Clone
2.
```sh
cd <REPO>
cd helix-driver
cargo install --path .
```

3. Setup [helix_zsh.zsh](./helix_zsh.zsh) to be `source`'d when your terminal opens
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
    p10k segment -f 2 -t "❯"
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
