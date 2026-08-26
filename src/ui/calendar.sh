#!/usr/bin/env bash

#######################################
# Calendar Component
# Builds the calendar grid with week numbers and visual indicators
#######################################

# Render-cycle cache: today's month/year, refreshed once per render so the
# "today" marker survives midnight (see render() in the entry point)
declare -g _RENDER_MONTH_NOW=""
declare -g _RENDER_YEAR_NOW=""

#######################################
# Build the main calendar grid into the frame buffer
# Displays up to 6 weeks with ISO week numbers, starting at LAYOUT_GRID_TOP
# Arguments:
#   $1 - Name of frame buffer variable
# Globals:
#   _MC_DAYS, _MC_FIRST_DOW, _MC_WEEK_NUMS - Cached month metadata
#   CALENDAR_GRID_WIDTH, TERM_COLS, COLORS, CHAR
#######################################
_build_calendar() {
    local -n __cal="${1}"

    local days="${_MC_DAYS}"
    local first_day="${_MC_FIRST_DOW}"
    local day_num=1

    local grid_width="${CALENDAR_GRID_WIDTH}"
    local left_pos=$(((TERM_COLS - grid_width) / 2))
    # Prevent negative position (small terminals)
    ((left_pos < 0)) && left_pos=0
    local line_num="${LAYOUT_GRID_TOP}"

    # Draw up to 6 weeks
    local week dow should_draw week_num
    for ((week = 0; week < 6; week++)); do
        ((day_num > days)) && break

        _bcup __cal "${line_num}" "${left_pos}"

        # Week number column (cached per month)
        week_num="${_MC_WEEK_NUMS[week]:-}"
        if [[ -n "${week_num}" ]]; then
            _bprintf __cal '%b%2s%b %b%s%b  ' \
                "${COLORS[BASE_DIMMER]}" \
                "${week_num}" \
                "${COLORS[RESET]}" \
                "${COLORS[SUBTLE]}" \
                "${CHAR[v_light]}" \
                "${COLORS[RESET]}"
        else
            _bprintf __cal '      '
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
                _build_day __cal "${day_num}" "${dow}"
                day_num=$((day_num + 1))
            else
                # Empty cell with subtle indicator
                _bprintf __cal '%b%b  %s%b' \
                    "${COLORS[SUBTLE]}" \
                    "${COLORS[DIM]}" \
                    "${CHAR[dot]}" \
                    "${COLORS[RESET]}"
            fi

            # Spacing between columns (except last)
            ((dow < 7)) && _bprintf __cal '  '
        done

        # Move to next week line (skip blank line for visual spacing)
        line_num=$((line_num + LAYOUT_GRID_STEP))
    done
}

#######################################
# Build a single day cell with appropriate styling
# State priority: selected > today > event > holiday > weekend > weekday
# Arguments:
#   $1 - Name of frame buffer variable
#   $2 - Day number (1-31)
#   $3 - Day of week (1-7, where 1=Monday)
# Globals:
#   TODAY_DAY, SELECTED_DAY, CURRENT_MONTH, CURRENT_YEAR
#   _RENDER_MONTH_NOW, _RENDER_YEAR_NOW - Cached current date
#   COLORS, CHAR
#######################################
_build_day() {
    local -n __day="${1}"
    local day_num="${2}"
    local dow="${3}"

    local is_today=0 is_selected=0 is_holiday_day=0 is_event_day=0

    # Check if this is today (using cached values refreshed per render)
    ((day_num == TODAY_DAY && CURRENT_MONTH == _RENDER_MONTH_NOW && CURRENT_YEAR == _RENDER_YEAR_NOW)) \
        && is_today=1
    ((day_num == SELECTED_DAY)) && is_selected=1
    is_holiday "${day_num}" "${CURRENT_MONTH}" && is_holiday_day=1
    is_event "${day_num}" "${CURRENT_MONTH}" && is_event_day=1

    # Resolve number color, weight and marker from the state priority
    local marker=" " marker_color="${COLORS[RESET]}"
    local num_color="${COLORS[BASE]}" bold=""

    if ((is_selected)); then
        marker="${CHAR[diamond]}"     marker_color="${COLORS[ACCENT]}"
        num_color="${COLORS[HIGHLIGHT]}"
        bold="${COLORS[BOLD]}"
    elif ((is_today)); then
        marker="${CHAR[circle]}"      marker_color="${COLORS[BASE]}"
        num_color="${COLORS[ACCENT_BRIGHT]}"
        bold="${COLORS[BOLD]}"
    elif ((is_event_day)); then
        marker="${CHAR[event]}"       marker_color="${COLORS[ACCENT]}"
        num_color="${COLORS[ACCENT]}"
        bold="${COLORS[BOLD]}"
    elif ((is_holiday_day)); then
        marker="${CHAR[star]}"        marker_color="${COLORS[ACCENT_BRIGHT]}"
        num_color="${COLORS[ACCENT]}"
        bold="${COLORS[BOLD]}"
    elif ((dow >= 6)); then
        marker="${CHAR[dot]}"         marker_color="${COLORS[SUBTLE]}"
        num_color="${COLORS[BASE_DIMMER]}"
    fi

    _bprintf __day '%b%b%2d%b%b%s%b' \
        "${num_color}" \
        "${bold}" \
        "${day_num}" \
        "${COLORS[RESET]}" \
        "${marker_color}" \
        "${marker}" \
        "${COLORS[RESET]}"
}
