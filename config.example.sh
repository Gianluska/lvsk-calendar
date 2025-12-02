#!/bin/bash

# lvsk-calendar User Configuration File
# Copy this file to: ~/.config/lvsk-calendar/config.sh
#
# Only include the settings you want to customize.
# All settings are optional - defaults will be used if not specified.

# ============================================================================
# COLOR SCHEME
# ============================================================================
# Available schemes: "monochrome" (default), "pastel", "nord", "dracula", "gruvbox"
COLOR_SCHEME="monochrome"

# ============================================================================
# BACKGROUND ILLUSTRATION
# ============================================================================
# Choose your background style
# Available by default: "orbital" (default), "minimal", "stars", "none"
BACKGROUND_STYLE="orbital"

# All backgrounds are in: ~/.config/lvsk-calendar/backgrounds/
# You can edit them directly or create new ones!
# To create a custom background:
#   1. Copy an existing: cp ~/.config/lvsk-calendar/backgrounds/orbital.sh ~/.config/lvsk-calendar/backgrounds/custom.sh
#   2. Edit it: nvim ~/.config/lvsk-calendar/backgrounds/custom.sh
#   3. Use it: BACKGROUND_STYLE="custom"

# ============================================================================
# DIMENSIONS
# ============================================================================
# Customize the width of UI components
# Defaults: HEADER_FRAME_WIDTH=40, FOOTER_FRAME_WIDTH=52, CALENDAR_GRID_WIDTH=38
HEADER_FRAME_WIDTH=40
FOOTER_FRAME_WIDTH=52
CALENDAR_GRID_WIDTH=38

# ============================================================================
# BEHAVIOR
# ============================================================================
# Skip splash screen on startup (true/false)
SKIP_SPLASH=false

# ============================================================================
# ADVANCED: CUSTOM COLORS
# ============================================================================
# You can override individual colors if you want full control
# Uncomment and customize as needed:
#
# COLORS[BASE]='\033[38;5;253m'           # Main text color
# COLORS[BASE_DIM]='\033[38;5;250m'       # Dimmed text
# COLORS[BASE_DIMMER]='\033[38;5;245m'    # More dimmed text
# COLORS[ACCENT]='\033[38;5;254m'         # Accent color
# COLORS[ACCENT_BRIGHT]='\033[38;5;255m'  # Bright accent
# COLORS[SUBTLE]='\033[38;5;242m'         # Subtle elements (borders, etc)
# COLORS[HIGHLIGHT]='\033[38;5;255m'      # Today/selected highlight
# COLORS[HIGHLIGHT_BG]='\033[48;5;236m'   # Today/selected background

# ============================================================================
# ADVANCED: CUSTOM CHARACTERS
# ============================================================================
# You can override individual characters for borders and indicators
# Uncomment and customize as needed:
#
# CHAR[h]='─'              # Horizontal border
# CHAR[v]='│'              # Vertical border
# CHAR[tl]='╭'             # Top-left corner
# CHAR[tr]='╮'             # Top-right corner
# CHAR[bl]='╰'             # Bottom-left corner
# CHAR[br]='╯'             # Bottom-right corner
# CHAR[dot]='·'            # Dot
# CHAR[circle]='○'         # Circle
# CHAR[filled_circle]='●'  # Filled circle
# CHAR[marker]='┃'         # Marker
