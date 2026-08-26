#!/usr/bin/env bats
# Events CRUD: atomicity, permissions, sorting, edge cases

load 'helper'

setup_events() {
    EVENTS_ENABLED=true
    init_events
}

@test "add + load round-trip, private permissions" {
    setup_events
    add_event "2026-08-25" "10:00" "standup"
    [ "$(stat -c %a "${EVENTS_DATA_FILE}")" = "600" ]
    [ "$(stat -c %a "${EVENTS_DATA_DIR}")" = "700" ]
    is_event 25 8
    ! is_event 26 8
}

@test "titles containing pipes round-trip through delete/edit" {
    setup_events
    add_event "2026-08-25" "10:00" "standup | sprint 42"
    add_event "2026-08-25" "11:00" "other"
    delete_event "2026-08-25" "10:00" "standup | sprint 42"
    local -a items=()
    _events_for_date items "2026-08-25"
    [ "${#items[@]}" = "1" ]
    [ "${items[0]#*$'\x1f'}" = "other" ]
}

@test "events sort chronologically, untimed last" {
    setup_events
    add_event "2026-08-25" "10:00" "b"
    add_event "2026-08-25" "" "untimed"
    add_event "2026-08-25" "09:00" "a"
    local -a items=()
    _events_for_date items "2026-08-25"
    [ "${items[0]%%$'\x1f'*}" = "09:00" ]
    [ "${items[1]%%$'\x1f'*}" = "10:00" ]
    [ "${items[2]#*$'\x1f'}" = "untimed" ]
}

@test "summary shows first event plus (+N)" {
    setup_events
    add_event "2026-08-25" "10:00" "b"
    add_event "2026-08-25" "09:00" "a"
    run get_events_summary "2026-08-25"
    [ "$output" = "09:00 a (+1)" ]
}

@test "edit replaces exactly one matching event" {
    setup_events
    add_event "2026-08-25" "09:00" "café"
    add_event "2026-08-25" "09:00" "café"
    edit_event "2026-08-25" "09:00" "café" "09:30" "café da manhã"
    local -a items=()
    _events_for_date items "2026-08-25"
    [ "${items[0]%%$'\x1f'*}" = "09:00" ]
    [ "${items[1]%%$'\x1f'*}" = "09:30" ]
}

@test "edit on an empty file leaves no blank-line garbage" {
    setup_events
    : > "${EVENTS_DATA_FILE}"
    load_events_to_memory
    edit_event "2026-08-25" "x" "y" "z" "w" || true
    [ "$(stat -c %s "${EVENTS_DATA_FILE}")" = "0" ]
}

@test "rewrites are atomic (no tempfile left behind)" {
    setup_events
    add_event "2026-08-25" "10:00" "x"
    delete_event "2026-08-25" "10:00" "x"
    run bash -c "ls '${EVENTS_DATA_DIR}'/events.tsv.?????? 2>/dev/null"
    [ "$output" = "" ]
}

@test "mutations survive a concurrent writer (flock serializes)" {
    setup_events
    add_event "2026-08-25" "10:00" "keep"
    # Two concurrent adds through the lock: both must land
    add_event "2026-08-25" "11:00" "one" &
    add_event "2026-08-25" "12:00" "two" &
    wait
    load_events_to_memory
    local -a items=()
    _events_for_date items "2026-08-25"
    [ "${#items[@]}" = "3" ]
}

@test "_is_valid_time accepts HH:MM and empty, rejects junk" {
    _is_valid_time ""
    _is_valid_time "00:00"
    _is_valid_time "23:59"
    ! _is_valid_time "24:00"
    ! _is_valid_time "9:00"
    ! _is_valid_time "09:60"
    ! _is_valid_time "abc"
}

@test "event_add_action stores the modal result (24h)" {
    setup_events
    MOCK_FORM_TIME="19:30" MOCK_FORM_TITLE="planning"
    event_add_action
    run get_events_summary "2026-08-25"
    [ "$output" = "19:30 planning" ]
}

@test "event_add_action does nothing when the modal cancels" {
    setup_events
    MOCK_FORM_RC=1 MOCK_FORM_TIME="" MOCK_FORM_TITLE=""
    event_add_action
    [ ! -s "${EVENTS_DATA_FILE}" ]
}

@test "event_edit_action rewrites via picker + form" {
    setup_events
    add_event "2026-08-25" "10:00" "old"
    MOCK_FORM_TIME="07:00" MOCK_FORM_TITLE="new"
    event_edit_action
    run get_events_summary "2026-08-25"
    [ "$output" = "07:00 new" ]
}

@test "event_delete_action honors the confirmation modal" {
    setup_events
    add_event "2026-08-25" "10:00" "x"
    MOCK_CONFIRM_RC=1 event_delete_action
    is_event 25 8
    MOCK_CONFIRM_RC=0 event_delete_action
    ! is_event 25 8
}

@test "disabled events feature is inert" {
    EVENTS_ENABLED=false
    init_events
    ! is_event 25 8
    run get_events_summary "2026-08-25"
    [ "$output" = "" ]
}
