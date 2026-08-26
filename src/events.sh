#!/usr/bin/env bash

#######################################
# Events Module
# Handles user-created calendar events: storage, loading, CRUD, and display.
# Mirrors the holidays module pattern (derive data -> text file under XDG ->
# associative array -> render in grid/footer).
#######################################

# ============================================================================
# CONFIGURATION
# ============================================================================

# Note: EVENTS_ENABLED is defined in config.sh

# Data directory and file (user data lives under XDG_DATA_HOME, not cache)
declare -g EVENTS_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/lvsk-calendar"
declare -g EVENTS_DATA_FILE="${EVENTS_DATA_DIR}/events.tsv"

# Associative array: "YYYY-MM-DD" -> events for that day, joined by record
# separator. Each event entry is "HH:MM<US>title".
declare -gA EVENTS_DATA=()

# In-memory separators (ASCII control chars that never appear in user input)
# Guarded so re-sourcing the module (e.g. in tests) doesn't trip on readonly
if [[ ! -v EVENTS_RS ]]; then
    declare -gr EVENTS_RS=$'\x1e'  # record separator: between events of the same day
    declare -gr EVENTS_US=$'\x1f'  # unit separator: between time and title
fi

# ============================================================================
# STORAGE HELPERS
# ============================================================================

#######################################
# Ensure data directory exists with private permissions (0700)
# Returns:
#   0 on success, 1 if the directory can't be created
#######################################
_ensure_events_dir() {
    if [[ ! -d "${EVENTS_DATA_DIR}" ]]; then
        # shellcheck disable=SC2174  # -m on the leaf only is intended: parents keep defaults
        mkdir -p -m 700 "${EVENTS_DATA_DIR}" 2>/dev/null || return 1
    else
        # Tighten directories created by older versions with the default umask
        chmod 700 "${EVENTS_DATA_DIR}" 2>/dev/null || true
    fi
    return 0
}

#######################################
# Run a mutation while holding the events file lock
# Serializes concurrent read-modify-write cycles between instances (the
# launcher allows several). Degrades to unlocked if flock is unavailable.
# Arguments:
#   $@ - Command (function) to run under the lock
#######################################
_with_events_lock() {
    _ensure_events_dir || return 1

    local rc=0 __lock_fd
    if command -v flock >/dev/null 2>&1; then
        exec {__lock_fd}>"${EVENTS_DATA_DIR}/.events.lock" || return 1
        if ! flock -w 5 "${__lock_fd}"; then
            exec {__lock_fd}>&-
            return 1
        fi
        "$@"; rc=$?
        exec {__lock_fd}>&-
    else
        "$@"; rc=$?
    fi
    return "${rc}"
}

