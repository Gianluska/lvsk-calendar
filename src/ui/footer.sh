#!/usr/bin/env bash

#######################################
# Footer Component
# Builds keyboard controls, navigation hints, and event/holiday info
#######################################

# Key hints shown on the controls line, as "keys:label" pairs.
# The visible width of the line is computed from this table, so editing it
# never desynchronizes the centering.
declare -ga FOOTER_HINTS=(
    'hjkl:nav'
    '[]:month'
    '{}:year'
    't:today'
    'a/e/d:events'
    'q:quit'
)

#######################################
# Build the footer into the frame buffer
# Occupies rows LAYOUT_INFO_ROW .. LAYOUT_CONTROLS_ROW
# Arguments:
#   $1 - Name of frame buffer variable
# Globals:
#   FOOTER_FRAME_WIDTH, TERM_COLS, COLORS, CHAR
#######################################
_build_footer() {
    local -n __ftr="${1}"

    local frame_width="${FOOTER_FRAME_WIDTH}"
    local left_pos=$(((TERM_COLS - frame_width) / 2))
    # Prevent negative position (small terminals)
    ((left_pos < 0)) && left_pos=0

    # Info line - user events and/or holiday for the selected day.
    # Blank the strip first (pure bash padding), then write centered info.
    _bcup __ftr "${LAYOUT_INFO_ROW}" "${left_pos}"
    _bprintf __ftr '%*s' "${frame_width}" ''

    local holiday_name="" events_info=""
    declare -f _selected_holiday_name &>/dev/null && _selected_holiday_name holiday_name
    declare -f _selected_events_summary &>/dev/null && _selected_events_summary events_info

    # Compose the info line (events take precedence; holiday appended if both)
    local info="" lead_char="${CHAR[dot]}"
    if [[ -n "${events_info}" && -n "${holiday_name}" ]]; then
        info="${events_info}  ${CHAR[star]} ${holiday_name}"
        lead_char="${CHAR[event]}"
    elif [[ -n "${events_info}" ]]; then
        info="${events_info}"
        lead_char="${CHAR[event]}"
    elif [[ -n "${holiday_name}" ]]; then
        info="${holiday_name}"
    fi

    if [[ -n "${info}" ]]; then
        # Truncate if too long
        local max_len=$((frame_width - 4))
        if ((${#info} > max_len)); then
            info="${info:0:$((max_len - 3))}..."
        fi

        # Calculate centering (+4 for markers and spaces)
        local display_len=$((${#info} + 4))
        local padding=$(((frame_width - display_len) / 2))
        ((padding < 0)) && padding=0

        _bcup __ftr "${LAYOUT_INFO_ROW}" "${left_pos}"
        _bprintf __ftr '%*s' "${padding}" ''
        _bprintf __ftr '%b%s%b %b%s%b %b%s%b' \
            "${COLORS[BASE_DIM]}" \
            "${lead_char}" \
            "${COLORS[RESET]}" \
            "${COLORS[ACCENT_BRIGHT]}" \
            "${info}" \
            "${COLORS[RESET]}" \
            "${COLORS[BASE_DIM]}" \
            "${lead_char}" \
            "${COLORS[RESET]}"
    fi

    # Separator line
    local separator
    _repeat_v separator "${CHAR[h]}" "${frame_width}"
    _bcup __ftr "${LAYOUT_SEP_ROW}" "${left_pos}"
    _bprintf __ftr '%b%b%s%b' \
        "${COLORS[SUBTLE]}" \
        "${COLORS[DIM]}" \
        "${separator}" \
        "${COLORS[RESET]}"

    # Controls line - centered on screen, width computed from the hint table
    # (per hint: keys + space + bullet + space + label; 3 spaces between hints)
    local hint keys label
    local controls_len=0 first=1
    for hint in "${FOOTER_HINTS[@]}"; do
        keys="${hint%%:*}"
        label="${hint#*:}"
        ((first)) || controls_len=$((controls_len + 3))
        controls_len=$((controls_len + ${#keys} + 3 + ${#label}))
        first=0
    done

    local controls_pos=$(((TERM_COLS - controls_len) / 2))
    # Prevent negative position (small terminals)
    ((controls_pos < 0)) && controls_pos=0

    _bcup __ftr "${LAYOUT_CONTROLS_ROW}" "${controls_pos}"

    first=1
    for hint in "${FOOTER_HINTS[@]}"; do
        keys="${hint%%:*}"
        label="${hint#*:}"
        ((first)) || _bprintf __ftr '   '
        first=0
        _bprintf __ftr '%b%s%b %b%s%b %b%s%b' \
            "${COLORS[BASE_DIM]}" \
            "${keys}" \
            "${COLORS[RESET]}" \
            "${COLORS[SUBTLE]}" \
            "${CHAR[bullet]}" \
            "${COLORS[RESET]}" \
            "${COLORS[BASE]}" \
            "${label}" \
            "${COLORS[RESET]}"
    done
}
