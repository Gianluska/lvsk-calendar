#!/usr/bin/env bash

#######################################
# Modal Component
# Centered overlay dialogs drawn on top of the calendar: box drawing, an
# inline line editor, a 12h time field and an AM/PM selector. All input is
# read key-by-key from /dev/tty (echo stays off; fields render themselves),
# so ESC cancels cleanly and nothing ever leaks outside the box.
# Callers set FIRST_RENDER=1 after closing so the next render repaints.
#######################################

# Geometry of the currently open modal (set by _modal_open)
declare -g _MODAL_TOP=0
declare -g _MODAL_LEFT=0
declare -g _MODAL_W=0
declare -g _MODAL_H=0

#######################################
# Draw a centered modal box with a title row
# Arguments:
#   $1 - Height (rows, including borders)
#   $2 - Width (columns, including borders)
#   $3 - Title (shown centered on the first inner row)
# Globals:
#   _MODAL_TOP/_MODAL_LEFT/_MODAL_W/_MODAL_H - Set for the helpers below
#######################################
_modal_open() {
    _MODAL_H="${1}"
    _MODAL_W="${2}"
    local title="${3}"

    _MODAL_TOP=$(((TERM_ROWS - _MODAL_H) / 2))
    ((_MODAL_TOP < 0)) && _MODAL_TOP=0
    _MODAL_LEFT=$(((TERM_COLS - _MODAL_W) / 2))
    ((_MODAL_LEFT < 0)) && _MODAL_LEFT=0

    local inner=$((_MODAL_W - 2))
    local border blank i
    _repeat_v border "${CHAR[h]}" "${inner}"
    printf -v blank '%*s' "${inner}" ''

    local buf=""
    _bcup buf "${_MODAL_TOP}" "${_MODAL_LEFT}"
    _bprintf buf '%b%s%s%s%b' \
        "${COLORS[SUBTLE]}" "${CHAR[tl]}" "${border}" "${CHAR[tr]}" "${COLORS[RESET]}"

    for ((i = 1; i < _MODAL_H - 1; i++)); do
        _bcup buf $((_MODAL_TOP + i)) "${_MODAL_LEFT}"
        _bprintf buf '%b%s%b%s%b%s%b' \
            "${COLORS[SUBTLE]}" "${CHAR[v]}" "${COLORS[RESET]}" \
            "${blank}" \
            "${COLORS[SUBTLE]}" "${CHAR[v]}" "${COLORS[RESET]}"
    done

    _bcup buf $((_MODAL_TOP + _MODAL_H - 1)) "${_MODAL_LEFT}"
    _bprintf buf '%b%s%s%s%b' \
        "${COLORS[SUBTLE]}" "${CHAR[bl]}" "${border}" "${CHAR[br]}" "${COLORS[RESET]}"

    # Centered title, clipped so it can never cross the border
    # (character-based length: byte counts would shift multibyte titles)
    local tlen
    _char_len tlen "${title}"
    if ((tlen > inner - 2)); then
        title="${title:0:$((inner - 3))}…"
        _char_len tlen "${title}"
    fi
    local tcol=$((_MODAL_LEFT + (_MODAL_W - tlen) / 2))
    ((tcol < _MODAL_LEFT + 1)) && tcol=$((_MODAL_LEFT + 1))
    _bcup buf $((_MODAL_TOP + 1)) "${tcol}"
    _bprintf buf '%b%b%s%b' \
        "${COLORS[ACCENT_BRIGHT]}" "${COLORS[BOLD]}" "${title}" "${COLORS[RESET]}"

    printf '%s' "${buf}"
}

