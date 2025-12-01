#!/bin/bash

# Input Handling Module
# Processes keyboard input and updates application state

# Main input handler
handle_input() {
    local key
    IFS= read -rsn1 key

    # Handle escape sequences (arrow keys)
    if [[ $key == $'\x1b' ]]; then
        read -rsn2 key
        handle_arrow_keys "$key"
    else
        handle_regular_keys "$key"
    fi

    # Handle month overflow after day navigation
    handle_day_overflow
}

# Handle arrow key navigation
handle_arrow_keys() {
    local key=$1

    case $key in
        '[A') SELECTED_DAY=$(( SELECTED_DAY - 7 )) ;;  # Up arrow
        '[B') SELECTED_DAY=$(( SELECTED_DAY + 7 )) ;;  # Down arrow
        '[C') SELECTED_DAY=$(( SELECTED_DAY + 1 )) ;;  # Right arrow
        '[D') SELECTED_DAY=$(( SELECTED_DAY - 1 )) ;;  # Left arrow
    esac
}

# Handle regular keyboard input
handle_regular_keys() {
    local key=$1

    case $key in
        'q'|'Q')
            exit 0
            ;;
        't'|'T')
            goto_today
            ;;
        '[')
            prev_month
            return
            ;;
        ']')
            next_month
            return
            ;;
        'h')
            SELECTED_DAY=$(( SELECTED_DAY - 1 ))
            ;;
        'l')
            SELECTED_DAY=$(( SELECTED_DAY + 1 ))
            ;;
        'k')
            SELECTED_DAY=$(( SELECTED_DAY - 7 ))
            ;;
        'j')
            SELECTED_DAY=$(( SELECTED_DAY + 7 ))
            ;;
    esac
}
