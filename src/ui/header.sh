#!/usr/bin/env bash

#######################################
# Header Component
# Displays the month and year in an elegant frame
#######################################

#######################################
# Draw the header with month/year in a bordered frame
# Positions at lines 3-5 of terminal
# Globals:
#   CURRENT_MONTH - Current month number
#   CURRENT_YEAR - Current year
#   HEADER_FRAME_WIDTH - Width of the frame
#   COLORS - Color definitions
#   CHAR - Character definitions
#######################################
draw_header() {
    local month_name
    month_name=$(get_month_name "${CURRENT_MONTH}" "${CURRENT_YEAR}")
    local title="${month_name} ${CURRENT_YEAR}"

    local term_width
    term_width=$(tput cols)

    local frame_width="${HEADER_FRAME_WIDTH}"
    local left_pos=$(((term_width - frame_width) / 2))
    local inner_width=$((frame_width - 2))

    # Build horizontal border string (pure bash)
    local h_border=""
    local i
    for ((i = 0; i < inner_width; i++)); do
        h_border+="${CHAR[h]}"
    done

    # Top border (line 3)
    tput cup 3 "${left_pos}"
    printf '%b%s%s%s%b' \
        "${COLORS[SUBTLE]}" \
        "${CHAR[tl]}" \
        "${h_border}" \
        "${CHAR[tr]}" \
        "${COLORS[RESET]}"

    # Title line (line 4)
    local title_len=${#title}
    local title_padding=$(((inner_width - title_len) / 2))

    tput cup 4 "${left_pos}"
    printf '%b%s%b' "${COLORS[SUBTLE]}" "${CHAR[v]}" "${COLORS[RESET]}"

    tput cup 4 $((left_pos + 1 + title_padding))
    printf '%b%b%s%b' \
        "${COLORS[ACCENT_BRIGHT]}" \
        "${COLORS[BOLD]}" \
        "${title}" \
        "${COLORS[RESET]}"

    tput cup 4 $((left_pos + frame_width - 1))
    printf '%b%s%b' "${COLORS[SUBTLE]}" "${CHAR[v]}" "${COLORS[RESET]}"

    # Bottom border (line 5)
    tput cup 5 "${left_pos}"
    printf '%b%s%s%s%b' \
        "${COLORS[SUBTLE]}" \
        "${CHAR[bl]}" \
        "${h_border}" \
        "${CHAR[br]}" \
        "${COLORS[RESET]}"
}

#######################################
# Draw day name headers with week column
# Positions at lines 7-8 of terminal
# Globals:
#   CALENDAR_GRID_WIDTH - Width of calendar grid
#   COLORS - Color definitions
#   CHAR - Character definitions
#######################################
draw_day_headers() {
    # Day name abbreviations (ISO week format: Monday first)
    local -a days=("mo" "tu" "we" "th" "fr" "sa" "su")

    local term_width
    term_width=$(tput cols)

    local grid_width="${CALENDAR_GRID_WIDTH}"
    local left_pos=$(((term_width - grid_width) / 2))

    # Day names with week column header (line 7)
    tput cup 7 "${left_pos}"

    # Week column header
    printf '%b%bwk%b %b%s%b  ' \
        "${COLORS[BASE_DIMMER]}" \
        "${COLORS[BOLD]}" \
        "${COLORS[RESET]}" \
        "${COLORS[SUBTLE]}" \
        "${CHAR[v_light]}" \
        "${COLORS[RESET]}"

    # Day name headers
    local i
    for i in {0..6}; do
        if ((i >= 5)); then
            # Weekend - slightly dimmed
            printf '%b%b%s%b' \
                "${COLORS[BASE_DIMMER]}" \
                "${COLORS[BOLD]}" \
                "${days[i]}" \
                "${COLORS[RESET]}"
        else
            # Weekday
            printf '%b%b%s%b' \
                "${COLORS[BASE]}" \
                "${COLORS[BOLD]}" \
                "${days[i]}" \
                "${COLORS[RESET]}"
        fi

        # Spacing between days (except last)
        ((i < 6)) && printf '   '
    done

    # Subtle separator line (line 8)
    tput cup 8 "${left_pos}"

    # Week column separator
    printf '%b%b%s%s%b %b%s%b  ' \
        "${COLORS[SUBTLE]}" \
        "${COLORS[DIM]}" \
        "${CHAR[h]}" \
        "${CHAR[h]}" \
        "${COLORS[RESET]}" \
        "${COLORS[SUBTLE]}" \
        "${CHAR[v_light]}" \
        "${COLORS[RESET]}"

    # Day separator lines
    for i in {0..6}; do
        printf '%b%b%s%s%b' \
            "${COLORS[SUBTLE]}" \
            "${COLORS[DIM]}" \
            "${CHAR[h]}" \
            "${CHAR[h]}" \
            "${COLORS[RESET]}"

        ((i < 6)) && printf '   '
    done
}
