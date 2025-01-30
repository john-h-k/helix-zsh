# global mode state
hx_mode="insert"

driver="./helix-driver/target/debug/helix-driver"

coproc { $driver 2> driver.log }

PS1=${PS1//(#m)vicmd(|[01])/hxcmd}
PS1=${PS1//viins/hxins}

last_pid=""

# function to call hx-zsh and update buffer
hx_zle_widget() {
    if [[ $? -eq 130 && $! != $last_pid ]]; then
        hx_break
        last_pid=$!
        return
    fi

    # local input="$BUFFER"
    # local mark="${MARK:-0}"
    # local cursor="$CURSOR"

    if [[ $KEYS == $'\r' || $KEYS == $'\n' || $KEYS == '^M' ]]; then
        zle accept-line
        echo -n "\n" >&p
        return
    fi

    echo -n "$KEYS" >&p
    echo -ne "\x00" >&p
    read -k 1 -u 0 res <&p

    IFS= read -u 0 -d $'\C-@' text <&p
    read -u 0 -d $'\C-@' head <&p
    read -u 0 -d $'\C-@' anchor <&p

    if (( head < anchor )); then
        start=$head
        end="$anchor"
    else
        start=$anchor
        end="$head"
    fi

    BUFFER="$text"
    CURSOR="$start"

    region_highlight=("$start $end bg=#ececec,fg=#000000,bold")
    echo $region_highlight >> reg.txt

    # local new_buffer new_cursor new_mark new_mode
    # new_buffer=$(echo "$json_output" | jq -r '.buffer')
    # new_cursor=$(echo "$json_output" | jq -r '.cursor')
    # new_mark=$(echo "$json_output" | jq -r '.mark')
    # new_mode=$(echo "$json_output" | jq -r '.mode')

    # hx_mode="$new_mode"

    # BUFFER="$new_buffer"
    # CURSOR="$new_cursor"
    # MARK="$new_mark"

    zle redisplay
}

hx_break() {
    ctrlc=$(echo -ne "\x03")
    BUFFER="${BUFFER}${ctrlc}"
    echo -n $ctrlc >&p
}

undefined-key() {
    hx_zle_widget
}

# switch to normal mode
hx_normal_mode() {
    hx_mode="normal"
    bindkey -A hxcmd main  # switch keymap
    hx_zle_widget
}

# switch to insert mode
hx_insert_mode() {
    hx_mode="insert"
    bindkey -A hxins main  # switch keymap
    hx_zle_widget
}

zle -N hx_normal_mode
zle -N hx_insert_mode
zle -N hx_break
zle -N undefined-key

bindkey -N hxcmd
# note: copy from viins so char insertion works
bindkey -N hxins # viins

bindkey -M hxins '^[' hx_normal_mode  # 'esc' exits insert mode

bindkey -M hxins '^C' hx_break
bindkey -M hxcmd '^C' hx_break

bindkey -M hxcmd 'i' hx_insert_mode  # 'i' enters insert mode

# start in insert mode
bindkey -A hxins main
