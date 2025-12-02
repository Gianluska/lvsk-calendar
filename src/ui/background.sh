#!/bin/bash

# Background Component
# Loads background illustrations from user's config directory

# Main draw function - loads and executes the selected background
draw_background() {
    local style="${BACKGROUND_STYLE:-orbital}"
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lvsk-calendar"
    local background_file="${config_dir}/backgrounds/${style}.sh"

    # Load and execute the background file if found
    if [ -f "$background_file" ]; then
        source "$background_file"
        # Call the draw function defined in the background file
        if type draw_custom_background &>/dev/null; then
            draw_custom_background
        fi
    fi
}
