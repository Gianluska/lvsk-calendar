#!/usr/bin/env bash

#######################################
# Holidays Module
# Handles holiday detection, API fetching, caching, and display
#######################################

# ============================================================================
# CONFIGURATION
# ============================================================================

# Note: HOLIDAYS_ENABLED and COUNTRY_CODE are defined in config.sh

# Cache directory for holiday data
declare -g HOLIDAYS_CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/lvsk-calendar/holidays"

# Associative array to store holidays for current year (MM-DD -> name)
declare -gA HOLIDAYS_DATA=()

# Track loaded country/year to detect changes
declare -g HOLIDAYS_LOADED_COUNTRY=""
declare -g HOLIDAYS_LOADED_YEAR=""

# API endpoint (readonly)
declare -gr NAGER_API="https://date.nager.at/api/v3"

# ============================================================================
# COUNTRY DETECTION
# ============================================================================

#######################################
# Detect country code from system locale
# Extracts 2-letter ISO country code from LANG/LC_* variables
# Falls back to US if detection fails
# Outputs:
#   2-letter country code (defaults to US)
#######################################
detect_country_from_locale() {
    local locale="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"

    # Extract country code from locale (e.g., pt_BR.UTF-8 -> BR)
    if [[ "${locale}" =~ _([A-Z]{2}) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
        return 0
    fi

    # Fallback: try to get from language code
    if [[ "${locale}" =~ ^([a-z]{2}) ]]; then
        # Map common language codes to countries
        case "${BASH_REMATCH[1]}" in
            en) printf 'US' ;;
            pt) printf 'BR' ;;
            es) printf 'ES' ;;
            de) printf 'DE' ;;
            fr) printf 'FR' ;;
            it) printf 'IT' ;;
            ja) printf 'JP' ;;
            zh) printf 'CN' ;;
            ko) printf 'KR' ;;
            ru) printf 'RU' ;;
            *)  printf 'US' ;;  # Default to US for unknown languages
        esac
        return 0
    fi

    # Ultimate fallback: US
    printf 'US'
}

#######################################
# Save country code to config file
# Uses pure bash for file manipulation (no sed/grep)
# Arguments:
#   $1 - 2-letter country code
# Returns:
#   0 on success, 1 on invalid code
# Globals:
#   COUNTRY_CODE - Updated with new value
#######################################
save_country_to_config() {
    local code="${1}"

    # Validate: must be exactly 2 uppercase letters
    if [[ ! "${code}" =~ ^[A-Z]{2}$ ]]; then
        return 1
    fi

    local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/lvsk-calendar"
    local user_config="${config_dir}/config"

    # Ensure config directory exists
    [[ ! -d "${config_dir}" ]] && mkdir -p "${config_dir}"

    # Read existing config into array (pure bash approach)
    local -a config_lines=()
    local found_country=0
    local line

    if [[ -f "${user_config}" ]]; then
        while IFS= read -r line || [[ -n "${line}" ]]; do
            # Check if this is the country_code line
            if [[ "${line}" == country_code=* ]]; then
                config_lines+=("country_code=${code}")
                found_country=1
            else
                config_lines+=("${line}")
            fi
        done < "${user_config}"
    fi

    # If country_code wasn't found, add it
    if ((found_country == 0)); then
        config_lines+=("")
        config_lines+=("# Country code for public holidays (2-letter ISO code)")
        config_lines+=("country_code=${code}")
    fi

    # Write back to file (single write operation)
    printf '%s\n' "${config_lines[@]}" > "${user_config}"

    # Update global variable
    COUNTRY_CODE="${code}"
}

# ============================================================================
# API & CACHING
# ============================================================================

#######################################
# Ensure cache directory exists
#######################################
_ensure_cache_dir() {
    [[ ! -d "${HOLIDAYS_CACHE_DIR}" ]] && mkdir -p "${HOLIDAYS_CACHE_DIR}"
}

#######################################
# Get cache file path for a specific year and country
# Arguments:
#   $1 - Year (YYYY)
#   $2 - Country code
# Outputs:
#   Full path to cache file
#######################################
_get_cache_file() {
    local year="${1}"
    local country="${2}"
    printf '%s/%s_%s.txt' "${HOLIDAYS_CACHE_DIR}" "${country}" "${year}"
}

