#!/usr/bin/env bash
# Shared test setup: sources the modules with all state isolated in a
# per-test tempdir. The app reads /dev/tty for input, so tests never drive
# the TUI itself - they source the modules and call functions directly,
# stubbing the interactive prompts where needed.

ROOT="${BATS_TEST_DIRNAME}/.."

setup() {
    export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
    export XDG_CACHE_HOME="${BATS_TEST_TMPDIR}/cache"
    export SRC_DIR="${ROOT}/src"

    source "${ROOT}/src/config.sh"
    source "${ROOT}/src/utils.sh"
    source "${ROOT}/src/holidays.sh"
    source "${ROOT}/src/events.sh"
    source "${ROOT}/src/ui/background.sh"
    source "${ROOT}/src/ui/modal.sh"
    source "${ROOT}/src/navigation.sh"
    source "${ROOT}/src/input.sh"

    # Deterministic date context for tests (2026-08-25 is a Tuesday)
    CURRENT_YEAR=2026
    CURRENT_MONTH=8
    SELECTED_DAY=25
    TODAY_DAY=25
    FIRST_RENDER=0
    _MC_KEY=""

    # Terminal stand-ins (no tput in the test environment)
    TERM_COLS=80
    TERM_ROWS=30
    TC_CLEAR='' TC_EL='' TC_CIVIS='' TC_CNORM=''

    # Override the interactive modals AFTER sourcing (the module definitions
    # would otherwise win). Real modals need a tty; these stubs are driven by
    # MOCK_* variables:
    #   MOCK_FORM_TIME / MOCK_FORM_TITLE / MOCK_FORM_RC - form modal result
    #   MOCK_PICK (1-based)                             - picker choice
    #   MOCK_CONFIRM_RC                                 - confirmation answer
    _event_form_modal() {
        local -n __stub_t="${1}" __stub_ti="${2}"
        __stub_t="${MOCK_FORM_TIME-}"
        __stub_ti="${MOCK_FORM_TITLE-}"
        return "${MOCK_FORM_RC:-0}"
    }
    _event_pick_modal() {
        local -n __stub_o="${1}"
        __stub_o=""
        local -a __stub_items=()
        _events_for_date __stub_items "${2}"
        ((${#__stub_items[@]} == 0)) && return 1
        __stub_o="${__stub_items[$((${MOCK_PICK:-1} - 1))]}"
        return 0
    }
    _modal_confirm() { return "${MOCK_CONFIRM_RC:-0}"; }
}
