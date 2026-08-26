#!/usr/bin/env bash
# Helper script to generate .SRCINFO from PKGBUILD
# This file must be committed to the AUR repository along with PKGBUILD

set -o errexit -o nounset -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ ! -f "PKGBUILD" ]]; then
    echo "Error: PKGBUILD not found in $(pwd)" >&2
    exit 1
fi

echo "Generating .SRCINFO from PKGBUILD..."
makepkg --printsrcinfo > .SRCINFO

if [[ -s ".SRCINFO" ]]; then
    echo "✓ .SRCINFO generated successfully"
    echo ""
    echo "Files ready for AUR submission:"
    ls -lh PKGBUILD .SRCINFO
    if compgen -G '*.install' > /dev/null; then
        ls -lh ./*.install
    fi
else
    echo "Error: Failed to generate .SRCINFO" >&2
    exit 1
fi
