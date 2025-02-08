HELIX_ZSH="1"

driver="./helix-driver/target/debug/helix-driver"
# driver="helix-driver"

DRIVER_LOG="/dev/null"
# DRIVER_LOG="./helix-driver.log"

coproc { RUST_BACKTRACE=1 RUST_LOG=trace $driver 2> $DRIVER_LOG }

LOG="/dev/null"
# LOG="./helix_zsh.log"

_hx_add_default_bindings() {
    _hx_bindkey_all "^A"-"^C" self-insert
    _hx_bindkey_all "^D" list-choices
    _hx_bindkey_all "^E"-"^F" self-insert
    _hx_bindkey_all "^G" list-expand
    _hx_bindkey_all "^H" vi-backward-delete-char
    _hx_bindkey_all "^I" expand-or-complete
    _hx_bindkey_all "^J" accept-line
    _hx_bindkey_all "^K" self-insert
    _hx_bindkey_all "^L" clear-screen
    _hx_bindkey_all "^M" accept-line
    _hx_bindkey_all "^N"-"^P" self-insert
    _hx_bindkey_all "^Q" vi-quoted-insert
    _hx_bindkey_all "^R" redisplay
    _hx_bindkey_all "^S"-"^T" self-insert
    _hx_bindkey_all "^U" vi-kill-line
    _hx_bindkey_all "^V" vi-quoted-insert
    _hx_bindkey_all "^W" vi-backward-kill-word
    _hx_bindkey_all "^Y"-"^Z" self-insert
    _hx_bindkey_all "^[OA" up-line-or-beginning-search
    _hx_bindkey_all "^[OB" down-line-or-beginning-search
    _hx_bindkey_all "^[OC" vi-forward-char
    _hx_bindkey_all "^[OD" vi-backward-char
    _hx_bindkey_all "^[OF" end-of-line
    _hx_bindkey_all "^[OH" beginning-of-line
    _hx_bindkey_all "^[[1;5C" forward-word
    _hx_bindkey_all "^[[1;5D" backward-word
    _hx_bindkey_all "^[[200~" bracketed-paste
    _hx_bindkey_all "^[[3;5~" kill-word
    _hx_bindkey_all "^[[3~" delete-char
    _hx_bindkey_all "^[[5~" up-line-or-history
    _hx_bindkey_all "^[[6~" down-line-or-history
    _hx_bindkey_all "^[[A" up-line-or-history
    _hx_bindkey_all "^[[B" down-line-or-history
    _hx_bindkey_all "^[[C" vi-forward-char
    _hx_bindkey_all "^[[D" vi-backward-char
    _hx_bindkey_all "^[[Z" reverse-menu-complete
}

_hx_driver_keys() {
    print -n -- 'K' >&p
    print -n -- "$1" >&p
    print -n -- "\0" >&p
}

_hx_driver_text() {
    print -n -- 'T' >&p
    print -n -- "$1" >&p
    print -n -- "\0" >&p
}

_hx_driver_cursor() {
    print -n -- 'C' >&p
    print -n -- "$1" >&p
    print -n -- "\0" >&p
}

_hx_driver_reset() {
    print -n -- 'R' >&p
    print -n -- "\0" >&p
    hx_mode="hxins"
    _hx_mode="hxins"
    _hx_buffer=""
    _hx_cursor=0
}

_hx_cursor_beam() {
    echo -ne '\e[5 q'
}

_hx_cursor_block() {
    echo -ne '\e[1 q'
}

# public variable, kept so we can change inners
# must be `hxins|hxcmd|hxsel`
typeset -g hx_mode="hxins"
_hx_mode="hxins"
_hx_cursor="0"
_hx_buffer=""

_hx_get_mode() {
    case $1 in
        i)
            echo hxins ;;
        n)
            echo hxcmd ;;
        s)
            echo hxsel ;;
    esac
}

_hx_process() {
    if [[ $KEYS == $'\r' || $KEYS == $'\n' || $KEYS == '^M' ]]; then
        region_highlight=()
        zle accept-line
        _hx_driver_reset
        return
    fi

    if [[ "$_hx_buffer" != "$BUFFER" ]]; then
        echo "Buffer changed; from '$_hx_buffer' -> '$BUFFER' and cursor from $CURSOR -> $_hx_cursor" >> $LOG

        _hx_driver_reset
        _hx_driver_cursor "$CURSOR"
    fi

    if [[ "$_hx_cursor" != "$CURSOR" ]]; then
        echo "Moving cursor from $CURSOR -> $_hx_cursor" >> $LOG
        _hx_driver_cursor "$CURSOR"
    fi

    _hx_driver_keys "$KEYS"

    local res text head anchor cb new_mode;

    read -k 1 -u 0 res <&p

    IFS= read -u 0 -d $'\0' text <&p
    IFS= read -u 0 -d $'\0' head <&p
    IFS= read -u 0 -d $'\0' anchor <&p

    read -k 1 -u 0 c <&p
    if [[ "$c" == "Y" ]]; then
        IFS= read -u 0 -d $'\C-@' cb <&p
        echo -n "$cb" | pbcopy
    fi

    read -k 1 -u 0 new_mode <&p
    new_mode=$(_hx_get_mode $new_mode)

    # clear stdout. there shouldn't be anything here, but just in case
    while IFS= read -t 0 -u p -r; do :; done

    if (( head < anchor )); then
        start=$head
        end="$anchor"
    else
        start=$anchor
        end="$head"
    fi

    BUFFER="$text"
    CURSOR="$start"

    region_highlight=()

    if [[ "$new_mode" != "$_hx_mode" ]]; then
        case "$new_mode" in
            hxins)
                echo "hxins" >> $LOG
                _hx_cursor_beam
                zle -K hxins ;;
            hxcmd)
                echo "cmd" >> $LOG
                _hx_cursor_block
                zle -K hxcmd ;;
            hxsel)
                echo "sel" >> $LOG
                _hx_cursor_block
                zle -K hxcmd ;;
        esac

        _hx_mode="$new_mode"
        hx_mode="$new_mode"
        zle .reset-prompt
    fi

    if [[ "$_hx_mode" != "hxins" ]]; then
        region_highlight=("$start $end bg=#a9a9a9")
    fi

    if [[ $BUFFER != $_hx_buffer || -n $buffer ]]; then
        zle redisplay
    fi

    _hx_buffer="$BUFFER"
    _hx_cursor="$CURSOR"
}

_hx_line_init() {
    _hx_driver_reset
}

_hx_bracketed_paste() {
    
}

_hx_keymaps=("hxcmd" "hxins")

_hx_bindkey_all() {
    for keymap in $_hx_keymaps; do
        bindkey -M $keymap "$@"
    done
}

zle -N _hx_process
zle -N _hx_bracketed_paste
zle -N undefined-key _hx_process

echo -ne '\e[?2004h'

for keymap in $_hx_keymaps; do
    bindkey -N $keymap
done

_hx_add_default_bindings

# explicitly binding escape prevents zle waiting for an escape sequence
_hx_bindkey_all '^[' _hx_process
_hx_bindkey_all '^[[200~' _hx_bracketed_paste
_hx_bindkey_all '^[[A' up-line-or-beginning-search
_hx_bindkey_all '^[[B' down-line-or-beginning-search

# start in insert mode
bindkey -A hxins main
