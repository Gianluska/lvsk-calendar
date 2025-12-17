#!/usr/bin/env bash

#######################################
# Configuration and Constants Module
# Stores all color definitions, character mappings, and global state
#######################################

# ============================================================================
# COLOR SCHEMES
# ============================================================================

#######################################
# Apply a predefined color scheme
# Arguments:
#   $1 - Scheme name (monochrome, pastel, nord, dracula, gruvbox)
# Globals:
#   COLORS - Modified with scheme colors
#######################################
apply_color_scheme() {
    local scheme="${1:-monochrome}"

    case "${scheme}" in
        monochrome)
            # Warm pastel monochrome - elegant and minimalist with better contrast
            COLORS[BASE]='\033[38;5;253m'
            COLORS[BASE_DIM]='\033[38;5;250m'
            COLORS[BASE_DIMMER]='\033[38;5;245m'
            COLORS[ACCENT]='\033[38;5;254m'
            COLORS[ACCENT_BRIGHT]='\033[38;5;255m'
            COLORS[SUBTLE]='\033[38;5;242m'
            COLORS[HIGHLIGHT]='\033[38;5;255m'
            COLORS[HIGHLIGHT_BG]='\033[48;5;236m'
            COLORS[BG]='\033[38;5;236m'
            ;;
        pastel)
            # Soft pastel colors
            COLORS[BASE]='\033[38;5;189m'
            COLORS[BASE_DIM]='\033[38;5;146m'
            COLORS[BASE_DIMMER]='\033[38;5;181m'
            COLORS[ACCENT]='\033[38;5;225m'
            COLORS[ACCENT_BRIGHT]='\033[38;5;229m'
            COLORS[SUBTLE]='\033[38;5;145m'
            COLORS[HIGHLIGHT]='\033[38;5;219m'
            COLORS[HIGHLIGHT_BG]='\033[48;5;235m'
            COLORS[BG]='\033[38;5;236m'
            ;;
        nord)
            # Nord theme colors
            COLORS[BASE]='\033[38;5;253m'
            COLORS[BASE_DIM]='\033[38;5;252m'
            COLORS[BASE_DIMMER]='\033[38;5;245m'
            COLORS[ACCENT]='\033[38;5;109m'
            COLORS[ACCENT_BRIGHT]='\033[38;5;116m'
            COLORS[SUBTLE]='\033[38;5;242m'
            COLORS[HIGHLIGHT]='\033[38;5;110m'
            COLORS[HIGHLIGHT_BG]='\033[48;5;236m'
            COLORS[BG]='\033[38;5;236m'
            ;;
        dracula)
            # Dracula theme colors
            COLORS[BASE]='\033[38;5;255m'
            COLORS[BASE_DIM]='\033[38;5;248m'
            COLORS[BASE_DIMMER]='\033[38;5;240m'
            COLORS[ACCENT]='\033[38;5;141m'
            COLORS[ACCENT_BRIGHT]='\033[38;5;212m'
            COLORS[SUBTLE]='\033[38;5;61m'
            COLORS[HIGHLIGHT]='\033[38;5;228m'
            COLORS[HIGHLIGHT_BG]='\033[48;5;236m'
            COLORS[BG]='\033[38;5;236m'
            ;;
        gruvbox)
            # Gruvbox theme colors
            COLORS[BASE]='\033[38;5;223m'
            COLORS[BASE_DIM]='\033[38;5;250m'
            COLORS[BASE_DIMMER]='\033[38;5;243m'
            COLORS[ACCENT]='\033[38;5;214m'
            COLORS[ACCENT_BRIGHT]='\033[38;5;229m'
            COLORS[SUBTLE]='\033[38;5;239m'
            COLORS[HIGHLIGHT]='\033[38;5;142m'
            COLORS[HIGHLIGHT_BG]='\033[48;5;237m'
            COLORS[BG]='\033[38;5;237m'
            ;;
        *)
            # Default to monochrome if unknown scheme
            apply_color_scheme "monochrome"
            return
            ;;
    esac
}

# ============================================================================
# GLOBAL DECLARATIONS
# ============================================================================

