#!/usr/bin/env bash

# Orbital Background - Cosmic/orbital design with stars and circles
# This background style creates a celestial atmosphere

draw_custom_background() {
    printf '%b%s%b' "${COLORS[BG]}" \
"
                                                                          ✧
         ˙                                                            ◦   ·   ◦
              ·   ·       ∘                 ˙   ∘               ✦         ·     ·
                    ∘  ·     · ∘                          ˙           ◦ ·         · ◦
            ∘             ˙                                      ○           ·     ·
                ·   ∘   ˙   ˙      ○    ·    ○      ˙   ˙   ◦   ·   ◦       ˙
              ○           ·    ·    ·    ·    ·    ·    ·       ◦        ·
                    ·                                     ·           ∘
      ∗                         ◦                                            ◦
            ·                       ·       ○                   ˙       ·
         ◦                                      ∘
                    ˙                                   ·                  ˙           ·
                          ∘  ·  ∘                             ∘
              ·                                                       ○
                                   ·   ✦   ·                    ·           ·
                                                     ◦
                                 ○     ∘     ∘     ○                  ✧
                   ∘          ○           ∘                       ˙
         ◦   ·                                                        ·
                    ·   ·   ·                               ○       ∘
              ○                                   ∘
                 ∘· · ·∘                ˙          ○      ˙   ˙               ·
               ∘ ·     · ∘            ·                 ˙       ˙
     ˙           ∘· · ·∘         ◦              ◦          ˙   ˙          ◦
                    ∘                 ·                     ˙       ·
              ·                           ˙                      ○         ✦
                      ∗          ∘   ·   ∘              ✧      ·
                           ◦                                            ·       ˙
" \
"${COLORS[RESET]}"
}