#######################################
# Check if cache exists and is valid (non-empty)
# Arguments:
#   $1 - Year
#   $2 - Country code
# Returns:
#   0 if cache exists and valid, 1 otherwise
#######################################
_cache_exists() {
    local year="${1}"
    local country="${2}"
    local cache_file

    cache_file="$(_get_cache_file "${year}" "${country}")"

    [[ -f "${cache_file}" && -s "${cache_file}" ]]
}

#######################################
# Fetch holidays from API and cache them
# Arguments:
#   $1 - Year (YYYY)
#   $2 - Country code
# Returns:
#   0 on success, 1 on failure
#######################################
fetch_and_cache_holidays() {
    local year="${1}"
    local country="${2}"

    _ensure_cache_dir

    local cache_file api_url response
    cache_file="$(_get_cache_file "${year}" "${country}")"
    api_url="${NAGER_API}/PublicHolidays/${year}/${country}"

    # Check if curl is available
    if ! command -v curl &>/dev/null; then
        return 1
    fi

    # Fetch from API with timeout
    response=$(curl -s --connect-timeout 5 --max-time 10 "${api_url}" 2>/dev/null) || return 1

    # Check if response is valid
    if [[ -z "${response}" || "${response}" == "null" || "${response}" == *"NotFound"* ]]; then
        return 1
    fi

    # Parse JSON and save to cache
    # Format: MM-DD|localName (or name if localName is empty)
    if command -v jq &>/dev/null; then
        # Use jq for robust parsing
        printf '%s' "${response}" | jq -r '.[] | "\(.date | split("-") | .[1:] | join("-"))|\(.localName // .name)"' > "${cache_file}" 2>/dev/null
    else
        # Fallback: use grep/sed (less robust but works for simple cases)
        local date mm_dd name
        while IFS= read -r date; do
            # Extract month-day (remove YYYY- prefix)
            mm_dd="${date#????-}"
            # Try to get localName first, then name
            name=$(printf '%s' "${response}" | grep -oP "\"date\"\\s*:\\s*\"${date}\"[^}]*\"localName\"\\s*:\\s*\"\\K[^\"]*" | head -1) || true
            if [[ -z "${name}" ]]; then
                name=$(printf '%s' "${response}" | grep -oP "\"date\"\\s*:\\s*\"${date}\"[^}]*\"name\"\\s*:\\s*\"\\K[^\"]*" | head -1) || true
            fi
            printf '%s|%s\n' "${mm_dd}" "${name}"
        done < <(printf '%s' "${response}" | grep -oP '"date"\s*:\s*"\K[^"]+') > "${cache_file}" 2>/dev/null
    fi

    # Verify cache was created and is non-empty
    [[ -s "${cache_file}" ]]
}

#######################################
# Load holidays from cache into memory
# Arguments:
#   $1 - Year
#   $2 - Country code
# Returns:
#   0 on success, 1 if cache doesn't exist
# Globals:
#   HOLIDAYS_DATA - Populated with holiday data
#######################################
load_holidays_to_memory() {
    local year="${1}"
    local country="${2}"

    # Clear existing data
    HOLIDAYS_DATA=()

    local cache_file
    cache_file="$(_get_cache_file "${year}" "${country}")"

    [[ ! -f "${cache_file}" ]] && return 1

    # Read cache file into associative array
    local date name
    while IFS='|' read -r date name || [[ -n "${date}" ]]; do
        [[ -z "${date}" ]] && continue
        HOLIDAYS_DATA["${date}"]="${name}"
    done < "${cache_file}"

    return 0
}

# ============================================================================
# PUBLIC API
# ============================================================================

