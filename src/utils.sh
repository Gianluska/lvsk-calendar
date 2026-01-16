#!/usr/bin/env bash

#######################################
# Utility Functions Module
# Date calculations, terminal management, and helper functions
#######################################

# ============================================================================
# DATE UTILITIES
# ============================================================================

#######################################
# Calculate days in a given month
# Uses pure bash arithmetic where possible
# Arguments:
#   $1 - Month (1-12)
#   $2 - Year (YYYY)
# Outputs:
#   Number of days in the month
#######################################
days_in_month() {
    local month="${1}"
    local year="${2}"

    # Days per month (index 0 = placeholder, 1-12 = months)
    local -a days_table=(0 31 28 31 30 31 30 31 31 30 31 30 31)

    # Handle February and leap years
    if ((month == 2)); then
        # Leap year check: divisible by 4, except centuries unless divisible by 400
        if ((year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))); then
            printf '29'
            return
        fi
    fi

    printf '%d' "${days_table[month]}"
}

#######################################
# Get full month name
# Uses date command for locale-aware names
# Arguments:
#   $1 - Month (1-12)
#   $2 - Year (YYYY)
# Outputs:
#   Full month name (e.g., "January")
#######################################
get_month_name() {
    local month="${1}"
    local year="${2}"

    # Use date for locale-aware month names
    date -d "${year}-${month}-01" +%B
}

#######################################
# Get day of week for first day of month (1=Monday, 7=Sunday)
# Arguments:
#   $1 - Month (1-12)
#   $2 - Year (YYYY)
# Outputs:
#   Day of week number (1-7, ISO format)
#######################################
get_first_dow() {
    local month="${1}"
    local year="${2}"

    date -d "${year}-${month}-01" +%u
}

#######################################
# Get ISO week number for a given date
# Arguments:
#   $1 - Day
#   $2 - Month
#   $3 - Year
# Outputs:
#   ISO week number (01-53)
#######################################
get_week_number() {
    local day="${1}"
    local month="${2}"
    local year="${3}"

    date -d "${year}-${month}-${day}" +%V 2>/dev/null || printf ''
}

# ============================================================================
# TERMINAL MANAGEMENT
# ============================================================================

# Global: Window address captured at startup for safe cleanup
declare -g LVSK_WINDOW_ADDRESS=""

#######################################
# Setup terminal for TUI mode
# Hides cursor, enables alternate screen, disables echo
#######################################
setup_terminal() {
    # Hide cursor
    tput civis
    # Enable alternate screen buffer
    tput smcup
    # Clear screen
    clear
    # Disable echo
    stty -echo
}

#######################################
# Cleanup and restore terminal
# Restores cursor, screen, echo; closes Hyprland window if applicable
#######################################
cleanup_terminal() {
    # Show cursor
    tput cnorm
    # Disable alternate screen buffer (restore original)
    tput rmcup
    # Enable echo
    stty echo
    # Clear screen
    clear

    # Close terminal window in Hyprland only when launched via launcher
    # When running directly in terminal (./lvsk-calendar), just exit without closing the terminal
    if [[ -n "${LAUNCHED_BY_LAUNCHER:-}" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -n "${LVSK_WINDOW_ADDRESS:-}" ]]; then
        # Verify window still exists before attempting to close
        # This prevents closing a different window if the calendar was already closed
        if hyprctl clients -j 2>/dev/null | grep -q "\"address\": \"${LVSK_WINDOW_ADDRESS}\""; then
            hyprctl dispatch closewindow "address:${LVSK_WINDOW_ADDRESS}" 2>/dev/null || true
        fi
    fi
}

#######################################
# Setup Hyprland floating window
# Captures window address and applies Hyprland-specific settings
# Globals:
#   LVSK_WINDOW_ADDRESS - Set to current window address
#######################################
setup_hyprland() {
    # Check if running in Hyprland
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        # Window should already be floating via windowrules
        # Small delay to ensure windowrules are applied
        sleep 0.1

        # Capture our window address at startup for safe cleanup later
        # This prevents closing a different window if focus changed
        LVSK_WINDOW_ADDRESS=$(hyprctl activewindow -j 2>/dev/null | grep -oP '"address": "\K[^"]+' | head -1) || true
    fi
}

# ============================================================================
# UI HELPERS
# ============================================================================

#######################################
# Get terminal dimensions
# Sets global variables for width and height
# Globals:
#   TERM_WIDTH - Set to terminal column count
#   TERM_HEIGHT - Set to terminal line count
#######################################
get_terminal_size() {
    TERM_WIDTH=$(tput cols)
    TERM_HEIGHT=$(tput lines)
}

#######################################
# Generate a repeated character string (pure bash)
# Arguments:
#   $1 - Character to repeat
#   $2 - Number of repetitions
# Outputs:
#   Repeated string
#######################################
repeat_char() {
    local char="${1}"
    local count="${2}"
    local result=""

    # Use printf with format string for efficiency
    printf -v result '%*s' "${count}" ''
    printf '%s' "${result// /${char}}"
}

#######################################
# Center text within a given width
# Arguments:
#   $1 - Text to center
#   $2 - Total width
# Outputs:
#   Left padding spaces count
#######################################
center_padding() {
    local text="${1}"
    local width="${2}"
    local text_len="${#text}"

    printf '%d' "$(((width - text_len) / 2))"
}

# ============================================================================
# SPLASH SCREEN
# ============================================================================

#######################################
# Display minimalist splash screen
# Shows ASCII art logo centered in terminal
# Globals:
#   COLORS - Uses color definitions
#######################################
show_splash() {
    tput civis
    clear

    local color="${COLORS[BASE]}"
    local term_height
    local term_width

    term_height=$(tput lines)
    term_width=$(tput cols)

    # ASCII art logo
    local -a logo=(
        '  |               |    '
        '  | \ \   /  __|  |  / '
        '  |  \ \ / \__ \    <  '
        ' _|   \_/  ____/ _|\_\ '
    )

    local logo_height=${#logo[@]}
    local top_padding=$(((term_height - logo_height) / 2))

    # Print empty lines for vertical centering
    local i
    for ((i = 0; i < top_padding; i++)); do
        printf '\n'
    done

    # Print logo lines centered
    local line line_len left_padding
    for line in "${logo[@]}"; do
        line_len=${#line}
        left_padding=$(((term_width - line_len) / 2))
        printf '%*s' "${left_padding}" ''
        printf '%b%b%s%b\n' "${color}" "${COLORS[DIM]}" "${line}" "${COLORS[RESET]}"
    done

    sleep 1
}
