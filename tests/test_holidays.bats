#!/usr/bin/env bats
# Holidays: cache format, TTL, config writing (no network involved)

load 'helper'

seed_cache() {
    HOLIDAYS_ENABLED=true
    COUNTRY_CODE=BR
    _ensure_cache_dir
    printf '09-07|Independência do Brasil\n12-25|Natal\n' > "$(_get_cache_file 2026 BR)"
    load_holidays_to_memory 2026 BR
}

@test "cache loads into memory and answers lookups" {
    seed_cache
    is_holiday 7 9
    ! is_holiday 8 9
    [ "$(get_holiday_name 25 12)" = "Natal" ]
    local n
    _holiday_name_v n 7 9
    [ "$n" = "Independência do Brasil" ]
}

@test "holiday names keep pipes intact (name is the last field)" {
    HOLIDAYS_ENABLED=true COUNTRY_CODE=BR
    _ensure_cache_dir
    printf '01-01|New Year | Ano Novo\n' > "$(_get_cache_file 2026 BR)"
    load_holidays_to_memory 2026 BR
    [ "$(get_holiday_name 1 1)" = "New Year | Ano Novo" ]
}

@test "cache TTL: past years never expire, current year does" {
    seed_cache
    printf '01-01|x\n' > "$(_get_cache_file 2020 BR)"
    touch -d "400 days ago" "$(_get_cache_file 2020 BR)"
    _cache_fresh 2020 BR

    _cache_fresh 2026 BR                       # just written -> fresh
    touch -d "40 days ago" "$(_get_cache_file 2026 BR)"
    ! _cache_fresh 2026 BR                     # stale current year -> refetch
}

@test "save_country_to_config rewrites atomically and preserves other keys" {
    mkdir -p "${XDG_CONFIG_HOME}/lvsk-calendar"
    printf 'color_scheme=nord\ncountry_code=US\n' > "${XDG_CONFIG_HOME}/lvsk-calendar/config"
    save_country_to_config "BR"
    run head -1 "${XDG_CONFIG_HOME}/lvsk-calendar/config"
    [ "$output" = "color_scheme=nord" ]
    grep -q '^country_code=BR$' "${XDG_CONFIG_HOME}/lvsk-calendar/config"
    run bash -c "ls '${XDG_CONFIG_HOME}/lvsk-calendar'/config.?????? 2>/dev/null"
    [ "$output" = "" ]
}

@test "save_country_to_config appends when key is missing" {
    mkdir -p "${XDG_CONFIG_HOME}/lvsk-calendar"
    printf 'color_scheme=nord\n' > "${XDG_CONFIG_HOME}/lvsk-calendar/config"
    save_country_to_config "DE"
    grep -q '^country_code=DE$' "${XDG_CONFIG_HOME}/lvsk-calendar/config"
}

@test "save_country_to_config rejects invalid codes" {
    ! save_country_to_config "BRA"
    ! save_country_to_config "b1"
    ! save_country_to_config ""
}

@test "detect_country_from_locale parses LANG variants" {
    [ "$(LC_ALL= LC_MESSAGES= LANG=pt_BR.UTF-8 detect_country_from_locale)" = "BR" ]
    [ "$(LC_ALL= LC_MESSAGES= LANG=de_DE.UTF-8 detect_country_from_locale)" = "DE" ]
    [ "$(LC_ALL= LC_MESSAGES= LANG=pt detect_country_from_locale)" = "BR" ]
    [ "$(LC_ALL= LC_MESSAGES= LANG= detect_country_from_locale)" = "US" ]
}

@test "disabled holidays feature is inert" {
    HOLIDAYS_ENABLED=false
    seed_cache 2>/dev/null || true
    HOLIDAYS_ENABLED=false
    ! is_holiday 7 9
    [ "$(get_holiday_name 7 9)" = "" ]
}
