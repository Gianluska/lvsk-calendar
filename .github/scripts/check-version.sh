#!/usr/bin/env bash
# Verify that every place a version is declared agrees before releasing:
# the app (LVSK_VERSION), PKGBUILD, PKGBUILD.local and - when running for a
# tag push - the tag itself. Publishing is refused on any mismatch, so a
# "forgot to bump X" can never reach the AUR.
set -o errexit -o nounset -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

pkgver=$(grep -Po '^pkgver=\K.+' PKGBUILD)
local_pkgver=$(grep -Po '^pkgver=\K.+' PKGBUILD.local)
app_version=$(grep -Po '^declare -r LVSK_VERSION="\K[^"]+' lvsk-calendar)

fail=0
if [[ "${pkgver}" != "${app_version}" ]]; then
    echo "::error::PKGBUILD pkgver (${pkgver}) != LVSK_VERSION (${app_version}) in lvsk-calendar"
    fail=1
fi
if [[ "${pkgver}" != "${local_pkgver}" ]]; then
    echo "::error::PKGBUILD pkgver (${pkgver}) != PKGBUILD.local pkgver (${local_pkgver})"
    fail=1
fi
if [[ -n "${RELEASE_TAG:-}" && "${RELEASE_TAG#v}" != "${pkgver}" ]]; then
    echo "::error::tag ${RELEASE_TAG} does not match pkgver ${pkgver}"
    fail=1
fi

if ((fail == 0)); then
    echo "Version consistency OK: ${pkgver}"
fi
exit "${fail}"
