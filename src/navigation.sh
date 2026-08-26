#!/usr/bin/env bash

#######################################
# Navigation Module
# Handles month and year navigation logic
#######################################

#######################################
# Refresh month metadata, clamp the selection and force a full re-render
# Shared tail of every month/year change
# Globals:
#   SELECTED_DAY - Clamped to the new month's day count
#   FIRST_RENDER - Set to 1 to force full re-render
#######################################
_clamp_and_redraw() {
    refresh_month_cache
    ((SELECTED_DAY > _MC_DAYS)) && SELECTED_DAY="${_MC_DAYS}"
    FIRST_RENDER=1
}

#######################################
# Shift the displayed month, wrapping across year boundaries
# Arguments:
#   $1 - Offset (+1 or -1)
# Globals:
#   CURRENT_MONTH, CURRENT_YEAR - Updated
#######################################
shift_month() {
    CURRENT_MONTH=$((CURRENT_MONTH + $1))

    if ((CURRENT_MONTH < 1)); then
        CURRENT_MONTH=12
        CURRENT_YEAR=$((CURRENT_YEAR - 1))
    elif ((CURRENT_MONTH > 12)); then
        CURRENT_MONTH=1
        CURRENT_YEAR=$((CURRENT_YEAR + 1))
    fi

    _clamp_and_redraw
}

#######################################
# Shift the displayed year
# Arguments:
#   $1 - Offset (+1 or -1)
# Globals:
#   CURRENT_YEAR - Updated
#######################################
shift_year() {
    CURRENT_YEAR=$((CURRENT_YEAR + $1))
    _clamp_and_redraw
}

# Directional wrappers (public API used by the input dispatcher)
prev_month() { shift_month -1; }
next_month() { shift_month 1; }
prev_year()  { shift_year -1; }
next_year()  { shift_year 1; }

#######################################
# Navigate to today's date
# Resets view to current month/year and selects today
# Globals:
#   CURRENT_MONTH - Set to current month
#   CURRENT_YEAR - Set to current year
#   SELECTED_DAY - Set to today's day
#######################################
goto_today() {
    # Use printf builtin for date (bash 4.2+) - avoids subshell
    printf -v CURRENT_MONTH '%(%m)T' -1
    CURRENT_MONTH="${CURRENT_MONTH#0}"  # Remove leading zero

    printf -v CURRENT_YEAR '%(%Y)T' -1

    printf -v SELECTED_DAY '%(%d)T' -1
    SELECTED_DAY="${SELECTED_DAY#0}"  # Remove leading zero

    # Force full re-render when changing month
    FIRST_RENDER=1
}

#######################################
# Handle day navigation overflow/underflow
# Automatically switches to prev/next month when selection goes out of
# bounds, preserving the day-of-week offset (moving up a week from day 3
# lands on the same weekday in the previous month, not on its last day).
# Globals:
#   SELECTED_DAY - Adjusted to valid range, may trigger month change
#   CURRENT_MONTH - May change via shift_month
#   CURRENT_YEAR - May change via shift_month
#######################################
handle_day_overflow() {
    refresh_month_cache
    local max_days="${_MC_DAYS}" overflow

    while ((SELECTED_DAY < 1)); do
        overflow=$((1 - SELECTED_DAY))
        shift_month -1
        max_days="${_MC_DAYS}"
        SELECTED_DAY=$((max_days - overflow + 1))
    done

    while ((SELECTED_DAY > max_days)); do
        SELECTED_DAY=$((SELECTED_DAY - max_days))
        shift_month 1
        max_days="${_MC_DAYS}"
    done
}
