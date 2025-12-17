#!/usr/bin/env bash

#######################################
# Calendar Component
# Displays the calendar grid with week numbers and visual indicators
#######################################

# Render-cycle cache (set once per draw_calendar call)
declare -g _RENDER_MONTH_NOW=""
declare -g _RENDER_YEAR_NOW=""

#######################################
# Draw the main calendar grid
# Displays up to 6 weeks with ISO week numbers
# Positions at lines 10-21 of terminal
# Globals:
#   CURRENT_MONTH - Current month
#   CURRENT_YEAR - Current year
#   CALENDAR_GRID_WIDTH - Width of calendar grid
#   COLORS - Color definitions
#   CHAR - Character definitions
#######################################
draw_calendar() {
    # Cache current date for this render cycle (avoid repeated calls)
    printf -v _RENDER_MONTH_NOW '%(%m)T' -1
    _RENDER_MONTH_NOW="${_RENDER_MONTH_NOW#0}"
    printf -v _RENDER_YEAR_NOW '%(%Y)T' -1

    local days
    days=$(days_in_month "${CURRENT_MONTH}" "${CURRENT_YEAR}")

    local first_day
    first_day=$(get_first_dow "${CURRENT_MONTH}" "${CURRENT_YEAR}")

    local day_num=1
    local term_width
    term_width=$(tput cols)

    local grid_width="${CALENDAR_GRID_WIDTH}"
    local left_pos=$(((term_width - grid_width) / 2))
    local line_num=10  # Starting line for calendar grid

    # Draw up to 6 weeks
    local week dow should_draw week_day week_num
    for ((week = 0; week < 6; week++)); do
        ((day_num > days)) && break

        tput cup "${line_num}" "${left_pos}"

        # Calculate week number for display
        if ((week == 0)); then
            week_day=1
        else
            week_day="${day_num}"
        fi

        week_num=$(get_week_number "${week_day}" "${CURRENT_MONTH}" "${CURRENT_YEAR}")

        # Draw week number column
        if [[ -n "${week_num}" ]]; then
            printf '%b%2s%b %b%s%b  ' \
                "${COLORS[BASE_DIMMER]}" \
                "${week_num}" \
                "${COLORS[RESET]}" \
                "${COLORS[SUBTLE]}" \
                "${CHAR[v_light]}" \
                "${COLORS[RESET]}"
        else
            printf '      '
        fi

        # Draw 7 days per week
        for ((dow = 1; dow <= 7; dow++)); do
            should_draw=0

            if ((week == 0)); then
                ((dow >= first_day)) && should_draw=1
            else
                should_draw=1
            fi

            if ((should_draw && day_num <= days)); then
                _render_day "${day_num}" "${dow}"
                day_num=$((day_num + 1))
            else
                # Empty cell with subtle indicator
                printf '%b%b  %s%b' \
                    "${COLORS[SUBTLE]}" \
                    "${COLORS[DIM]}" \
                    "${CHAR[dot]}" \
                    "${COLORS[RESET]}"
            fi

            # Spacing between columns (except last)
            ((dow < 7)) && printf '  '
        done

        # Move to next week line (skip blank line for visual spacing)
        line_num=$((line_num + 2))
    done
}

#######################################
# Render a single day cell with appropriate styling
# Arguments:
#   $1 - Day number (1-31)
#   $2 - Day of week (1-7, where 1=Monday)
# Globals:
#   TODAY_DAY - Today's day number
#   SELECTED_DAY - Currently selected day
#   CURRENT_MONTH - Current month
#   CURRENT_YEAR - Current year
#   _RENDER_MONTH_NOW - Cached current month (set by draw_calendar)
#   _RENDER_YEAR_NOW - Cached current year (set by draw_calendar)
#   COLORS - Color definitions
#   CHAR - Character definitions
#######################################
_render_day() {
    local day_num="${1}"
    local dow="${2}"

    local is_today=0
    local is_selected=0
    local is_holiday_day=0

    # Check if this is today (using cached values from draw_calendar)
    if ((day_num == TODAY_DAY && CURRENT_MONTH == _RENDER_MONTH_NOW && CURRENT_YEAR == _RENDER_YEAR_NOW)); then
        is_today=1
    fi

    # Check if selected
    ((day_num == SELECTED_DAY)) && is_selected=1

    # Check if holiday
    if is_holiday "${day_num}" "${CURRENT_MONTH}" 2>/dev/null; then
        is_holiday_day=1
    fi

    # Determine the marker character based on state
    # Priority: selected > today > holiday > weekend > weekday
    local marker=" "
    local marker_color="${COLORS[RESET]}"

    if ((is_selected)); then
        marker="${CHAR[diamond]}"
        marker_color="${COLORS[ACCENT]}"
    elif ((is_today)); then
        marker="${CHAR[circle]}"
        marker_color="${COLORS[BASE]}"
    elif ((is_holiday_day)); then
        marker="${CHAR[star]}"
        marker_color="${COLORS[ACCENT_BRIGHT]}"
    elif ((dow >= 6)); then
        marker="${CHAR[dot]}"
        marker_color="${COLORS[SUBTLE]}"
    fi

    # Render based on state priority: selected > today > holiday > weekend > weekday
    if ((is_selected)); then
        # Selected day - bold with diamond marker
        printf '%b%b%2d%b%b%s%b' \
            "${COLORS[HIGHLIGHT]}" \
            "${COLORS[BOLD]}" \
            "${day_num}" \
            "${COLORS[RESET]}" \
            "${marker_color}" \
            "${marker}" \
            "${COLORS[RESET]}"
    elif ((is_today)); then
        # Today - highlighted with circle marker
        printf '%b%b%2d%b%b%s%b' \
            "${COLORS[ACCENT_BRIGHT]}" \
            "${COLORS[BOLD]}" \
            "${day_num}" \
            "${COLORS[RESET]}" \
            "${marker_color}" \
            "${marker}" \
            "${COLORS[RESET]}"
    elif ((is_holiday_day)); then
        # Holiday - accent color with bullet marker
        printf '%b%b%2d%b%b%s%b' \
            "${COLORS[ACCENT]}" \
            "${COLORS[BOLD]}" \
            "${day_num}" \
            "${COLORS[RESET]}" \
            "${marker_color}" \
            "${marker}" \
            "${COLORS[RESET]}"
    elif ((dow >= 6)); then
        # Weekend - dimmed with dot marker
        printf '%b%2d%b%b%s%b' \
            "${COLORS[BASE_DIMMER]}" \
            "${day_num}" \
            "${COLORS[RESET]}" \
            "${marker_color}" \
            "${marker}" \
            "${COLORS[RESET]}"
    else
        # Regular weekday - no marker
        printf '%b%2d%b%s' \
            "${COLORS[BASE]}" \
            "${day_num}" \
            "${COLORS[RESET]}" \
            "${marker}"
    fi
}
