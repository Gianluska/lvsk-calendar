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
    [INVERSE]='\033[7m'
)

# Box-drawing and indicator characters
# Every entry here is rendered somewhere and configurable via char_* keys
declare -gA CHAR=(
    # Borders
    [h]='─'
    [v]='│'
    [tl]='╭'
    [tr]='╮'
    [bl]='╰'
    [br]='╯'
    [v_light]='┆'
    # Indicators
    [dot]='·'
    [circle]='○'
    [diamond]='◆'
    [bullet]='•'
    [star]='★'
    [event]='▪'
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

# Layout constants (frame widths can be overridden by user config)
declare -g HEADER_FRAME_WIDTH=40
declare -g FOOTER_FRAME_WIDTH=52
declare -g CALENDAR_GRID_WIDTH=38

# Vertical layout (0-based terminal rows) and minimum usable terminal size
declare -g LAYOUT_HEADER_TOP=3      # header frame occupies rows 3-5
declare -g LAYOUT_DAYHDR_ROW=7      # weekday names
declare -g LAYOUT_DAYSEP_ROW=8      # separator under weekday names
declare -g LAYOUT_GRID_TOP=10       # first calendar week row
declare -g LAYOUT_GRID_STEP=2       # spacing between week rows
declare -g LAYOUT_INFO_ROW=22       # footer info line (events/holiday)
declare -g LAYOUT_SEP_ROW=23        # footer separator
declare -g LAYOUT_CONTROLS_ROW=24   # footer key hints
declare -g LAYOUT_MIN_ROWS=25
declare -g LAYOUT_MIN_COLS=56

# Behavior settings (can be overridden by user config)
declare -g SKIP_SPLASH="false"

# Holidays settings (can be overridden by user config)
declare -g HOLIDAYS_ENABLED="true"
declare -g COUNTRY_CODE=""

# Events settings (can be overridden by user config)
declare -g EVENTS_ENABLED="true"

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
# Convert color value to ANSI escape sequence (no forks)
# Supports: hex (#RRGGBB or RRGGBB), ANSI 256 codes (0-255)
# Arguments:
#   $1 - Name of output variable
#   $2 - Color value (hex or ANSI code)
#   $3 - Type: 'fg' (foreground) or 'bg' (background)
# Returns:
#   0 on success, 1 on invalid input (output variable left empty)
#######################################
parse_color() {
    local -n __pc="${1}"
    local __pc_value="${2}"
    local __pc_type="${3:-fg}"
    __pc=""

    # Empty value check
    [[ -z "${__pc_value}" ]] && return 1

    # Remove # prefix if present (pure bash - no external commands)
    __pc_value="${__pc_value#\#}"

    if _is_valid_hex "${__pc_value}"; then
        # Convert hex to RGB using arithmetic expansion
        local __pc_r=$((16#${__pc_value:0:2}))
        local __pc_g=$((16#${__pc_value:2:2}))
        local __pc_b=$((16#${__pc_value:4:2}))

        if [[ "${__pc_type}" == "bg" ]]; then
            printf -v __pc '\033[48;2;%d;%d;%dm' "${__pc_r}" "${__pc_g}" "${__pc_b}"
        else
            printf -v __pc '\033[38;2;%d;%d;%dm' "${__pc_r}" "${__pc_g}" "${__pc_b}"
        fi
    elif _is_valid_ansi256 "${__pc_value}"; then
        if [[ "${__pc_type}" == "bg" ]]; then
            printf -v __pc '\033[48;5;%sm' "${__pc_value}"
        else
            printf -v __pc '\033[38;5;%sm' "${__pc_value}"
        fi
    else
        return 1
    fi
}

#######################################
# Trim whitespace from string (pure bash, no forks)
# Arguments:
#   $1 - Name of output variable
#   $2 - String to trim
#######################################
_trim() {
    # Local is namespaced: with dynamic scoping, a plain local here would
    # shadow a caller's output variable of the same name
    local -n __tr="${1}"
    local __tr_s="${2}"
    # Remove leading whitespace
    __tr_s="${__tr_s#"${__tr_s%%[![:space:]]*}"}"
    # Remove trailing whitespace
    __tr="${__tr_s%"${__tr_s##*[![:space:]]}"}"
}

#######################################
# Parse a config file (key=value format) in a single pass
# Reads all keys first (last occurrence wins), applies the color scheme, then
# applies every other key so explicit colors override the scheme. Invalid
# values are validated and silently ignored, exactly as before.
# Arguments:
#   $1 - Path to config file
# Globals:
#   Various - Sets config variables based on file contents
#######################################
parse_config_file() {
    local config_file="${1}"

    [[ ! -f "${config_file}" ]] && return 1

    local -A raw=()
    local line key value

    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip empty lines and comments
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

        # Skip lines without =
        [[ "${line}" != *"="* ]] && continue

        # Split on first =, trim whitespace (pure bash)
        _trim key "${line%%=*}"
        _trim value "${line#*=}"

        # Skip empty keys/values; later duplicates override earlier ones
        [[ -z "${key}" || -z "${value}" ]] && continue
        raw["${key}"]="${value}"
    done < "${config_file}"

    # Apply the scheme first so explicit color_* overrides win below
    if [[ -n "${raw[color_scheme]:-}" ]]; then
        COLOR_SCHEME="${raw[color_scheme]}"
        apply_color_scheme "${COLOR_SCHEME}"
    fi

    local parsed_color
    for key in "${!raw[@]}"; do
        value="${raw[${key}]}"
        case "${key}" in
            color_scheme)        ;;  # applied above
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
            events_enabled)
                _is_valid_bool "${value}" && EVENTS_ENABLED="${value,,}"
                ;;

            # Country code (uppercase 2-letter)
            country_code)
                [[ "${value}" =~ ^[A-Za-z]{2}$ ]] && COUNTRY_CODE="${value^^}"
                ;;

            # Custom colors (hex #RRGGBB or ANSI 256 codes)
            # Only apply if parse_color succeeds
            color_base)
                parse_color parsed_color "${value}" fg && COLORS[BASE]="${parsed_color}"
                ;;
            color_base_dim)
                parse_color parsed_color "${value}" fg && COLORS[BASE_DIM]="${parsed_color}"
                ;;
            color_base_dimmer)
                parse_color parsed_color "${value}" fg && COLORS[BASE_DIMMER]="${parsed_color}"
                ;;
            color_accent)
                parse_color parsed_color "${value}" fg && COLORS[ACCENT]="${parsed_color}"
                ;;
            color_accent_bright)
                parse_color parsed_color "${value}" fg && COLORS[ACCENT_BRIGHT]="${parsed_color}"
                ;;
            color_subtle)
                parse_color parsed_color "${value}" fg && COLORS[SUBTLE]="${parsed_color}"
                ;;
            color_highlight)
                parse_color parsed_color "${value}" fg && COLORS[HIGHLIGHT]="${parsed_color}"
                ;;
            color_bg)
                parse_color parsed_color "${value}" fg && COLORS[BG]="${parsed_color}"
                ;;

            # Custom characters (exactly one character, so the grid stays aligned)
            char_h)        ((${#value} == 1)) && CHAR[h]="${value}" ;;
            char_v)        ((${#value} == 1)) && CHAR[v]="${value}" ;;
            char_tl)       ((${#value} == 1)) && CHAR[tl]="${value}" ;;
            char_tr)       ((${#value} == 1)) && CHAR[tr]="${value}" ;;
            char_bl)       ((${#value} == 1)) && CHAR[bl]="${value}" ;;
            char_br)       ((${#value} == 1)) && CHAR[br]="${value}" ;;
            char_v_light)  ((${#value} == 1)) && CHAR[v_light]="${value}" ;;
            char_dot)      ((${#value} == 1)) && CHAR[dot]="${value}" ;;
            char_circle)   ((${#value} == 1)) && CHAR[circle]="${value}" ;;
            char_diamond)  ((${#value} == 1)) && CHAR[diamond]="${value}" ;;
            char_bullet)   ((${#value} == 1)) && CHAR[bullet]="${value}" ;;
            char_star)     ((${#value} == 1)) && CHAR[star]="${value}" ;;
            char_event)    ((${#value} == 1)) && CHAR[event]="${value}" ;;
        esac
    done

    # A trailing rejected value must not leak a falsy status to the caller
    return 0
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

    # Create directories if they don't exist; without them we just run with defaults
    if ! mkdir -p "${config_dir}" "${backgrounds_dir}" 2>/dev/null; then
        return 0
    fi

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

    # Parse user configuration if it exists (single pass)
    if [[ -f "${user_config}" ]]; then
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

#######################################
# Initialize configuration (called explicitly by the entry point)
# Kept out of source time so the module can be sourced by tests without
# side effects (directory creation, file copies).
#######################################
config_init() {
    apply_color_scheme "${COLOR_SCHEME}"
    load_user_config
}
