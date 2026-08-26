#!/usr/bin/env bash

#######################################
# Input Handling Module
# Processes keyboard input and updates application state
#######################################

# Navigation step constants (guarded so re-sourcing in tests doesn't trip)
if [[ ! -v DAY_STEP ]]; then
    declare -gr DAY_STEP=1
    declare -gr WEEK_STEP=7
fi

#######################################
# Main input handler
# Reads single keypress and dispatches to appropriate handler
# Globals:
#   SELECTED_DAY - May be modified by navigation
#######################################
handle_input() {
    local key rc

    # Read single character with no echo
    # Use /dev/tty explicitly to work when launched from app launchers
    if ! IFS= read -rsn1 key < /dev/tty; then
        rc=$?
        # >128: interrupted by a trapped signal (e.g. SIGWINCH on resize) -
        # not EOF; return to the main loop, which re-renders
        ((rc > 128)) && return 0
        # EOF / tty gone: exit cleanly instead of busy-looping at 100% CPU
        exit 0
    fi

    # Handle escape sequences (arrow keys, function keys, etc.)
    if [[ "${key}" == $'\x1b' ]]; then
        _read_escape_sequence key
        _handle_escape_key "${key}"
    else
        _handle_regular_keys "${key}"
    fi

    # Handle month overflow after day navigation
    handle_day_overflow
}

#######################################
# Read the remainder of an escape sequence, draining it completely
# CSI sequences (ESC [ ...) and SS3 (ESC O ...) can be 2-6 bytes; reading a
# fixed amount would leave trailing bytes in the buffer that reappear as
# ghost keypresses (PgUp = ESC [ 5 ~ would leave a stray '~').
# Arguments:
#   $1 - Name of output variable (receives the post-ESC bytes, may be empty)
#######################################
_read_escape_sequence() {
    local -n __esc="${1}"
    __esc=""

    local __esc_c=""
    # Bare ESC: nothing follows within the timeout
    IFS= read -rsn1 -t 0.05 __esc_c < /dev/tty || return 0
    __esc="${__esc_c}"

    if [[ "${__esc_c}" == '[' || "${__esc_c}" == 'O' ]]; then
        # Parameters/intermediates until a final byte (letter or ~)
        while IFS= read -rsn1 -t 0.05 __esc_c < /dev/tty; do
            __esc+="${__esc_c}"
            [[ "${__esc_c}" == [A-Za-z~] ]] && break
        done
    fi
}

#######################################
# Handle a complete escape sequence
# The final byte discriminates arrows in every variant: CSI (ESC [ A),
# SS3/application mode (ESC O A) and modified (ESC [ 1 ; 5 A).
# Arguments:
#   $1 - Escape sequence suffix (without the leading ESC)
# Globals:
#   SELECTED_DAY - Modified based on arrow key
#######################################
_handle_escape_key() {
    local seq="${1}"

    case "${seq}" in
        '['*A | OA) SELECTED_DAY=$((SELECTED_DAY - WEEK_STEP)) ;;  # Up - one week back
        '['*B | OB) SELECTED_DAY=$((SELECTED_DAY + WEEK_STEP)) ;;  # Down - one week forward
        '['*C | OC) SELECTED_DAY=$((SELECTED_DAY + DAY_STEP)) ;;   # Right - one day forward
        '['*D | OD) SELECTED_DAY=$((SELECTED_DAY - DAY_STEP)) ;;   # Left - one day back
    esac
}

#######################################
# Handle regular keyboard input
# Arguments:
#   $1 - Single character key
# Globals:
#   SELECTED_DAY - Modified by vim-style navigation
#######################################
_handle_regular_keys() {
    local key="${1}"

    case "${key}" in
        q|Q)
            # Quit application
            exit 0
            ;;
        t|T)
            # Go to today
            goto_today
            ;;
        a|A)
            # Add an event on the selected day
            event_add_action
            ;;
        e|E)
            # Edit an event on the selected day
            event_edit_action
            ;;
        d|D)
            # Delete an event from the selected day
            event_delete_action
            ;;
        '[')
            # Previous month
            prev_month
            ;;
        ']')
            # Next month
            next_month
            ;;
        '{')
            # Previous year
            prev_year
            ;;
        '}')
            # Next year
            next_year
            ;;
        h)
            # Vim: move left one day
            SELECTED_DAY=$((SELECTED_DAY - DAY_STEP))
            ;;
        l)
            # Vim: move right one day
            SELECTED_DAY=$((SELECTED_DAY + DAY_STEP))
            ;;
        k)
            # Vim: move up one week
            SELECTED_DAY=$((SELECTED_DAY - WEEK_STEP))
            ;;
        j)
            # Vim: move down one week
            SELECTED_DAY=$((SELECTED_DAY + WEEK_STEP))
            ;;
    esac
}
