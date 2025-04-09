HELIX_ZSH=""

HELIX_ZSH_EN_LOG=""
HELIX_ZSH_LOG_DIR=~/.cache/helix-zsh

# _helix_zsh_driver="./helix-driver/target/debug/helix-driver"
_helix_zsh_driver="helix-driver"
_helix_zsh_driver_path=""
_helix_zsh_driver_ver=""

_hx_driver_exists() {
    # check it exists
    [[ -f $_helix_zsh_driver ]] || command -v $_helix_zsh_driver &> /dev/null || return 1

    # now check it is what we expect
    local name ver
    { read -r name && read -r ver; } < <($_helix_zsh_driver version) || return 1

    if [[ "$name" == "helix-driver" ]]; then
        _helix_zsh_driver_ver="$ver"
        return 0;
    else
        return 1
    fi
}

_hx_driver_info() {
    _hx_driver_exists || return 1

    if [[ "$(whence -w $_helix_zsh_driver)" == *function* ]]; then
        _helix_zsh_driver_path="(zsh function)"
    else
        _helix_zsh_driver_path=$(command -v $_helix_zsh_driver)
    fi
}

hx-zsh() {
    # TODO: flesh this out

    _hx-zsh-help() {
        echo "helix-zsh bindings"
        echo "John Kelly <johnharrykelly@gmail.com>"
        echo ""
        echo "hx-zsh [OPTIONS]"
        echo ""
        echo "OPTIONS:"
        echo ""
        echo "    -e,--enabled "
        echo "        Succeed if hx-zsh is enabled"
        echo ""
        echo "    --driver "
        echo "        Show driver information"
        echo ""
        echo "    --info "
        echo "        Show information"
        echo ""
        echo "    -h,--help "
        echo "        Show help"
        echo ""
    }

    if [[ $# == 0 ]]; then
        echo "hx-zsh"
        echo "John Kelly <johnharrykelly@gmail.com>"
        echo ""
        if [[ "$HELIX_ZSH" == "1" ]]; then
            echo "Status: enabled"
        else
            echo "Status: disabled (likely could not find driver)"
        fi
        echo ""

        return
    fi

    _hx_zsh_log_info() {
        if [[ "$HELIX_ZSH_EN_LOG" == "1" ]]; then
            echo "Logs:"
            echo "  HELIX_ZSH_LOG_DIR: $HELIX_ZSH_LOG_DIR"
            echo "  HELIX_ZSH_DRIVER_LOG: $HELIX_ZSH_DRIVER_LOG"
            echo "  HELIX_ZSH_LOG: $HELIX_ZSH_LOG"
        else
            echo "Logging disabled"
        fi
    }

    _hx_zsh_driver_info() {
        if ! _hx_driver_info; then
            echo "Driver could not be found!"
        else
            echo "Driver: "
            echo "  command:  $_helix_zsh_driver"
            echo "  path:     $_helix_zsh_driver_path"
            echo "  version:  $_helix_zsh_driver_ver"
        fi
    }

    case "$1" in
        --help|-h|help)
            _hx-zsh-help
            return
            ;;
        -e|--enabled)
            return [[ "$HELIX_ZSH" == "1" ]]
            ;;
        --info)
            _hx_zsh_log_info
            echo "\n"
            _hx_zsh_driver_info
            ;;
        --driver)
            _hx_zsh_driver_info
            ;;
        *)
            tput setaf 1
            tput bold

            echo "Unrecognised argument '$1'"

            tput sgr0
            ;;
    esac
}

_helix_zsh_failed=""

if [[ -n "$_helix_zsh_failed" ]] || ! _hx_driver_exists; then
    _helix_zsh_failed="1"

    # the newlines prevent this text being hidden by prompts

    tput setaf 1
    tput bold
    
    echo "\n\n\n\n"
    echo "helix-zsh enabled but could not find helix-driver, is it installed?"
    echo "\n\n\n\n"

    tput sgr0
