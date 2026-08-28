#!/usr/bin/env bash

#######################################
# Utility Functions Module
# Date calculations, terminal management, and helper functions
#######################################

# ============================================================================
# DATE UTILITIES (pure bash - no `date` forks at runtime)
# ============================================================================

#######################################
# Calculate days in a given month (pure bash, no forks)
# Arguments:
#   $1 - Name of output variable
#   $2 - Month (1-12)
#   $3 - Year (YYYY)
#######################################
_days_in_month() {
    # Locals are namespaced: with dynamic scoping, a plain local here would
    # shadow a caller's output variable of the same name
    local -n __dim="${1}"
    local __dim_m="${2}"
    local __dim_y="${3}"

    # Days per month (index 0 = placeholder, 1-12 = months)
    local -a __dim_table=(0 31 28 31 30 31 30 31 31 30 31 30 31)

    # Leap year check: divisible by 4, except centuries unless divisible by 400
    if ((__dim_m == 2)) && ((__dim_y % 4 == 0 && (__dim_y % 100 != 0 || __dim_y % 400 == 0))); then
        __dim=29
    else
        __dim="${__dim_table[__dim_m]}"
    fi
}

#######################################
# Calculate days in a given month (printing wrapper, kept for tests/scripts)
# Arguments:
#   $1 - Month (1-12)
#   $2 - Year (YYYY)
# Outputs:
#   Number of days in the month
#######################################
days_in_month() {
    local d
    _days_in_month d "${1}" "${2}"
    printf '%d' "${d}"
}

#######################################
# Convert a civil date to Unix epoch seconds at UTC midnight (pure bash)
# Uses Howard Hinnant's days_from_civil algorithm; exact for all Gregorian
# dates (verified against date -u for leap years and century boundaries).
# The result must be formatted with TZ=UTC0 printf '%(..)T' - formatting it
# in a local timezone would shift the civil date.
# Arguments:
#   $1 - Name of output variable
#   $2 - Year  (YYYY)
#   $3 - Month (1-12)
#   $4 - Day   (1-31)
#######################################
_epoch_of() {
    local -n __ep="${1}"
    local __ep_y="${2}" __ep_m="${3}" __ep_d="${4}" __ep_era __ep_yoe __ep_doy __ep_doe

    ((__ep_m <= 2)) && ((__ep_y--))
    if ((__ep_y >= 0)); then __ep_era=$((__ep_y / 400)); else __ep_era=$(((__ep_y - 399) / 400)); fi
    __ep_yoe=$((__ep_y - __ep_era * 400))
    __ep_doy=$(((153 * (__ep_m + (__ep_m > 2 ? -3 : 9)) + 2) / 5 + __ep_d - 1))
    __ep_doe=$((__ep_yoe * 365 + __ep_yoe / 4 - __ep_yoe / 100 + __ep_doy))
    __ep=$(((__ep_era * 146097 + __ep_doe - 719468) * 86400))
}

#######################################
# Validate day/month values
# Arguments:
#   $1 - Day (1-31)
#   $2 - Month (1-12)
# Returns:
#   0 if valid, 1 otherwise
#######################################
_is_valid_date() {
    local day="${1}"
    local month="${2}"

    [[ "${month}" =~ ^[0-9]+$ && "${month}" -ge 1 && "${month}" -le 12 ]] || return 1
    [[ "${day}" =~ ^[0-9]+$ && "${day}" -ge 1 && "${day}" -le 31 ]] || return 1

    return 0
}

# ============================================================================
# MONTH METADATA CACHE
# Month name, first weekday, day count and ISO week numbers only change when
# the displayed month changes - never per keypress. Cached here so the render
# path performs zero forks.
# ============================================================================

declare -g _MC_KEY=""
declare -g _MC_NAME=""
declare -g _MC_FIRST_DOW=1
declare -g _MC_DAYS=31
declare -ga _MC_WEEK_NUMS=()

