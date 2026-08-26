#!/usr/bin/env bash

# Minimal Background - Simple dots pattern
# A clean, minimalist approach with sparse decorations

draw_custom_background() {
    printf '%b%s%b' "${COLORS[BG]}" \
"




              ·                                                         ·


                                    ·                       ·




                    ·                                   ·


         ·                                                                    ·



                                          ·



              ·                                       ·



                                   ·                               ·




         ·                                         ·
" \
"${COLORS[RESET]}"
}
