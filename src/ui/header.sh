#!/bin/bash

# Header Component
# Displays the month and year in an elegant frame

draw_header() {
    local month_name=$(get_month_name $CURRENT_MONTH $CURRENT_YEAR)
    local title="$month_name $CURRENT_YEAR"

    echo ""
    echo ""

    local term_width=$(tput cols)
    local frame_width=$HEADER_FRAME_WIDTH
    local left_padding=$(( (term_width - frame_width) / 2 ))

    # Top border
    printf "%*s" "$left_padding" ""
    printf "${COLORS[SUBTLE]}${CHAR[tl]}"
    for ((i=0; i<frame_width-2; i++)); do
        printf "${CHAR[h]}"
    done
    printf "${CHAR[tr]}${COLORS[RESET]}\n"

    # Title line
    local title_len=${#title}
    local inner_width=$((frame_width - 2))
    local title_padding=$(( (inner_width - title_len) / 2 ))

    printf "%*s" "$left_padding" ""
    printf "${COLORS[SUBTLE]}${CHAR[v]}${COLORS[RESET]}"
    printf "%*s" "$title_padding" ""
    printf "${COLORS[ACCENT_BRIGHT]}${COLORS[BOLD]}%s${COLORS[RESET]}" "$title"
    printf "%*s" "$((inner_width - title_len - title_padding))" ""
    printf "${COLORS[SUBTLE]}${CHAR[v]}${COLORS[RESET]}\n"

    # Bottom border
    printf "%*s" "$left_padding" ""
    printf "${COLORS[SUBTLE]}${CHAR[bl]}"
    for ((i=0; i<frame_width-2; i++)); do
        printf "${CHAR[h]}"
    done
    printf "${CHAR[br]}${COLORS[RESET]}\n"

    echo ""
}

# Elegant day headers with separators
draw_day_headers() {
    local days=("mo" "tu" "we" "th" "fr" "sa" "su")

    local term_width=$(tput cols)
    local grid_width=$CALENDAR_GRID_WIDTH
    local left_padding=$(( (term_width - grid_width) / 2 ))

    # Day names with week column header
    printf "%*s" "$left_padding" ""
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
    echo ""

    # Subtle separator
    printf "%*s" "$left_padding" ""
    # Week column separator
    printf "${COLORS[SUBTLE]}${COLORS[DIM]}${CHAR[h]}${CHAR[h]}${COLORS[RESET]} ${COLORS[SUBTLE]}${CHAR[v_light]}${COLORS[RESET]}  "

    for i in {0..6}; do
        printf "${COLORS[SUBTLE]}${COLORS[DIM]}${CHAR[h]}${CHAR[h]}${COLORS[RESET]}"
        if [ $i -lt 6 ]; then
            printf "   "
        fi
    done
    echo ""
    echo ""
}
