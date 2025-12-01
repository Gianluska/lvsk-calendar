#!/bin/bash

# Background Component
# Draws orbital background illustration

# Draw a single orbital particle
draw_orbital_particle() {
    local x=$1
    local y=$2
    local char=$3
    local term_width=$(tput cols)
    local term_height=$(tput lines)

    if [ $x -gt 0 ] && [ $x -lt $term_width ] && [ $y -gt 0 ] && [ $y -lt $term_height ]; then
        tput cup $y $x
        printf "${COLORS[SUBTLE]}${COLORS[DIM]}%s${COLORS[RESET]}" "$char"
    fi
}

# Draw a circular orbit using pre-calculated approximations
draw_orbit_circle() {
    local cx=$1    # center x
    local cy=$2    # center y
    local r=$3     # radius
    local char=$4  # character to use
    local term_width=$(tput cols)
    local term_height=$(tput lines)

    # Draw circle using approximated points (8 cardinal/ordinal directions)
    # Approximate positions for circular orbit
    local -a positions=(
        # angle:x_offset:y_offset (y scaled by 0.5 for terminal aspect ratio)
        "$r:0"                    # 0° - right
        "$((r*7/10)):$((r*7/20))"  # 45° - top-right
        "0:$((r/2))"              # 90° - top
        "$((-r*7/10)):$((r*7/20))" # 135° - top-left
        "$((-r)):0"               # 180° - left
        "$((-r*7/10)):$((-r*7/20))" # 225° - bottom-left
        "0:$((-r/2))"             # 270° - bottom
        "$((r*7/10)):$((-r*7/20))" # 315° - bottom-right
    )

    # Additional intermediate points for smoother circles
    local -a extra_positions=(
        "$((r*92/100)):$((r*38/100))"   # 22.5°
        "$((r*38/100)):$((r*46/100))"   # 67.5°
        "$((-r*38/100)):$((r*46/100))"  # 112.5°
        "$((-r*92/100)):$((r*38/100))"  # 157.5°
        "$((-r*92/100)):$((-r*38/100))" # 202.5°
        "$((-r*38/100)):$((-r*46/100))" # 247.5°
        "$((r*38/100)):$((-r*46/100))"  # 292.5°
        "$((r*92/100)):$((-r*38/100))"  # 337.5°
    )

    # Draw main cardinal and ordinal points
    for pos in "${positions[@]}"; do
        IFS=':' read -r dx dy <<< "$pos"
        local x=$((cx + dx))
        local y=$((cy + dy))

        if [ $x -gt 0 ] && [ $x -lt $term_width ] && [ $y -gt 0 ] && [ $y -lt $term_height ]; then
            tput cup $y $x
            printf "${COLORS[SUBTLE]}${COLORS[DIM]}%s${COLORS[RESET]}" "$char"
        fi
    done

    # Draw extra points for smoother appearance (only for larger orbits)
    if [ $r -ge 8 ]; then
        for pos in "${extra_positions[@]}"; do
            IFS=':' read -r dx dy <<< "$pos"
            local x=$((cx + dx))
            local y=$((cy + dy))

            if [ $x -gt 0 ] && [ $x -lt $term_width ] && [ $y -gt 0 ] && [ $y -lt $term_height ]; then
                tput cup $y $x
                printf "${COLORS[SUBTLE]}${COLORS[DIM]}%s${COLORS[RESET]}" "$char"
            fi
        done
    fi
}

# Draw orbital background illustration
draw_background() {
    local term_width=$(tput cols)
    local term_height=$(tput lines)

    # Save cursor position
    tput sc

    # Center coordinates for main orbital system
    local center_x=$((term_width / 2))
    local center_y=$((term_height / 2))

    # Draw concentric orbital rings in the center
    # Inner orbit - delicate dots
    draw_orbit_circle $center_x $center_y 6 '·'

    # Middle orbit - small circles
    draw_orbit_circle $center_x $center_y 10 '∘'

    # Outer orbit - medium circles
    draw_orbit_circle $center_x $center_y 14 '○'

    # Far orbit - subtle dots
    draw_orbit_circle $center_x $center_y 18 '˙'

    # Decorative orbital systems on corners
    # Top-left orbit system
    draw_orbit_circle $((center_x - 24)) $((center_y - 8)) 4 '·'
    draw_orbit_circle $((center_x - 24)) $((center_y - 8)) 6 '∘'

    # Top-right orbit system
    draw_orbit_circle $((center_x + 24)) $((center_y - 8)) 5 '·'
    draw_orbit_circle $((center_x + 24)) $((center_y - 8)) 7 '◦'

    # Bottom-left orbit system
    draw_orbit_circle $((center_x - 20)) $((center_y + 10)) 3 '·'
    draw_orbit_circle $((center_x - 20)) $((center_y + 10)) 5 '∘'

    # Bottom-right orbit system
    draw_orbit_circle $((center_x + 20)) $((center_y + 10)) 4 '˙'
    draw_orbit_circle $((center_x + 20)) $((center_y + 10)) 6 '○'

    # Add some scattered orbital particles
    draw_orbital_particle $((center_x - 15)) $((center_y - 12)) '∗'
    draw_orbital_particle $((center_x + 15)) $((center_y - 12)) '✦'
    draw_orbital_particle $((center_x - 18)) $((center_y + 14)) '∗'
    draw_orbital_particle $((center_x + 18)) $((center_y + 14)) '✧'
    draw_orbital_particle $((center_x - 30)) $center_y '·'
    draw_orbital_particle $((center_x + 30)) $center_y '·'

    # Restore cursor position
    tput rc
}
