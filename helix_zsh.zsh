HELIX_ZSH="1"

# global mode state
hx_mode="insert"

driver="helix-driver"

coproc $driver 2> /dev/null

function _add_default_bindings() {
    bindkey -M $1 "^A"-"^C" self-insert
    bindkey -M $1 "^D" list-choices
    bindkey -M $1 "^E"-"^F" self-insert
    bindkey -M $1 "^G" list-expand
    bindkey -M $1 "^H" vi-backward-delete-char
    bindkey -M $1 "^I" expand-or-complete
    bindkey -M $1 "^J" accept-line
    bindkey -M $1 "^K" self-insert
    bindkey -M $1 "^L" clear-screen
    bindkey -M $1 "^M" accept-line
    bindkey -M $1 "^N"-"^P" self-insert
    bindkey -M $1 "^Q" vi-quoted-insert
    bindkey -M $1 "^R" redisplay
    bindkey -M $1 "^S"-"^T" self-insert
    bindkey -M $1 "^U" vi-kill-line
    bindkey -M $1 "^V" vi-quoted-insert
    bindkey -M $1 "^W" vi-backward-kill-word
    bindkey -M $1 "^Y"-"^Z" self-insert
    bindkey -M $1 "^[OA" up-line-or-beginning-search
    bindkey -M $1 "^[OB" down-line-or-beginning-search
    bindkey -M $1 "^[OC" vi-forward-char
    bindkey -M $1 "^[OD" vi-backward-char
    bindkey -M $1 "^[OF" end-of-line
    bindkey -M $1 "^[OH" beginning-of-line
    bindkey -M $1 "^[[1;5C" forward-word
    bindkey -M $1 "^[[1;5D" backward-word
    bindkey -M $1 "^[[200~" bracketed-paste
    bindkey -M $1 "^[[3;5~" kill-word
    bindkey -M $1 "^[[3~" delete-char
    bindkey -M $1 "^[[5~" up-line-or-history
    bindkey -M $1 "^[[6~" down-line-or-history
    bindkey -M $1 "^[[A" up-line-or-history
    bindkey -M $1 "^[[B" down-line-or-history
    bindkey -M $1 "^[[C" vi-forward-char
    bindkey -M $1 "^[[D" vi-backward-char
    bindkey -M $1 "^[[Z" reverse-menu-complete
}

mode=""
hxmode=""

hx_zle_widget() {
    if [[ $KEYS == $'\r' || $KEYS == $'\n' || $KEYS == '^M' ]]; then
        region_highlight=()
        zle accept-line
        echo -n "\n" >&p
        return
    fi

    echo -n "$KEYS" >&p
    echo -ne "\x00" >&p
    read -k 1 -u 0 res <&p

    IFS= read -u 0 -d $'\C-@' text <&p
    IFS= read -u 0 -d $'\C-@' head <&p
    IFS= read -u 0 -d $'\C-@' anchor <&p

    read -k 1 -u 0 c <&p
    if [[ "$c" == "Y" ]]; then
        IFS= read -u 0 -d $'\C-@' cb <&p
        echo -n "$cb" | pbcopy
    fi

    read -k 1 -u 0 new_mode <&p

    if (( head < anchor )); then
        start=$head
        end="$anchor"
    else
        start=$anchor
        end="$head"
    fi

    BUFFER="$text"
    CURSOR="$start"

    region_highlight=("$start $end bg=#a9a9a9")

    if [[ "$new_mode" != "$mode" ]]; then
        case $new_mode in
            i)
                hxmode="hxins"
                zle -K hxins ;;
            n)
                hxmode="hxcmd"
                zle -K hxcmd ;;
            s)
                hxmode="hxsel"
                zle -K hxcmd ;;
        esac

        mode=$new_mode

        zle reset-prompt
    else
        zle redisplay
    fi
}

undefined-key() {
    hx_zle_widget
}

hx_normal_mode() {
    hx_mode="normal"
    bindkey -A hxcmd main
    hx_zle_widget
}

hx_insert_mode() {
    hx_mode="insert"
    bindkey -A hxins main
    hx_zle_widget
}

zle-line-init() {
    ctrlc=$(echo -ne "\x03")
    echo -n $ctrlc >&p
}

zle -N zle-line-init

unset zle_bracketed_paste
echo -ne "\e[?2004l"

zle -N hx_normal_mode
zle -N hx_insert_mode
zle -N hx_break
zle -N undefined-key

bindkey -N hxcmd
bindkey -N hxins

_add_default_bindings hxcmd
_add_default_bindings hxins

bindkey -M hxins '^[' hx_normal_mode  # 'esc' exits insert mode

bindkey -M hxcmd 'i' hx_insert_mode  # 'i' enters insert mode

# start in insert mode
bindkey -A hxins main
