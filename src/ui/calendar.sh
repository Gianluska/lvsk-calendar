#!/bin/bash

# Calendar Component
# Displays the calendar grid with week numbers and visual indicators

draw_calendar() {
    local days=$(days_in_month $CURRENT_MONTH $CURRENT_YEAR)
    local first_day=$(date -d "${CURRENT_YEAR}-${CURRENT_MONTH}-01" +%u)

    local day_num=1
    local term_width=$(tput cols)
    local grid_width=$CALENDAR_GRID_WIDTH
    local left_pos=$(( (term_width - grid_width) / 2 ))

    local line_num=10  # Starting line for calendar grid

    # Draw up to 6 weeks
    for ((week=0; week<6; week++)); do
        [ $day_num -gt $days ] && break

        tput cup $line_num $left_pos

        # Calculate week number for the first day of this week
        local week_day=$day_num
        if [ $week -eq 0 ]; then
            # For first week, use the first actual day in the month
            week_day=1
        fi
        local week_num=$(date -d "${CURRENT_YEAR}-${CURRENT_MONTH}-${week_day}" +%V 2>/dev/null || echo "")

        # Draw week number column
        if [ -n "$week_num" ]; then
            printf "${COLORS[BASE_DIMMER]}%2s${COLORS[RESET]} ${COLORS[SUBTLE]}${CHAR[v_light]}${COLORS[RESET]}  " "$week_num"
        else
            printf "      "
        fi

        # Draw 7 days
        for ((dow=1; dow<=7; dow++)); do
            local should_draw=0

            if [ $week -eq 0 ]; then
                [ $dow -ge $first_day ] && should_draw=1
            else
                should_draw=1
            fi

            if [ $should_draw -eq 1 ] && [ $day_num -le $days ]; then
                render_day $day_num $dow
                day_num=$((day_num + 1))
            else
                # Empty cell with subtle indicator - 3 chars to match
                printf "${COLORS[SUBTLE]}${COLORS[DIM]}  ${CHAR[dot]}${COLORS[RESET]}"
            fi

            # Spacing between columns - 2 spaces to make each cell 5 chars total (except last)
            [ $dow -lt 7 ] && printf "  "
        done

        line_num=$((line_num + 2))  # Move to next week line (skip blank line)
    done
}

# Render a single day cell with appropriate styling
render_day() {
    local day_num=$1
    local dow=$2

    local is_today=0
    local is_selected=0

    [ $day_num -eq $TODAY_DAY ] && [ $CURRENT_MONTH -eq $(date +%m) ] && [ $CURRENT_YEAR -eq $(date +%Y) ] && is_today=1
    [ $day_num -eq $SELECTED_DAY ] && is_selected=1

    # Render day with striking visual styling - each cell is 5 chars (2 digit + 1 marker + 2 space) except last
    if [ $is_selected -eq 1 ]; then
        # Selected - bold with diamond marker
        printf "${COLORS[HIGHLIGHT]}${COLORS[BOLD]}%2d${COLORS[RESET]}${COLORS[ACCENT]}${CHAR[diamond]}${COLORS[RESET]}" "$day_num"
    elif [ $is_today -eq 1 ]; then
        # Today - highlighted with circle
        printf "${COLORS[ACCENT_BRIGHT]}${COLORS[BOLD]}%2d${COLORS[RESET]}${COLORS[BASE]}${CHAR[circle]}${COLORS[RESET]}" "$day_num"
    else
        # Regular day
        if [ $dow -ge 6 ]; then
            # Weekend - dimmed with subtle marker
            printf "${COLORS[BASE_DIMMER]}%2d${COLORS[RESET]}${COLORS[SUBTLE]}${CHAR[dot]}${COLORS[RESET]}" "$day_num"
        else
            # Weekday
            printf "${COLORS[BASE]}%2d${COLORS[RESET]} ${COLORS[RESET]}" "$day_num"
        fi
    fi
}