#######################################
# Initialize holidays system
# Auto-detects country from locale if not configured
# Called once at startup
# Globals:
#   HOLIDAYS_ENABLED - Checked for feature flag
#   COUNTRY_CODE - May be set from auto-detection
#######################################
init_holidays() {
    [[ "${HOLIDAYS_ENABLED}" != "true" ]] && return 0

    # If country code is not set, auto-detect from locale and save
    if [[ -z "${COUNTRY_CODE}" ]]; then
        local detected
        detected=$(detect_country_from_locale)
        if [[ -n "${detected}" ]]; then
            COUNTRY_CODE="${detected}"
            save_country_to_config "${detected}"
        fi
    fi

    # Load holidays for current year
    if [[ -n "${COUNTRY_CODE}" ]]; then
        load_holidays "${CURRENT_YEAR}"
    fi
}

#######################################
# Load holidays for a specific year
# Fetches from API if not cached
# Arguments:
#   $1 - Year (optional, defaults to CURRENT_YEAR)
# Globals:
#   HOLIDAYS_LOADED_YEAR - Updated on successful load
#   HOLIDAYS_LOADED_COUNTRY - Updated on successful load
#######################################
load_holidays() {
    local year="${1:-${CURRENT_YEAR}}"

    [[ "${HOLIDAYS_ENABLED}" != "true" || -z "${COUNTRY_CODE}" ]] && return 0

    # Check if already loaded for this year/country
    if [[ "${HOLIDAYS_LOADED_YEAR}" == "${year}" && "${HOLIDAYS_LOADED_COUNTRY}" == "${COUNTRY_CODE}" ]]; then
        return 0
    fi

    # Try to load from cache, fetch if not available
    if ! _cache_exists "${year}" "${COUNTRY_CODE}"; then
        fetch_and_cache_holidays "${year}" "${COUNTRY_CODE}" || true
    fi

    # Load into memory
    if load_holidays_to_memory "${year}" "${COUNTRY_CODE}"; then
        HOLIDAYS_LOADED_YEAR="${year}"
        HOLIDAYS_LOADED_COUNTRY="${COUNTRY_CODE}"
    fi
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

    # Validate month range (1-12)
    [[ "${month}" =~ ^[0-9]+$ && "${month}" -ge 1 && "${month}" -le 12 ]] || return 1

    # Validate day range (1-31, basic check)
    [[ "${day}" =~ ^[0-9]+$ && "${day}" -ge 1 && "${day}" -le 31 ]] || return 1

    return 0
}

#######################################
# Check if a specific date is a holiday
# Arguments:
#   $1 - Day (1-31)
#   $2 - Month (1-12, optional, defaults to CURRENT_MONTH)
# Returns:
#   0 if holiday, 1 otherwise
#######################################
is_holiday() {
    local day="${1}"
    local month="${2:-${CURRENT_MONTH}}"

    # Early exit conditions
    [[ "${HOLIDAYS_ENABLED}" != "true" || ${#HOLIDAYS_DATA[@]} -eq 0 ]] && return 1

    # Bounds checking
    _is_valid_date "${day}" "${month}" || return 1

    # Format as MM-DD with leading zeros using printf
    local mm_dd
    printf -v mm_dd '%02d-%02d' "${month}" "${day}"

    [[ -n "${HOLIDAYS_DATA[${mm_dd}]:-}" ]]
}

#######################################
# Get holiday name for a specific date
# Arguments:
#   $1 - Day (1-31)
#   $2 - Month (1-12, optional, defaults to CURRENT_MONTH)
# Outputs:
#   Holiday name or empty string
#######################################
get_holiday_name() {
    local day="${1}"
    local month="${2:-${CURRENT_MONTH}}"

    # Early exit conditions
    if [[ "${HOLIDAYS_ENABLED}" != "true" || ${#HOLIDAYS_DATA[@]} -eq 0 ]]; then
        return
    fi

    # Bounds checking - return empty on invalid
    _is_valid_date "${day}" "${month}" || return

    # Format as MM-DD with leading zeros
    local mm_dd
    printf -v mm_dd '%02d-%02d' "${month}" "${day}"

    printf '%s' "${HOLIDAYS_DATA[${mm_dd}]:-}"
}

#######################################
# Get holiday name for currently selected day
# Outputs:
#   Holiday name or empty string
# Globals:
#   SELECTED_DAY - Current selection
#   CURRENT_MONTH - Current month
#######################################
get_selected_holiday() {
    get_holiday_name "${SELECTED_DAY}" "${CURRENT_MONTH}"
}