# Color palette - Base styles (always available)
declare -gA COLORS=(
    [RESET]='\033[0m'
    [BOLD]='\033[1m'
    [DIM]='\033[2m'
    [ITALIC]='\033[3m'
    [UNDERLINE]='\033[4m'
)

# Box-drawing and indicator characters
declare -gA CHAR=(
    # Borders
    [h]='─'
    [v]='│'
    [tl]='╭'
    [tr]='╮'
    [bl]='╰'
    [br]='╯'
    [h_heavy]='━'
    [v_light]='┆'
    # Indicators
    [dot]='·'
    [circle]='○'
    [filled_circle]='●'
    [bar]='▏'
    [marker]='┃'
    [diamond]='◆'
    [square]='▪'
    [bullet]='•'
    [star]='★'
)

# Global state variables - initialized with current date
declare -g CURRENT_MONTH
declare -g CURRENT_YEAR
declare -g TODAY_DAY
declare -g SELECTED_DAY
declare -g FIRST_RENDER=1

# Initialize date values (avoid subshell with printf)
printf -v CURRENT_MONTH '%(%m)T' -1
CURRENT_MONTH="${CURRENT_MONTH#0}"  # Remove leading zero
printf -v CURRENT_YEAR '%(%Y)T' -1
printf -v TODAY_DAY '%(%d)T' -1
TODAY_DAY="${TODAY_DAY#0}"  # Remove leading zero
SELECTED_DAY="${TODAY_DAY}"

# Layout constants (can be overridden by user config)
declare -g HEADER_FRAME_WIDTH=40
declare -g FOOTER_FRAME_WIDTH=52
declare -g CALENDAR_GRID_WIDTH=38

# Behavior settings (can be overridden by user config)
declare -g SKIP_SPLASH="false"

# Holidays settings (can be overridden by user config)
declare -g HOLIDAYS_ENABLED="true"
declare -g COUNTRY_CODE=""

# ============================================================================
# VALIDATION HELPERS
# ============================================================================

#######################################
# Validate ANSI 256 color code (0-255)
# Arguments:
#   $1 - Value to validate
# Returns:
#   0 if valid, 1 otherwise
#######################################
_is_valid_ansi256() {
    local value="${1}"
    # Must be numeric and in range 0-255
    [[ "${value}" =~ ^[0-9]+$ && "${value}" -ge 0 && "${value}" -le 255 ]]
}