#######################################
# Atomically replace the events file with the given lines
# Writes to a same-directory tempfile (0600 via mktemp) and renames over the
# original, so a crash mid-write can never truncate the user's data.
# Arguments:
#   $1 - Name of array holding the new file lines
#######################################
_rewrite_events_file() {
    local -n __rwl="${1}"
    local __rwl_tmp
    __rwl_tmp=$(mktemp "${EVENTS_DATA_FILE}.XXXXXX" 2>/dev/null) || return 1

    if ((${#__rwl[@]} > 0)); then
        if ! printf '%s\n' "${__rwl[@]}" > "${__rwl_tmp}"; then
            rm -f "${__rwl_tmp}"
            return 1
        fi
    fi
    mv -f "${__rwl_tmp}" "${EVENTS_DATA_FILE}"
}

#######################################
# Build the date key for the currently selected day (YYYY-MM-DD)
# Arguments:
#   $1 - Name of output variable
# Globals:
#   CURRENT_YEAR, CURRENT_MONTH, SELECTED_DAY
#######################################
_event_key_v() {
    printf -v "${1}" '%04d-%02d-%02d' "${CURRENT_YEAR}" "${CURRENT_MONTH}" "${SELECTED_DAY}"
}

#######################################
# Validate a time string (empty allowed, otherwise HH:MM 24h)
# Arguments:
#   $1 - Time string
# Returns:
#   0 if valid, 1 otherwise
#######################################
_is_valid_time() {
    local t="${1}"
    [[ -z "${t}" ]] && return 0
    [[ "${t}" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]
}

# ============================================================================
# LOADING
# ============================================================================

#######################################
# Load events from the data file into memory
# A single file covers all years, so this is loaded once at startup and again
# after every mutation.
# Globals:
#   EVENTS_DATA - Populated (grouped by date)
#######################################
load_events_to_memory() {
    EVENTS_DATA=()

    [[ ! -f "${EVENTS_DATA_FILE}" ]] && return 0

    local date time title entry
    while IFS='|' read -r date time title || [[ -n "${date}" ]]; do
        [[ -z "${date}" ]] && continue
        entry="${time}${EVENTS_US}${title}"
        if [[ -n "${EVENTS_DATA[${date}]:-}" ]]; then
            EVENTS_DATA["${date}"]="${EVENTS_DATA[${date}]}${EVENTS_RS}${entry}"
        else
            EVENTS_DATA["${date}"]="${entry}"
        fi
    done < "${EVENTS_DATA_FILE}"

    return 0
}

#######################################
# Initialize events system (called once at startup)
# Globals:
#   EVENTS_ENABLED - Checked for feature flag
#######################################
init_events() {
    [[ "${EVENTS_ENABLED}" != "true" ]] && return 0
    _ensure_events_dir || return 0
    # Tighten files created by older versions with the default umask
    [[ -f "${EVENTS_DATA_FILE}" ]] && chmod 600 "${EVENTS_DATA_FILE}" 2>/dev/null
    load_events_to_memory
}

# ============================================================================
# LOOKUP
# ============================================================================

#######################################
# Get the events for a date, sorted by time, into an array (no forks)
# Chronological insertion sort on the fixed-width HH:MM prefix; untimed
# events use a high sentinel so they sort last. A "HH:MM|" prefix (the pipe
# never occurs in a time) is added for sorting and stripped afterwards.
# Arguments:
#   $1 - Name of output array variable
#   $2 - Date key (YYYY-MM-DD)
#######################################
_events_for_date() {
    # Locals are namespaced: with dynamic scoping, a plain local here would
    # shadow a caller's output variable of the same name and swallow the result
    local -n __evd="${1}"
    __evd=()

    local __efd_blob="${EVENTS_DATA[${2}]:-}"
    [[ -z "${__efd_blob}" ]] && return 0

    local -a __efd_items=()
    local __efd_rest="${__efd_blob}" __efd_item
    while [[ -n "${__efd_rest}" ]]; do
        __efd_item="${__efd_rest%%"${EVENTS_RS}"*}"
        __efd_items+=("${__efd_item}")
        [[ "${__efd_item}" == "${__efd_rest}" ]] && break
        __efd_rest="${__efd_rest#*"${EVENTS_RS}"}"
    done

    local -a __efd_keyed=()
    local __efd_tt
    for __efd_item in "${__efd_items[@]}"; do
        __efd_tt="${__efd_item%%"${EVENTS_US}"*}"
        [[ -z "${__efd_tt}" ]] && __efd_tt="99:99"
        __efd_keyed+=("${__efd_tt}|${__efd_item}")
    done

    # Insertion sort (stable, fork-free; n is at most a handful of events)
    local __efd_n=${#__efd_keyed[@]} __efd_cur __efd_i __efd_j
    for ((__efd_i = 1; __efd_i < __efd_n; __efd_i++)); do
        __efd_cur="${__efd_keyed[__efd_i]}"
        for ((__efd_j = __efd_i - 1; __efd_j >= 0; __efd_j--)); do
            [[ "${__efd_keyed[__efd_j]}" > "${__efd_cur}" ]] || break
            __efd_keyed[__efd_j + 1]="${__efd_keyed[__efd_j]}"
        done
        __efd_keyed[__efd_j + 1]="${__efd_cur}"
    done

    for ((__efd_i = 0; __efd_i < __efd_n; __efd_i++)); do
        __evd+=("${__efd_keyed[__efd_i]#*|}")
    done
}

#######################################
# Check if a date has at least one event (used for the grid marker)
# Arguments:
#   $1 - Day (1-31)
#   $2 - Month (optional, defaults to CURRENT_MONTH)
# Returns:
#   0 if the day has events, 1 otherwise
#######################################
is_event() {
    local day="${1}"
    local month="${2:-${CURRENT_MONTH}}"

    [[ "${EVENTS_ENABLED}" != "true" || ${#EVENTS_DATA[@]} -eq 0 ]] && return 1
    _is_valid_date "${day}" "${month}" || return 1

    local key
    printf -v key '%04d-%02d-%02d' "${CURRENT_YEAR}" "${month}" "${day}"
    [[ -n "${EVENTS_DATA[${key}]:-}" ]]
}

#######################################
# Build a one-line summary of a date's events (no forks)
# Arguments:
#   $1 - Name of output variable
#   $2 - Date key (YYYY-MM-DD)
# Outputs (via variable):
#   "HH:MM title" of the first event, with " (+N)" suffix if more exist
#######################################
_events_summary_v() {
    local -n __sum="${1}"
    __sum=""
    [[ "${EVENTS_ENABLED}" != "true" ]] && return 0

    local -a __sum_items=()
    _events_for_date __sum_items "${2}"
    local __sum_n=${#__sum_items[@]}
    ((__sum_n == 0)) && return 0

    local __sum_first="${__sum_items[0]}"
    local __sum_t="${__sum_first%%"${EVENTS_US}"*}"
    local __sum_title="${__sum_first#*"${EVENTS_US}"}"

    if [[ -n "${__sum_t}" ]]; then
        __sum="${__sum_t} ${__sum_title}"
    else
        __sum="${__sum_title}"
    fi
    ((__sum_n > 1)) && __sum+=" (+$((__sum_n - 1)))"
}

#######################################
# Get a date's events summary (printing wrapper, kept for tests/scripts)
# Arguments:
#   $1 - Date key (YYYY-MM-DD)
#######################################
get_events_summary() {
    local out
    _events_summary_v out "${1}"
    printf '%s' "${out}"
}

#######################################
# Footer helper: events summary for the currently selected day (no forks)
# Arguments:
#   $1 - Name of output variable
#######################################
_selected_events_summary() {
    local __ses_key
    _event_key_v __ses_key
    _events_summary_v "${1}" "${__ses_key}"
}

# ============================================================================
# MUTATIONS (file is the source of truth; reload memory after each change)
# All mutations run under the events lock and rewrite atomically.
# ============================================================================

#######################################
# Append a new event
# Arguments:
#   $1 - Date key (YYYY-MM-DD)
#   $2 - Time (HH:MM or empty)
#   $3 - Title (non-empty)
# Returns:
#   0 on success, 1 if title is empty or the write failed
#######################################
add_event() {
    local date="${1}" time="${2}" title="${3}"
    [[ -z "${title}" ]] && return 1

    _with_events_lock _add_event_locked "${date}" "${time}" "${title}" || return 1
    load_events_to_memory
}

_add_event_locked() {
    if [[ ! -e "${EVENTS_DATA_FILE}" ]]; then
        : > "${EVENTS_DATA_FILE}" || return 1
        chmod 600 "${EVENTS_DATA_FILE}" 2>/dev/null
    fi
    printf '%s|%s|%s\n' "${1}" "${2}" "${3}" >> "${EVENTS_DATA_FILE}"
}

#######################################
# Delete the first event matching a date/time/title
# Arguments:
#   $1 - Date key, $2 - Time, $3 - Title
#######################################
delete_event() {
    local date="${1}" time="${2}" title="${3}"
    [[ ! -f "${EVENTS_DATA_FILE}" ]] && return 1

    _with_events_lock _delete_event_locked "${date}" "${time}" "${title}" || return 1
    load_events_to_memory
}

_delete_event_locked() {
    local target="${1}|${2}|${3}"
    local -a lines=()
    local removed=0 line
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if ((removed == 0)) && [[ "${line}" == "${target}" ]]; then
            removed=1
            continue
        fi
        lines+=("${line}")
    done < "${EVENTS_DATA_FILE}"

    _rewrite_events_file lines
}

#######################################
# Replace the first event matching a date/time/title with new values
# Arguments:
#   $1 - Date key, $2 - old time, $3 - old title, $4 - new time, $5 - new title
#######################################
edit_event() {
    local date="${1}" old_time="${2}" old_title="${3}" new_time="${4}" new_title="${5}"
    [[ -z "${new_title}" ]] && return 1
    [[ ! -f "${EVENTS_DATA_FILE}" ]] && return 1

    _with_events_lock _edit_event_locked \
        "${date}" "${old_time}" "${old_title}" "${new_time}" "${new_title}" || return 1
    load_events_to_memory
}

_edit_event_locked() {
    local target="${1}|${2}|${3}"
    local replacement="${1}|${4}|${5}"
    local -a lines=()
    local replaced=0 line
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if ((replaced == 0)) && [[ "${line}" == "${target}" ]]; then
            lines+=("${replacement}")
            replaced=1
        else
            lines+=("${line}")
        fi
    done < "${EVENTS_DATA_FILE}"

    _rewrite_events_file lines
}

# ============================================================================
# 12-HOUR TIME CONVERSION
# Storage stays 24h "HH:MM": chronological sorting depends on the fixed-width
# 24h key and the file format is documented. The 12h + AM/PM representation
# exists only at the input/display layer (the modal).
# ============================================================================

#######################################
# Convert a 12h digit buffer + AM/PM into a 24h "HH:MM" string
# Digit buffers come from the modal time field: h, hh, hmm or hhmm
# (e.g. "730" = 7:30, "12" = 12:00). Empty means "no time".
# Arguments:
#   $1 - Name of output variable
#   $2 - Digit buffer (0-4 digits)
#   $3 - AM or PM
# Returns:
#   0 on success (or empty input), 1 on an invalid hour/minute
#######################################
_time12_digits_to_24() {
    local -n __t12="${1}"
    local __t12_d="${2}" __t12_ap="${3}"
    local __t12_h __t12_m
    __t12=""

    [[ -z "${__t12_d}" ]] && return 0

    case ${#__t12_d} in
        1|2) __t12_h=$((10#${__t12_d})); __t12_m=0 ;;
        3)   __t12_h=$((10#${__t12_d:0:1})); __t12_m=$((10#${__t12_d:1:2})) ;;
        4)   __t12_h=$((10#${__t12_d:0:2})); __t12_m=$((10#${__t12_d:2:2})) ;;
        *)   return 1 ;;
    esac

    ((__t12_h >= 1 && __t12_h <= 12)) || return 1
    ((__t12_m >= 0 && __t12_m <= 59)) || return 1

    if [[ "${__t12_ap}" == "AM" ]]; then
        ((__t12_h == 12)) && __t12_h=0          # 12 AM = 00
    else
        ((__t12_h != 12)) && __t12_h=$((__t12_h + 12))   # 12 PM = 12
    fi

    printf -v __t12 '%02d:%02d' "${__t12_h}" "${__t12_m}"
}

#######################################
# Convert a stored 24h "HH:MM" into a 12h digit buffer + AM/PM
# (used to prefill the modal when editing an existing event)
# Arguments:
#   $1 - Name of digits output variable (hhmm, or empty for no time)
#   $2 - Name of AM/PM output variable (AM when there is no time)
#   $3 - 24h time string ("HH:MM" or empty)
#######################################
_time_24_to_12() {
    local -n __t24d="${1}" __t24a="${2}"
    local __t24_t="${3}" __t24_h __t24_m
    __t24d=""
    __t24a="AM"

    [[ -z "${__t24_t}" ]] && return 0

    __t24_h=$((10#${__t24_t%%:*}))
    __t24_m=$((10#${__t24_t#*:}))

    if ((__t24_h >= 12)); then
        __t24a="PM"
        ((__t24_h > 12)) && __t24_h=$((__t24_h - 12))
    else
        ((__t24_h == 0)) && __t24_h=12
    fi

    printf -v __t24d '%02d%02d' "${__t24_h}" "${__t24_m}"
}

#######################################
# Fixed-width (8 chars) 12h display label for a stored 24h time
# "19:30" -> "07:30 PM"; untimed events get a placeholder
# Arguments:
#   $1 - Name of output variable
#   $2 - 24h time string ("HH:MM" or empty)
#######################################
_time24_to_12_display() {
    local -n __t12l="${1}"
    local __t12l_d __t12l_a
    if [[ -z "${2}" ]]; then
        __t12l="--:--   "
        return 0
    fi
    _time_24_to_12 __t12l_d __t12l_a "${2}"
    __t12l="${__t12l_d:0:2}:${__t12l_d:2:2} ${__t12l_a}"
}

# ============================================================================
# INTERACTIVE INPUT (modal overlays drawn on top of the calendar)
# ============================================================================

#######################################
# Draw the form's field labels with the active-field marker
# Arguments:
#   $1 - Title row, $2 - Time row, $3 - Label column, $4 - Active field name
#######################################
_efm_draw_labels() {
    local __efl_trow="${1}" __efl_hrow="${2}" __efl_col="${3}" __efl_active="${4}"

    local __efl_tm="  " __efl_hm="  "
    local __efl_tc="${COLORS[BASE_DIM]}" __efl_hc="${COLORS[BASE_DIM]}"
    if [[ "${__efl_active}" == "title" ]]; then
        __efl_tm="${CHAR[diamond]} "
        __efl_tc="${COLORS[ACCENT_BRIGHT]}${COLORS[BOLD]}"
    else
        __efl_hm="${CHAR[diamond]} "
        __efl_hc="${COLORS[ACCENT_BRIGHT]}${COLORS[BOLD]}"
    fi

    local __efl_buf=""
    _bcup __efl_buf "${__efl_trow}" $((__efl_col - 2))
    _bprintf __efl_buf '%b%s%b%b%-6s%b' \
        "${COLORS[ACCENT]}" "${__efl_tm}" "${COLORS[RESET]}" \
        "${__efl_tc}" "Title" "${COLORS[RESET]}"
    _bcup __efl_buf "${__efl_hrow}" $((__efl_col - 2))
    _bprintf __efl_buf '%b%s%b%b%-6s%b' \
        "${COLORS[ACCENT]}" "${__efl_hm}" "${COLORS[RESET]}" \
        "${__efl_hc}" "Time" "${COLORS[RESET]}"
    printf '%s' "${__efl_buf}"
}

#######################################
# Event form modal: title, 12h time and AM/PM selector
# Linear flow: Enter advances (title -> time -> AM/PM -> save); an empty time
# skips the AM/PM step and saves an untimed event; ESC cancels at any point.
# When editing, fields come prefilled and an emptied title falls back to the
# original (matching the previous prompt semantics).
# Arguments:
#   $1 - Name of 24h time output variable ("HH:MM" or empty)
#   $2 - Name of title output variable
#   $3 - Initial 24h time (empty for a new event)
#   $4 - Initial title (empty for a new event)
#   $5 - Heading ("New event" / "Edit event")
# Returns:
#   0 on save (outputs set), 1 on cancel
#######################################
_event_form_modal() {
    local -n __efm_time="${1}" __efm_title="${2}"
    local __efm_init24="${3}" __efm_inittitle="${4}" __efm_head="${5}"
    __efm_time=""
    __efm_title=""

    local __efm_digits __efm_ap
    _time_24_to_12 __efm_digits __efm_ap "${__efm_init24}"

    _modal_open 9 54 "${__efm_head} · ${_MC_NAME} ${SELECTED_DAY}"

    local __efm_lcol=$((_MODAL_LEFT + 3))
    local __efm_fcol=$((_MODAL_LEFT + 11))
    local __efm_trow=$((_MODAL_TOP + 3))
    local __efm_hrow=$((_MODAL_TOP + 5))
    local __efm_apcol=$((__efm_fcol + 8))
    local __efm_titlefw=$((_MODAL_W - 11 - 3))

    local __efm_buf __efm_probe __efm_err=0 __efm_step="title"
    while :; do
        case "${__efm_step}" in
            title)
                _efm_draw_labels "${__efm_trow}" "${__efm_hrow}" "${__efm_lcol}" "title"
                _modal_draw_time12 "${__efm_hrow}" "${__efm_fcol}" "${__efm_digits}"
                _modal_draw_ampm "${__efm_hrow}" "${__efm_apcol}" "${__efm_ap}" 0
                _modal_hint "type title · enter next · esc cancel"
                if ! _modal_read_line __efm_buf "${__efm_trow}" "${__efm_fcol}" \
                    "${__efm_titlefw}" 80 "${__efm_inittitle}"; then
                    return 1
                fi
                _trim __efm_buf "${__efm_buf}"
                if [[ -z "${__efm_buf}" ]]; then
                    # Empty title: cancel a new event, keep the original on edit
                    [[ -z "${__efm_inittitle}" ]] && return 1
                    __efm_buf="${__efm_inittitle}"
                fi
                __efm_title="${__efm_buf}"
                __efm_step="time"
                ;;
            time)
                _efm_draw_labels "${__efm_trow}" "${__efm_hrow}" "${__efm_lcol}" "time"
                if ((__efm_err)); then
                    _modal_hint "invalid time · use 1-12 hours, 00-59 minutes" "${COLORS[ACCENT_BRIGHT]}"
                    __efm_err=0
                else
                    _modal_hint "digits (0730 = 7:30) · enter next · esc cancel"
                fi
                if ! _modal_read_time12 __efm_digits "${__efm_hrow}" "${__efm_fcol}" \
                    "${__efm_digits}"; then
                    return 1
                fi
                if [[ -z "${__efm_digits}" ]]; then
                    __efm_time=""
                    return 0
                fi
                # Validate hour/minute early (AM as placeholder period)
                if ! _time12_digits_to_24 __efm_probe "${__efm_digits}" "AM"; then
                    __efm_err=1
                    continue
                fi
                __efm_step="ampm"
                ;;
            ampm)
                _modal_hint "◂ ▸ a/p toggle · enter save · esc cancel"
                if ! _modal_select_ampm __efm_ap "${__efm_hrow}" "${__efm_apcol}" "${__efm_ap}"; then
                    return 1
                fi
                # Digits were validated in the time step; this cannot fail
                _time12_digits_to_24 __efm_time "${__efm_digits}" "${__efm_ap}"
                return 0
                ;;
        esac
    done
}

#######################################
# Render the picker modal's visible rows
# Arguments:
#   $1 - Name of the items array
#   $2 - Highlight index, $3 - Window start, $4 - Rows shown
#######################################
_epm_draw_rows() {
    local -n __epr="${1}"
    local __epr_hl="${2}" __epr_ws="${3}" __epr_show="${4}"
    local __epr_buf="" __epr_i __epr_idx __epr_t __epr_title __epr_label __epr_pad
    local __epr_col=$((_MODAL_LEFT + 3))
    local __epr_maxtitle=$((_MODAL_W - 22))

    printf -v __epr_pad '%*s' $((_MODAL_W - 6)) ''

    for ((__epr_i = 0; __epr_i < __epr_show; __epr_i++)); do
        __epr_idx=$((__epr_ws + __epr_i))
        __epr_t="${__epr[__epr_idx]%%"${EVENTS_US}"*}"
        __epr_title="${__epr[__epr_idx]#*"${EVENTS_US}"}"
        ((${#__epr_title} > __epr_maxtitle)) && __epr_title="${__epr_title:0:$((__epr_maxtitle - 1))}…"
        _time24_to_12_display __epr_label "${__epr_t}"

        _bcup __epr_buf $((_MODAL_TOP + 2 + __epr_i)) "${__epr_col}"
        _bprintf __epr_buf '%s' "${__epr_pad}"
        _bcup __epr_buf $((_MODAL_TOP + 2 + __epr_i)) "${__epr_col}"
        if ((__epr_idx == __epr_hl)); then
            _bprintf __epr_buf '%b%s%b %b%2d%b %b%s%b  %b%b%s%b' \
                "${COLORS[ACCENT]}" "${CHAR[diamond]}" "${COLORS[RESET]}" \
                "${COLORS[BASE_DIM]}" $((__epr_idx + 1)) "${COLORS[RESET]}" \
                "${COLORS[BASE_DIM]}" "${__epr_label}" "${COLORS[RESET]}" \
                "${COLORS[HIGHLIGHT]}" "${COLORS[BOLD]}" "${__epr_title}" "${COLORS[RESET]}"
        else
            _bprintf __epr_buf '  %b%2d%b %b%s%b  %b%s%b' \
                "${COLORS[BASE_DIMMER]}" $((__epr_idx + 1)) "${COLORS[RESET]}" \
                "${COLORS[BASE_DIMMER]}" "${__epr_label}" "${COLORS[RESET]}" \
                "${COLORS[BASE]}" "${__epr_title}" "${COLORS[RESET]}"
        fi
    done
    printf '%s' "${__epr_buf}"
}

#######################################
# Event picker modal for a date
# A single event is selected automatically; several open a list modal with
# j/k or arrow navigation, 1-9 quick pick, Enter to confirm, ESC/q to cancel.
# Times are shown in 12h AM/PM format.
# Arguments:
#   $1 - Name of the output variable (set to "HH:MM<US>title" or empty)
#   $2 - Date key
# Returns:
#   0 if an event was chosen, 1 otherwise
#######################################
_event_pick_modal() {
    local -n __epm="${1}"
    local __epm_date="${2}"
    __epm=""

    local -a __epm_items=()
    _events_for_date __epm_items "${__epm_date}"
    local __epm_n=${#__epm_items[@]}
    ((__epm_n == 0)) && return 1

    if ((__epm_n == 1)); then
        __epm="${__epm_items[0]}"
        return 0
    fi

    # Clamp the visible window to the terminal (5 rows of modal chrome)
    local __epm_show="${__epm_n}"
    local __epm_maxshow=$((TERM_ROWS - 7))
    ((__epm_show > __epm_maxshow)) && __epm_show="${__epm_maxshow}"
    ((__epm_show < 1)) && __epm_show=1

    _modal_open $((__epm_show + 5)) 54 "Select event · ${_MC_NAME} ${SELECTED_DAY}"
    _modal_hint "j/k · 1-9 pick · enter select · esc cancel"
    printf '%s' "${TC_CIVIS}"

    local __epm_hl=0 __epm_ws=0
    _epm_draw_rows __epm_items "${__epm_hl}" "${__epm_ws}" "${__epm_show}"

    local __epm_c __epm_seq __epm_rc __epm_move
    while :; do
        if ! IFS= read -rsn1 __epm_c < /dev/tty; then
            __epm_rc=$?
            ((__epm_rc > 128)) && continue
            return 1
        fi

        __epm_move=0
        case "${__epm_c}" in
            ''|$'\r')  # Enter ("" via icrnl, raw \r without it)
                __epm="${__epm_items[__epm_hl]}"
                return 0
                ;;
            $'\x1b')
                _read_escape_sequence __epm_seq
                [[ -z "${__epm_seq}" ]] && return 1
                case "${__epm_seq}" in
                    '['*A|OA) __epm_move=-1 ;;
                    '['*B|OB) __epm_move=1 ;;
                esac
                ;;
            k) __epm_move=-1 ;;
            j) __epm_move=1 ;;
            [1-9])
                if ((__epm_c <= __epm_n)); then
                    __epm="${__epm_items[$((__epm_c - 1))]}"
                    return 0
                fi
                ;;
            q) return 1 ;;
        esac

        if ((__epm_move != 0)); then
            __epm_hl=$((__epm_hl + __epm_move))
            ((__epm_hl < 0)) && __epm_hl=0
            ((__epm_hl >= __epm_n)) && __epm_hl=$((__epm_n - 1))
            ((__epm_hl < __epm_ws)) && __epm_ws="${__epm_hl}"
            ((__epm_hl >= __epm_ws + __epm_show)) && __epm_ws=$((__epm_hl - __epm_show + 1))
            _epm_draw_rows __epm_items "${__epm_hl}" "${__epm_ws}" "${__epm_show}"
        fi
    done
}

# ============================================================================
# ACTIONS (dispatched from input.sh)
# ============================================================================

#######################################
# Add an event to the selected day (modal form)
#######################################
event_add_action() {
    [[ "${EVENTS_ENABLED}" != "true" ]] && return 0

    local date time24 title
    _event_key_v date

    if _event_form_modal time24 title "" "" "New event" && [[ -n "${title}" ]]; then
        _is_valid_time "${time24}" && add_event "${date}" "${time24}" "${title}"
    fi
    FIRST_RENDER=1
}

#######################################
# Edit an event on the selected day (picker + prefilled modal form)
#######################################
event_edit_action() {
    [[ "${EVENTS_ENABLED}" != "true" ]] && return 0

    local date chosen
    _event_key_v date
    if ! _event_pick_modal chosen "${date}" || [[ -z "${chosen}" ]]; then
        FIRST_RENDER=1
        return 0
    fi

    local old_time="${chosen%%"${EVENTS_US}"*}"
    local old_title="${chosen#*"${EVENTS_US}"}"
    local new_time new_title

    if _event_form_modal new_time new_title "${old_time}" "${old_title}" "Edit event" \
        && [[ -n "${new_title}" ]]; then
        _is_valid_time "${new_time}" \
            && edit_event "${date}" "${old_time}" "${old_title}" "${new_time}" "${new_title}"
    fi
    FIRST_RENDER=1
}

#######################################
# Delete an event from the selected day (picker + confirmation modal)
#######################################
event_delete_action() {
    [[ "${EVENTS_ENABLED}" != "true" ]] && return 0

    local date chosen
    _event_key_v date
    if ! _event_pick_modal chosen "${date}" || [[ -z "${chosen}" ]]; then
        FIRST_RENDER=1
        return 0
    fi

    local time="${chosen%%"${EVENTS_US}"*}"
    local title="${chosen#*"${EVENTS_US}"}"

    # Confirm before destroying (long titles are trimmed to fit the box)
    local label="${title}"
    ((${#label} > 32)) && label="${label:0:31}…"
    if _modal_confirm "Delete \"${label}\"?"; then
        delete_event "${date}" "${time}" "${title}"
    fi
    FIRST_RENDER=1
}
