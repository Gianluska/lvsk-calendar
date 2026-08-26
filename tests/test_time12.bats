#!/usr/bin/env bats
# 12-hour input layer <-> 24-hour storage conversions

load 'helper'

@test "_time12_digits_to_24: digits + period to storage format" {
    local t
    _time12_digits_to_24 t "730" AM;  [ "$t" = "07:30" ]
    _time12_digits_to_24 t "730" PM;  [ "$t" = "19:30" ]
    _time12_digits_to_24 t "0730" PM; [ "$t" = "19:30" ]
    _time12_digits_to_24 t "12" AM;   [ "$t" = "00:00" ]   # midnight
    _time12_digits_to_24 t "12" PM;   [ "$t" = "12:00" ]   # noon
    _time12_digits_to_24 t "1159" PM; [ "$t" = "23:59" ]
    _time12_digits_to_24 t "1" AM;    [ "$t" = "01:00" ]
    _time12_digits_to_24 t "" AM;     [ "$t" = "" ]        # untimed
}

@test "_time12_digits_to_24: rejects invalid hours and minutes" {
    local t
    ! _time12_digits_to_24 t "0" AM      # hour 0 (12h has no 0)
    ! _time12_digits_to_24 t "13" PM     # hour 13
    ! _time12_digits_to_24 t "1260" AM   # minute 60
    ! _time12_digits_to_24 t "060" AM    # hour 0 with minutes
}

@test "_time_24_to_12: prefill digits and period from storage" {
    local d a
    _time_24_to_12 d a "00:15"; [ "$d" = "1215" ]; [ "$a" = "AM" ]
    _time_24_to_12 d a "12:00"; [ "$d" = "1200" ]; [ "$a" = "PM" ]
    _time_24_to_12 d a "23:59"; [ "$d" = "1159" ]; [ "$a" = "PM" ]
    _time_24_to_12 d a "07:05"; [ "$d" = "0705" ]; [ "$a" = "AM" ]
    _time_24_to_12 d a "";      [ "$d" = "" ];     [ "$a" = "AM" ]
}

@test "round-trip 24h -> 12h -> 24h is the identity" {
    local d a t src
    for src in 00:00 00:59 01:00 11:59 12:00 12:01 13:00 23:59; do
        _time_24_to_12 d a "${src}"
        _time12_digits_to_24 t "${d}" "${a}"
        [ "$t" = "${src}" ]
    done
}

@test "_time24_to_12_display: fixed-width labels for the picker" {
    local l
    _time24_to_12_display l "19:30"; [ "$l" = "07:30 PM" ]
    _time24_to_12_display l "00:05"; [ "$l" = "12:05 AM" ]
    _time24_to_12_display l "";      [ "$l" = "--:--   " ]
}
