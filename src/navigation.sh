#!/bin/bash

# Navigation Module
# Handles month and year navigation logic

# Navigate to previous month
prev_month() {
    CURRENT_MONTH=$((CURRENT_MONTH - 1))
    if [ $CURRENT_MONTH -lt 1 ]; then
        CURRENT_MONTH=12
        CURRENT_YEAR=$((CURRENT_YEAR - 1))
    fi

    local max_days=$(days_in_month $CURRENT_MONTH $CURRENT_YEAR)
    [ $SELECTED_DAY -gt $max_days ] && SELECTED_DAY=$max_days

    # Force full re-render when changing month
    FIRST_RENDER=1
}

# Navigate to next month
next_month() {
    CURRENT_MONTH=$((CURRENT_MONTH + 1))
    if [ $CURRENT_MONTH -gt 12 ]; then
        CURRENT_MONTH=1
        CURRENT_YEAR=$((CURRENT_YEAR + 1))
    fi

    local max_days=$(days_in_month $CURRENT_MONTH $CURRENT_YEAR)
    [ $SELECTED_DAY -gt $max_days ] && SELECTED_DAY=$max_days

    # Force full re-render when changing month
    FIRST_RENDER=1
}

# Navigate to today's date
goto_today() {
    CURRENT_MONTH=$(date +%m)
    CURRENT_YEAR=$(date +%Y)
    SELECTED_DAY=$(date +%d)
}

# Handle day navigation overflow/underflow
handle_day_overflow() {
    local max_days=$(days_in_month $CURRENT_MONTH $CURRENT_YEAR)

    if [ $SELECTED_DAY -lt 1 ]; then
        prev_month
        SELECTED_DAY=$(days_in_month $CURRENT_MONTH $CURRENT_YEAR)
    elif [ $SELECTED_DAY -gt $max_days ]; then
        next_month
        SELECTED_DAY=1
    fi
}
