#!/usr/bin/env bash

#######################################
# Header Component
# Builds the month/year frame and weekday headers into the frame buffer
#######################################

#######################################
# Build the header with month/year in a bordered frame
# Occupies rows LAYOUT_HEADER_TOP .. LAYOUT_HEADER_TOP+2
# Arguments:
#   $1 - Name of frame buffer variable
# Globals:
#   CURRENT_YEAR - Current year
#   _MC_NAME - Cached locale-aware month name
#   HEADER_FRAME_WIDTH, TERM_COLS, COLORS, CHAR
#######################################
_build_header() {
    local -n __hdr="${1}"
    local title="${_MC_NAME} ${CURRENT_YEAR}"

    local frame_width="${HEADER_FRAME_WIDTH}"
    local left_pos=$(((TERM_COLS - frame_width) / 2))
    # Prevent negative position (small terminals)
    ((left_pos < 0)) && left_pos=0
    local inner_width=$((frame_width - 2))
    local top="${LAYOUT_HEADER_TOP}"

    # Horizontal border string (pure bash)
    local h_border
    _repeat_v h_border "${CHAR[h]}" "${inner_width}"

    # Top border
    _bcup __hdr "${top}" "${left_pos}"
    _bprintf __hdr '%b%s%s%s%b' \
        "${COLORS[SUBTLE]}" \
        "${CHAR[tl]}" \
        "${h_border}" \
        "${CHAR[tr]}" \
        "${COLORS[RESET]}"

    # Title line
    local title_len=${#title}
    local title_padding=$(((inner_width - title_len) / 2))
    ((title_padding < 0)) && title_padding=0

    _bcup __hdr $((top + 1)) "${left_pos}"
    _bprintf __hdr '%b%s%b' "${COLORS[SUBTLE]}" "${CHAR[v]}" "${COLORS[RESET]}"

    _bcup __hdr $((top + 1)) $((left_pos + 1 + title_padding))
    _bprintf __hdr '%b%b%s%b' \
        "${COLORS[ACCENT_BRIGHT]}" \
        "${COLORS[BOLD]}" \
        "${title}" \
        "${COLORS[RESET]}"

    _bcup __hdr $((top + 1)) $((left_pos + frame_width - 1))
    _bprintf __hdr '%b%s%b' "${COLORS[SUBTLE]}" "${CHAR[v]}" "${COLORS[RESET]}"

    # Bottom border
    _bcup __hdr $((top + 2)) "${left_pos}"
    _bprintf __hdr '%b%s%s%s%b' \
        "${COLORS[SUBTLE]}" \
        "${CHAR[bl]}" \
        "${h_border}" \
        "${CHAR[br]}" \
        "${COLORS[RESET]}"
}

#######################################
# Build day name headers with week column
# Occupies rows LAYOUT_DAYHDR_ROW and LAYOUT_DAYSEP_ROW
# Arguments:
#   $1 - Name of frame buffer variable
# Globals:
#   CALENDAR_GRID_WIDTH, TERM_COLS, COLORS, CHAR
#######################################
_build_day_headers() {
    local -n __dhd="${1}"

    # Day name abbreviations (ISO week format: Monday first)
    local -a days=("mo" "tu" "we" "th" "fr" "sa" "su")

    local grid_width="${CALENDAR_GRID_WIDTH}"
    local left_pos=$(((TERM_COLS - grid_width) / 2))
    # Prevent negative position (small terminals)
    ((left_pos < 0)) && left_pos=0

    # Day names with week column header
    _bcup __dhd "${LAYOUT_DAYHDR_ROW}" "${left_pos}"

    # Week column header
    _bprintf __dhd '%b%bwk%b %b%s%b  ' \
        "${COLORS[BASE_DIMMER]}" \
        "${COLORS[BOLD]}" \
        "${COLORS[RESET]}" \
        "${COLORS[SUBTLE]}" \
        "${CHAR[v_light]}" \
        "${COLORS[RESET]}"

    # Day name headers
    local i color
    for ((i = 0; i < 7; i++)); do
        # Weekend slightly dimmed
        if ((i >= 5)); then color="${COLORS[BASE_DIMMER]}"; else color="${COLORS[BASE]}"; fi
        _bprintf __dhd '%b%b%s%b' \
            "${color}" \
            "${COLORS[BOLD]}" \
            "${days[i]}" \
            "${COLORS[RESET]}"

        # Spacing between days (except last)
        ((i < 6)) && _bprintf __dhd '   '
    done

    # Subtle separator line
    _bcup __dhd "${LAYOUT_DAYSEP_ROW}" "${left_pos}"

    # Week column separator
    _bprintf __dhd '%b%b%s%s%b %b%s%b  ' \
        "${COLORS[SUBTLE]}" \
        "${COLORS[DIM]}" \
        "${CHAR[h]}" \
        "${CHAR[h]}" \
        "${COLORS[RESET]}" \
        "${COLORS[SUBTLE]}" \
        "${CHAR[v_light]}" \
        "${COLORS[RESET]}"

    # Day separator lines
    for ((i = 0; i < 7; i++)); do
        _bprintf __dhd '%b%b%s%s%b' \
            "${COLORS[SUBTLE]}" \
            "${COLORS[DIM]}" \
            "${CHAR[h]}" \
            "${CHAR[h]}" \
            "${COLORS[RESET]}"

        ((i < 6)) && _bprintf __dhd '   '
    done
}
