#!/usr/bin/env bats
# Navigation: month/year shifts, clamping, weekday-preserving overflow,
# and escape-sequence dispatch

load 'helper'

@test "month wraps across year boundaries" {
    CURRENT_MONTH=1; CURRENT_YEAR=2026; _MC_KEY=""
    prev_month
    [ "${CURRENT_MONTH}-${CURRENT_YEAR}" = "12-2025" ]
    next_month
    [ "${CURRENT_MONTH}-${CURRENT_YEAR}" = "1-2026" ]
}

@test "selection clamps when the target month is shorter" {
    CURRENT_MONTH=1; CURRENT_YEAR=2026; SELECTED_DAY=31; _MC_KEY=""
    refresh_month_cache
    next_month
    [ "${CURRENT_MONTH}" = "2" ]
    [ "${SELECTED_DAY}" = "28" ]
}

@test "year shift keeps month, clamps Feb 29 on non-leap target" {
    CURRENT_MONTH=2; CURRENT_YEAR=2024; SELECTED_DAY=29; _MC_KEY=""
    refresh_month_cache
    next_year
    [ "${CURRENT_YEAR}" = "2025" ]
    [ "${SELECTED_DAY}" = "28" ]
}

@test "underflow preserves the weekday column (Aug 3 - 7d = Jul 27)" {
    CURRENT_MONTH=8; CURRENT_YEAR=2026; _MC_KEY=""
    refresh_month_cache
    SELECTED_DAY=$((3 - 7))
    handle_day_overflow
    [ "${CURRENT_MONTH}" = "7" ]
    [ "${SELECTED_DAY}" = "27" ]
    [ "$(date -u -d 2026-07-27 +%u)" = "$(date -u -d 2026-08-03 +%u)" ]
}

@test "overflow preserves the weekday column (Aug 30 + 7d = Sep 6)" {
    CURRENT_MONTH=8; CURRENT_YEAR=2026; _MC_KEY=""
    refresh_month_cache
    SELECTED_DAY=$((30 + 7))
    handle_day_overflow
    [ "${CURRENT_MONTH}" = "9" ]
    [ "${SELECTED_DAY}" = "6" ]
}

@test "goto_today returns to the real current date" {
    CURRENT_MONTH=1; CURRENT_YEAR=1999
    goto_today
    [ "${CURRENT_YEAR}" = "$(date +%Y)" ]
    [ "${CURRENT_MONTH}" = "$(date +%-m)" ]
    [ "${SELECTED_DAY}" = "$(date +%-d)" ]
    [ "${FIRST_RENDER}" = "1" ]
}

@test "escape dispatch: CSI, SS3 and modified arrows move; tails are ignored" {
    SELECTED_DAY=15
    _handle_escape_key '[A';   [ "${SELECTED_DAY}" = "8" ]    # up
    _handle_escape_key 'OB';   [ "${SELECTED_DAY}" = "15" ]   # down (app mode)
    _handle_escape_key '[1;5C'; [ "${SELECTED_DAY}" = "16" ]  # ctrl+right
    _handle_escape_key '[5~';  [ "${SELECTED_DAY}" = "16" ]   # PgUp: no-op
    _handle_escape_key '';     [ "${SELECTED_DAY}" = "16" ]   # bare ESC: no-op
    _handle_escape_key 'a';    [ "${SELECTED_DAY}" = "16" ]   # alt+a: no-op
}

@test "vim keys move the selection" {
    SELECTED_DAY=15
    _handle_regular_keys h; [ "${SELECTED_DAY}" = "14" ]
    _handle_regular_keys l; [ "${SELECTED_DAY}" = "15" ]
    _handle_regular_keys k; [ "${SELECTED_DAY}" = "8" ]
    _handle_regular_keys j; [ "${SELECTED_DAY}" = "15" ]
}