else
    HELIX_ZSH="1"

    typeset -g _hx_driver_pid

    HELIX_ZSH_DRIVER_LOG="/dev/null"
    HELIX_ZSH_LOG="/dev/null"

    if [[ "$HELIX_ZSH_EN_LOG" == "1" ]]; then
        mkdir -p $HELIX_ZSH_LOG_DIR

        HELIX_ZSH_DRIVER_LOG="$HELIX_ZSH_LOG_DIR/helix-driver.log"
        HELIX_ZSH_LOG="$HELIX_ZSH_LOG_DIR/helix_zsh.log"
    fi

    _hx_driver() {
        RUST_BACKTRACE=1 RUST_LOG=trace $_helix_zsh_driver 2>> $HELIX_ZSH_DRIVER_LOG
    }

    _hx_driver_fail () {
        # hx driver has suddenly vanished
        # reset to default state and back out
        HELIX_ZSH="0"

        tput setaf 1
        tput bold

        echo "\n\n\n\n"
        echo "$1"

        if [[ "$HELIX_ZSH_EN_LOG" == "1" ]]; then
            echo "\n"
            echo "End of driver logs: "
            tail -20 $HELIX_ZSH_DRIVER_LOG
        fi

        echo "\n\n\n\n"

        tput sgr0

        bindkey -d
    }

    _hx_driver_heartbeat() {
        printf "%s" 'H' >&p
        printf "\0" >&p
    }

    _hx_driver_keys() {
        printf "%s" 'K' >&p
        printf "%s" "$1" >&p
        printf "\0" >&p
    }

    _hx_driver_text() {
        printf "%s" 'T' >&p
        printf "%s" "$1" >&p
        printf "\0" >&p
    }

    _hx_driver_cursor() {
        printf "%s" 'C' >&p
        printf "%s" "$1" >&p
        printf "\0" >&p
    }

    _hx_driver_reset() {
        printf "%s" 'R' >&p
        printf "\0" >&p
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

    _hx_ensure_driver() {
        echo "Ensuring driver" >> $HELIX_ZSH_LOG

        if ps -p $_hx_driver_pid > /dev/null 2>&1; then
            return
        fi

        if ! _hx_driver_exists; then
            _hx_driver_fail "helix-driver has disappeared, reverting to default keybindings"
            return 1
        fi

        coproc _hx_driver
        _hx_driver_pid=$!

        _hx_driver_heartbeat

        local heartbeat
        IFS= read -r -u 0 -d $'\0' heartbeat <&p

        if [[ "$heartbeat" != "1" ]]; then
            _hx_driver_fail "heartbeat check with helix-driver failed"
            return 1
        fi

        echo "Started driver pid=$_hx_driver_pid" >> $HELIX_ZSH_LOG
    }

    _hx_ensure_driver

    _hx_kill_driver() {
        echo "Killing driver pid=$_hx_driver_pid" >> $HELIX_ZSH_LOG
        kill $_hx_driver_pid >/dev/null 2>&1
    }

    # if exit was previously overriden, save it into `_hx_exit`, else just have `_hx_exit` call builtin

    if typeset -f exit > /dev/null && [[ "$(typeset -f exit)" != "$(typeset -f _hx_prev_exit)" ]]; then
      eval "_hx_prev_exit $(typeset -f exit | sed '1s/exit//')"
    else
      _hx_prev_exit() {
          builtin exit "$@"
      }
    fi

    exit() {
        _hx_kill_driver
        sleep 0.1
        _hx_prev_exit "$@"
    }

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
        _hx_ensure_driver

        if [[ $_hx_mode == "hxins" && ($KEYS == $'\r' || $KEYS == $'\n' || $KEYS == '^M') ]]; then
            region_highlight=()
            zle accept-line
            _hx_driver_reset
            return
        fi

        if [[ "$_hx_buffer" != "$BUFFER" ]]; then
            echo "Buffer changed; from '$_hx_buffer' -> '$BUFFER' and cursor from $_hx_cursor -> $CURSOR" >> $HELIX_ZSH_LOG

            _hx_driver_reset
            _hx_driver_text "$BUFFER"
            _hx_driver_cursor "$CURSOR"
        elif [[ "$_hx_cursor" != "$CURSOR" ]]; then
            echo "Moving cursor from $_hx_cursor -> $CURSOR" >> $HELIX_ZSH_LOG
            _hx_driver_cursor "$CURSOR"
        fi

        _hx_driver_keys "$KEYS"

        local text sel cb new_mode reset_prompt;

        IFS= read -r -u 0 -d $'\0' text <&p

        typeset -a sels

        while IFS= read -u 0 -d $'\0' sel <&p; do
          [[ -z "$sel" ]] && break
          sels+=("$sel")
        done

        read -k 1 -u 0 c <&p
        if [[ "$c" == "Y" ]]; then
            IFS= read -r -u 0 -d $'\0' cb <&p
            printf "%s" "$cb" | pbcopy
            echo "copied '$cb' to clipboard" >> $HELIX_ZSH_LOG
        fi

        read -k 1 -u 0 new_mode <&p
        new_mode=$(_hx_get_mode $new_mode)

        head=$sels[1]
        anchor=$sels[2]

        if (( head < anchor )); then
            start=$head
            end=$anchor
        else
            start=$anchor
            end=$head
        fi

        BUFFER="$text"
        CURSOR="$start"

        local render_regions=""
        local nsels=${#sels}
        if (( nsels > 2 )); then
            render_regions="1"
        fi

        region_highlight=()

        if [[ "$new_mode" != "$_hx_mode" ]]; then
            case "$new_mode" in
                hxins)
                    echo "hxins" >> $HELIX_ZSH_LOG
                    _hx_cursor_beam
                    zle -K hxins ;;
                hxcmd)
                    echo "cmd" >> $HELIX_ZSH_LOG
                    _hx_cursor_block
                    zle -K hxcmd ;;
                hxsel)
                    echo "sel" >> $HELIX_ZSH_LOG
                    _hx_cursor_block
                    zle -K hxsel ;;
            esac

            _hx_mode="$new_mode"
            hx_mode="$new_mode"
            reset_prompt="1"
        else
            reset_prompt=""
        fi

        if [[ "$_hx_mode" != "hxins" || -n $render_regions ]]; then
            region_highlight=()

            for ((i=1; i<${#sels[@]}; i+=2)); do
                head=${sels[i]}
                anchor=${sels[i+1]}

                if (( head < anchor )); then
                    start=$head
                    end=$anchor
                else
                    start=$anchor
                    end=$head
                fi

                region_highlight+=("$start $end bg=#a9a9a9")
            done
        fi

        if [[ $BUFFER != $_hx_buffer ]]; then
            zle redisplay
        elif [[ -n $reset_prompt ]]; then
            zle .reset-prompt
        fi

        _hx_buffer="$BUFFER"
        _hx_cursor="$CURSOR"
    }

    _hx_line_init() {
        _hx_driver_reset
    }

    _hx_bracketed_paste() {
        # TODO: impl
    }

    _hx_keymaps=("hxcmd" "hxins" "hxsel")

    _hx_bindkey_all() {
        for keymap in $_hx_keymaps; do
            bindkey -M $keymap "$@"
        done
    }

    zle -N _hx_process
    zle -N _hx_bracketed_paste
    zle -N undefined-key _hx_process
    zle -N zle-line-init _hx_ensure_driver

    echo -ne '\e[?2004h'

    for keymap in $_hx_keymaps; do
        bindkey -N $keymap
    done

    _hx_add_default_bindings

    # explicitly binding escape prevents zle waiting for an escape sequence
    _hx_bindkey_all '^[' _hx_process
    _hx_bindkey_all '^M' _hx_process
    _hx_bindkey_all $'\r' _hx_process
    _hx_bindkey_all '^[[200~' _hx_bracketed_paste
    _hx_bindkey_all '^[[A' up-line-or-beginning-search
    _hx_bindkey_all '^[[B' down-line-or-beginning-search

    # start in insert mode
    bindkey -A hxins main
fi
