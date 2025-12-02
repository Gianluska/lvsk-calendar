#!/bin/bash

# Header Component
# Displays the month and year in an elegant frame

draw_header() {
    local month_name=$(get_month_name $CURRENT_MONTH $CURRENT_YEAR)
    local title="$month_name $CURRENT_YEAR"

    local term_width=$(tput cols)
    local frame_width=$HEADER_FRAME_WIDTH
    local left_pos=$(( (term_width - frame_width) / 2 ))

    # Top border (line 3)
    tput cup 3 $left_pos
    printf "${COLORS[SUBTLE]}${CHAR[tl]}"
    for ((i=0; i<frame_width-2; i++)); do
        printf "${CHAR[h]}"
    done
    printf "${CHAR[tr]}${COLORS[RESET]}"

    # Title line (line 4)
    local title_len=${#title}
    local inner_width=$((frame_width - 2))
    local title_padding=$(( (inner_width - title_len) / 2 ))

    tput cup 4 $left_pos
    printf "${COLORS[SUBTLE]}${CHAR[v]}${COLORS[RESET]}"
    tput cup 4 $((left_pos + 1 + title_padding))
    printf "${COLORS[ACCENT_BRIGHT]}${COLORS[BOLD]}%s${COLORS[RESET]}" "$title"
    tput cup 4 $((left_pos + frame_width - 1))
    printf "${COLORS[SUBTLE]}${CHAR[v]}${COLORS[RESET]}"

    # Bottom border (line 5)
    tput cup 5 $left_pos
    printf "${COLORS[SUBTLE]}${CHAR[bl]}"
    for ((i=0; i<frame_width-2; i++)); do
        printf "${CHAR[h]}"
    done
    printf "${CHAR[br]}${COLORS[RESET]}"
}

# Elegant day headers with separators
draw_day_headers() {
    local days=("mo" "tu" "we" "th" "fr" "sa" "su")

    local term_width=$(tput cols)
    local grid_width=$CALENDAR_GRID_WIDTH
    local left_pos=$(( (term_width - grid_width) / 2 ))

    # Day names with week column header (line 7)
    tput cup 7 $left_pos
    # Week column header
    printf "${COLORS[BASE_DIMMER]}${COLORS[BOLD]}wk${COLORS[RESET]} ${COLORS[SUBTLE]}${CHAR[v_light]}${COLORS[RESET]}  "

    for i in {0..6}; do
        if [ $i -ge 5 ]; then
            # Weekend - slightly dimmed
            printf "${COLORS[BASE_DIMMER]}${COLORS[BOLD]}%s${COLORS[RESET]}" "${days[$i]}"
        else
            # Weekday
            printf "${COLORS[BASE]}${COLORS[BOLD]}%s${COLORS[RESET]}" "${days[$i]}"
        fi

        if [ $i -lt 6 ]; then
            printf "   "
        fi
    done

    # Subtle separator (line 8)
    tput cup 8 $left_pos
    # Week column separator
    printf "${COLORS[SUBTLE]}${COLORS[DIM]}${CHAR[h]}${CHAR[h]}${COLORS[RESET]} ${COLORS[SUBTLE]}${CHAR[v_light]}${COLORS[RESET]}  "

    for i in {0..6}; do
        printf "${COLORS[SUBTLE]}${COLORS[DIM]}${CHAR[h]}${CHAR[h]}${COLORS[RESET]}"
        if [ $i -lt 6 ]; then
            printf "   "
        fi
    done
}
