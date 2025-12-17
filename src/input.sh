#!/usr/bin/env bash

#######################################
# Input Handling Module
# Processes keyboard input and updates application state
#######################################

# Navigation step constants
declare -gr DAY_STEP=1
declare -gr WEEK_STEP=7

#######################################
# Main input handler
# Reads single keypress and dispatches to appropriate handler
# Globals:
#   SELECTED_DAY - May be modified by navigation
#######################################
handle_input() {
    local key

    # Read single character with no echo
    IFS= read -rsn1 key

    # Handle escape sequences (arrow keys, function keys, etc.)
    if [[ "${key}" == $'\x1b' ]]; then
        # Read additional characters for escape sequence
        read -rsn2 -t 0.1 key
        _handle_arrow_keys "${key}"
    else
        _handle_regular_keys "${key}"
    fi

    # Handle month overflow after day navigation
    handle_day_overflow
}

#######################################
# Handle arrow key navigation
# Arguments:
#   $1 - Escape sequence suffix (e.g., '[A' for up arrow)
# Globals:
#   SELECTED_DAY - Modified based on arrow key
#######################################
_handle_arrow_keys() {
    local key="${1}"

    case "${key}" in
        '[A') SELECTED_DAY=$((SELECTED_DAY - WEEK_STEP)) ;;  # Up arrow - move up one week
        '[B') SELECTED_DAY=$((SELECTED_DAY + WEEK_STEP)) ;;  # Down arrow - move down one week
        '[C') SELECTED_DAY=$((SELECTED_DAY + DAY_STEP)) ;;   # Right arrow - move right one day
        '[D') SELECTED_DAY=$((SELECTED_DAY - DAY_STEP)) ;;   # Left arrow - move left one day
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
        '[')
            # Previous month
            prev_month
            ;;
        ']')
            # Next month
            next_month
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
