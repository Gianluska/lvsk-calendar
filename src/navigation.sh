#!/usr/bin/env bash

#######################################
# Navigation Module
# Handles month and year navigation logic
#######################################

#######################################
# Navigate to previous month
# Wraps to December of previous year if needed
# Globals:
#   CURRENT_MONTH - Decremented (wraps 12 -> 1)
#   CURRENT_YEAR - Decremented if month wraps
#   SELECTED_DAY - Adjusted if exceeds new month's days
#   FIRST_RENDER - Set to 1 to force full re-render
#######################################
prev_month() {
    CURRENT_MONTH=$((CURRENT_MONTH - 1))

    if ((CURRENT_MONTH < 1)); then
        CURRENT_MONTH=12
        CURRENT_YEAR=$((CURRENT_YEAR - 1))
    fi

    # Clamp selected day to valid range for new month
    local max_days
    max_days=$(days_in_month "${CURRENT_MONTH}" "${CURRENT_YEAR}")
    ((SELECTED_DAY > max_days)) && SELECTED_DAY="${max_days}"

    # Force full re-render when changing month
    FIRST_RENDER=1
}

#######################################
# Navigate to next month
# Wraps to January of next year if needed
# Globals:
#   CURRENT_MONTH - Incremented (wraps 1 -> 12)
#   CURRENT_YEAR - Incremented if month wraps
#   SELECTED_DAY - Adjusted if exceeds new month's days
#   FIRST_RENDER - Set to 1 to force full re-render
#######################################
next_month() {
    CURRENT_MONTH=$((CURRENT_MONTH + 1))

    if ((CURRENT_MONTH > 12)); then
        CURRENT_MONTH=1
        CURRENT_YEAR=$((CURRENT_YEAR + 1))
    fi

    # Clamp selected day to valid range for new month
    local max_days
    max_days=$(days_in_month "${CURRENT_MONTH}" "${CURRENT_YEAR}")
    ((SELECTED_DAY > max_days)) && SELECTED_DAY="${max_days}"

    # Force full re-render when changing month
    FIRST_RENDER=1
}

#######################################
# Navigate to previous year
# Globals:
#   CURRENT_MONTH - Remains unchanged
#   CURRENT_YEAR - Decremented
#   SELECTED_DAY - Adjusted if exceeds new month's days
#   FIRST_RENDER - Set to 1 to force full re-render
#######################################
prev_year() {
    CURRENT_YEAR=$((CURRENT_YEAR - 1))

    # Clamp selected day to valid range for new month
    local max_days
    max_days=$(days_in_month "${CURRENT_MONTH}" "${CURRENT_YEAR}")
    ((SELECTED_DAY > max_days)) && SELECTED_DAY="${max_days}"

    # Force full re-render when changing month
    FIRST_RENDER=1
}

#######################################
# Navigate to next year
# Globals:
#   CURRENT_MONTH - Remains unchanged
#   CURRENT_YEAR - Incremented
#   SELECTED_DAY - Adjusted if exceeds new month's days
#   FIRST_RENDER - Set to 1 to force full re-render
#######################################
next_year() {
    CURRENT_YEAR=$((CURRENT_YEAR + 1))

    # Clamp selected day to valid range for new month
    local max_days
    max_days=$(days_in_month "${CURRENT_MONTH}" "${CURRENT_YEAR}")
    ((SELECTED_DAY > max_days)) && SELECTED_DAY="${max_days}"

    # Force full re-render when changing month
    FIRST_RENDER=1
}

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
}

#######################################
# Handle day navigation overflow/underflow
# Automatically switches to prev/next month when selection goes out of bounds
# Globals:
#   SELECTED_DAY - Adjusted to valid range, may trigger month change
#   CURRENT_MONTH - May change via prev_month/next_month
#   CURRENT_YEAR - May change via prev_month/next_month
#######################################
handle_day_overflow() {
    local max_days
    max_days=$(days_in_month "${CURRENT_MONTH}" "${CURRENT_YEAR}")

    if ((SELECTED_DAY < 1)); then
        prev_month
        SELECTED_DAY=$(days_in_month "${CURRENT_MONTH}" "${CURRENT_YEAR}")
    elif ((SELECTED_DAY > max_days)); then
        next_month
        SELECTED_DAY=1
    fi
}
