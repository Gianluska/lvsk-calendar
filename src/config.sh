#!/bin/bash

# Configuration and Constants
# Stores all color definitions, character mappings, and global state

# Detect terminal colors or use elegant fallback
detect_colors() {
    # Try to detect background brightness
    # Fallback to warm pastel monochrome palette

    # Warm pastel monochrome - elegant and minimalist with better contrast
    COLORS[BASE]='\033[38;5;253m'           # Very light warm gray
    COLORS[BASE_DIM]='\033[38;5;250m'       # Light warm gray
    COLORS[BASE_DIMMER]='\033[38;5;245m'    # Medium warm gray
    COLORS[ACCENT]='\033[38;5;254m'         # Almost white
    COLORS[ACCENT_BRIGHT]='\033[38;5;255m'  # Pure white
    COLORS[SUBTLE]='\033[38;5;242m'         # Subtle gray with better contrast

    # Today/selected highlights - subtle but present
    COLORS[HIGHLIGHT]='\033[38;5;255m'      # Pure white
    COLORS[HIGHLIGHT_BG]='\033[48;5;236m'   # Subtle dark background
}

# Color palette
declare -gA COLORS=(
    [RESET]='\033[0m'
    [BOLD]='\033[1m'
    [DIM]='\033[2m'
    [ITALIC]='\033[3m'
)

# Characters
declare -gA CHAR=(
    # borders
    [h]='─'
    [v]='│'
    [tl]='╭'
    [tr]='╮'
    [bl]='╰'
    [br]='╯'
    [h_heavy]='━'
    [v_light]='┆'

    # indicators
    [dot]='·'
    [circle]='○'
    [filled_circle]='●'
    [bar]='▏'
    [marker]='┃'
    [diamond]='◆'
    [square]='▪'
    [bullet]='•'
)

# Global state variables
declare -g CURRENT_MONTH=$(date +%m)
declare -g CURRENT_YEAR=$(date +%Y)
declare -g TODAY_DAY=$(date +%d)
declare -g SELECTED_DAY=$TODAY_DAY
declare -g FIRST_RENDER=1

# Layout constants
declare -g HEADER_FRAME_WIDTH=40
declare -g FOOTER_FRAME_WIDTH=52
declare -g CALENDAR_GRID_WIDTH=38

# Initialize colors
detect_colors
