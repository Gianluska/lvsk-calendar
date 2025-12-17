#!/usr/bin/env bash

#######################################
# Footer Component
# Displays keyboard controls, navigation hints, and holiday info
#######################################

#######################################
# Draw the footer with controls and holiday information
# Positions at lines 22-24 of terminal
# Globals:
#   FOOTER_FRAME_WIDTH - Width of footer frame
#   COLORS - Color definitions
#   CHAR - Character definitions
#######################################
draw_footer() {
    local term_width
    term_width=$(tput cols)

    local frame_width="${FOOTER_FRAME_WIDTH}"
    local left_pos=$(((term_width - frame_width) / 2))

    # Holiday info line (line 22) - above the divider
    tput cup 22 "${left_pos}"

    # Clear the line first (pure bash padding)
    printf '%*s' "${frame_width}" ''
    tput cup 22 "${left_pos}"

    # Get holiday name if function exists
    local holiday_name=""
    if declare -f get_selected_holiday &>/dev/null; then
        holiday_name=$(get_selected_holiday 2>/dev/null) || holiday_name=""
    fi

    if [[ -n "${holiday_name}" ]]; then
        # Truncate if too long
        local max_len=$((frame_width - 4))
        if ((${#holiday_name} > max_len)); then
            holiday_name="${holiday_name:0:$((max_len - 3))}..."
        fi

        # Calculate centering
        local display_len=$((${#holiday_name} + 4))  # +4 for dots and spaces
        local padding=$(((frame_width - display_len) / 2))

        printf '%*s' "${padding}" ''
        printf '%b%s%b %b%s%b %b%s%b' \
            "${COLORS[BASE_DIM]}" \
            "${CHAR[dot]}" \
            "${COLORS[RESET]}" \
            "${COLORS[ACCENT_BRIGHT]}" \
            "${holiday_name}" \
            "${COLORS[RESET]}" \
            "${COLORS[BASE_DIM]}" \
            "${CHAR[dot]}" \
            "${COLORS[RESET]}"
    fi

    # Separator line (line 23)
    tput cup 23 "${left_pos}"

    local i
    for ((i = 0; i < frame_width; i++)); do
        printf '%b%b%s%b' \
            "${COLORS[SUBTLE]}" \
            "${COLORS[DIM]}" \
            "${CHAR[h]}" \
            "${COLORS[RESET]}"
    done

    # Controls line (line 24)
    tput cup 24 $((left_pos + 3))

    # Navigation hint
    printf '%bhjkl%b %b%s%b %bnav%b' \
        "${COLORS[BASE_DIM]}" \
        "${COLORS[RESET]}" \
        "${COLORS[SUBTLE]}" \
        "${CHAR[bullet]}" \
        "${COLORS[RESET]}" \
        "${COLORS[BASE]}" \
        "${COLORS[RESET]}"

    printf '   '

    # Month navigation hint
    printf '%b[]%b %b%s%b %bmonth%b' \
        "${COLORS[BASE_DIM]}" \
        "${COLORS[RESET]}" \
        "${COLORS[SUBTLE]}" \
        "${CHAR[bullet]}" \
        "${COLORS[RESET]}" \
        "${COLORS[BASE]}" \
        "${COLORS[RESET]}"

    printf '   '

    # Today hint
    printf '%bt%b %b%s%b %btoday%b' \
        "${COLORS[BASE_DIM]}" \
        "${COLORS[RESET]}" \
        "${COLORS[SUBTLE]}" \
        "${CHAR[bullet]}" \
        "${COLORS[RESET]}" \
        "${COLORS[BASE]}" \
        "${COLORS[RESET]}"

    printf '   '

    # Quit hint
    printf '%bq%b %b%s%b %bquit%b' \
        "${COLORS[BASE_DIM]}" \
        "${COLORS[RESET]}" \
        "${COLORS[SUBTLE]}" \
        "${CHAR[bullet]}" \
        "${COLORS[RESET]}" \
        "${COLORS[BASE]}" \
        "${COLORS[RESET]}"
}
