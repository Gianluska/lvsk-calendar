#!/bin/bash

# Utility Functions
# Date calculations, terminal management, and helper functions

# Date utility functions
days_in_month() {
    local month=$1
    local year=$2
    date -d "${year}-${month}-01 + 1 month - 1 day" +%d
}

get_month_name() {
    local month=$1
    local year=$2
    date -d "${year}-${month}-01" +%B
}

# Terminal management
setup_terminal() {
    tput civis
    tput smcup
    clear
    stty -echo
}

cleanup_terminal() {
    tput cnorm
    tput rmcup
    stty echo
    clear

    # Close terminal window in Hyprland when exiting
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        local window_address=$(hyprctl activewindow -j | grep -oP '"address": "\K[^"]+' | head -1)
        if [ -n "$window_address" ]; then
            hyprctl dispatch closewindow "address:$window_address" 2>/dev/null
        fi
    fi
}

# Setup Hyprland floating window
setup_hyprland() {
    # Check if running in Hyprland
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        # Get the current window address
        local window_address=$(hyprctl activewindow -j | grep -oP '"address": "\K[^"]+' | head -1)

        if [ -n "$window_address" ]; then
            # Make window float and center it with optimal size
            hyprctl dispatch togglefloating "address:$window_address" 2>/dev/null
            hyprctl dispatch resizewindowpixel "exact 600 500,address:$window_address" 2>/dev/null
            hyprctl dispatch centerwindow 2>/dev/null
        fi
    fi
}

# Minimalist splash screen
show_splash() {
    tput civis
    clear

    local color="${COLORS[BASE]}"
    local term_height=$(tput lines)
    local term_width=$(tput cols)

    local -a logo=(
        ' _           _    '
        '| |         | |   '
        '| |_   _____| | __'
        '| \ \ / / __| |/ /'
        '| |\ V /\__ \   < '
        '|_| \_/ |___/_|\_\'
        '                  '
    )

    local logo_height=7
    local top_padding=$(( (term_height - logo_height) / 1 ))

    for ((i=0; i<top_padding; i++)); do
        echo ""
    done

    for line in "${logo[@]}"; do
        local line_len=${#line}
        local left_padding=$(( (term_width - line_len) / 2 ))
        printf "%*s   " "$left_padding" ""
        printf "${color}${COLORS[DIM]}%s${COLORS[RESET]}\n" "$line"
    done

    sleep 1
}
