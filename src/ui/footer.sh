#!/bin/bash

# Footer Component
# Displays keyboard controls and navigation hints

draw_footer() {
    echo ""
    echo ""

    local term_width=$(tput cols)
    local frame_width=$FOOTER_FRAME_WIDTH
    local left_padding=$(( (term_width - frame_width) / 2 ))

    # Top separator
    printf "%*s" "$left_padding" ""
    for ((i=0; i<frame_width; i++)); do
        printf "${COLORS[SUBTLE]}${COLORS[DIM]}${CHAR[h]}${COLORS[RESET]}"
    done
    echo ""
    echo ""

    # Controls line - compact to fit window
    printf "%*s   " "$left_padding" ""
    printf "${COLORS[BASE_DIM]}hjkl${COLORS[RESET]} ${COLORS[SUBTLE]}${CHAR[bullet]}${COLORS[RESET]} ${COLORS[BASE]}nav${COLORS[RESET]}"
    printf "   "
    printf "${COLORS[BASE_DIM]}[]${COLORS[RESET]} ${COLORS[SUBTLE]}${CHAR[bullet]}${COLORS[RESET]} ${COLORS[BASE]}month${COLORS[RESET]}"
    printf "   "
    printf "${COLORS[BASE_DIM]}t${COLORS[RESET]} ${COLORS[SUBTLE]}${CHAR[bullet]}${COLORS[RESET]} ${COLORS[BASE]}today${COLORS[RESET]}"
    printf "   "
    printf "${COLORS[BASE_DIM]}q${COLORS[RESET]} ${COLORS[SUBTLE]}${CHAR[bullet]}${COLORS[RESET]} ${COLORS[BASE]}quit${COLORS[RESET]}"
    echo ""

    echo ""
}