#######################################
# Refresh cached metadata for CURRENT_MONTH/CURRENT_YEAR (no-op if unchanged)
# Globals:
#   CURRENT_MONTH, CURRENT_YEAR - Read
#   _MC_NAME       - Locale-aware month name
#   _MC_FIRST_DOW  - ISO weekday of day 1 (1=Monday .. 7=Sunday)
#   _MC_DAYS       - Number of days in the month
#   _MC_WEEK_NUMS  - ISO week number per displayed row
#######################################
refresh_month_cache() {
    local key="${CURRENT_YEAR}-${CURRENT_MONTH}"
    [[ "${key}" == "${_MC_KEY}" ]] && return 0
    _MC_KEY="${key}"

    _days_in_month _MC_DAYS "${CURRENT_MONTH}" "${CURRENT_YEAR}"

    local epoch
    _epoch_of epoch "${CURRENT_YEAR}" "${CURRENT_MONTH}" 1
    TZ=UTC0 printf -v _MC_NAME '%(%B)T' "${epoch}"
    TZ=UTC0 printf -v _MC_FIRST_DOW '%(%u)T' "${epoch}"

    # ISO week number for each displayed row (row 0 keyed on day 1, later
    # rows on their first day), mirroring the previous per-render lookups
    _MC_WEEK_NUMS=()
    local week start_day
    for ((week = 0; week < 6; week++)); do
        if ((week == 0)); then
            start_day=1
        else
            start_day=$((9 - _MC_FIRST_DOW + (week - 1) * 7))
        fi
        ((start_day > _MC_DAYS)) && break
        _epoch_of epoch "${CURRENT_YEAR}" "${CURRENT_MONTH}" "${start_day}"
        TZ=UTC0 printf -v "_MC_WEEK_NUMS[week]" '%(%V)T' "${epoch}"
    done
}

# ============================================================================
# TERMINAL CAPABILITIES & FRAME BUFFER HELPERS
# tput is forked a handful of times at startup to capture the escape
# sequences; after that the render path never creates a process.
# ============================================================================

declare -g TC_CIVIS='' TC_CNORM='' TC_SMCUP='' TC_RMCUP='' TC_EL='' TC_CLEAR=''
declare -g TERM_COLS=80
declare -g TERM_ROWS=25

#######################################
# Capture terminal capabilities once at startup
# Globals:
#   TC_* - Set to the terminal's escape sequences (ANSI fallbacks)
#######################################
init_term_caps() {
    TC_CIVIS=$(tput civis 2>/dev/null) || TC_CIVIS=''
    TC_CNORM=$(tput cnorm 2>/dev/null) || TC_CNORM=''
    TC_SMCUP=$(tput smcup 2>/dev/null) || TC_SMCUP=''
    TC_RMCUP=$(tput rmcup 2>/dev/null) || TC_RMCUP=''
    TC_EL=$(tput el 2>/dev/null)       || TC_EL=''
    TC_CLEAR=$(tput clear 2>/dev/null) || TC_CLEAR=''

    [[ -n "${TC_CIVIS}" ]] || TC_CIVIS=$'\033[?25l'
    [[ -n "${TC_CNORM}" ]] || TC_CNORM=$'\033[?25h'
    [[ -n "${TC_SMCUP}" ]] || TC_SMCUP=$'\033[?1049h'
    [[ -n "${TC_RMCUP}" ]] || TC_RMCUP=$'\033[?1049l'
    [[ -n "${TC_EL}" ]]    || TC_EL=$'\033[K'
    [[ -n "${TC_CLEAR}" ]] || TC_CLEAR=$'\033[2J\033[H'
}

#######################################
# Refresh cached terminal dimensions (startup and SIGWINCH only)
# Globals:
#   TERM_COLS, TERM_ROWS - Updated
#######################################
update_term_size() {
    TERM_COLS=$(tput cols 2>/dev/null) || TERM_COLS=80
    TERM_ROWS=$(tput lines 2>/dev/null) || TERM_ROWS=25
}

