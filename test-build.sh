#!/bin/bash
# Script to test AUR package builds
# This script helps validate your PKGBUILD before submitting to AUR

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== AUR Build Test (Local) ===${NC}\n"

# Check if PKGBUILD.local exists
if [ ! -f "PKGBUILD.local" ]; then
    echo -e "${RED}✗ PKGBUILD.local not found!${NC}"
    exit 1
fi

# Check if lvsk-calendar executable exists
if [ ! -f "lvsk-calendar" ]; then
    echo -e "${RED}✗ lvsk-calendar executable not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PKGBUILD.local found${NC}"
echo -e "${GREEN}✓ lvsk-calendar executable found${NC}\n"

# Show package information
echo -e "${YELLOW}Package information:${NC}"
source PKGBUILD.local
echo "  Name: ${pkgname}"
echo "  Version: ${pkgver}-${pkgrel}"
echo "  Description: ${pkgdesc}"
echo "  Architecture: ${arch[@]}"
echo ""

# Ask if should continue
read -p "Continue with build? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
    echo "Build cancelled."
    exit 0
fi

# Clean previous builds
echo -e "\n${YELLOW}Cleaning previous builds...${NC}"
rm -rf src/ pkg/ *.pkg.tar.zst

# Run tests

echo -e "\n${YELLOW}1. Validating PKGBUILD with namcap...${NC}"
if command -v namcap &> /dev/null; then
    if namcap PKGBUILD.local; then
        echo -e "${GREEN}✓ namcap validation passed!${NC}"
    else
        echo -e "${YELLOW}⚠ Warnings found (check above)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ namcap not installed. Install with: sudo pacman -S namcap${NC}"
fi

echo -e "\n${YELLOW}2. Building the package...${NC}"
if makepkg -f -p PKGBUILD.local; then
    echo -e "${GREEN}✓ Build completed successfully!${NC}"
else
    echo -e "${RED}✗ Build failed!${NC}"
    exit 1
fi

# Check if package was created
PKG_FILE=$(ls -t *.pkg.tar.zst 2>/dev/null | head -1)
if [ -z "$PKG_FILE" ]; then
    echo -e "${RED}✗ .pkg.tar.zst file not found!${NC}"
    exit 1
fi

echo -e "\n${YELLOW}3. Validating built package with namcap...${NC}"
if command -v namcap &> /dev/null; then
    if namcap "$PKG_FILE"; then
        echo -e "${GREEN}✓ Package validation passed!${NC}"
    else
        echo -e "${YELLOW}⚠ Warnings found (check above)${NC}"
    fi
fi

echo -e "\n${YELLOW}4. Inspecting package contents...${NC}"
tar -tf "$PKG_FILE" | head -20
TOTAL_FILES=$(tar -tf "$PKG_FILE" | wc -l)
echo "..."
echo -e "${GREEN}✓ Total files: $TOTAL_FILES${NC}"

echo -e "\n${YELLOW}5. Checking package structure...${NC}"
tar -tf "$PKG_FILE" | grep -E '^\.PKGINFO$|^\.BUILDINFO$|^usr/' | head -10

# Ask if should install
echo -e "\n${YELLOW}=== Next steps ===${NC}"
echo -e "${GREEN}✓ Build complete and successful!${NC}"
echo ""
echo "Created file: $PKG_FILE"
echo ""
echo "To install the package:"
echo "  sudo pacman -U $PKG_FILE"
echo ""
echo "To inspect all files:"
echo "  tar -tf $PKG_FILE"
echo ""
echo "To extract and verify:"
echo "  tar -xf $PKG_FILE -C /tmp/pkg-test"
echo ""
echo "To remove after testing:"
echo "  sudo pacman -R ${pkgname}"
echo ""

read -p "Install the package now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo pacman -U "$PKG_FILE"
    echo -e "\n${GREEN}✓ Package installed!${NC}"
    echo "Verify with: pacman -Ql ${pkgname}"
fi
