#!/usr/bin/env bash
# Publish the current PKGBUILD (+ freshly generated .SRCINFO and the .install
# file) to the AUR repository. Idempotent: pushes nothing when the AUR is
# already up to date.
#
# Environment:
#   AUR_SSH_PRIVATE_KEY  - private key authorized on the AUR account
#                          (required for the default ssh:// URL)
#   AUR_REPO_URL         - override for local testing, e.g. file:///tmp/bare
#   AUR_DRY_RUN=1        - do everything except the final git push
#   AUR_COMMIT_NAME/AUR_COMMIT_EMAIL - committer identity
set -o errexit -o nounset -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

AUR_REPO_URL="${AUR_REPO_URL:-ssh://aur@aur.archlinux.org/lvsk-calendar.git}"
AUR_COMMIT_NAME="${AUR_COMMIT_NAME:-Gianlucca Claudino}"
AUR_COMMIT_EMAIL="${AUR_COMMIT_EMAIL:-gianluccaclaudino@gmail.com}"

# aur.archlinux.org host key, pinned (verify against https://aur.archlinux.org
# if it ever rotates); StrictHostKeyChecking=yes makes this fail-closed
AUR_HOST_KEY='aur.archlinux.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuBKrPzbawxA/k2g6NcyV5jmqwJ2s+zpgZGZ7tpLIcN'

pkgver=$(grep -Po '^pkgver=\K.+' PKGBUILD)
pkgrel=$(grep -Po '^pkgrel=\K.+' PKGBUILD)

# CI container prerequisites (no-ops when already present / not root)
if [[ ${EUID} -eq 0 ]] && command -v pacman >/dev/null 2>&1; then
    pacman -Syu --noconfirm --needed git openssh >/dev/null
fi

# --- 1. Generate .SRCINFO from the PKGBUILD being published -----------------
# (the .install file must sit next to the PKGBUILD or makepkg refuses)
workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT
cp PKGBUILD lvsk-calendar.install "${workdir}/"
if [[ ${EUID} -eq 0 ]]; then
    # makepkg refuses root: use a throwaway user
    useradd -m builder 2>/dev/null || true
    chown -R builder:builder "${workdir}"
    su builder -c "cd '${workdir}' && makepkg --printsrcinfo > .SRCINFO"
else
    (cd "${workdir}" && makepkg --printsrcinfo > .SRCINFO)
fi
[[ -s "${workdir}/.SRCINFO" ]] || { echo "::error::failed to generate .SRCINFO"; exit 1; }

# --- 2. SSH setup (only for the real AUR remote) ----------------------------
if [[ "${AUR_REPO_URL}" == ssh://* ]]; then
    if [[ -z "${AUR_SSH_PRIVATE_KEY:-}" ]]; then
        echo "::error::AUR_SSH_PRIVATE_KEY is not set (add it as a repository secret)"
        exit 1
    fi
    ssh_dir="${HOME}/.ssh"
    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"
    printf '%s\n' "${AUR_SSH_PRIVATE_KEY}" > "${ssh_dir}/aur_ci"
    chmod 600 "${ssh_dir}/aur_ci"
    printf '%s\n' "${AUR_HOST_KEY}" > "${ssh_dir}/aur_known_hosts"
    export GIT_SSH_COMMAND="ssh -i ${ssh_dir}/aur_ci -o UserKnownHostsFile=${ssh_dir}/aur_known_hosts -o StrictHostKeyChecking=yes -o IdentitiesOnly=yes"
fi

# --- 3. Clone, sync files, commit if changed, push --------------------------
clone_dir="${workdir}/aur"
git clone "${AUR_REPO_URL}" "${clone_dir}"

cp PKGBUILD lvsk-calendar.install "${clone_dir}/"
cp "${workdir}/.SRCINFO" "${clone_dir}/"

cd "${clone_dir}"
git add -A
if git diff --cached --quiet; then
    echo "AUR is already up to date (${pkgver}-${pkgrel}); nothing to push."
    exit 0
fi

git -c user.name="${AUR_COMMIT_NAME}" -c user.email="${AUR_COMMIT_EMAIL}" \
    commit -q -m "Update to ${pkgver}-${pkgrel}" \
    -m "Published automatically by GitHub Actions from the v${pkgver} tag."

echo "==> Prepared AUR commit:"
git show --stat HEAD

if [[ -n "${AUR_DRY_RUN:-}" ]]; then
    echo "==> AUR_DRY_RUN set: skipping push."
    exit 0
fi

git push origin master
echo "==> Published ${pkgver}-${pkgrel} to the AUR."