#######################################
# Append a cursor move to a frame buffer variable (no forks)
# Arguments:
#   $1 - Name of buffer variable
#   $2 - Row (0-based, tput-style)
#   $3 - Column (0-based, tput-style)
#######################################
_bcup() {
    local -n __bcb="${1}"
    local __bcs
    printf -v __bcs '\033[%d;%dH' "$(($2 + 1))" "$(($3 + 1))"
    __bcb+="${__bcs}"
}

#######################################
# Append printf-formatted text to a frame buffer variable (no forks)
# Arguments:
#   $1 - Name of buffer variable
#   $2 - printf format string
#   $@ - Format arguments
#######################################
_bprintf() {
    local -n __bpb="${1}"
    shift
    local __bps
    printf -v __bps "$@"
    __bpb+="${__bps}"
}

#######################################
# Build a repeated-character string (pure bash, no forks)
# Arguments:
#   $1 - Name of output variable
#   $2 - Character to repeat
#   $3 - Number of repetitions
#######################################
_repeat_v() {
    local -n __rpt="${1}"
    printf -v __rpt '%*s' "${3}" ''
    __rpt="${__rpt// /${2}}"
}

#######################################
# Count characters regardless of locale (pure bash, no forks)
# ${#var} counts bytes under a C locale, which shifts any centering math
# that involves multibyte glyphs (· ◂ ▸ ─ ...). This strips UTF-8
# continuation bytes under a forced byte locale, yielding the character
# count in every environment.
# Arguments:
#   $1 - Name of output variable
#   $2 - String to measure
#######################################
_char_len() {
    local -n __cl="${1}"
    local LC_ALL=C
    local __cl_s="${2}"
    __cl_s="${__cl_s//[$'\x80'-$'\xbf']/}"
    __cl="${#__cl_s}"
}

# ============================================================================
# TERMINAL MANAGEMENT
# ============================================================================

# Original stty state, saved at startup and restored on exit
declare -g _STTY_SAVED=""

# Window address captured at startup for safe cleanup
declare -g LVSK_WINDOW_ADDRESS=""

#######################################
# Setup terminal for TUI mode
# Saves the original stty state, disables echo, enters the alternate screen
# and hides the cursor. Aborts with a message if no controlling tty exists.
# Globals:
#   _STTY_SAVED - Set to the original stty -g state
#######################################
setup_terminal() {
    if ! _STTY_SAVED=$(stty -g < /dev/tty 2>/dev/null); then
        printf 'lvsk-calendar: no controlling terminal (/dev/tty unavailable)\n' >&2
        exit 1
    fi
    # Disable echo; /dev/tty keeps this working when launched from app launchers
    stty -echo < /dev/tty
    printf '%s%s%s' "${TC_SMCUP}" "${TC_CIVIS}" "${TC_CLEAR}"
}

#######################################
# Cleanup and restore terminal
# Restores the exact original stty state and leaves the alternate screen.
# Deliberately does NOT clear: rmcup restores the user's previous screen
# contents, and clearing here would destroy them.
#######################################
cleanup_terminal() {
    [[ -n "${_STTY_SAVED}" ]] && stty "${_STTY_SAVED}" < /dev/tty 2>/dev/null
    printf '%s%s' "${TC_RMCUP}" "${TC_CNORM}"

    # Close the floating window only when launched via the launcher, and only
    # if we positively identified our own window at startup (see setup_hyprland)
    if [[ -n "${LAUNCHED_BY_LAUNCHER:-}" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -n "${LVSK_WINDOW_ADDRESS}" ]]; then
        if hyprctl clients -j 2>/dev/null \
            | jq -e --arg a "${LVSK_WINDOW_ADDRESS}" 'any(.[]; .address == $a)' >/dev/null 2>&1; then
            # Hyprland 0.56 (Omarchy Quattro) evaluates `hyprctl dispatch`
            # arguments as Lua. Older Hyprland has no Lua API and answers an
            # unknown dispatcher with a message rather than a failure, so the
            # reply is checked too before falling back to the legacy form.
            local hypr_reply hypr_status
            hypr_reply=$(hyprctl dispatch \
                "hl.dsp.window.close({ window = \"address:${LVSK_WINDOW_ADDRESS}\" })" 2>&1)
            hypr_status=$?
            if ((hypr_status != 0)) || [[ -n "${hypr_reply}" && "${hypr_reply}" != "ok" ]]; then
                hyprctl dispatch closewindow "address:${LVSK_WINDOW_ADDRESS}" >/dev/null 2>&1 || true
            fi
        fi
    fi
}

