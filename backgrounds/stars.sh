#!/usr/bin/env bash

# Stars Background - Starry night design
# A night sky filled with twinkling stars

draw_custom_background() {
    printf '%b%s%b' "${COLORS[BG]}" \
"
                                                                          ✧
         ✦                                              ✧            ·
              ·         ∗                 ✦                    ✧         ·
                    ·           ✧                    ✦           ·         ✧
            ·                                                ✧
                ✦           ·        ✧           ·                   ✦
              ·           ✧          ·        ·          ✧        ·
                    ·                                     ✦           ·
      ✧                         ·                                            ·
            ✦                       ·                       ·       ✧
         ·                                      ✧
                    ·                                   ✦                  ·
                          ✧                                   ·
              ·                                                       ✦
                                   ✦                           ·           ✧
                                                     ·
                                 ·           ✧                        ✦
                   ·          ✦                                   ·
         ·                                                        ✧
                    ✧                                   ·       ·
              ·                                   ✦
                 ·                          ✧                          ✦
                                ✦                       ·
     ·                            ·              ✧          ·               ·
                    ·                 ✦                     ·       ✧
              ✦                           ·                      ·         ✧
                      ✧          ·                    ✦      ·
                           ·                                            ✧       ·
" \
"${COLORS[RESET]}"
}
