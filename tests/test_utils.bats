#!/usr/bin/env bats
# Date arithmetic and month metadata cache

load 'helper'

@test "days_in_month: regular months" {
    [ "$(days_in_month 1 2026)" = "31" ]
    [ "$(days_in_month 4 2026)" = "30" ]
    [ "$(days_in_month 8 2026)" = "31" ]
}

@test "days_in_month: leap year rules (4 / 100 / 400)" {
    [ "$(days_in_month 2 2024)" = "29" ]   # divisible by 4
    [ "$(days_in_month 2 1900)" = "28" ]   # century, not by 400
    [ "$(days_in_month 2 2000)" = "29" ]   # divisible by 400
    [ "$(days_in_month 2 2026)" = "28" ]
}

@test "_epoch_of matches date -u across boundaries" {
    local d ep want y m day rest
    for d in 1970-01-01 1999-12-31 2000-02-29 2024-02-29 2026-08-25 2100-02-28; do
        y=${d%%-*}; rest=${d#*-}; m=${rest%%-*}; day=${rest#*-}
        m=${m#0}; day=${day#0}
        _epoch_of ep "$y" "$m" "$day"
        want=$(date -u -d "${d} 00:00:00" +%s)
        [ "$ep" = "$want" ]
    done
}

@test "refresh_month_cache: name, first dow, days, ISO weeks" {
    refresh_month_cache
    [ "${_MC_DAYS}" = "31" ]
    [ "${_MC_NAME}" = "$(date -u -d 2026-08-01 +%B)" ]
    [ "${_MC_FIRST_DOW}" = "$(date -u -d 2026-08-01 +%u)" ]
    [ "${_MC_WEEK_NUMS[0]}" = "$(date -u -d 2026-08-01 +%V)" ]
    local start=$((9 - _MC_FIRST_DOW))
    [ "${_MC_WEEK_NUMS[1]}" = "$(date -u -d "2026-08-0${start}" +%V)" ]
}

@test "refresh_month_cache: no recompute while month unchanged" {
    refresh_month_cache
    _MC_NAME="CANARY"
    refresh_month_cache
    [ "${_MC_NAME}" = "CANARY" ]
}

@test "_is_valid_date bounds" {
    _is_valid_date 1 1
    _is_valid_date 31 12
    ! _is_valid_date 0 5
    ! _is_valid_date 32 5
    ! _is_valid_date 5 13
    ! _is_valid_date x 5
}

@test "_repeat_v builds repeated strings without forks" {
    local s
    _repeat_v s '─' 5
    [ "$s" = "─────" ]
    _repeat_v s 'x' 0
    [ "$s" = "" ]
}

@test "_char_len counts characters in any locale" {
    local n
    _char_len n "abc";        [ "$n" = "3" ]
    _char_len n "";           [ "$n" = "0" ]
    _char_len n "a·b";        [ "$n" = "3" ]   # · is 2 bytes
    _char_len n "◂ ▸ · ─ ◆";  [ "$n" = "9" ]   # 3-byte glyphs
    # Under a byte locale ${#} miscounts, _char_len must not
    run bash -c "
        export LC_ALL=C
        source '${ROOT}/src/utils.sh'
        s=\$'\xc2\xb7\xc2\xb7'          # two middle dots (4 bytes)
        _char_len n \"\$s\"
        echo \"\${#s} \$n\"
    "
    [ "$output" = "4 2" ]
}
