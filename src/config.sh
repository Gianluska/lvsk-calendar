#!/bin/bash

# Configuration and Constants
# Stores all color definitions, character mappings, and global state

# ============================================================================
# COLOR SCHEMES
# ============================================================================

apply_color_scheme() {
    local scheme="${1:-monochrome}"

    case "$scheme" in
        "monochrome")
            # Warm pastel monochrome - elegant and minimalist with better contrast
            COLORS[BASE]='\033[38;5;253m'           # Very light warm gray
            COLORS[BASE_DIM]='\033[38;5;250m'       # Light warm gray
            COLORS[BASE_DIMMER]='\033[38;5;245m'    # Medium warm gray
            COLORS[ACCENT]='\033[38;5;254m'         # Almost white
            COLORS[ACCENT_BRIGHT]='\033[38;5;255m'  # Pure white
            COLORS[SUBTLE]='\033[38;5;242m'         # Subtle gray with better contrast
            COLORS[HIGHLIGHT]='\033[38;5;255m'      # Pure white
            COLORS[HIGHLIGHT_BG]='\033[48;5;236m'   # Subtle dark background
            ;;

        "pastel")
            # Soft pastel colors
            COLORS[BASE]='\033[38;5;189m'           # Lavender
            COLORS[BASE_DIM]='\033[38;5;146m'       # Soft green
            COLORS[BASE_DIMMER]='\033[38;5;181m'    # Dusty rose
            COLORS[ACCENT]='\033[38;5;225m'         # Light pink
            COLORS[ACCENT_BRIGHT]='\033[38;5;229m'  # Cream
            COLORS[SUBTLE]='\033[38;5;145m'         # Muted teal
            COLORS[HIGHLIGHT]='\033[38;5;219m'      # Pink
            COLORS[HIGHLIGHT_BG]='\033[48;5;235m'   # Dark bg
            ;;

        "nord")
            # Nord theme colors
            COLORS[BASE]='\033[38;5;253m'           # Snow storm
            COLORS[BASE_DIM]='\033[38;5;252m'       # Polar night light
            COLORS[BASE_DIMMER]='\033[38;5;245m'    # Polar night
            COLORS[ACCENT]='\033[38;5;109m'         # Frost blue-green
            COLORS[ACCENT_BRIGHT]='\033[38;5;116m'  # Frost cyan
            COLORS[SUBTLE]='\033[38;5;242m'         # Dark gray
            COLORS[HIGHLIGHT]='\033[38;5;110m'      # Frost blue
            COLORS[HIGHLIGHT_BG]='\033[48;5;236m'   # Dark bg
            ;;

        "dracula")
            # Dracula theme colors
            COLORS[BASE]='\033[38;5;255m'           # Foreground
            COLORS[BASE_DIM]='\033[38;5;248m'       # Comment
            COLORS[BASE_DIMMER]='\033[38;5;240m'    # Darker comment
            COLORS[ACCENT]='\033[38;5;141m'         # Purple
            COLORS[ACCENT_BRIGHT]='\033[38;5;212m'  # Pink
            COLORS[SUBTLE]='\033[38;5;61m'          # Muted purple
            COLORS[HIGHLIGHT]='\033[38;5;228m'      # Yellow
            COLORS[HIGHLIGHT_BG]='\033[48;5;236m'   # Selection
            ;;

        "gruvbox")
            # Gruvbox theme colors
            COLORS[BASE]='\033[38;5;223m'           # Light fg
            COLORS[BASE_DIM]='\033[38;5;250m'       # Gray
            COLORS[BASE_DIMMER]='\033[38;5;243m'    # Dark gray
            COLORS[ACCENT]='\033[38;5;214m'         # Orange
            COLORS[ACCENT_BRIGHT]='\033[38;5;229m'  # Yellow
            COLORS[SUBTLE]='\033[38;5;239m'         # Dark bg
            COLORS[HIGHLIGHT]='\033[38;5;142m'      # Green
            COLORS[HIGHLIGHT_BG]='\033[48;5;237m'   # Dark bg
            ;;

        *)
            # Default to monochrome if unknown scheme
            apply_color_scheme "monochrome"
            ;;
    esac
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

# Layout constants (can be overridden by user config)
declare -g HEADER_FRAME_WIDTH=40
declare -g FOOTER_FRAME_WIDTH=52
declare -g CALENDAR_GRID_WIDTH=38

# Behavior settings (can be overridden by user config)
declare -g SKIP_SPLASH=false

# ============================================================================
# USER CONFIGURATION
# ============================================================================

load_user_config() {
    local user_config="${XDG_CONFIG_HOME:-$HOME/.config}/lvsk-calendar/config.sh"
    local config_dir="$(dirname "$user_config")"
    local backgrounds_dir="${config_dir}/backgrounds"

    # Create config directory if it doesn't exist
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
    fi

    # Create backgrounds directory if it doesn't exist
    if [ ! -d "$backgrounds_dir" ]; then
        mkdir -p "$backgrounds_dir"
    fi

    # If user config doesn't exist, create it from example
    if [ ! -f "$user_config" ]; then
        local example_config=""

        # Try to find example config (installed location first, then development)
        if [ -f "/usr/share/doc/lvsk-calendar/config.example.sh" ]; then
            example_config="/usr/share/doc/lvsk-calendar/config.example.sh"
        elif [ -f "${SRC_DIR}/../config.example.sh" ]; then
            example_config="${SRC_DIR}/../config.example.sh"
        fi

        # Copy example to user config if found
        if [ -n "$example_config" ] && [ -f "$example_config" ]; then
            cp "$example_config" "$user_config" 2>/dev/null
        fi
    fi

    # Copy builtin backgrounds if they don't exist
    local source_backgrounds_dir=""
    if [ -d "/usr/share/doc/lvsk-calendar/backgrounds" ]; then
        source_backgrounds_dir="/usr/share/doc/lvsk-calendar/backgrounds"
    elif [ -d "${SRC_DIR}/../backgrounds" ]; then
        source_backgrounds_dir="${SRC_DIR}/../backgrounds"
    fi

    if [ -n "$source_backgrounds_dir" ]; then
        for bg_file in "$source_backgrounds_dir"/*.sh; do
            if [ -f "$bg_file" ]; then
                local bg_name="$(basename "$bg_file")"
                if [ ! -f "$backgrounds_dir/$bg_name" ]; then
                    cp "$bg_file" "$backgrounds_dir/$bg_name" 2>/dev/null
                fi
            fi
        done
    fi

    # Load user configuration if it exists
    if [ -f "$user_config" ]; then
        source "$user_config"
    fi
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Set default color scheme
COLOR_SCHEME="${COLOR_SCHEME:-monochrome}"

# Set default background style
# All backgrounds are loaded from ~/.config/lvsk-calendar/backgrounds/
BACKGROUND_STYLE="${BACKGROUND_STYLE:-orbital}"

# Load user configuration
load_user_config

# Apply color scheme (user config can override COLOR_SCHEME)
apply_color_scheme "$COLOR_SCHEME"
