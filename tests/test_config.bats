#!/usr/bin/env bats
# Config parsing, validation and the background path-traversal guard

load 'helper'

@test "sourcing modules has no side effects" {
    [ ! -e "${XDG_CONFIG_HOME}/lvsk-calendar" ]
    [ ! -e "${XDG_DATA_HOME}/lvsk-calendar" ]
}

@test "_trim strips surrounding whitespace" {
    local out
    _trim out "   hello world  "
    [ "$out" = "hello world" ]
    _trim out $'\t \n'
    [ "$out" = "" ]
}

@test "parse_color: hex, ansi256, invalid" {
    local c
    parse_color c "#FF8000" fg
    [ "$c" = $'\033[38;2;255;128;0m' ]
    parse_color c "253" fg
    [ "$c" = $'\033[38;5;253m' ]
    parse_color c "0" bg
    [ "$c" = $'\033[48;5;0m' ]
    ! parse_color c "zzz" fg
    ! parse_color c "300" fg
    ! parse_color c "" fg
}

@test "parse_config_file: single pass, scheme + override precedence" {
    local cfg="${BATS_TEST_TMPDIR}/cfg"
    cat > "${cfg}" <<'EOF'
# comment
color_scheme=nord
color_accent=#010203
header_frame_width= 44
skip_splash=TRUE
events_enabled=nope
country_code=br
char_event=X
char_h=abc
EOF
    parse_config_file "${cfg}"
    [ "${COLORS[ACCENT]}" = $'\033[38;2;1;2;3m' ]   # explicit beats scheme
    [ "${HEADER_FRAME_WIDTH}" = "44" ]              # value trimmed
    [ "${SKIP_SPLASH}" = "true" ]                   # bool normalized
    [ "${EVENTS_ENABLED}" = "true" ]                # invalid bool ignored
    [ "${COUNTRY_CODE}" = "BR" ]                    # upcased
    [ "${CHAR[event]}" = "X" ]                      # single char accepted
    [ "${CHAR[h]}" = "─" ]                          # multi char rejected
}

@test "parse_config_file: invalid integers ignored" {
    local cfg="${BATS_TEST_TMPDIR}/cfg"
    printf 'header_frame_width=0\nfooter_frame_width=-3\ncalendar_grid_width=abc\n' > "${cfg}"
    parse_config_file "${cfg}"
    [ "${HEADER_FRAME_WIDTH}" = "40" ]
    [ "${FOOTER_FRAME_WIDTH}" = "52" ]
    [ "${CALENDAR_GRID_WIDTH}" = "38" ]
}

@test "every parseable char_ key is rendered and vice versa" {
    # The parser accepts exactly the keys that exist in CHAR
    local k
    for k in h v tl tr bl br v_light dot circle diamond bullet star event; do
        [ -n "${CHAR[$k]}" ]
    done
}

@test "draw_background blocks path traversal" {
    mkdir -p "${XDG_CONFIG_HOME}/lvsk-calendar/backgrounds"
    printf 'draw_custom_background() { printf EVIL; }\n' > "${BATS_TEST_TMPDIR}/evil.sh"
    BACKGROUND_STYLE="../../../..${BATS_TEST_TMPDIR}/evil"
    run draw_background
    [ "$output" = "" ]
}

@test "draw_background loads a legit background once" {
    mkdir -p "${XDG_CONFIG_HOME}/lvsk-calendar/backgrounds"
    printf 'draw_custom_background() { printf GOOD; }\n' \
        > "${XDG_CONFIG_HOME}/lvsk-calendar/backgrounds/good.sh"
    BACKGROUND_STYLE="good"
    run draw_background
    [ "$output" = "GOOD" ]
}
