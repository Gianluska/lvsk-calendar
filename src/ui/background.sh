#!/usr/bin/env bash

#######################################
# Background Component
# Loads background illustrations from user's config directory
#######################################

# Style whose draw function is currently loaded (sourced once per style,
# not on every full redraw)
declare -g _BG_LOADED_STYLE=""

#######################################
# Draw the background
# Loads and executes the selected background style. The style name is
# restricted to a plain name so a hostile config value can never traverse
# out of the user's backgrounds directory (it is sourced as code).
# Globals:
#   BACKGROUND_STYLE - Name of background to load
#######################################
draw_background() {
    local style="${BACKGROUND_STYLE:-orbital}"

    # Plain name only: no slashes, dots or spaces (prevents path traversal)
    [[ "${style}" =~ ^[A-Za-z0-9_-]+$ ]] || style="orbital"

    local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/lvsk-calendar"
    local background_file="${config_dir}/backgrounds/${style}.sh"

    # (Re)load only when the style changed since the last full redraw
    if [[ "${_BG_LOADED_STYLE}" != "${style}" ]]; then
        unset -f draw_custom_background 2>/dev/null || true

        if [[ -f "${background_file}" ]]; then
            # shellcheck source=/dev/null
            source "${background_file}" || return 0
        fi
        _BG_LOADED_STYLE="${style}"
    fi

    # Call the draw function defined in the background file
    if declare -f draw_custom_background &>/dev/null; then
        draw_custom_background
    fi
    return 0
}