#######################################
# Validate hex color (with or without #)
# Arguments:
#   $1 - Value to validate
# Returns:
#   0 if valid, 1 otherwise
#######################################
_is_valid_hex() {
    local value="${1#\#}"  # Remove # if present
    [[ ${#value} -eq 6 && "${value}" =~ ^[0-9A-Fa-f]+$ ]]
}

#######################################
# Validate boolean string
# Arguments:
#   $1 - Value to validate
# Returns:
#   0 if valid, 1 otherwise
#######################################
_is_valid_bool() {
    local value="${1,,}"  # Convert to lowercase
    [[ "${value}" == "true" || "${value}" == "false" ]]
}

#######################################
# Validate positive integer
# Arguments:
#   $1 - Value to validate
# Returns:
#   0 if valid, 1 otherwise
#######################################
_is_positive_int() {
    local value="${1}"
    [[ "${value}" =~ ^[1-9][0-9]*$ ]]
}

# ============================================================================
# USER CONFIGURATION
# ============================================================================

#######################################
# Convert color value to ANSI escape sequence
# Supports: hex (#RRGGBB or RRGGBB), ANSI 256 codes (0-255)
# Arguments:
#   $1 - Color value (hex or ANSI code)
#   $2 - Type: 'fg' (foreground) or 'bg' (background)
# Outputs:
#   ANSI escape sequence string (empty on invalid input)
#######################################
parse_color() {
    local value="${1}"
    local type="${2:-fg}"

    # Empty value check
    [[ -z "${value}" ]] && return 1

    # Remove # prefix if present (pure bash - no external commands)
    value="${value#\#}"

    # Check if it's a valid hex color (6 characters, valid hex)
    if _is_valid_hex "${value}"; then
        # Convert hex to RGB using arithmetic expansion
        local r=$((16#${value:0:2}))
        local g=$((16#${value:2:2}))
        local b=$((16#${value:4:2}))

        if [[ "${type}" == "bg" ]]; then
            printf '\033[48;2;%d;%d;%dm' "${r}" "${g}" "${b}"
        else
            printf '\033[38;2;%d;%d;%dm' "${r}" "${g}" "${b}"
        fi
    elif _is_valid_ansi256 "${value}"; then
        # Valid ANSI 256 code
        if [[ "${type}" == "bg" ]]; then
            printf '\033[48;5;%sm' "${value}"
        else
            printf '\033[38;5;%sm' "${value}"
        fi
    else
        # Invalid color value - return empty (caller should handle)
        return 1
    fi
}

#######################################
# Trim whitespace from string (pure bash)
# Arguments:
#   $1 - String to trim
# Outputs:
#   Trimmed string
#######################################
_trim() {
    local str="${1}"
    # Remove leading whitespace
    str="${str#"${str%%[![:space:]]*}"}"
    # Remove trailing whitespace
    str="${str%"${str##*[![:space:]]}"}"
    printf '%s' "${str}"
}

#######################################
# Parse a config file (key=value format)
# Validates input and ignores invalid values
# Arguments:
#   $1 - Path to config file
# Globals:
#   Various - Sets config variables based on file contents
#######################################
parse_config_file() {
    local config_file="${1}"

    [[ ! -f "${config_file}" ]] && return 1

    local key value line parsed_color

    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip empty lines and comments
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

        # Skip lines without =
        [[ "${line}" != *"="* ]] && continue

        # Split on first =
        key="${line%%=*}"
        value="${line#*=}"

        # Trim whitespace (pure bash)
        key="$(_trim "${key}")"
        value="$(_trim "${value}")"

        # Skip empty values
        [[ -z "${value}" ]] && continue

        # Apply configuration based on key (with validation)
        case "${key}" in
            color_scheme)        COLOR_SCHEME="${value}" ;;
            background_style)    BACKGROUND_STYLE="${value}" ;;

            # Integer settings (validate before applying)
            header_frame_width)
                _is_positive_int "${value}" && HEADER_FRAME_WIDTH="${value}"
                ;;
            footer_frame_width)
                _is_positive_int "${value}" && FOOTER_FRAME_WIDTH="${value}"
                ;;
            calendar_grid_width)
                _is_positive_int "${value}" && CALENDAR_GRID_WIDTH="${value}"
                ;;

            # Boolean settings (validate before applying)
            skip_splash)
                _is_valid_bool "${value}" && SKIP_SPLASH="${value,,}"
                ;;
            holidays_enabled)
                _is_valid_bool "${value}" && HOLIDAYS_ENABLED="${value,,}"
                ;;

            # Country code (uppercase 2-letter)
            country_code)
                [[ "${value}" =~ ^[A-Za-z]{2}$ ]] && COUNTRY_CODE="${value^^}"
                ;;

            # Custom colors (hex #RRGGBB or ANSI 256 codes)
            # Only apply if parse_color succeeds
            color_base)
                parsed_color="$(parse_color "${value}" fg)" && COLORS[BASE]="${parsed_color}"
                ;;
            color_base_dim)
                parsed_color="$(parse_color "${value}" fg)" && COLORS[BASE_DIM]="${parsed_color}"
                ;;
            color_base_dimmer)
                parsed_color="$(parse_color "${value}" fg)" && COLORS[BASE_DIMMER]="${parsed_color}"
                ;;
            color_accent)
                parsed_color="$(parse_color "${value}" fg)" && COLORS[ACCENT]="${parsed_color}"
                ;;
            color_accent_bright)
                parsed_color="$(parse_color "${value}" fg)" && COLORS[ACCENT_BRIGHT]="${parsed_color}"
                ;;
            color_subtle)
                parsed_color="$(parse_color "${value}" fg)" && COLORS[SUBTLE]="${parsed_color}"
                ;;
            color_highlight)
                parsed_color="$(parse_color "${value}" fg)" && COLORS[HIGHLIGHT]="${parsed_color}"
                ;;
            color_highlight_bg)
                parsed_color="$(parse_color "${value}" bg)" && COLORS[HIGHLIGHT_BG]="${parsed_color}"
                ;;

            # Custom characters (single character validation)
            char_h)              [[ ${#value} -le 3 ]] && CHAR[h]="${value}" ;;
            char_v)              [[ ${#value} -le 3 ]] && CHAR[v]="${value}" ;;
            char_tl)             [[ ${#value} -le 3 ]] && CHAR[tl]="${value}" ;;
            char_tr)             [[ ${#value} -le 3 ]] && CHAR[tr]="${value}" ;;
            char_bl)             [[ ${#value} -le 3 ]] && CHAR[bl]="${value}" ;;
            char_br)             [[ ${#value} -le 3 ]] && CHAR[br]="${value}" ;;
            char_dot)            [[ ${#value} -le 3 ]] && CHAR[dot]="${value}" ;;
            char_circle)         [[ ${#value} -le 3 ]] && CHAR[circle]="${value}" ;;
            char_filled_circle)  [[ ${#value} -le 3 ]] && CHAR[filled_circle]="${value}" ;;
            char_marker)         [[ ${#value} -le 3 ]] && CHAR[marker]="${value}" ;;
        esac
    done < "${config_file}"
}

#######################################
# Load user configuration
# Creates config directory and copies defaults if needed
# Globals:
#   Various - Sets config from user file
#######################################
load_user_config() {
    local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/lvsk-calendar"
    local user_config="${config_dir}/config"
    local backgrounds_dir="${config_dir}/backgrounds"

    # Create directories if they don't exist
    [[ ! -d "${config_dir}" ]] && mkdir -p "${config_dir}"
    [[ ! -d "${backgrounds_dir}" ]] && mkdir -p "${backgrounds_dir}"

    # If user config doesn't exist, create it from example
    if [[ ! -f "${user_config}" ]]; then
        local example_config=""

        # Try to find example config (installed location first, then development)
        if [[ -f "/usr/share/doc/lvsk-calendar/config.example" ]]; then
            example_config="/usr/share/doc/lvsk-calendar/config.example"
        elif [[ -n "${SRC_DIR:-}" && -f "${SRC_DIR}/../config.example" ]]; then
            example_config="${SRC_DIR}/../config.example"
        fi

        # Copy example to user config if found
        if [[ -n "${example_config}" && -f "${example_config}" ]]; then
            cp "${example_config}" "${user_config}" 2>/dev/null || true
        fi
    fi

    # Copy builtin backgrounds if they don't exist
    local source_backgrounds_dir=""
    if [[ -d "/usr/share/doc/lvsk-calendar/backgrounds" ]]; then
        source_backgrounds_dir="/usr/share/doc/lvsk-calendar/backgrounds"
    elif [[ -n "${SRC_DIR:-}" && -d "${SRC_DIR}/../backgrounds" ]]; then
        source_backgrounds_dir="${SRC_DIR}/../backgrounds"
    fi

    if [[ -n "${source_backgrounds_dir}" ]]; then
        local bg_file bg_name
        for bg_file in "${source_backgrounds_dir}"/*.sh; do
            [[ -f "${bg_file}" ]] || continue
            bg_name="${bg_file##*/}"
            if [[ ! -f "${backgrounds_dir}/${bg_name}" ]]; then
                cp "${bg_file}" "${backgrounds_dir}/${bg_name}" 2>/dev/null || true
            fi
        done
    fi

    # Parse user configuration if it exists
    if [[ -f "${user_config}" ]]; then
        # First pass: get color scheme
        parse_config_file "${user_config}"
        # Apply color scheme
        apply_color_scheme "${COLOR_SCHEME:-monochrome}"
        # Second pass: override with custom colors
        parse_config_file "${user_config}"
    fi
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Set default color scheme
declare -g COLOR_SCHEME="${COLOR_SCHEME:-monochrome}"

# Set default background style
declare -g BACKGROUND_STYLE="${BACKGROUND_STYLE:-orbital}"

# Apply default color scheme
apply_color_scheme "${COLOR_SCHEME}"

# Load user configuration (will override defaults)
load_user_config
