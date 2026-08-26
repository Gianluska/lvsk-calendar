#!/usr/bin/env bash
# Build the Arch package exactly like an AUR user would (the PKGBUILD clones
# the pushed GitHub tag), then prove the result is sane: required files are
# inside the package and, when possible, the installed binary answers
# --version with the right number. Run inside an archlinux container in CI;
# runs locally too (BUILD_PKGBUILD=PKGBUILD.local skips the network clone).
set -o errexit -o nounset -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
REPO_ROOT=$(pwd)

BUILD_PKGBUILD="${BUILD_PKGBUILD:-PKGBUILD}"
pkgver=$(grep -Po '^pkgver=\K.+' "${BUILD_PKGBUILD}")

# CI container prerequisites (no-ops when already present / not root)
if [[ ${EUID} -eq 0 ]] && command -v pacman >/dev/null 2>&1; then
    pacman -Syu --noconfirm --needed git namcap >/dev/null
fi

# makepkg refuses to run as root: build under a throwaway user in CI
run_makepkg() { # $1=directory $2...=makepkg args
    local dir="${1}"
    shift
    if [[ ${EUID} -eq 0 ]]; then
        useradd -m builder 2>/dev/null || true
        chown -R builder:builder "${dir}"
        su builder -c "cd '${dir}' && makepkg $*"
    else
        (cd "${dir}" && makepkg "$@")
    fi
}

build_dir=$(mktemp -d)
trap 'rm -rf "${build_dir}"' EXIT
cp "${BUILD_PKGBUILD}" "${build_dir}/PKGBUILD"
cp lvsk-calendar.install "${build_dir}/"
if [[ "${BUILD_PKGBUILD}" == "PKGBUILD.local" ]]; then
    # local variant packages from startdir: give it the working tree
    cp -r lvsk-calendar lvsk-calendar-launcher config.example LICENSE README.md \
        src backgrounds "${build_dir}/"
fi

echo "==> Building ${BUILD_PKGBUILD} (pkgver ${pkgver})..."
run_makepkg "${build_dir}" --noconfirm -f

pkg_file=$(find "${build_dir}" -maxdepth 1 -name '*.pkg.tar.zst' | head -1)
[[ -n "${pkg_file}" ]] || { echo "::error::no package produced"; exit 1; }

echo "==> Verifying package contents..."
required=(
    usr/bin/lvsk-calendar
    usr/bin/lvsk-calendar-launcher
    usr/share/lvsk-calendar/src/events.sh
    usr/share/lvsk-calendar/src/ui/modal.sh
    usr/share/licenses/lvsk-calendar/LICENSE
    usr/share/doc/lvsk-calendar/config.example
)
listing=$(tar -tf "${pkg_file}")
for f in "${required[@]}"; do
    if ! grep -qx "${f}" <<<"${listing}"; then
        echo "::error::package is missing ${f}"
        exit 1
    fi
done
echo "All required files present ($(wc -l <<<"${listing}") entries)"

# Real smoke: install and ask the packaged binary its version (root/CI only)
if [[ ${EUID} -eq 0 ]]; then
    echo "==> Installing and smoke-testing..."
    pacman -U --noconfirm "${pkg_file}" >/dev/null
    got=$(lvsk-calendar --version)
    if [[ "${got}" != "lvsk-calendar ${pkgver}" ]]; then
        echo "::error::installed binary reports '${got}', expected 'lvsk-calendar ${pkgver}'"
        exit 1
    fi
    echo "Installed binary OK: ${got}"
fi

# Advisory lint (never fails the build)
if command -v namcap >/dev/null 2>&1; then
    echo "==> namcap (advisory):"
    namcap "${pkg_file}" || true
fi

mkdir -p "${REPO_ROOT}/dist"
cp "${pkg_file}" "${REPO_ROOT}/dist/"
echo "==> Package ready: dist/$(basename "${pkg_file}")"
