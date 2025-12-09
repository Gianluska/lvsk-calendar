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
declare -g CURRENT_MONTH=$(date +%-m)
declare -g CURRENT_YEAR=$(date +%Y)
declare -g TODAY_DAY=$(date +%-d)
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

# Convert color value to ANSI escape sequence
# Supports: hex (#RRGGBB or RRGGBB), ANSI 256 codes (0-255)
parse_color() {
    local value="$1"
    local type="${2:-fg}"  # fg or bg

    # Remove # if present
    value="${value#\#}"

    # Check if it's a hex color (6 characters, valid hex)
    if [[ ${#value} -eq 6 && "$value" =~ ^[0-9A-Fa-f]+$ ]]; then
        # Convert hex to RGB
        local r=$((16#${value:0:2}))
        local g=$((16#${value:2:2}))
        local b=$((16#${value:4:2}))

        if [[ "$type" == "bg" ]]; then
            echo "\033[48;2;${r};${g};${b}m"
        else
            echo "\033[38;2;${r};${g};${b}m"
        fi
    else
        # Assume ANSI 256 code
        if [[ "$type" == "bg" ]]; then
            echo "\033[48;5;${value}m"
        else
            echo "\033[38;5;${value}m"
        fi
    fi
}

# Parse a .config file (key=value format)
parse_config_file() {
    local config_file="$1"

    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

        # Trim whitespace
        key=$(echo "$key" | tr -d '[:space:]')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Apply configuration based on key
        case "$key" in
            color_scheme)       COLOR_SCHEME="$value" ;;
            background_style)   BACKGROUND_STYLE="$value" ;;
            header_frame_width) HEADER_FRAME_WIDTH="$value" ;;
            footer_frame_width) FOOTER_FRAME_WIDTH="$value" ;;
            calendar_grid_width) CALENDAR_GRID_WIDTH="$value" ;;
            skip_splash)        SKIP_SPLASH="$value" ;;

            # Custom colors (hex #RRGGBB or ANSI 256 codes)
            color_base)         COLORS[BASE]="$(parse_color "$value" fg)" ;;
            color_base_dim)     COLORS[BASE_DIM]="$(parse_color "$value" fg)" ;;
            color_base_dimmer)  COLORS[BASE_DIMMER]="$(parse_color "$value" fg)" ;;
            color_accent)       COLORS[ACCENT]="$(parse_color "$value" fg)" ;;
            color_accent_bright) COLORS[ACCENT_BRIGHT]="$(parse_color "$value" fg)" ;;
            color_subtle)       COLORS[SUBTLE]="$(parse_color "$value" fg)" ;;
            color_highlight)    COLORS[HIGHLIGHT]="$(parse_color "$value" fg)" ;;
            color_highlight_bg) COLORS[HIGHLIGHT_BG]="$(parse_color "$value" bg)" ;;

            # Custom characters
            char_h)             CHAR[h]="$value" ;;
            char_v)             CHAR[v]="$value" ;;
            char_tl)            CHAR[tl]="$value" ;;
            char_tr)            CHAR[tr]="$value" ;;
            char_bl)            CHAR[bl]="$value" ;;
            char_br)            CHAR[br]="$value" ;;
            char_dot)           CHAR[dot]="$value" ;;
            char_circle)        CHAR[circle]="$value" ;;
            char_filled_circle) CHAR[filled_circle]="$value" ;;
            char_marker)        CHAR[marker]="$value" ;;
        esac
    done < "$config_file"
}

load_user_config() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lvsk-calendar"
    local user_config="${config_dir}/config"
    local backgrounds_dir="${config_dir}/backgrounds"

    # Create config directory if it doesn't exist
    [ ! -d "$config_dir" ] && mkdir -p "$config_dir"

    # Create backgrounds directory if it doesn't exist
    [ ! -d "$backgrounds_dir" ] && mkdir -p "$backgrounds_dir"

    # If user config doesn't exist, create it from example
    if [ ! -f "$user_config" ]; then
        local example_config=""

        # Try to find example config (installed location first, then development)
        if [ -f "/usr/share/doc/lvsk-calendar/config.example" ]; then
            example_config="/usr/share/doc/lvsk-calendar/config.example"
        elif [ -f "${SRC_DIR}/../config.example" ]; then
            example_config="${SRC_DIR}/../config.example"
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

    # Parse user configuration if it exists
    if [ -f "$user_config" ]; then
        parse_config_file "$user_config"
        apply_color_scheme "$COLOR_SCHEME"
        parse_config_file "$user_config"
    fi
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Set default color scheme
COLOR_SCHEME="${COLOR_SCHEME:-monochrome}"

# Set default background style
BACKGROUND_STYLE="${BACKGROUND_STYLE:-orbital}"

# Apply defalt color scheme
apply_color_scheme "$COLOR_SCHEME"

# Load user configuration (will override defaults)
load_user_config
