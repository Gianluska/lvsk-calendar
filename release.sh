#!/usr/bin/env bash
# One-command release: bump every version declaration, regenerate .SRCINFO,
# sanity-check, commit, tag and push. Pushing the tag triggers the Release
# workflow, which tests, builds the package from the tag and publishes the
# PKGBUILD + .SRCINFO to the AUR automatically.
#
# Usage: ./release.sh <version>        e.g. ./release.sh 0.3.11
set -o errexit -o nounset -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

die() { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }

version="${1:-}"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "usage: ./release.sh <version>  (e.g. 0.3.11)"

# --- Preconditions -----------------------------------------------------------
branch=$(git rev-parse --abbrev-ref HEAD)
[[ "${branch}" == "main" ]] || die "releases are cut from main (current: ${branch})"

[[ -z "$(git status --porcelain)" ]] \
    || die "working tree is not clean - commit or stash your changes first"

git rev-parse -q --verify "refs/tags/v${version}" >/dev/null \
    && die "tag v${version} already exists"

current=$(grep -Po '^pkgver=\K.+' PKGBUILD)
if [[ "$(printf '%s\n%s\n' "${current}" "${version}" | sort -V | tail -1)" != "${version}" \
    || "${current}" == "${version}" ]]; then
    die "new version ${version} must be greater than current ${current}"
fi

echo -e "${YELLOW}=== Releasing lvsk-calendar ${current} -> ${version} ===${NC}\n"

# --- Bump every version declaration -----------------------------------------
sed -i "s/^declare -r LVSK_VERSION=\".*\"/declare -r LVSK_VERSION=\"${version}\"/" lvsk-calendar
sed -i -e "s/^pkgver=.*/pkgver=${version}/" -e "s/^pkgrel=.*/pkgrel=1/" PKGBUILD PKGBUILD.local

./update-srcinfo.sh >/dev/null
echo -e "${GREEN}✓ Bumped lvsk-calendar, PKGBUILD, PKGBUILD.local and .SRCINFO${NC}"

# --- Sanity ------------------------------------------------------------------
bash .github/scripts/check-version.sh
for f in lvsk-calendar lvsk-calendar-launcher src/*.sh src/ui/*.sh; do
    bash -n "${f}"
done
if command -v bats >/dev/null 2>&1; then
    echo -e "${YELLOW}Running test suite...${NC}"
    bats tests/ >/dev/null && echo -e "${GREEN}✓ Tests pass${NC}"
else
    echo -e "${YELLOW}⚠ bats not installed - skipping local tests (CI will run them)${NC}"
fi

# --- Commit + tag ------------------------------------------------------------
git add lvsk-calendar PKGBUILD PKGBUILD.local .SRCINFO
git commit -q -m "chore(release): v${version}"
git tag -a "v${version}" -m "lvsk-calendar ${version}"
echo -e "${GREEN}✓ Committed and tagged v${version}${NC}\n"

# --- Push (this is the trigger for the automated AUR publish) ----------------
echo "About to push to origin:"
git log --oneline -1
echo "  tag v${version}"
echo
read -p "Push and publish? [y/N] " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Not pushed. To undo the local release:${NC}"
    echo "  git tag -d v${version} && git reset --hard HEAD~1"
    exit 0
fi

git push origin main
git push origin "v${version}"
echo
echo -e "${GREEN}✓ Pushed. GitHub Actions is now testing, building and publishing to the AUR:${NC}"
echo "  https://github.com/Gianluska/lvsk-calendar/actions"