#######################################
# Collect the ancestor PID chain of this process (pure bash, /proc walk)
# Arguments:
#   $1 - Name of output variable (space-separated PID list)
#######################################
_ancestor_pids() {
    local -n __anc="${1}"
    local __anc_pid=$$ __anc_line
    __anc=""
    while ((__anc_pid > 1)); do
        __anc+="${__anc_pid} "
        IFS= read -r __anc_line < "/proc/${__anc_pid}/stat" 2>/dev/null || break
        # Strip "pid (comm) " - comm may contain spaces or parentheses
        __anc_line="${__anc_line##*) }"
        set -- ${__anc_line}
        __anc_pid="${2}"   # field after state is ppid
    done
    __anc="${__anc% }"
}

#######################################
# Identify our own Hyprland window for safe cleanup
# Matches the client whose PID is in our ancestor chain (the terminal
# emulator), which is immune to focus changes and duplicate titles.
# Requires jq; without it no window is ever closed (conservative).
# Globals:
#   LVSK_WINDOW_ADDRESS - Set to our window address, or left empty
#######################################
setup_hyprland() {
    LVSK_WINDOW_ADDRESS=""
    [[ -n "${LAUNCHED_BY_LAUNCHER:-}" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 0
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0

    local clients pids
    clients=$(hyprctl clients -j 2>/dev/null) || return 0
    _ancestor_pids pids

    LVSK_WINDOW_ADDRESS=$(jq -r --arg pids "${pids}" \
        '($pids | split(" ") | map(tonumber)) as $set
         | first(.[] | select(.pid as $p | $set | index($p)) | .address) // empty' \
        <<<"${clients}" 2>/dev/null) || LVSK_WINDOW_ADDRESS=""
}

# ============================================================================
# SPLASH SCREEN
# ============================================================================

#######################################
# Display minimalist splash screen
# Shows ASCII art logo centered in terminal
# Globals:
#   COLORS - Uses color definitions
#   TERM_COLS, TERM_ROWS - Cached terminal dimensions
#######################################
show_splash() {
    local buf="${TC_CLEAR}"

    # ASCII art logo
    local -a logo=(
        '  |               |    '
        '  | \ \   /  __|  |  / '
        '  |  \ \ / \__ \    <  '
        ' _|   \_/  ____/ _|\_\ '
    )

    local logo_height=${#logo[@]}
    local top_padding=$(((TERM_ROWS - logo_height) / 2))
    ((top_padding < 0)) && top_padding=0

    local i line line_len left_padding
    for ((i = 0; i < logo_height; i++)); do
        line="${logo[i]}"
        line_len=${#line}
        left_padding=$(((TERM_COLS - line_len) / 2))
        ((left_padding < 0)) && left_padding=0
        _bcup buf $((top_padding + i)) "${left_padding}"
        _bprintf buf '%b%b%s%b' "${COLORS[BASE]}" "${COLORS[DIM]}" "${line}" "${COLORS[RESET]}"
    done

    printf '%s' "${buf}"
    sleep 1
}