#######################################
# Write the modal's hint line (second-to-last row), centered
# Arguments:
#   $1 - Hint text
#   $2 - Color (optional; defaults to SUBTLE, pass an error color for alerts)
#######################################
_modal_hint() {
    local text="${1}"
    local color="${2:-${COLORS[SUBTLE]}}"
    local row=$((_MODAL_TOP + _MODAL_H - 2))
    local inner=$((_MODAL_W - 2))

    local blank
    printf -v blank '%*s' "${inner}" ''

    # Clip so a hint can never cross the border
    # (character-based length: byte counts would shift multibyte hints)
    local tlen
    _char_len tlen "${text}"
    if ((tlen > inner - 2)); then
        text="${text:0:$((inner - 3))}…"
        _char_len tlen "${text}"
    fi

    local tcol=$((_MODAL_LEFT + (_MODAL_W - tlen) / 2))
    ((tcol < _MODAL_LEFT + 1)) && tcol=$((_MODAL_LEFT + 1))

    printf '\033[%d;%dH%s' $((row + 1)) $((_MODAL_LEFT + 2)) "${blank}"
    printf '\033[%d;%dH%b%s%b' $((row + 1)) $((tcol + 1)) "${color}" "${text}" "${COLORS[RESET]}"
}

#######################################
# Render a text field: the tail of the value, padded to the field width,
# with the terminal cursor left at the end of the text
# Arguments:
#   $1 - Row, $2 - Column, $3 - Field width, $4 - Text value
#######################################
_modal_draw_field() {
    local row="${1}" col="${2}" fw="${3}" text="${4}"

    local disp="${text}"
    ((${#disp} > fw)) && disp="${disp: -fw}"

    # Pad by character count, not printf's byte count (multibyte-safe)
    local pad
    printf -v pad '%*s' $((fw - ${#disp})) ''

    printf '\033[%d;%dH%b%s%b%s' $((row + 1)) $((col + 1)) \
        "${COLORS[ACCENT_BRIGHT]}" "${disp}" "${COLORS[RESET]}" "${pad}"
    printf '\033[%d;%dH' $((row + 1)) $((col + ${#disp} + 1))
}

#######################################
# Inline line editor inside a modal
# Printable characters append (up to the max length), Backspace deletes,
# Ctrl-U clears, Enter accepts, ESC cancels. Arrow keys are ignored.
# Arguments:
#   $1 - Name of output variable
#   $2 - Row, $3 - Column, $4 - Field width, $5 - Max length, $6 - Initial value
# Returns:
#   0 on Enter (value in the output variable), 1 on ESC/EOF
#######################################
_modal_read_line() {
    local -n __mrl="${1}"
    local __mrl_row="${2}" __mrl_col="${3}" __mrl_fw="${4}" __mrl_max="${5}"
    local __mrl_buf="${6}"
    local __mrl_c __mrl_seq __mrl_rc

    printf '%s' "${TC_CNORM}"
    _modal_draw_field "${__mrl_row}" "${__mrl_col}" "${__mrl_fw}" "${__mrl_buf}"

    while :; do
        if ! IFS= read -rsn1 __mrl_c < /dev/tty; then
            __mrl_rc=$?
            ((__mrl_rc > 128)) && continue   # signal (resize) - keep editing
            printf '%s' "${TC_CIVIS}"
            return 1
        fi

        case "${__mrl_c}" in
            ''|$'\r')  # Enter ("" via icrnl, raw \r without it)
                __mrl="${__mrl_buf}"
                printf '%s' "${TC_CIVIS}"
                return 0
                ;;
            $'\x1b')
                _read_escape_sequence __mrl_seq
                if [[ -z "${__mrl_seq}" ]]; then   # bare ESC cancels
                    printf '%s' "${TC_CIVIS}"
                    return 1
                fi
                ;;                                  # arrows etc.: ignored
            $'\x7f'|$'\x08')  # Backspace
                __mrl_buf="${__mrl_buf%?}"
                _modal_draw_field "${__mrl_row}" "${__mrl_col}" "${__mrl_fw}" "${__mrl_buf}"
                ;;
            $'\x15')  # Ctrl-U clears
                __mrl_buf=""
                _modal_draw_field "${__mrl_row}" "${__mrl_col}" "${__mrl_fw}" "${__mrl_buf}"
                ;;
            *)
                if [[ "${__mrl_c}" == [[:print:]] ]] && ((${#__mrl_buf} < __mrl_max)); then
                    __mrl_buf+="${__mrl_c}"
                    _modal_draw_field "${__mrl_row}" "${__mrl_col}" "${__mrl_fw}" "${__mrl_buf}"
                fi
                ;;
        esac
    done
}

#######################################
# Render the 12h time field from its digit buffer
# Empty shows a "--:--" placeholder; digits format progressively
# (7 -> "7", 73 -> "73", 730 -> "7:30", 0730 -> "07:30")
# Arguments:
#   $1 - Row, $2 - Column, $3 - Digit buffer (0-4 digits)
#######################################
_modal_draw_time12() {
    local row="${1}" col="${2}" digits="${3}"

    local disp
    case ${#digits} in
        0) disp="" ;;
        1|2) disp="${digits}" ;;
        3) disp="${digits:0:1}:${digits:1}" ;;
        *) disp="${digits:0:2}:${digits:2}" ;;
    esac

    if [[ -z "${disp}" ]]; then
        printf '\033[%d;%dH%b--:--%b' $((row + 1)) $((col + 1)) \
            "${COLORS[SUBTLE]}" "${COLORS[RESET]}"
        printf '\033[%d;%dH' $((row + 1)) $((col + 1))
    else
        local pad
        printf -v pad '%*s' $((5 - ${#disp})) ''
        printf '\033[%d;%dH%b%s%b%s' $((row + 1)) $((col + 1)) \
            "${COLORS[ACCENT_BRIGHT]}" "${disp}" "${COLORS[RESET]}" "${pad}"
        printf '\033[%d;%dH' $((row + 1)) $((col + ${#disp} + 1))
    fi
}

#######################################
# Digit-only editor for the 12h time field
# Accepts up to 4 digits (h, hh, hmm or hhmm); the colon is inserted by the
# renderer, so Backspace simply removes the last digit. Enter accepts
# (including empty = untimed), ESC cancels.
# Arguments:
#   $1 - Name of output variable (receives the digit buffer)
#   $2 - Row, $3 - Column, $4 - Initial digit buffer
# Returns:
#   0 on Enter, 1 on ESC/EOF
#######################################
_modal_read_time12() {
    local -n __mrt="${1}"
    local __mrt_row="${2}" __mrt_col="${3}"
    local __mrt_buf="${4}"
    local __mrt_c __mrt_seq __mrt_rc

    printf '%s' "${TC_CNORM}"
    _modal_draw_time12 "${__mrt_row}" "${__mrt_col}" "${__mrt_buf}"

    while :; do
        if ! IFS= read -rsn1 __mrt_c < /dev/tty; then
            __mrt_rc=$?
            ((__mrt_rc > 128)) && continue
            printf '%s' "${TC_CIVIS}"
            return 1
        fi

        case "${__mrt_c}" in
            ''|$'\r')  # Enter ("" via icrnl, raw \r without it)
                __mrt="${__mrt_buf}"
                printf '%s' "${TC_CIVIS}"
                return 0
                ;;
            $'\x1b')
                _read_escape_sequence __mrt_seq
                if [[ -z "${__mrt_seq}" ]]; then
                    printf '%s' "${TC_CIVIS}"
                    return 1
                fi
                ;;
            $'\x7f'|$'\x08')
                __mrt_buf="${__mrt_buf%?}"
                _modal_draw_time12 "${__mrt_row}" "${__mrt_col}" "${__mrt_buf}"
                ;;
            $'\x15')
                __mrt_buf=""
                _modal_draw_time12 "${__mrt_row}" "${__mrt_col}" "${__mrt_buf}"
                ;;
            [0-9])
                if ((${#__mrt_buf} < 4)); then
                    __mrt_buf+="${__mrt_c}"
                    _modal_draw_time12 "${__mrt_row}" "${__mrt_col}" "${__mrt_buf}"
                fi
                ;;
        esac
    done
}

#######################################
# Render the AM/PM selector cells
# Arguments:
#   $1 - Row, $2 - Column, $3 - Selection (AM or PM), $4 - Active flag (0/1)
#######################################
_modal_draw_ampm() {
    local row="${1}" col="${2}" sel="${3}" active="${4}"

    local am_style pm_style
    if ((active)); then
        am_style="${COLORS[BASE_DIMMER]}"
        pm_style="${COLORS[BASE_DIMMER]}"
        if [[ "${sel}" == "AM" ]]; then
            am_style="${COLORS[INVERSE]}${COLORS[BOLD]}"
        else
            pm_style="${COLORS[INVERSE]}${COLORS[BOLD]}"
        fi
    else
        am_style="${COLORS[SUBTLE]}"
        pm_style="${COLORS[SUBTLE]}"
        if [[ "${sel}" == "AM" ]]; then
            am_style="${COLORS[ACCENT_BRIGHT]}"
        else
            pm_style="${COLORS[ACCENT_BRIGHT]}"
        fi
    fi

    printf '\033[%d;%dH%b AM %b  %b PM %b' $((row + 1)) $((col + 1)) \
        "${am_style}" "${COLORS[RESET]}" \
        "${pm_style}" "${COLORS[RESET]}"
}

#######################################
# Interactive AM/PM selector
# Left/Right arrows, h/l, Space or Tab toggle; a/p select directly;
# Enter accepts, ESC cancels.
# Arguments:
#   $1 - Name of output variable (AM or PM)
#   $2 - Row, $3 - Column, $4 - Initial selection
# Returns:
#   0 on Enter, 1 on ESC/EOF
#######################################
_modal_select_ampm() {
    local -n __msa="${1}"
    local __msa_row="${2}" __msa_col="${3}"
    local __msa_sel="${4:-AM}"
    local __msa_c __msa_seq __msa_rc

    printf '%s' "${TC_CIVIS}"
    _modal_draw_ampm "${__msa_row}" "${__msa_col}" "${__msa_sel}" 1

    local __msa_flip
    while :; do
        if ! IFS= read -rsn1 __msa_c < /dev/tty; then
            __msa_rc=$?
            ((__msa_rc > 128)) && continue
            return 1
        fi

        __msa_flip=0
        case "${__msa_c}" in
            ''|$'\r')  # Enter ("" via icrnl, raw \r without it)
                __msa="${__msa_sel}"
                _modal_draw_ampm "${__msa_row}" "${__msa_col}" "${__msa_sel}" 0
                return 0
                ;;
            $'\x1b')
                _read_escape_sequence __msa_seq
                if [[ -z "${__msa_seq}" ]]; then
                    return 1
                fi
                case "${__msa_seq}" in
                    '['*C|OC|'['*D|OD) __msa_flip=1 ;;   # left/right arrows
                esac
                ;;
            h|l|' '|$'\t') __msa_flip=1 ;;
            a|A) __msa_sel="AM"; _modal_draw_ampm "${__msa_row}" "${__msa_col}" "${__msa_sel}" 1 ;;
            p|P) __msa_sel="PM"; _modal_draw_ampm "${__msa_row}" "${__msa_col}" "${__msa_sel}" 1 ;;
        esac

        if ((__msa_flip)); then
            if [[ "${__msa_sel}" == "AM" ]]; then __msa_sel="PM"; else __msa_sel="AM"; fi
            _modal_draw_ampm "${__msa_row}" "${__msa_col}" "${__msa_sel}" 1
        fi
    done
}

#######################################
# Small centered confirmation modal
# Arguments:
#   $1 - Message (a question)
# Returns:
#   0 if confirmed with y/Y, 1 otherwise (any other key, ESC, EOF)
#######################################
_modal_confirm() {
    local msg="${1}"
    local hint="y confirm · any other key cancels"

    # Wide enough for both the message and the hint, with breathing room
    # (character-based lengths keep the width right in any locale)
    local msg_len hint_len
    _char_len msg_len "${msg}"
    _char_len hint_len "${hint}"
    local w=$((msg_len + 8))
    ((w < hint_len + 6)) && w=$((hint_len + 6))
    ((w > TERM_COLS - 2)) && w=$((TERM_COLS - 2))

    _modal_open 5 "${w}" "${msg}"
    _modal_hint "${hint}"
    printf '%s' "${TC_CIVIS}"

    local __mc_c
    IFS= read -rsn1 __mc_c < /dev/tty || return 1
    [[ "${__mc_c}" == [yY] ]]
}
