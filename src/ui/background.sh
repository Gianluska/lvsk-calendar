#!/usr/bin/env bash

#######################################
# Background Component
# Loads background illustrations from user's config directory
#######################################

#######################################
# Draw the background
# Loads and executes the selected background style
# Globals:
#   BACKGROUND_STYLE - Name of background to load
#######################################
draw_background() {
    local style="${BACKGROUND_STYLE:-orbital}"
    local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/lvsk-calendar"
    local background_file="${config_dir}/backgrounds/${style}.sh"

    # Load and execute the background file if found
    if [[ -f "${background_file}" ]]; then
        # shellcheck source=/dev/null
        source "${background_file}"

        # Call the draw function defined in the background file
        if declare -f draw_custom_background &>/dev/null; then
            draw_custom_background
        fi
    fi
}
